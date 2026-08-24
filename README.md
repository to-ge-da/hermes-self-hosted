# Hermes Self-Hosted

Prepare a Debian host and install one Hermes Agent instance. This repo covers bootstrap and hardening; the agent itself comes from the official installer.

One instance per host. VPS and EC2 are not documented yet.

## Stack

- OS: Debian Server
- Models: OpenRouter (external API). Local inference is TBD.

## Install docs

The ordered path is in [INSTALLATION.md](docs/INSTALLATION.md).

| Doc | Topic |
|---|---|
| [INSTALLATION.md](docs/INSTALLATION.md) | Ordered self-hosted install |
| [BOOTSTRAP.md](docs/BOOTSTRAP.md) | First-boot host setup |
| [SSH-KEYS.md](docs/SSH-KEYS.md) | SSH keys for the hermes user |
| [HARDENING.md](docs/HARDENING.md) | Security hardening |
| [NETWORK.md](docs/NETWORK.md) | Static IP and DNS |
| [install.md](docs/hermes/install.md) | Hermes Agent install |
| [FILE-TRANSFER.md](docs/FILE-TRANSFER.md) | Copy files to the host |
| [MISE.md](docs/MISE.md) | Mise tools |

## Other docs

| Doc | Topic |
|---|---|
| [uninstall.md](docs/hermes/uninstall.md) | Remove Hermes Agent |
| [profile-templates.md](docs/hermes/profile-templates.md) | USER.md / MEMORY.md starters |
| [dashboard-service.md](docs/hermes/dashboard-service.md) | Dashboard as a background service |
| [GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md) | Issue and PR templates |
| [AGENTS.md](AGENTS.md) | Repo conventions |

## Forks

Cursor trees hosted here, not the install path. Index: [docs/forks/README.md](docs/forks/README.md).

Layout: `scripts/` (bootstrap, hardening, mise), `config/` (example bootstrap YAML), `templates/` (profile starters), `docs/`.

## Contributing

Use the Bug, Feature, or Task issue template and the PR template. Conventional Commits; branch from `main` as `feat/`, `fix/`, `chore/`, or `docs/`. Details: [AGENTS.md](AGENTS.md).

## Quick start

1. Clone this repository.
2. Install prerequisites from project files.
3. Build and run the project's standard tests.
