# AGENTS.md

Conventions for this repo.

## Git

- Branch from `main`: `feat/`, `fix/`, `chore/`, `docs/`
- Conventional Commits
- Do not commit or push to `main`

## GitHub

- Use `gh` for issues, PRs, and merge
- Squash merge; delete the remote branch after merge
- Bug, Feature, or Task issue template; follow the PR template

## Scripts

- Live in `scripts/`: `#!/bin/bash`, `set -euo pipefail`, `--help`
- Bootstrap is YAML via `--config` (no prompts)
- Run `shellcheck` on new or edited scripts (CI covers `scripts/`)

## Docs

Markdown in `docs/`. Cursor trees in `docs/forks/`.

## Testing

Smoke on a fresh Debian VM. Walk the path in [docs/INSTALLATION.md](docs/INSTALLATION.md).
