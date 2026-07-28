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

## Docs

| Doc | Topic |
|---|---|
| [INSTALLATION.md](docs/INSTALLATION.md) | Ordered self-hosted install path |
| [BOOTSTRAP.md](docs/BOOTSTRAP.md) | First-boot host setup (purpose, config, usage, state) |
| [SSH-KEYS.md](docs/SSH-KEYS.md) | SSH keys for the hermes user |
| [HARDENING.md](docs/HARDENING.md) | Security hardening |
| [NETWORK.md](docs/NETWORK.md) | Static IP and DNS |
| [INSTALL-HERMES.md](docs/INSTALL-HERMES.md) | Hermes Agent install |
| [testing-custom-forks.md](docs/testing-custom-forks.md) | Test a custom Hermes fork with Cursor |
| [FILE-TRANSFER.md](docs/FILE-TRANSFER.md) | Copy files to the host |
| [MISE.md](docs/MISE.md) | Mise tools, system-wide activation, uninstall |
| [GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md) | Issue and PR templates |
| [AGENTS.md](AGENTS.md) | Development conventions (humans + Cursor) |

Layout: `scripts/` (bootstrap, hardening, mise helpers), `config/` (example bootstrap YAML), `docs/`.

## Contributing

- Use the right issue template (Bug, Feature, or Task) — see [GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md)
- Follow the PR template
- Conventional Commits; branch from `main` as `feat/...`, `fix/...`, or `chore/...`
- Full conventions: [AGENTS.md](AGENTS.md)
