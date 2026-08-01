#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

grafana_port="${GRAFANA_PORT:-}"
if [[ -z "$grafana_port" && -f .env ]]; then
  grafana_port="$(sed -n 's/^GRAFANA_PORT=//p' .env | tail -n 1)"
fi
grafana_port="${grafana_port:-3000}"
base_url="http://127.0.0.1:${grafana_port}"

attempts=1
if [[ "${1:-}" == "--wait" ]]; then
  attempts=30
fi

ready=false
for ((attempt = 1; attempt <= attempts; attempt++)); do
  if health="$(curl --fail --silent --max-time 5 "${base_url}/api/health" 2>/dev/null)" &&
    jq -e '.database == "ok"' <<<"$health" >/dev/null; then
    ready=true
    break
  fi
  sleep 1
done

if [[ "$ready" != "true" ]]; then
  echo "Grafana API did not become ready at ${base_url}." >&2
  exit 1
fi

curl --fail --silent --show-error --max-time 5 \
  "${base_url}/api/dashboards/uid/mapproxy-operations" |
  jq -e '.dashboard.uid == "mapproxy-operations"' >/dev/null

while IFS=$'\t' read -r query_type expression; do
  endpoint="query"
  extra_args=()
  if [[ "$query_type" == "range" ]]; then
    endpoint="query_range"
    extra_args=(--data-urlencode "since=15m" --data-urlencode "limit=10")
  fi

  curl --fail --silent --show-error --max-time 10 --get \
    --data-urlencode "query=${expression}" \
    "${extra_args[@]}" \
    "${base_url}/api/datasources/proxy/uid/loki/loki/api/v1/${endpoint}" |
    jq -e '.status == "success"' >/dev/null
done < <(jq -r '.panels[] | .targets[]? | [.queryType, .expr] | @tsv' \
  monitoring/grafana/dashboards/mapproxy.json)

echo "Monitoring validation passed."
