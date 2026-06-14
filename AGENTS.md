# AGENTS.md — Project Workflow Guide

This file guides AI agents (Hermes, OpenCode) on how to work with this repository.

## Project Overview

**Repo:** `to-ge-da/hermes-self-hosted`  
**Purpose:** Deploy Hermes Agent on a Debian server (bare-metal, VM, or VPS).  
**Stack:** Bash scripts + Hermes Agent (Python/Node.js via Hermes' own installer).

## Team Roles

| Role | Tool | What they do |
|---|---|---|
| **Coordinator** | Hermes | Issues, planning, code review, PR management |
| **Executor** | OpenCode CLI | Local coding, testing, pushing code |

## Workflow (Issue → Code → PR)

```
ISSUE created by Hermes (describes the task)
    ↓
BRANCH created by executor: feat/description or fix/description
    ↓
CODE written and tested locally
    ↓
COMMIT with Conventional Commits message
    ↓
PR opened against main
    ↓
HERMES reviews the PR
    ↓
PR merged (squash) → branch deleted
```

## Git Conventions

- **Account:** `to-ge-da` (not personal account)
- **Auth:** `gh` CLI via `mise exec gh -- gh ...`
- **Clone:** `mise exec gh -- gh repo clone to-ge-da/hermes-self-hosted`
- **Branch from:** `main` (always update local main first)
- **Branch naming:** `feat/short-description` or `fix/short-description`
- **NEVER commit or push to main**
- **Commit messages:** Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, etc.)
- **PRs:** Squash merge, delete branch after merge

## Code Standards

- **Scripts:** `scripts/` directory, `#!/bin/bash`, `set -euo pipefail`
- **Documentation:** `docs/` directory, Markdown, English
- **Conventions:**
  - Run `shellcheck` on new/edited scripts
  - No hardcoded admin usernames (detect via `$SUDO_USER`)
  - Scripts must handle both interactive and non-interactive modes
  - Add `--help` flag to all scripts

## Testing

- Test scripts in a VM (VirtualBox) before opening a PR
- The VM must have a fresh Debian install
- Commands: `sudo ./scripts/bootstrap.sh` then `sudo ./scripts/hardening.sh`

## Communication

- Hermes communicates in English (technical docs) or Portuguese (conversation)
- OpenCode is prompted in English
