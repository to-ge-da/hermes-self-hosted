# hermes-self-hosted — Development Guide

Guides Hermes and OpenCode on workflow and conventions for this repository.

## Project Overview

**Repo:** `to-ge-da/hermes-self-hosted`  
**Purpose:** Deploy Hermes Agent on a Debian server (bare-metal, VM, or VPS).  
**Stack:** Bash scripts + Hermes Agent (Python/Node.js via Hermes' own installer).

## Team Roles

| Role | Tool | What they do |
|---|---|---|
| **Architect / Coordinator** | Hermes | Design, planning, issue creation, code review, PR management |
| **Executor** | OpenCode CLI | Local coding, testing, pushing code |

## Labels Convention

| Label | Assigner | Purpose |
|---|---|---|
| `hermes` | Hermes | Issues that Hermes coordinates — planning, design decisions, review |
| `opencode` | Hermes or OpenCode | Issues/PRs that OpenCode executes — coding, testing, pushing |

- Every issue created by Hermes gets the `hermes` label
- When a PR is ready for review, the `opencode` label can be applied if tracking executor work
- Issue type labels (`bug`, `enhancement`, `documentation`) follow GitHub defaults

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

- **Account:** `to-ge-da` (not personal account)
- **Auth:** `gh` CLI (available on PATH via `mise activate`)
- **Clone:** `gh repo clone to-ge-da/hermes-self-hosted`
- **Branch from:** `main` (always update local main first)
- **Branch naming:** `feat/short-description`, `fix/short-description`, or `chore/short-description`
- **NEVER commit or push to main**
- **Commit messages:** Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, etc.)
- **PRs:** Squash merge, delete branch after merge
- **Updating this file:** AGENTS.md is a living document — update it whenever a workflow or convention change is agreed upon during PR review

## Code Standards

- **Scripts:** `scripts/` directory, `#!/bin/bash`, `set -euo pipefail`
- **Documentation:** `docs/` directory, Markdown
- **Conventions:**
  - No hardcoded admin usernames (detect via `$SUDO_USER`)
  - Scripts must handle both interactive and non-interactive modes
  - Add `--help` flag to all scripts

## Testing

- Run `shellcheck` on all new/edited scripts
- Test in a VM (VirtualBox) with a fresh Debian install
- Run the full install flow to verify it completes without errors

## Issue Type Guidance

| Template | When to use |
|---|---|
| `task.md` | General work item — feature, fix, improvement, or chore with clear scope |
| `feature.md` | New capability or enhancement that needs problem/solution/alternatives breakdown |
| `bug.md` | Unexpected behavior or regression with reproduction steps |

- **Task** is the default — use it unless the work benefits from the structured sections of `feature.md` or `bug.md`
- Research issues (like #25) start as `task.md` and may spawn implementation issues

## Issue Lifecycle

```
Research Issue → Discussion / Decision → Implementation Issue → PR → Merge
```

Some issues flow through multiple stages:
1. **Research** — Investigate options, document findings (e.g., #25: sudo requirements research)
2. **Discussion** — Decide on approach based on research output
3. **Implementation** — Code the agreed solution (e.g., #23: sudoers policy implementation, depends on #25)
4. **Review & Merge** — Standard PR workflow

Not every issue needs all stages — simple tasks go straight to implementation.

## Project Phases

| Phase | Script | Description |
|---|---|---|
| **Bootstrap** | `scripts/bootstrap.sh` | Initial server setup — packages, users, SSH, firewall |
| **Hardening** | `scripts/hardening.sh` | Security hardening — root lock, auditd, sysctl |
| **Install Hermes** | `scripts/install-hermes.sh` | Install and configure the Hermes Agent |
| **Profiles** | `scripts/profiles/` | Optional feature profiles (dev, monitoring, etc.) |

## GH CLI Quick Reference

```bash
# Clone the repo
gh repo clone to-ge-da/hermes-self-hosted

# View an issue
gh issue view <number>

# Create a PR
gh pr create --base main --title "type: description" --body "Summary of changes"

# List open issues
gh issue list --state open

# List open PRs
gh pr list --state open

# Check out a PR locally
gh pr checkout <number>
```

