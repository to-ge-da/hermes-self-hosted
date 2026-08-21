# Working with Hermes + Cursor trees

Official Hermes (Nous) still has **no in-tree Cursor provider**. Until that
lands, `to-ge-da` keeps **two** trees. This guide is how to pick one, install
it, isolate it, and update it.

Official host install (no Cursor): [INSTALL-HERMES.md](../docs/INSTALL-HERMES.md).  
Why Cursor is forked at all: [cursor-integration-research.md](cursor-integration-research.md)
(July 2026 research — read the status box at the top before the tables).

## Which tree

| Repo | GitHub kind | Hermes base | Cursor’s role | Use |
|---|---|---|---|---|
| [to-ge-da/hermes-agent](https://github.com/to-ge-da/hermes-agent) | **Fork** of `NousResearch/hermes-agent` | Frozen ~v0.19.0 (Jul 2026) + lawmight runtime | Cursor **drives** the turn (`api_mode=cursor_agent`) | Legacy instance already running this checkout |
| [to-ge-da/hermes-agent-sdk](https://github.com/to-ge-da/hermes-agent-sdk) | Regular repo (**not** a fork) | Latest Nous `main` + [Nous #88212](https://github.com/NousResearch/hermes-agent/pull/88212) | Hermes stays the harness; `cursor-sdk` only infers | **New instances** — best Hermes + Cursor token spend |
| [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) | Upstream | Latest | No native Cursor | Default path in [INSTALL-HERMES.md](../docs/INSTALL-HERMES.md) |

`hermes-agent-sdk` is the line that moves. `hermes-agent` stays frozen except
Cursor-runtime hotfixes (meter, recycle). Do not rebase the legacy tree onto
Nous `main` unless you intend a full rewrite.

When Nous merges a native Cursor provider, sync `hermes-agent-sdk` to
upstream and retire the extra commits. The legacy fork can be archived.

## GitHub constraint

An org can **fork** a given upstream **once**. `to-ge-da/hermes-agent` already
is that fork. A second tree **must** be a normal repo (`gh repo create`), then
push Nous `main` + the Cursor patch. You lose the GitHub “Contribute / Compare”
button to Nous; keep an `upstream` remote in git instead.

```bash
# inside hermes-agent-sdk
git remote -v
# origin   = to-ge-da/hermes-agent-sdk
# upstream = NousResearch/hermes-agent
```

Do **not** run `gh repo fork NousResearch/hermes-agent` again.

## Isolation rules

This repo still documents **one Hermes instance per host**.

| Do | Do not |
|---|---|
| New tree → **new host** (or new VM) | Share `~/.hermes` between trees |
| Own `HERMES_HOME` + own `~/.local/bin/hermes` | `hermes update` on a fork and expect Nous `main` |
| `CURSOR_API_KEY` in that instance’s `.env` | Point both trees at the same venv / symlink |

Same machine (unsupported here, last resort):

```bash
# example — separate data + code dirs
export HERMES_HOME="$HOME/.hermes-sdk"
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- \
  --dir "$HOME/src/hermes-agent-sdk" \
  --hermes-home "$HERMES_HOME" \
  --skip-setup --non-interactive
```

Prefer a second host. Two `hermes` binaries on one `PATH` will shadow each other.

## Prerequisites (any custom tree)

| Tool | Why |
|---|---|
| [mise](https://mise.jdx.dev/) | Optional; pinned host tools in this repo — [MISE.md](../docs/MISE.md) |
| [uv](https://docs.astral.sh/uv/) | Sync and run a source checkout |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Clone with auth |
| Cursor Pro+ | Dashboard key (`crsr_…` / `CURSOR_API_KEY`) |

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv --version
gh --version
```

Create the key at [Cursor Dashboard → API](https://cursor.com/dashboard/api)
(or Integrations). Do not commit it.

## Install from source

Pick **one** clone. Shallow clone is fine for a smoke test (~2 GB full).

### A. New instance — `hermes-agent-sdk` (preferred)

```bash
gh repo clone to-ge-da/hermes-agent-sdk -- --depth 1
cd hermes-agent-sdk
# default branch `main` is already Nous tip + #88212
uv sync
# cursor-sdk is lazy-only (~48 MB). uv sync / [all] will not pull it.
uv pip install cursor-sdk
uv run hermes --version
uv run hermes doctor
```

Expected: a current Hermes version (not `v0.19.0`), provider `cursor` in
`hermes model`.

### B. Legacy — `hermes-agent`

```bash
gh repo clone to-ge-da/hermes-agent -- --depth 1
cd hermes-agent
git fetch origin
git branch -a | grep -i cursor
# typical tips:
#   feat/cursor-native-integration
#   fix/cursor-context-meter-and-recycle   # 500K meter + session recycle
git checkout fix/cursor-context-meter-and-recycle   # if you need the meter fix
uv sync
uv pip install cursor-sdk   # lazy-only; first cursor turn also auto-installs
uv run hermes --version
# expect: Hermes Agent v0.19.0 … local <sha> (+N carried commits)
```

### Auth (both)

```bash
mkdir -p ~/.hermes
touch ~/.hermes/.env
echo 'CURSOR_API_KEY=crsr_your_key_here' >> ~/.hermes/.env
grep -E '^CURSOR_API_KEY=' ~/.hermes/.env | sed 's/=.*/=***/'
```

## SMOKE_TEST

Same one-shot on both trees. This section is the source of truth — do not
copy it into the Hermes clones.

```bash
uv run hermes model          # confirm `cursor` is listed
uv run hermes config set model.provider cursor
uv run hermes config set model.name grok-4.6
```

One-shot (this is the pass/fail):

```bash
uv run hermes chat --provider cursor -m grok-4.6 -q "Reply with exactly NATIVE_CURSOR_OK and nothing else."
```

**Pass:** the model reply contains `NATIVE_CURSOR_OK`.

Sdk tree: `hermes --version` is **not** `v0.19.0`.  
Legacy tree: `hermes --version` **is** `v0.19.0`.

### Expected noise (not a fail)

On current `hermes-agent-sdk` `main`, these should **not** appear:

- `TERMINAL_CWD` in `.env` is copied into `config.yaml` `terminal.cwd` on startup.
- Missing HTTP aux for titles is skipped quietly (Cursor-only box).

If you still see them, `git pull` the sdk tree. Older checkouts (and the
legacy v0.19 tree) still print:

| Symptom | Why | Optional fix |
|---|---|---|
| `TERMINAL_CWD=… found in .env — this is deprecated` | Hermes moved cwd to `config.yaml`. | `hermes config set terminal.cwd /path` then drop the `.env` line. |
| `Auxiliary title generation failed: No LLM provider configured for task=title_generation` | Titles/compression do **not** use `cursor-sdk://`. #88212 diverts aux to `xai-oauth`; a Cursor-only `.env` has no HTTP provider. **Chat still works.** | `hermes config set auxiliary.title_generation.enabled false` **or** add a cheap HTTP provider (`XAI_API_KEY`, OpenRouter, `hermes auth add xai-oauth`). |
| Model says “I’m Cursor Grok 4.6, not Hermes” | You addressed the harness; the model answered with its identity. | Ignore. Hermes is the harness; Grok 4.6 via Cursor is the model. |

### Fail

`ModuleNotFoundError` / missing `cursor_sdk` → `uv pip install cursor-sdk` (not bare `pip`; not `uv sync`).  
`401` / missing key → new dashboard key.  
`cursor` not in `hermes model` → wrong repo/branch.

Legacy-only extras (may be missing on the sdk tree):

```bash
uv run hermes cursor me
uv run hermes cursor models
```

Catalog helper in this repo (same key):

```bash
export CURSOR_API_KEY="$(grep -E '^CURSOR_API_KEY=' ~/.hermes/.env | cut -d= -f2-)"
./scripts/tools/list-cursor-models.sh
```

Prefix commands with `uv run`, or `source .venv/bin/activate`. For a global
`hermes`, see [Make Hermes available globally](#make-hermes-available-globally).

## Updating

| Tree | How |
|---|---|
| Official install | `hermes update` — see [INSTALL-HERMES.md](../docs/INSTALL-HERMES.md) |
| `hermes-agent` (legacy) | **Do not** `hermes update` against Nous. Cherry-pick only Cursor runtime fixes onto `feat/cursor-native-integration`. |
| `hermes-agent-sdk` | Fetch Nous `main`, rebase/replay the Cursor commits, push `origin`. |

Sync the sdk tree (from a full clone, not `--depth 1`):

```bash
cd hermes-agent-sdk
git fetch upstream
git checkout main
git rebase upstream/main
# resolve the same files #88212 already touches:
#   agent/conversation_loop.py, agent/agent_runtime_helpers.py,
#   agent/auxiliary_client.py, plugins/model-providers/cursor/,
#   hermes_cli/*, providers/base.py
git push origin main
```

If rebase is painful, reset `main` to `upstream/main` and cherry-pick the
Cursor series again (the six #88212 commits, or whatever you still carry).

Watch [Nous #88212](https://github.com/NousResearch/hermes-agent/pull/88212).
`needs-decision` + conflicts means “keep the snapshot”, not “rebase the
legacy runtime”.

## Make Hermes available globally

By default `hermes` only works as `uv run hermes` inside the clone.

### Option A: Symlink (recommended)

```bash
# sdk instance
ln -sf ~/projects/hermes-agent-sdk/.venv/bin/hermes ~/.local/bin/hermes

# legacy instance (other host)
ln -sf ~/projects/hermes-agent/.venv/bin/hermes ~/.local/bin/hermes
```

`~/.local/bin` must be on `PATH`. One symlink per host.

`uv pip install -e .` does **not** put `hermes` on `PATH`. Use the symlink.

### Option B: Shell alias

```bash
echo 'alias hermes="cd ~/projects/hermes-agent-sdk && uv run hermes"' >> ~/.bashrc
source ~/.bashrc
```

### Verify

```bash
which hermes          # ~/.local/bin/hermes (option A)
hermes --version
hermes model
```

## Rollback — official Hermes

1. Leave the clone (optional `rm -rf` the checkout).
2. If you only used `uv run` from the clone, the official install is unchanged:

```bash
which hermes
hermes --version
```

3. If PATH or the official install was overwritten:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive
source ~/.bashrc
hermes doctor
```

4. Drop Cursor-only config if you no longer need it:

```bash
grep -n -i cursor ~/.hermes/config.yaml ~/.hermes/.env 2>/dev/null || true
```

## Troubleshooting

| Symptom | What to check |
|---|---|
| `cursor` missing from `hermes model` | Wrong repo/branch. Sdk: `main`. Legacy: a `cursor-*` branch, not frozen `main`. |
| Official `hermes` shadows the tree | `which -a hermes` — installer vs symlink vs `uv run`. |
| `ModuleNotFoundError` / missing `cursor_sdk` | `uv pip install cursor-sdk` in the clone venv. `uv sync` and `[all]` do **not** install it. |
| `Deprecated .env` / `TERMINAL_CWD` | Setup warning, not a Cursor fail. Move cwd to `config.yaml` (see [SMOKE_TEST](#smoke_test)). |
| `Auxiliary title generation failed` | Expected on a Cursor-only box. Chat is fine. Disable titles or add an HTTP aux provider. |
| After `/exit`, typing is invisible (need new SSH) | TUI cooked→raw healer raced past unwind and left `stty -echo`. Current sdk `main` snapshots tty attrs at TUI start and restores them on every exit. `git pull`. Temporary: `stty sane`. |
| `CURSOR_API_KEY` / `401` | Key missing, truncated, or not Pro+. New key at the dashboard. |
| `hermes: command not found` | `uv run hermes` from the clone, or the symlink above. |
| Context bar `825K/256K` | Legacy tree without the meter fix. Checkout `fix/cursor-context-meter-and-recycle` (grok-4.6 is 500K). |
| Session hangs after a huge tool dump | Legacy: Cursor owns the window; Hermes will not compact. Use the recycle patch or a new chat. Prefer the sdk tree. |
| `gh repo fork` fails / “already forked” | Expected. Create a normal repo (`hermes-agent-sdk` pattern). |
| `hermes update` says “up to date” on v0.19 | It is up to date **with the fork**, not with Nous. |
| Python / wheel failures | Python 3.11–3.13 (`uv python install 3.12 && uv sync`). |

```bash
uv run hermes doctor
uv run hermes --version
which -a hermes
echo "$VIRTUAL_ENV"
git remote -v && git log -1 --oneline
```

## Related

- Official install: [INSTALL-HERMES.md](../docs/INSTALL-HERMES.md)
- Uninstall: [hermes-uninstall.md](../docs/hermes-uninstall.md)
- Mise: [MISE.md](../docs/MISE.md)
- Smoke test: [SMOKE_TEST](#smoke_test)
- Cursor catalog helper: [`scripts/tools/list-cursor-models.sh`](../scripts/tools/list-cursor-models.sh)
- Research (2026-07-28): [cursor-integration-research.md](cursor-integration-research.md)
- Legacy fork: https://github.com/to-ge-da/hermes-agent
- Sdk snapshot: https://github.com/to-ge-da/hermes-agent-sdk
- Upstream: https://github.com/NousResearch/hermes-agent
- Nous Cursor PR: https://github.com/NousResearch/hermes-agent/pull/88212
