# Hermes Self-Hosted

Prepare a Debian host and install one Hermes Agent instance. This repo covers bootstrap and hardening; the agent itself comes from the official installer.

One instance per host. VPS and EC2 are not documented yet.

## Product site

GitHub Pages product page (DIY docs + interest in a preinstalled host): built from `site/` + `docs/` via `.github/workflows/pages.yml`.

After Pages is enabled (Settings → Pages → Source: **GitHub Actions**), the site is at `https://to-ge-da.github.io/hermes-self-hosted/`.

### Donations

Bitcoin and Monero only — no pricing table. Addresses live in [`site/donations.yml`](site/donations.yml) (empty until the owner pastes real wallets). The site shows a coin only when its address is non-empty.

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
| [gateway-platforms.md](docs/hermes/gateway-platforms.md) | Day 2 — Telegram and SimpleX |
| [GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md) | Issue and PR templates |
| [AGENTS.md](AGENTS.md) | Repo conventions |

## Hermes Agent

Install, uninstall, dashboard, day-2 gateway platforms, and profile templates. Index: [docs/hermes/README.md](docs/hermes/README.md).

## Forks

Cursor trees hosted here, not the install path. Index: [docs/forks/README.md](docs/forks/README.md).

Layout: `scripts/` (bootstrap, hardening, mise), `config/` (example bootstrap YAML), `templates/` (profile starters), `docs/`, `site/` (GitHub Pages product site source).

## Contributing

Use the Bug, Feature, or Task issue template and the PR template. Conventional Commits; branch from `main` as `feat/`, `fix/`, `chore/`, or `docs/`. Details: [AGENTS.md](AGENTS.md).
