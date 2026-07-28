# Testing Custom Hermes Forks (Cursor)

Step-by-step guide to clone, install from source, and test the
[`to-ge-da/hermes-agent`](https://github.com/to-ge-da/hermes-agent) fork with
native Cursor provider integration.

This path is for **local development / smoke testing**. For the official
release install on a hardened host, see [INSTALL-HERMES.md](INSTALL-HERMES.md).

## Prerequisites

| Tool | Why |
|---|---|
| [mise](https://mise.jdx.dev/) | Optional but recommended for pinned host tools in this repo — see [MISE.md](MISE.md) |
| [uv](https://docs.astral.sh/uv/) | Python package manager used to sync and run the fork |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Clone the fork with auth |
| Cursor Pro+ subscription | Required for Cursor API access / `CURSOR_API_KEY` |

Install `uv` if needed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Confirm:

```bash
uv --version
gh --version
```

Create a Cursor API key in the Cursor dashboard (Settings → API Keys / Integrations)
and keep it ready for the auth step below.

## 1. Clone the fork

```bash
# Shallow clone (recommended — large repo ~2 GB)
gh repo clone to-ge-da/hermes-agent -- --depth 1
cd hermes-agent
```

Optional: check out a specific Cursor feature branch if the fork documents one:

```bash
git fetch origin
git branch -a | grep -i cursor
# git checkout <branch>
```

## 2. Install from source

From the repo root:

```bash
uv sync
```

Smoke-check the CLI via the project environment:

```bash
uv run hermes --version
uv run hermes doctor
```

Tip: prefix every command below with `uv run` (for example `uv run hermes model`),
or activate the project venv once (`source .venv/bin/activate`) and call `hermes`
directly.

## 3. Set up auth

Hermes loads provider keys from `~/.hermes/.env`:

```bash
mkdir -p ~/.hermes
touch ~/.hermes/.env
```

Add your Cursor API key (do not commit this file):

```bash
echo 'CURSOR_API_KEY=crsr_your_key_here' >> ~/.hermes/.env
```

Verify the variable is present (value redacted):

```bash
grep -E '^CURSOR_API_KEY=' ~/.hermes/.env | sed 's/=.*/=***/'
```

## 4. Verify the provider

Open the interactive model/provider picker and confirm **cursor** appears:

```bash
uv run hermes model
```

You can also set provider/model non-interactively if your fork supports it:

```bash
uv run hermes config set model.provider cursor
uv run hermes config set model name composer-2.5
```

Exact config keys may vary by fork revision — use `hermes model` when unsure.

## 5. Test connectivity

Probe the Cursor account and model catalog:

```bash
uv run hermes cursor me
uv run hermes cursor models
```

Expected: account metadata for `me`, and a list that includes models such as
`composer-2.5`.

Optional cross-check with this repo’s helper (uses the same API key):

```bash
export CURSOR_API_KEY="$(grep -E '^CURSOR_API_KEY=' ~/.hermes/.env | cut -d= -f2-)"
# from hermes-self-hosted:
./scripts/tools/list-cursor-models.sh
```

## 6. Run with Cursor

Start a chat through the Cursor provider:

```bash
uv run hermes --provider cursor --model composer-2.5
```

One-shot prompt:

```bash
uv run hermes --provider cursor --model composer-2.5 chat -q "Reply with: cursor ok"
```

If the CLI rejects flags, use the picker first (`hermes model` → cursor /
composer-2.5), then:

```bash
uv run hermes chat -q "Reply with: cursor ok"
```

## 7. Make Hermes available globally

By default, `hermes` only works with `uv run hermes ...` inside the fork
directory. To run `hermes` from any path:

### Option A: Install the fork in editable mode (recommended)

```bash
cd ~/projects/hermes-agent
uv pip install -e .
```

This registers `hermes` at `~/.local/bin/hermes` pointing to your fork.
Any code changes you make are reflected automatically — you do not need
to reinstall.

### Option B: Manual symlink

```bash
ln -sf ~/projects/hermes-agent/.venv/bin/hermes ~/.local/bin/hermes
```

### Option C: Shell alias

```bash
echo 'alias hermes="cd ~/projects/hermes-agent && uv run hermes"' >> ~/.zshrc
source ~/.zshrc
```

### Verify

```bash
which hermes          # ~/.local/bin/hermes (options A/B)
hermes model          # works from any directory
```

## Troubleshooting

| Symptom | What to check |
|---|---|
| `cursor` missing from `hermes model` | Wrong checkout / branch; Cursor provider not merged into this fork tip. `git log --oneline \| head` and confirm you are on the Cursor-enabled branch. |
| `ModuleNotFoundError` / missing deps | Re-run `uv sync` from the fork root. If extras are required: `uv sync --all-extras` (or install `[all,dev]` per the fork’s CONTRIBUTING). |
| `CURSOR_API_KEY` / auth errors | Key missing or truncated in `~/.hermes/.env`; export not loaded. Re-add the key; restart the shell; avoid quoting spaces incorrectly. |
| `401` / unauthorized on `hermes cursor me` | Invalid or revoked API key; subscription tier without API access. Create a new key under a Pro+ account. |
| `hermes: command not found` | Use `uv run hermes ...` from the clone, or activate `.venv`. |
| Python / wheel build failures | Need Python 3.11–3.13 (`uv python install 3.12` then `uv sync`). |
| Official `hermes` shadows the fork | `which hermes` may point at `~/.local/bin` from the installer. Prefer `uv run hermes` from the clone while testing. |

Debug helpers:

```bash
uv run hermes doctor
uv run hermes --version
which -a hermes
echo "$VIRTUAL_ENV"
```

## Rollback — return to official Hermes

1. Leave the fork checkout (or remove it):

```bash
cd ~
# optional: rm -rf ~/path/to/hermes-agent
```

2. If you only used `uv run` from the clone, the official install is unchanged.
   Confirm:

```bash
which hermes
hermes --version
```

3. If you overwrote the official install or PATH entry, reinstall with the
   upstream installer:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
source ~/.bashrc   # or ~/.zshrc
hermes doctor
```

4. Clear Cursor-only config if you want a clean official default:

```bash
# optional — review before editing
grep -n -i cursor ~/.hermes/config.yaml ~/.hermes/.env 2>/dev/null || true
# remove or comment CURSOR_API_KEY if no longer needed
```

See [INSTALL-HERMES.md](INSTALL-HERMES.md) for the normal host install path.

## Related

- Official Hermes install: [INSTALL-HERMES.md](INSTALL-HERMES.md)
- Mise tools: [MISE.md](MISE.md)
- Cursor model list helper: [`scripts/tools/list-cursor-models.sh`](../scripts/tools/list-cursor-models.sh)
- Fork: https://github.com/to-ge-da/hermes-agent
- Upstream: https://github.com/NousResearch/hermes-agent
