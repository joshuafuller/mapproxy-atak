# Contributing

Thanks for helping improve ATAK MapProxy.

Start with the [Docker guide](docs/DOCKER.md) for a development environment and
the [map-layer guide](docs/ADDING-MAP-LAYERS.md) for the configuration model.

## Development workflow

1. Fork and clone the repository.
2. Configure a local runtime:

   ```bash
   ./scripts/configure.sh \
     127.0.0.1 https://example.com/contact 18080
   ```

3. Start and validate it:

   ```bash
   docker compose up -d --force-recreate --wait
   ./scripts/validate.sh --live
   ```

4. Keep pull requests focused and explain how the change was tested.
5. Confirm generated deployment files remain untracked:

   ```bash
   git status --short
   git ls-files runtime cache_data
   ```

## Adding map providers

Before adding an upstream source, document:

- its official usage and caching policy;
- required attribution;
- authentication or API-key requirements;
- supported zoom range and geographic coverage;
- whether offline download or prefetching is allowed; and
- an operator contact strategy for the upstream User-Agent.

A source being publicly reachable does not mean it may be proxied, cached, or
redistributed. Sources without clear permission should remain disabled.

Follow the complete checklist in
[Adding map layers](docs/ADDING-MAP-LAYERS.md#layer-checklist).

## Style

- Shell scripts must pass `bash -n` and should use `set -euo pipefail`.
- Generated files belong in `runtime/`; cached tiles belong in `cache_data/`.
- Do not commit LAN addresses, secrets, generated QR codes, or private contact
  information.
- Preserve the north-west XYZ origin expected by ATAK.
- Do not commit generated XML files, `.env`, cache content, API keys, or
  credentials.

## Pull requests

Before opening a pull request:

```bash
./scripts/validate.sh
./scripts/validate.sh --live
git diff --check
```

For documentation-only changes, `git diff --check` is sufficient if no runtime
behavior changed. Describe any provider-policy assumptions explicitly.
