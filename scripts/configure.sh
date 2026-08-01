#!/usr/bin/env bash
set -euo pipefail

host="${1:-}"
contact_url="${2:-}"
port="${3:-8080}"
gateway_bind_address="${4:-0.0.0.0}"
gateway_port="${5:-$port}"
trusted_forwarder="${6:-false}"

if [[ -z "$host" || -z "$contact_url" ]]; then
  echo "Usage: $0 <LAN-host-or-IP> <contact-url> [port]" >&2
  echo "Example: $0 192.168.1.50 https://example.com/contact 8080" >&2
  echo "A monitored HTTPS contact page is required for the public OpenStreetMap tile service." >&2
  exit 2
fi

if [[ ! "$host" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "Host must be an IPv4 address or DNS name without a scheme or path." >&2
  exit 2
fi
if [[ ! "$contact_url" =~ ^https://[A-Za-z0-9./_?=%+-]+$ ]]; then
  echo "Contact must be an HTTPS URL without spaces." >&2
  exit 2
fi
if [[ ! "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
  echo "Port must be between 1 and 65535." >&2
  exit 2
fi
if [[ ! "$gateway_port" =~ ^[0-9]+$ ]] || ((gateway_port < 1 || gateway_port > 65535)); then
  echo "Gateway port must be between 1 and 65535." >&2
  exit 2
fi
if [[ "$gateway_bind_address" != "0.0.0.0" && "$gateway_bind_address" != "127.0.0.1" ]]; then
  echo "Gateway bind address must be 0.0.0.0 or 127.0.0.1." >&2
  exit 2
fi
if [[ "$trusted_forwarder" != "true" && "$trusted_forwarder" != "false" ]]; then
  echo "Trusted-forwarder mode must be true or false." >&2
  exit 2
fi
if [[ "$trusted_forwarder" == "true" && "$port" == "$gateway_port" ]]; then
  echo "Public and Docker backend ports must differ in trusted-forwarder mode." >&2
  exit 2
fi

for command in docker jq; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_dir="$project_dir/runtime"
site_dir="$runtime_dir/site"
base_url="http://${host}:${port}"
download_url="${base_url}/sources/OpenStreetMap-MapProxy.xml"
encoded_url="$(jq -nr --arg value "$download_url" '$value|@uri')"
import_uri="tak://com.atakmap.app/import?url=${encoded_url}"
upstream_user_agent="mapproxy-atak/1.0 (+${contact_url})"

mkdir -p "$site_dir"

printf 'MAPPROXY_BIND_ADDRESS=%s\nMAPPROXY_PORT=%s\nPUBLIC_PORT=%s\nGRAFANA_BIND_ADDRESS=127.0.0.1\nGRAFANA_PORT=3000\n' \
  "$gateway_bind_address" "$gateway_port" "$port" > "$project_dir/.env.tmp"
mv "$project_dir/.env.tmp" "$project_dir/.env"

if [[ "$trusted_forwarder" == "true" ]]; then
  printf '%s\n' \
    'set_real_ip_from 172.16.0.0/12;' \
    'set_real_ip_from 192.168.0.0/16;' \
    'set_real_ip_from 10.0.0.0/8;' \
    'real_ip_header X-Forwarded-For;' \
    'real_ip_recursive on;' > "$runtime_dir/real-ip.conf.tmp"
else
  printf '%s\n' '# Direct LAN mode: use the socket source address.' > "$runtime_dir/real-ip.conf.tmp"
fi
mv "$runtime_dir/real-ip.conf.tmp" "$runtime_dir/real-ip.conf"

sed \
  -e "s|__PUBLIC_PORT__|${port}|g" \
  -e "s|__BACKEND_PORT__|${gateway_port}|g" \
  "$project_dir/templates/Caddyfile.template" > "$runtime_dir/Caddyfile.tmp"
mv "$runtime_dir/Caddyfile.tmp" "$runtime_dir/Caddyfile"

cp "$project_dir/templates/mapproxy.yaml.template" "$runtime_dir/mapproxy.yaml.tmp"
mv "$runtime_dir/mapproxy.yaml.tmp" "$runtime_dir/mapproxy.yaml"

sed "s|__OSM_USER_AGENT__|${upstream_user_agent}|g" \
  "$project_dir/templates/upstream-nginx.conf.template" > "$runtime_dir/upstream-nginx.conf.tmp"
mv "$runtime_dir/upstream-nginx.conf.tmp" "$runtime_dir/upstream-nginx.conf"

for template in "$project_dir"/templates/*.xml.template; do
  output_name="$(basename "$template" .template)"
  sed "s|__PUBLIC_BASE_URL__|${base_url}|g" \
    "$template" > "$runtime_dir/${output_name}.tmp"
  mv "$runtime_dir/${output_name}.tmp" "$runtime_dir/$output_name"
done

sed \
  -e "s|__PUBLIC_BASE_URL__|${base_url}|g" \
  -e "s|__IMPORT_URI__|${import_uri}|g" \
  -e "s|__CONTACT_URL__|${contact_url}|g" \
  "$project_dir/templates/index.html.template" > "$site_dir/index.html.tmp"
mv "$site_dir/index.html.tmp" "$site_dir/index.html"

docker run --rm \
  -e QR_DATA="$import_uri" \
  -e OUTPUT_UID="$(id -u)" \
  -e OUTPUT_GID="$(id -g)" \
  -e PIP_DISABLE_PIP_VERSION_CHECK=1 \
  -e PIP_ROOT_USER_ACTION=ignore \
  -v "$site_dir:/out" \
  python:3.13-alpine \
  sh -c 'pip install --quiet --no-cache-dir "qrcode[pil]==8.2" >/dev/null && python -c "import os,qrcode; qrcode.make(os.environ[\"QR_DATA\"]).save(\"/out/atak-import-qr.png\")" && chown "$OUTPUT_UID:$OUTPUT_GID" /out/atak-import-qr.png'

printf 'Configured ATAK MapProxy\n\n'
printf '  Install page: %s/\n' "$base_url"
printf '  ATAK XML:    %s\n' "$download_url"
printf '  OSM contact: %s\n\n' "$contact_url"
printf 'Start with: docker compose up -d --wait\n'
