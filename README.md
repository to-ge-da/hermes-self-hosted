# Hermes Self-Hosted

Deploy a **Hermes Agent instance** on Debian.

## What this is

This repository prepares a Debian host and installs **one** Hermes Agent instance (bootstrap/hardening + the official Hermes installer).

**Limits today:** one instance per host. Multi-instance is not supported yet.

## Deployment targets

| Target | Status |
|---|---|
| Self-hosted (local machine or local VM) | Documented and supported |
| VPS | Not covered yet |
| Amazon EC2 | Not covered yet |

## Stack

- **OS:** Debian Server
- **Models:** External API (OpenRouter) — local inference TBD

## Installation order (self-hosted)

1. **[FILE-TRANSFER.md](docs/FILE-TRANSFER.md)** — Copy config/keys to the host (`scp` / `rsync`) as needed
2. **[bootstrap.sh](scripts/bootstrap.sh)** — Config-driven system update, users, SSH keys, hostname (`--config`)
3. **[hardening.sh](scripts/hardening.sh)** — Firewall, kernel, auditd, file permissions
4. **[NETWORK.md](docs/NETWORK.md)** — Configure static IP and DNS
5. **[INSTALL-HERMES.md](docs/INSTALL-HERMES.md)** — Install Hermes Agent and gateway
6. **[MISE-SYSTEM-WIDE.md](docs/MISE-SYSTEM-WIDE.md)** — System-wide mise activation (optional)

## Docs

| Doc | Topic |
|---|---|
| [BOOTSTRAP.md](docs/BOOTSTRAP.md) | Initial system setup |
| [BOOTSTRAP-CONFIG.md](docs/BOOTSTRAP-CONFIG.md) | Bootstrap YAML schema and state |
| [SSH-KEYS.md](docs/SSH-KEYS.md) | SSH keys for the hermes user |
| [HARDENING.md](docs/HARDENING.md) | Security hardening |
| [NETWORK.md](docs/NETWORK.md) | Static IP and DNS |
| [INSTALL-HERMES.md](docs/INSTALL-HERMES.md) | Hermes Agent install |
| [FILE-TRANSFER.md](docs/FILE-TRANSFER.md) | Copy files to the host |
| [MISE-SYSTEM-WIDE.md](docs/MISE-SYSTEM-WIDE.md) | System-wide mise |
| [GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md) | Issue and PR templates |
| [AGENTS.md](AGENTS.md) | Development conventions (humans + Cursor) |

Layout: `scripts/` (bootstrap, hardening, mise helpers), `config/` (example bootstrap YAML), `docs/`.

## Contributing

- Use the right issue template (Bug, Feature, or Task) — see [GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md)
- Follow the PR template checklist
- Conventional Commits; branch from `main` as `feat/...`, `fix/...`, or `chore/...`
- Full conventions: [AGENTS.md](AGENTS.md)
