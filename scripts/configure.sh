#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

# Run the Dockerized generator as the current host user. Generated deployment
# files stay editable without granting the setup container root access.
exec docker compose run --rm --build \
  --user "$(id -u):$(id -g)" \
  configure "$@"
