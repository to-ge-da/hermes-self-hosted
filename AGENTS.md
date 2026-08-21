# AGENTS.md

Conventions for this repo.

Here, Hermes means the agent, its system user, and the install target, not a GitHub workflow role.

## Git

- Use `gh` for issues, PRs, and merge
- Branch from `main`: `feat/`, `fix/`, `chore/`, `docs/`
- Conventional Commits
- Squash merge; delete the branch after merge
- Do not commit or push to `main`

## Scripts

- Live in `scripts/`: `#!/bin/bash`, `set -euo pipefail`, `--help`
- Bootstrap is YAML via `--config` (no prompts)
- Run `shellcheck` on new or edited scripts (CI covers `scripts/`)

## Docs

Markdown in `docs/`.

## Testing

Smoke on a fresh Debian VM. Walk the path in [docs/INSTALLATION.md](docs/INSTALLATION.md).
