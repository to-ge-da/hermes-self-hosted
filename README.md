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
│   ├── bootstrap.md       # Initial system setup: users, SSH, base config
│   └── hardening.md       # Server security hardening
├── scripts/
│   ├── examples/          # Original legacy scripts (reference)
│   │   ├── hardening-linux-01.sh
│   │   └── hardening-linux-02.sh
│   ├── bootstrap.sh       # Interactive first-boot setup
│   ├── hardening.sh       # Security hardening (run after bootstrap)
│   └── install-hermes.sh  # Hermes Agent installation (coming soon)
└── config/                # Hermes configuration files (coming soon)
```

## Installation Order

1. **[bootstrap.sh](scripts/bootstrap.sh)** — System update, users, SSH keys, hostname
2. **[hardening.sh](scripts/hardening.sh)** — Firewall, kernel, auditd, file permissions
3. **install-hermes.sh** — Hermes Agent + gateway (planned)

See [docs/](docs/) for detailed guides.
