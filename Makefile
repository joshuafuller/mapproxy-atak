SHELL := /usr/bin/env bash
CONTACT ?=
PORT ?= 8080
BACKEND_PORT ?= 18080

.PHONY: configure configure-windows-forwarder windows-up windows-down up down restart logs status validate cache-size monitoring-up monitoring-down monitoring-status monitoring-validate windows-forwarder-install windows-forwarder-up windows-forwarder-down windows-forwarder-status

configure:
	@test -n "$(HOST)" || (echo "Usage: make configure HOST=192.168.1.50 CONTACT=https://example.com/contact [PORT=8080]" >&2; exit 2)
	@test -n "$(CONTACT)" || (echo "CONTACT is required when using the public OpenStreetMap tile service." >&2; exit 2)
	./scripts/configure.sh "$(HOST)" "$(CONTACT)" "$(PORT)"

configure-windows-forwarder:
	@test -n "$(HOST)" || (echo "Usage: make configure-windows-forwarder HOST=192.168.1.50 CONTACT=https://example.com/contact [PORT=8080] [BACKEND_PORT=18080]" >&2; exit 2)
	@test -n "$(CONTACT)" || (echo "CONTACT is required when using the public OpenStreetMap tile service." >&2; exit 2)
	./scripts/configure.sh "$(HOST)" "$(CONTACT)" "$(PORT)" 127.0.0.1 "$(BACKEND_PORT)" true

windows-up:
	@test -n "$(HOST)" || (echo "Usage: make windows-up HOST=192.168.1.50 CONTACT=https://example.com/contact" >&2; exit 2)
	@test -n "$(CONTACT)" || (echo "CONTACT is required when using the public OpenStreetMap tile service." >&2; exit 2)
	$(MAKE) windows-forwarder-install
	$(MAKE) configure-windows-forwarder HOST="$(HOST)" CONTACT="$(CONTACT)" PORT="$(PORT)" BACKEND_PORT="$(BACKEND_PORT)"
	$(MAKE) up
	$(MAKE) windows-forwarder-up

windows-down:
	$(MAKE) windows-forwarder-down
	$(MAKE) down

up:
	@test -f runtime/mapproxy.yaml || (echo "Run 'make configure HOST=<LAN-IP>' first." >&2; exit 2)
	docker compose up -d --force-recreate --wait

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

status:
	docker compose ps

validate:
	./scripts/validate.sh

cache-size:
	@du -sh cache_data
	@docker compose exec -T tile-cache du -sh /var/cache/nginx 2>/dev/null || true

monitoring-up:
	docker compose --profile monitoring up -d --wait
	@./scripts/validate-monitoring.sh --wait
	@echo "Grafana: http://127.0.0.1:$${GRAFANA_PORT:-3000}/d/mapproxy-operations"

monitoring-down:
	docker compose --profile monitoring stop grafana alloy loki

monitoring-status:
	docker compose --profile monitoring ps

monitoring-validate:
	./scripts/validate-monitoring.sh

windows-forwarder-install:
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$(wslpath -w scripts/windows-forwarder.ps1)" install

windows-forwarder-up:
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$(wslpath -w scripts/windows-forwarder.ps1)" start -ConfigPath "$$(wslpath -w runtime/Caddyfile)"

windows-forwarder-down:
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$(wslpath -w scripts/windows-forwarder.ps1)" stop

windows-forwarder-status:
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$(wslpath -w scripts/windows-forwarder.ps1)" status
