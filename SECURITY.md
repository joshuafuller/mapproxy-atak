# Security policy

## Supported versions

Security fixes are made on the current `main` branch. Until tagged releases are
published, older commits are not maintained as separate supported versions.

## Reporting a vulnerability

Please do not open a public issue for a vulnerability that could expose a
deployment, credentials, or private network information. Use the repository's
private vulnerability-reporting feature under **Security → Advisories → New
draft security advisory**, including reproduction details and affected files
or versions.

## Deployment notes

This project serves unauthenticated HTTP on a trusted LAN by default. Do not
expose it directly to the public internet. For untrusted networks, place it
behind an authenticated TLS reverse proxy and review all configured upstream
credentials and cache contents before sharing diagnostics.

Generated XML files and QR codes contain the deployment's LAN address. They are
ignored by Git, but operators should still treat exported diagnostics and
screenshots as potentially sensitive.
