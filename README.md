# Hermes Self-Hosted

Deploy Hermes Agent on a home server (bare-metal or virtualized).

## Goal

Run Hermes Agent 24/7 on dedicated hardware, with a clean, step-by-step documented installation.

## Stack

- **OS**: Debian Server
- **Hardware**: Fujitsu, 16GB RAM, 120GB SSD, no GPU
- **Models**: External API (OpenRouter) — local inference to be evaluated later

## Project Structure

```
.
├── README.md
├── docs/
│   ├── BOOTSTRAP.md       # Initial system setup: users, SSH, base config
│   ├── HARDENING.md       # Server security hardening
│   ├── NETWORK.md         # Static IP and DNS configuration
│   ├── INSTALL-HERMES.md  # Hermes Agent installation guide
│   └── GITHUB_TEMPLATES.md# GitHub templates documentation
├── scripts/
│   ├── examples/          # Original legacy scripts (reference)
│   │   ├── hardening-linux-01.sh
│   │   └── hardening-linux-02.sh
│   ├── bootstrap.sh       # Interactive first-boot setup
│   └── hardening.sh       # Security hardening (run after bootstrap)
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md   # PR template with checklist
│   └── ISSUE_TEMPLATE/
│       ├── task.md                # General task template
│       ├── bug.md                 # Bug report template
│       └── feature.md             # Feature request template
```

## Installation Order

1. **[bootstrap.sh](scripts/bootstrap.sh)** — System update, users, SSH keys, hostname
2. **[hardening.sh](scripts/hardening.sh)** — Firewall, kernel, auditd, file permissions
3. **[NETWORK.md](docs/NETWORK.md)** — Configure static IP and DNS
4. **[INSTALL-HERMES.md](docs/INSTALL-HERMES.md)** — Install Hermes Agent and gateway

## Contributing

We use GitHub templates to standardize issues and pull requests. See **[docs/GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md)** for details.

When contributing:
- Choose the right issue template (Bug Report, Feature Request, or Task)
- Follow the PR template checklist
- Use Conventional Commits for commit messages
- Branch from `main` with naming: `feat/...`, `fix/...`, or `chore/...`

See [docs/](docs/) for detailed guides.
