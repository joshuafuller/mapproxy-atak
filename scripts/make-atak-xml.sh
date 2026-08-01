#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Note: make-atak-xml.sh is retained for compatibility; use configure.sh for new installs." >&2
exec "$project_dir/scripts/configure.sh" "$@"
