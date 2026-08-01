#!/usr/bin/env bash
set -euo pipefail

host="${1:-}"
contact_url="${2:-}"
public_port="${3:-8080}"
backend_port="${4:-18080}"

if [[ -z "$host" || -z "$contact_url" ]]; then
  echo "Usage: $0 <Windows-LAN-IP> <contact-url> [public-port] [backend-port]" >&2
  echo "Example: $0 192.168.1.50 https://example.com/contact" >&2
  exit 2
fi

for command in docker powershell.exe wslpath; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w scripts/windows-forwarder.ps1)" install

docker compose run --rm configure \
  "$host" "$contact_url" "$public_port" 127.0.0.1 "$backend_port" true
docker compose up -d --force-recreate --wait

powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w scripts/windows-forwarder.ps1)" start \
  -ConfigPath "$(wslpath -w runtime/Caddyfile)"

printf '\nReady: http://%s:%s/\n' "$host" "$public_port"
