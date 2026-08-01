<div align="center">
  <img src="docs/assets/banner.svg" alt="ATAK MapProxy — one uplink fetch, many LAN clients" width="100%">

  <p>
    <img alt="Docker Compose" src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white">
    <img alt="MapProxy 7.0" src="https://img.shields.io/badge/MapProxy-7.0-69DD8B">
    <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-A9BCAE">
  </p>

  <p><strong>A shared OpenStreetMap cache for field networks.</strong></p>
  <p>Built for Starlink, satellite backhaul, incident networks, and other constrained connections.</p>
</div>

---

## What is this project?

ATAK MapProxy is a self-hosted map server for devices sharing a local network.
It runs with Docker on one Windows, Linux, or macOS host and gives ATAK clients
one LAN address for OpenStreetMap raster tiles.

When a client requests a tile, the server checks its local caches first. A
missing or expired tile is retrieved upstream only when somebody is actively
viewing it; repeat requests from other clients stay on the LAN. This is useful
when a team shares constrained backhaul such as Starlink, satellite, cellular,
or a temporary incident-network uplink.

The project includes:

- a MapProxy tile endpoint with visible
  [OpenStreetMap attribution](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines);
- a generated install page, ATAK XML source, deep link, and deployment-specific
  QR code;
- two persistent cache layers for rendered tiles and upstream responses;
- Windows/WSL forwarding that preserves real LAN client addresses; and
- an optional real-time Grafana operations dashboard.

It is not a bulk downloader, an offline-map archive builder, or a public tile
service. Its public OpenStreetMap configuration is demand-driven and intended
only for normal interactive viewing under the upstream usage policy.

## Why run it locally?

When several field devices view the same area, they should not each download
the same map tiles across the uplink.

- The first request for a missing tile retrieves it upstream.
- MapProxy stores the result on the Docker host.
- Later requests reuse the LAN cache.
- Stale tiles are revalidated only when somebody views them again.

```mermaid
flowchart TB
    subgraph LAN[Field LAN]
        direction TB
        CLIENTS["ATAK clients<br/>A · B · C · …"] --> GATEWAY[LAN gateway]
        GATEWAY --> PROXY[MapProxy]
        PROXY <--> RENDERED[(Rendered tiles)]
        PROXY --> RAW[HTTP cache]
        RAW <--> RESPONSES[(Raw responses)]
    end

    RAW -->|miss or stale revalidation| LINK[Starlink / constrained backhaul]
    LINK --> OSM[OpenStreetMap]

    classDef local fill:#102319,stroke:#69dd8b,color:#edf7ef,stroke-width:2px;
    classDef cache fill:#173c24,stroke:#69dd8b,color:#edf7ef;
    classDef uplink fill:#342b12,stroke:#e7bd45,color:#fff5cf;
    class CLIENTS,GATEWAY,PROXY local;
    class RENDERED,RAW,RESPONSES cache;
    class LINK,OSM uplink;
```

The cache is demand-driven. It does not pre-seed or create offline archives
from the public OSM tile service.

## Quick start

Install [Docker](https://docs.docker.com/get-started/get-docker/) and Git. Then
clone or download this repository and enter its directory:

```bash
git clone https://github.com/joshuafuller/mapproxy-atak.git
cd mapproxy-atak
```

### Windows with WSL

Find the Windows LAN address with `ipconfig.exe`. Use the IPv4 address under the
active Wi-Fi or Ethernet adapter—not the private WSL address.

```bash
./scripts/windows-up.sh 192.168.1.50 https://maps.example.org/contact
```

The Windows command installs a local Caddy forwarder. This preserves real LAN
client addresses that Docker Desktop would otherwise replace with a bridge
address.

### Native Linux or direct Docker

Find the host's LAN address with `ip -4 address`, then run:

```bash
./scripts/configure.sh \
  192.168.1.50 https://maps.example.org/contact
docker compose up -d --force-recreate --wait
```

Replace the example address and contact URL. Configuration intentionally fails
without an operator-controlled, monitored HTTPS contact page. The generated
upstream identity is `mapproxy-atak/1.0 (+CONTACT_URL)`, allowing OSM operators
to identify the service and reach its operator without embedding personal
details in this repository.

For complete Windows, Linux, macOS, firewall, and troubleshooting instructions,
read the [Docker and network guide](docs/DOCKER.md).

### Generated LAN install page

[![Generated ATAK MapProxy LAN install page](docs/assets/install-page.png)](docs/assets/install-page.png)

*The QR area is intentionally replaced in this screenshot. Every deployment
generates its own QR code for that LAN address.*

## Add the map to ATAK

On the ATAK device, open the install page:

```text
http://192.168.1.50:8080/
```

Then choose one method:

1. Tap **Add to ATAK**.
2. Download and import the XML.
3. Display the page on another screen and scan its QR code.

Select **OSM Standard — © OpenStreetMap contributors (Local MapProxy)** in the
map or imagery selector.

The XML and QR code are generated for the deployment under ignored `runtime/`.
They are never committed to the repository.

## Operations dashboard

Monitoring is optional. Start it when you need an event-operations wallboard:

```bash
docker compose --profile monitoring up -d --wait
```

Open [http://127.0.0.1:3000/d/mapproxy-operations](http://127.0.0.1:3000/d/mapproxy-operations).

[![Grafana operations dashboard showing cache reuse](docs/assets/operations-dashboard.png)](docs/assets/operations-dashboard.png)

*Dashboard shown with synthetic client activity against already-cached tiles.*

The Grafana dashboard is organized into seven sections:

- live 10-second demand;
- five-minute efficiency;
- LAN and upstream payload;
- latency and reliability;
- cache behavior;
- client and map demand; and
- errors and slow requests.

It includes estimated upstream payload avoided. That estimate compares
application-layer tile bodies; it does not measure TCP, VPN, retransmission, or
satellite-modem overhead.

See [Monitoring](docs/MONITORING.md) for metric definitions, client-IP handling,
privacy, retention, and LAN access.

## Cache and OpenStreetMap behavior

| Layer | Default behavior |
| --- | --- |
| ATAK client | Revalidates with the LAN proxy after 24 hours. |
| Rendered tile cache | Refreshes a viewed tile after seven days. |
| Raw HTTP cache | Honors upstream freshness headers; seven days is the fallback. |
| Inactive raw response | Eligible for removal after 90 days. |
| Upstream protocol | HTTP/1.1; HTTP/2 and HTTP/3 are not currently supported. |

Rendered tiles persist in ignored `cache_data/`. Raw responses persist in the
Docker volume `osm_http_cache_v2`. A normal `docker compose down` preserves
both.

> [!IMPORTANT]
> Do not use ATAK's offline-download feature against `tile.openstreetmap.org`.
> For offline coverage, use data you host or a provider that explicitly permits
> downloading and redistribution.

The public OSM source is for demand-driven, human-interactive viewing only. For
sustained operational demand, preloaded coverage, or guaranteed availability,
use a suitable tile provider or self-hosted data instead.

OpenStreetMap attribution appears in the layer name, install page, and every
rendered tile. Before deployment, review the current
[OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/),
[OSMF attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines),
[OSM copyright page](https://www.openstreetmap.org/copyright), and
[report-a-map-issue page](https://www.openstreetmap.org/fixthemap).

## Common Docker commands

| Command | Purpose |
| --- | --- |
| `docker compose ps` | Show container health and ports. |
| `docker compose logs -f` | Follow service logs. |
| `docker compose up -d --force-recreate --wait` | Start the map services, load generated configuration, and wait for health checks. |
| `docker compose down` | Stop the map services while preserving caches. |
| `docker compose --profile monitoring up -d --wait` | Start the map services and dashboard. |
| `docker compose --profile monitoring stop grafana alloy loki` | Stop only the dashboard services. |

## Add more maps

MapProxy can serve reviewed XYZ, TMS, WMS, and WMTS sources. The
[map-layer guide](docs/ADDING-MAP-LAYERS.md) explains the configuration,
attribution, caching, validation, and provider-policy checks.

It also explains how self-hosted vector MBTiles or PMTiles can be rendered into
raster tiles with English-preferred labels for ATAK. Existing raster PNG tiles
cannot be translated because their labels are already baked into the image.

## Project notes

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a map provider.
- Report vulnerabilities through the repository's private security-advisory
  workflow described in [SECURITY.md](SECURITY.md).
- This project is not affiliated with or endorsed by TAK.GOV, Starlink, or the
  OpenStreetMap Foundation.

Built with [MapProxy](https://mapproxy.org/), nginx, Docker, Grafana, Loki,
Alloy, Caddy, and OpenStreetMap.

## License

Project code and documentation are available under the [MIT License](LICENSE).
That license does not grant rights to upstream tiles, map data, branding, or
third-party services.
