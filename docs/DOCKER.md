# Docker and network guide

This guide explains how to install, start, update, and troubleshoot ATAK
MapProxy. No previous Docker experience is required.

## What Docker runs

Docker Compose starts three containers:

| Container | Job | Exposed to the LAN? |
| --- | --- | --- |
| `gateway` | Serves the green install page, XML files, and public tile URLs. | Yes, port 8080 by default. |
| `mapproxy` | Renders attribution and stores finished raster tiles. | No. |
| `tile-cache` | Caches raw OSM responses and performs conditional revalidation. | No. |

Containers are isolated processes built from published images. Compose creates
them, connects them to a private network, and mounts persistent storage. You do
not need to install nginx, Python, or MapProxy directly on the host.

## Windows with WSL

### 1. Install Docker Desktop

1. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/).
2. Start Docker Desktop.
3. Open **Settings → General** and enable the WSL 2 based engine.
4. Open **Settings → Resources → WSL Integration**.
5. Enable integration for the Linux distribution where this repository lives.
6. Select **Apply & restart**.

Open a new WSL terminal and check the connection:

```bash
docker version
docker compose version
```

`docker version` should show both a Client and Server section. If it shows only
the client or cannot reach the daemon, Docker Desktop is not running or WSL
integration is not enabled for that distribution.

### 2. Install command-line prerequisites

Inside WSL:

```bash
sudo apt-get update
sudo apt-get install -y curl git jq ripgrep
```

### 3. Find the Windows LAN address

Inside WSL, run:

```bash
ipconfig.exe
```

Find the active **Wireless LAN adapter Wi-Fi** or **Ethernet adapter** and copy
its IPv4 address. It commonly looks like `192.168.1.50` or `10.0.0.25`.

Do not use:

- `127.0.0.1` in the ATAK XML;
- the address from `hostname -I` inside WSL; or
- an address belonging to a disconnected adapter, VPN, or virtual switch.

The ATAK device must be able to reach the Windows LAN address.

### 4. Configure and start

From the repository in WSL:

```bash
make windows-up \
  HOST=192.168.1.50 \
  CONTACT=https://maps.example.org/contact
```

Replace both example values. The contact should be an operator-controlled,
monitored HTTPS page when the public OSM service is used.

This Windows entry point installs Caddy with Windows Package Manager, binds the
Docker gateway to `127.0.0.1:18080`, and exposes the public port through a
Windows-native forwarder. Caddy sees the LAN socket address and supplies a
trusted `X-Forwarded-For` value to nginx. This prevents Docker Desktop's NAT
address from collapsing every dashboard client into one entry.

After a reboot, start the Docker containers and forwarder again with the same
`make windows-up` command. Check the forwarder independently with:

```bash
make windows-forwarder-status
```

### 5. Test Windows access

First test inside WSL:

```bash
curl http://127.0.0.1:18080/healthz
```

Then open this in a Windows browser:

```text
http://192.168.1.50:8080/
```

Finally, open the same LAN URL on the ATAK device.

### 6. Allow Windows Firewall only if necessary

If localhost works but another LAN device cannot connect, allow inbound TCP
8080 on the Windows **Private** network profile. From an elevated PowerShell:

```powershell
New-NetFirewallRule `
  -DisplayName "ATAK MapProxy 8080" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 8080 `
  -Action Allow `
  -Profile Private
```

Do not open this port on a public network profile. To remove the rule later:

```powershell
Remove-NetFirewallRule -DisplayName "ATAK MapProxy 8080"
```

Docker host networking is not required. The public listener runs natively on
Windows while the Docker backend remains loopback-only.

## Linux

Install Docker Engine and the Compose plugin using Docker's official
[installation instructions](https://docs.docker.com/engine/install/). Add your
user to the Docker group only if that matches your host's security policy.

Install the remaining tools on Ubuntu or Debian:

```bash
sudo apt-get update
sudo apt-get install -y curl git jq ripgrep
```

Find a LAN address:

```bash
ip -4 address
```

Then configure and start:

```bash
make configure HOST=192.168.1.50 CONTACT=https://maps.example.org/contact
make up
```

If a host firewall is enabled, allow the configured TCP port from the trusted
LAN only.

## macOS

Install and start [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/),
then install Git and `jq` with your preferred package manager. Find the active
address under **System Settings → Network** and use it as `HOST`.

```bash
make configure HOST=192.168.1.50 CONTACT=https://maps.example.org/contact
make up
```

## First startup

`make up` performs the equivalent of:

```bash
docker compose up -d --force-recreate --wait
```

The options mean:

- `-d`: run in the background;
- `--force-recreate`: load newly generated configuration files; and
- `--wait`: return only after the health checks pass or startup fails.

The first run downloads container images and takes longer than later starts.

Check the result:

```bash
make status
```

All three services should report `healthy`.

## Day-to-day operation

### View logs

```bash
make logs
```

Press `Ctrl+C` to stop following logs. This does not stop the containers.

### Stop the service

```bash
make down
```

This removes the containers and private network but preserves both caches.

On Windows/WSL, stop both the native forwarder and Docker services with:

```bash
make windows-down
```

### Start it again

```bash
make up
```

### Change the address or port

```bash
make configure HOST=maps.lan CONTACT=https://maps.example.org/contact PORT=9090
make up
```

Changing the port also changes the generated ATAK XML, install link, and QR
code. Re-import the XML on clients after changing the host or port.

### Update container images

```bash
docker compose pull
make up
```

Review release notes and retest before updating a field deployment.

## Persistent data

| Data | Location | Survives `make down`? | Committed to Git? |
| --- | --- | --- | --- |
| Rendered tiles | `cache_data/` | Yes | No |
| Raw HTTP responses | Docker volume `osm_http_cache` | Yes | No |
| Generated config, XML, page, and QR | `runtime/` | Yes | No |
| Port settings | `.env` | Yes | No |

`docker compose down --volumes` removes the raw response volume. It does not
remove `cache_data/`, `runtime/`, or `.env`.

Inspect cache sizes:

```bash
make cache-size
```

## Troubleshooting

### Docker command not found

Install Docker Desktop or Docker Engine and open a new terminal. On WSL, verify
that Docker Desktop integration is enabled for the correct distribution.

### Cannot connect to the Docker daemon

Start Docker Desktop or the Linux Docker service. Confirm `docker version`
shows a Server section.

### Port 8080 is already in use

Choose another port:

```bash
make configure HOST=192.168.1.50 CONTACT=https://maps.example.org/contact PORT=9090
make up
```

Use `http://192.168.1.50:9090/` on the ATAK device.

### Containers are unhealthy

Run:

```bash
make status
docker compose logs --no-color --tail=100
```

Common causes are an invalid generated configuration, no internet connection
during the first image pull, or Docker Desktop not having enough resources.

### Localhost works but the ATAK device cannot connect

Check, in order:

1. The ATAK device and host are on the same trusted LAN.
2. The XML was generated with the host's LAN address, not `127.0.0.1` or WSL's
   private address.
3. `make status` shows `0.0.0.0:8080->80/tcp` for the gateway.
4. The host firewall permits the configured TCP port on the private LAN.
5. Wi-Fi client isolation or guest-network isolation is disabled.
6. A VPN is not forcing traffic away from the local network.

### The XML downloads as the wrong file type

Run `make up` to reload `site-nginx.conf`, then check:

```bash
curl -I http://127.0.0.1:8080/sources/OpenStreetMap-MapProxy.xml
```

The response should contain `Content-Type: application/xml`.

### ATAK imports the XML but no tiles appear

Open the tile endpoint in a host browser and inspect logs:

```bash
make logs
```

Also verify that the host has internet access, the device can reach the LAN
gateway, and the chosen layer appears in ATAK's imagery selector.

### Validate everything

```bash
make validate
./scripts/validate.sh --live
```

The live validator automatically discovers the port published by Compose.
