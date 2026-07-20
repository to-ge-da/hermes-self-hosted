# hermes-self-hosted — Development Guide

Conventions for humans and Cursor working in this repository.

## Project Overview

**Repo:** `to-ge-da/hermes-self-hosted`

Scripts and docs to prepare a Debian host and install one Hermes Agent instance
(bootstrap, hardening, then the official Hermes installer).

| Target | Status |
|---|---|
| Self-hosted (local machine or local VM) | Documented and supported |
| VPS | Not covered yet |
| Amazon EC2 | Not covered yet |

Single instance per host today. Multi-instance is not supported.

**Stack:** Bash scripts + Hermes Agent (official installer). Models via external API (OpenRouter); local inference TBD.

In this repo, **Hermes** means the agent product, its system user, and the install target — not a GitHub workflow role.

## Git Conventions

- Use `gh` CLI for all GitHub operations (issues, PRs, merge)
- Branch from `main`: `feat/`, `fix/`, or `chore/` prefix
- Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)
- Squash merge, delete branch after merge
- **NEVER commit or push to `main`**

## Code Standards

- **Scripts:** `scripts/`, `#!/bin/bash`, `set -euo pipefail`, `--help` flag; bootstrap is config-driven (YAML via `--config`, no interactive prompts)
- **Documentation:** `docs/` directory, Markdown

## Testing

- Run `shellcheck` on all new/edited scripts
- Test in a VM (VirtualBox) with a fresh Debian install
- Run the full install flow (self-hosted path) to verify it completes without errors

## Project Phases

Mise tools (prerequisite) → Bootstrap (`bootstrap.sh`) → Hardening (`hardening.sh`) → Network → Hermes install (official installer) → Profiles (TBD).

These phases describe the **self-hosted** instance path today. Full ordered path with links: [docs/INSTALLATION.md](docs/INSTALLATION.md).
