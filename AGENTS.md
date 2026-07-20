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

## Issue Type Guidance

- **Task** (`task.md`) — scoped implementation work (docs, chores, refactors)
- **Feature** (`feature.md`) — new capability needing problem/solution/alternatives
- **Bug** (`bug.md`) — unexpected behavior with reproduction steps

Use issue-type labels (`bug`, `enhancement`, `documentation`) as needed. There are no role labels.

## Issue Lifecycle

Research → Discussion → Implementation → PR → Review → Merge.

Not every issue needs all stages — simple tasks can go straight to implementation.

## Project Phases

Bootstrap (`bootstrap.sh`) → Hardening (`hardening.sh`) → Hermes install (official installer) → Profiles (TBD).

These phases describe the **self-hosted** instance path today.
