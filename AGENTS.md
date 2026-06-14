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
BRANCH created by executor: feat/description, fix/description, or chore/description
    ↓
CODE written and tested locally
    ↓
COMMIT with Conventional Commits message
    ↓
PR opened against main
    ↓
HERMES reviews the PR
   ├── approved ──→ PR merged (squash) → branch deleted
   └── changes requested ──→ CODE updated → back to COMMIT
```

## Git Conventions

- **Account:** `to-ge-da` (not personal account)
- **Auth:** `gh` CLI via `mise exec gh -- gh ...`
- **Clone:** `mise exec gh -- gh repo clone to-ge-da/hermes-self-hosted`
- **Branch from:** `main` (always update local main first)
- **Branch naming:** `feat/short-description`, `fix/short-description`, or `chore/short-description`
- **NEVER commit or push to main**
- **Commit messages:** Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, etc.)
- **PRs:** Squash merge, delete branch after merge
- **Updating this file:** AGENTS.md is a living document — update it whenever a workflow or convention change is agreed upon during PR review

## Code Standards

- **Scripts:** `scripts/` directory, `#!/bin/bash`, `set -euo pipefail`
- **Documentation:** `docs/` directory, Markdown, English
- **Conventions:**
  - No hardcoded admin usernames (detect via `$SUDO_USER`)
  - Scripts must handle both interactive and non-interactive modes
  - Add `--help` flag to all scripts

## Testing

- Run `shellcheck` on all new/edited scripts
- Test in a VM (VirtualBox) with a fresh Debian install
- Run the full install flow to verify it completes without errors

## Communication

- Hermes communicates in English (technical docs) or Portuguese (conversation)
- OpenCode is prompted in English
