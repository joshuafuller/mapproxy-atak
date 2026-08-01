#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

for file in runtime/mapproxy.yaml runtime/upstream-nginx.conf runtime/real-ip.conf runtime/Caddyfile runtime/OpenStreetMap-MapProxy.xml runtime/site/index.html runtime/site/atak-import-qr.png; do
  if [[ ! -f "$file" ]]; then
    echo "Missing generated file: $file (run scripts/configure.sh first)" >&2
    exit 1
  fi
done

bash -n scripts/*.sh
jq empty monitoring/grafana/dashboards/mapproxy.json
jq -e '
  (.panels | map(.id) | length) == (.panels | map(.id) | unique | length) and
  (.panels | map(.title) | length) == (.panels | map(.title) | unique | length) and
  all(.panels[]; .gridPos.x >= 0 and .gridPos.y >= 0 and
      .gridPos.w > 0 and .gridPos.h > 0 and
      (.gridPos.x + .gridPos.w) <= 24) and
  all(.panels[] | select(.type != "row");
      (.description | type == "string") and (.description | length > 0)) and
  all(.panels[] | select(.type == "timeseries"); .interval == "10s") and
  all(.panels[] | select(.type == "barchart");
      .options.legend.showLegend == false and
      all(.targets[]; .queryType == "instant")) and
  all(.panels[] | select(.type == "stat" and .id != 6);
      all(.targets[]; .expr | contains("or vector(0)"))) and
  (.panels | map(.type) | index("piechart") | not) and
  (.panels[] | select(.id == 6) |
      .type == "stat" and .fieldConfig.defaults.noValue == "No source-cache activity") and
  (.panels[] | select(.id == 7) |
      any(.transformations[]; .id == "organize") and
      any(.transformations[]; .id == "sortBy"))
' monitoring/grafana/dashboards/mapproxy.json >/dev/null
if jq -r '.panels[] | [.id,.gridPos.x,.gridPos.y,.gridPos.w,.gridPos.h] | @tsv' \
  monitoring/grafana/dashboards/mapproxy.json |
  awk -F '\t' '
    {
      for (i = 0; i < count; i++) {
        if ($2 < x[i] + width[i] && x[i] < $2 + $4 &&
            $3 < y[i] + height[i] && y[i] < $3 + $5) {
          print "Dashboard panels overlap: " $1 " and " id[i]
          failed = 1
        }
      }
      id[count] = $1
      x[count] = $2
      y[count] = $3
      width[count] = $4
      height[count] = $5
      count++
    }
    END { exit failed }
  '; then
  :
else
  exit 1
fi
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh
fi
if command -v yamllint >/dev/null 2>&1; then
  yamllint \
    compose.yaml \
    templates/mapproxy.yaml.template \
    monitoring/loki.yaml \
    monitoring/grafana/provisioning/datasources/*.yaml \
    monitoring/grafana/provisioning/dashboards/*.yaml \
    .github/workflows/*.yml \
    .github/ISSUE_TEMPLATE/*.yml
fi
docker compose config --quiet
docker compose --profile monitoring config --quiet
if rg --quiet '^set_real_ip_from ' runtime/real-ip.conf; then
  rg --quiet '^MAPPROXY_BIND_ADDRESS=127\.0\.0\.1$' .env
fi

if rg -n '__[A-Z0-9_]+__' runtime; then
  echo "Unresolved placeholder found in generated runtime files." >&2
  exit 1
fi
private_domain='sigma''defense'
private_name='sigma'' defense'
if rg -n -i "${private_domain}|${private_name}" . --glob '!cache_data/**' --glob '!runtime/**' --glob '!.git/**'; then
  echo "Private-domain reference found in tracked project files." >&2
  exit 1
fi

docker run --rm \
  -v "$project_dir/runtime:/work:ro" \
  python:3.13-alpine \
  python -c 'import glob,xml.etree.ElementTree as ET; files=glob.glob("/work/*.xml"); assert files; assert all(ET.parse(f).getroot().tag == "customMapSource" for f in files)'

rg --quiet '© OpenStreetMap contributors' runtime/OpenStreetMap-MapProxy.xml
rg --quiet '© OpenStreetMap contributors' runtime/site/index.html
rg --quiet 'https://www.openstreetmap.org/copyright' runtime/site/index.html
rg --quiet 'watermark:' runtime/mapproxy.yaml
rg --quiet '© OpenStreetMap contributors' runtime/mapproxy.yaml
rg --quiet 'refresh_before:' runtime/mapproxy.yaml
rg --quiet 'days: 7' runtime/mapproxy.yaml
rg --quiet 'expires_hours: 24' runtime/mapproxy.yaml
rg --quiet 'proxy_cache_revalidate on;' runtime/upstream-nginx.conf
rg --quiet 'proxy_cache_valid 200 7d;' runtime/upstream-nginx.conf
rg --quiet 'https://tile.openstreetmap.org' runtime/upstream-nginx.conf
rg --quiet 'User-Agent "MapProxyCache/1.0' runtime/upstream-nginx.conf
if rg --quiet 'spacing: wide' runtime/mapproxy.yaml; then
  echo "Watermark must appear on every tile; wide spacing is not allowed." >&2
  exit 1
fi

echo "Static validation passed."

if [[ "${1:-}" == "--live" ]]; then
  port="${MAPPROXY_PORT:-}"
  if [[ -z "$port" ]]; then
    published_address="$(docker compose port gateway 80)"
    port="${published_address##*:}"
  fi
  port="${port:-8080}"
  base="http://127.0.0.1:${port}"
  curl --fail --silent --show-error --max-time 5 "${base}/healthz" >/dev/null
  curl --fail --silent --show-error --max-time 5 "${base}/mapproxy/demo/" >/dev/null
  docker compose exec -T tile-cache wget -q -T 3 -O /dev/null http://127.0.0.1/healthz
  content_type="$(curl --fail --silent --show-error --max-time 5 --head "${base}/sources/OpenStreetMap-MapProxy.xml" | tr -d '\r' | awk 'BEGIN{IGNORECASE=1} /^Content-Type:/ {print $2}')"
  [[ "$content_type" == "application/xml" ]] || { echo "Unexpected XML Content-Type: $content_type" >&2; exit 1; }
  echo "Live validation passed."
fi
