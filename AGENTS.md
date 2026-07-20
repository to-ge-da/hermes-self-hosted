# hermes-self-hosted — Development Guide

Guides Hermes and OpenCode on workflow and conventions for this repository.

## Project Overview

**Repo:** `to-ge-da/hermes-self-hosted` — Deploy Hermes Agent on Debian.  
**Stack:** Bash scripts + Hermes Agent (via official installer).

## Team Roles

| Role | Tool | What they do |
|---|---|---|
| **Architect / Coordinator** | Hermes | Design, planning, issue creation, code review, PR management |
| **Executor** | OpenCode CLI | Local coding, testing, pushing code |

## Labels

| Label | Purpose |
|---|---|
| `hermes` | Architect/coordinator work — planning, design, review |
| `opencode` | Executor work — coding, testing, PRs |

Issue type labels (`bug`, `enhancement`, `documentation`) coexist with team labels.

## Workflow (Issue → Code → PR)

```
ISSUE created by Hermes (describes the task, gets `hermes` label)
    ↓
BRANCH created by executor: feat/description, fix/description, or chore/description
    ↓
CODE written and tested locally
    ↓
COMMIT with Conventional Commits message
    ↓
PR opened against main (gets `opencode` label if tracking executor work)
    ↓
HERMES reviews the PR
   ├── approved ──→ PR merged (squash) → branch deleted
   └── changes requested ──→ CODE updated → back to COMMIT
```

## Git Conventions

- Use `gh` CLI for all GitHub operations (issues, PRs, merge)
- Branch from `main`: `feat/`, `fix/`, or `chore/` prefix
- Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)
- Squash merge, delete branch after merge
- **NEVER commit or push to main**

## Code Standards

- **Scripts:** `scripts/`, `#!/bin/bash`, `set -euo pipefail`, `--help` flag; bootstrap is config-driven (YAML via `--config`, no interactive prompts)
- **Documentation:** `docs/` directory, Markdown

## Testing

- Run `shellcheck` on all new/edited scripts
- Test in a VM (VirtualBox) with a fresh Debian install
- Run the full install flow to verify it completes without errors

## Issue Type Guidance

- **Task** (`task.md`) — default for any work with clear scope
- **Feature** (`feature.md`) — new capability needing problem/solution/alternatives breakdown
- **Bug** (`bug.md`) — unexpected behavior with reproduction steps

## Issue Lifecycle

Research → Discussion → Implementation → PR → Review → Merge.
Not every issue needs all stages — simple tasks go straight to implementation.

## Project Phases

Bootstrap (`bootstrap.sh`) → Hardening (`hardening.sh`) → Hermes install (official installer) → Profiles (TBD).



