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
│   ├── BOOTSTRAP.md         # Initial system setup: users, SSH, base config
│   ├── BOOTSTRAP-CONFIG.md  # Config schema, mise, state conventions
│   ├── FILE-TRANSFER.md     # Copy files to the host (scp / rsync)
│   ├── SSH-KEYS.md          # Generate SSH keys for the hermes user
│   ├── HARDENING.md         # Server security hardening
│   ├── NETWORK.md           # Static IP and DNS configuration
│   ├── INSTALL-HERMES.md    # Hermes Agent installation guide
│   ├── MISE-SYSTEM-WIDE.md  # System-wide mise activation
│   └── GITHUB_TEMPLATES.md  # GitHub templates documentation
├── config/
│   └── bootstrap.example.yaml  # Copy to bootstrap.yaml (gitignored)
├── mise.toml                # Pinned host tools (yq) for bootstrap
├── scripts/
│   ├── examples/            # Original legacy scripts (reference)
│   │   ├── hardening-linux-01.sh
│   │   └── hardening-linux-02.sh
│   ├── bootstrap.sh         # Config-driven first-boot setup
│   ├── hardening.sh         # Security hardening (run after bootstrap)
│   └── install-mise-system-wide.sh  # System-wide mise activation
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md   # PR template with checklist
│   └── ISSUE_TEMPLATE/
│       ├── task.md                # General task template
│       ├── bug.md                 # Bug report template
│       └── feature.md             # Feature request template
```

## Installation Order

1. **[FILE-TRANSFER.md](docs/FILE-TRANSFER.md)** — Copy config/keys to the host (`scp` / `rsync`) as needed
2. **[bootstrap.sh](scripts/bootstrap.sh)** — Config-driven system update, users, SSH keys, hostname (`--config`)
3. **[hardening.sh](scripts/hardening.sh)** — Firewall, kernel, auditd, file permissions
4. **[NETWORK.md](docs/NETWORK.md)** — Configure static IP and DNS
5. **[INSTALL-HERMES.md](docs/INSTALL-HERMES.md)** — Install Hermes Agent and gateway
6. **[MISE-SYSTEM-WIDE.md](docs/MISE-SYSTEM-WIDE.md)** — System-wide mise activation (optional)

## Contributing

We use GitHub templates to standardize issues and pull requests. See **[docs/GITHUB_TEMPLATES.md](docs/GITHUB_TEMPLATES.md)** for details.

When contributing:
- Choose the right issue template (Bug Report, Feature Request, or Task)
- Follow the PR template checklist
- Use Conventional Commits for commit messages
- Branch from `main` with naming: `feat/...`, `fix/...`, or `chore/...`

See [docs/](docs/) for detailed guides.
