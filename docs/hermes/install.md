# Install Hermes Agent

Official installation of Hermes Agent on the server. Run as the unprivileged **hermes** user (no sudo, no password) created by [bootstrap](../BOOTSTRAP.md).

## Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Playwright / Chromium](#playwright--chromium)
- [Installer flags](#installer-flags)
- [Gateway (24/7 access)](#gateway-247-access)
- [Future automation](#future-automation)
- [Custom Cursor trees](#custom-cursor-trees)
- [Uninstall](#uninstall)
- [Reference](#reference)

## Prerequisites

- [Bootstrap](../BOOTSTRAP.md) completed (users created, SSH configured) — installs Hermes system packages (`build-essential`, `python3-dev`, `libffi-dev`, `ripgrep`, `ffmpeg`)
- [Hardening](../HARDENING.md) completed (system secured) — recommended for production; VM smoke tests may skip
- Server has internet access

### System packages (from bootstrap)

[Bootstrap](../BOOTSTRAP.md) installs the apt packages the official installer would otherwise try to add via `sudo`. The `hermes` user has **no password and no sudo**.

If those packages are missing, `--non-interactive` answers **yes** to installing them, then the installer calls `sudo` and blocks or fails. Do not sudo as `hermes` — use the admin fallback below.

| Package set | Why | How the installer detects them |
|-------------|-----|--------------------------------|
| `build-essential`, `python3-dev`, `libffi-dev` | Compile some Python deps into the venv | `dpkg` checks for `gcc`, `python3-dev`, `libffi-dev` |
| `ripgrep`, `ffmpeg` | Optional: fast file search + TTS | `rg` / `ffmpeg` on `PATH` |

**Fallback** (hosts bootstrapped before this change, or if packages were removed) — as **admin**:

```bash
sudo apt install -y build-essential python3-dev libffi-dev ripgrep ffmpeg
```

After this bootstrap, the installer should not prompt. If it still asks for sudo as `hermes`, stop, install the packages as admin, and re-run.

## Installation

### Step 1: SSH in as hermes user

```bash
ssh -i ~/.ssh/<key> hermes@<server-ip>
# or: ssh hermes@<server-ip>
```

### Step 2: Install Hermes Agent (non-interactive)

Recommended for this repo — fully automated, no setup wizard:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive
```

- `--skip-setup` — skips the interactive provider/model wizard (needed over SSH: a TTY still exists even with `curl | bash`)
- `--non-interactive` — skips installer stages that need user input

Playwright/Chromium is included. `--skip-browser` is optional (no browser tools). See [Playwright / Chromium](#playwright--chromium).

A plain `curl … | bash` (no flags) is interactive when a terminal is available.

Layout after install:

| Item | Location |
|------|----------|
| Code | `~/.hermes/hermes-agent/` |
| Data / config | `~/.hermes/` |
| CLI launcher | `~/.local/bin/hermes` |

### Step 3: Verify

```bash
hermes --version
hermes doctor
```

`PATH` already includes `~/.local/bin` from bootstrap (`/etc/profile.d/00-local-bin.sh`).

`hermes doctor` may still show Playwright red until an **admin** installs OS libraries (`install-deps`). The agent itself is installed. See [Playwright / Chromium](#playwright--chromium).

### Step 4: Set up provider and model

With `--skip-setup`, configure after install (non-interactive or wizard):

```bash
# Non-interactive
hermes config set model.provider openrouter

# Or interactive later
hermes model
# hermes setup
```

Set your API key in `~/.hermes/.env`:

```bash
echo "OPENROUTER_API_KEY=your-key-here" >> ~/.hermes/.env
```

### Step 5: Test

```bash
hermes chat -q "Hello, are you working?"
```

## Playwright / Chromium

Upstream [hermes-agent#93357](https://github.com/NousResearch/hermes-agent/pull/93357) (merged 2026-08-24) pins Playwright **1.62.1**. That closed the Node 26 extract hang ([#76312](https://github.com/NousResearch/hermes-agent/issues/76312)). Fresh official installs download Chromium during `install.sh`.

`hermes` still has **no sudo**, so the installer skips `--with-deps`. After Step 2, as **admin** from this clone:

```bash
sudo ./scripts/playwright.sh
```

Uses hermes's `npx`/`node` (`~hermes/.hermes/node/bin`) — `sudo npx` on a clean PATH fails with `env: 'node': No such file or directory`. Do not log out; this is not a login PATH issue.

Then as `hermes`: `hermes doctor` — look for `Playwright Chromium (browser engine)`.

`--skip-browser` is optional (headless host, no browser tools). It is not in the recommended command.

## Installer flags

Every option below matches live `install.sh --help` from
https://hermes-agent.nousresearch.com/install.sh (checked 2026-08-24).
The recommended command for this repo is `--skip-setup --non-interactive` (see above).

Print the live list (re-check after upstream installer updates):

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --help
```

`--help` exits before install. A `curl: (23)` after the help text is the pipe
closing — ignore it.

### Recommended for this repo

`--skip-setup` and `--non-interactive` together:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive
```

| Flag | What it does | Why this repo uses it |
|------|--------------|------------------------|
| `--skip-setup` | Skip the interactive provider/model wizard (`hermes setup`) | Over SSH a TTY still exists, so a plain `curl \| bash` launches the wizard |
| `--non-interactive` | Yes/no prompts take their default; `--stage setup` / `--stage gateway` are skipped | So a yes/no cannot sit waiting on the SSH session. Does not skip the setup wizard (`--skip-setup`). Missing apt packages still hit the installer's `sudo` — see [System packages](#system-packages-from-bootstrap) |

A plain `curl … | bash` (no flags) is interactive when a terminal is available.

Leave every other flag at its default unless you have a reason in the sections
below: venv on, bundled skills on, official `main`, paths under `~/.hermes`.

### Reference table

Purposes match `--help` wording.

| Flag | Purpose |
|------|---------|
| `--no-venv` | Don't create a virtual environment |
| `--skip-setup` | Skip interactive setup wizard |
| `--skip-browser` | Skip Playwright/Chromium (browser tools won't work) |
| `--skip-computer-use` | Skip the `cua-driver` (Computer Use) install |
| `--no-skills` | No bundled skills; writes `$HERMES_HOME/.no-bundled-skills` so later `hermes update` also skips them |
| `--branch NAME` | Git branch to install (default: `main`) |
| `--commit SHA` | Pin checkout to a commit after clone/update (ignored if it would roll an existing install back) |
| `--force-commit` | Apply `--commit` even if it rolls the install backwards |
| `--manifest` | Print desktop bootstrap stage manifest as JSON |
| `--stage NAME` | Run one desktop bootstrap stage |
| `--json` | Print a JSON result frame for `--stage` |
| `--non-interactive` | Skip stages that require user input |
| `--include-desktop` | Also build the desktop app (`apps/desktop` → `Hermes.app`) |
| `--dir PATH` | Installation directory (default: `~/.hermes/hermes-agent`; as root on Linux: `/usr/local/lib/hermes-agent`) |
| `--hermes-home PATH` | Data directory (default: `~/.hermes`, or `$HERMES_HOME`) |
| `--ensure DEPS` | Install only listed deps, comma-separated (`node`, `browser`, `ripgrep`, `ffmpeg`). Does not clone or create a venv |
| `-h` / `--help` | Show installer help |

`--ensure` appears under **Notes** in `--help`, not under **Options**. It is a
real flag. `--skip-browser` also accepts `--no-playwright` (same effect; not
listed in `--help`).

### Skip optional components

#### `--skip-browser`

Skips Playwright/Chromium and the Browser Use CLI. Browser tools will not work
until you install them later.

This repo: **do not use** in the recommended command. Playwright **1.62.1**
(upstream [#93357](https://github.com/NousResearch/hermes-agent/pull/93357))
fixed the Node 26 extract hang. Add the flag only if you do not want browser
tools. To enable later: `npx playwright install chromium` as `hermes`, then
admin `sudo ./scripts/playwright.sh`. See
[Playwright / Chromium](#playwright--chromium).

#### `--skip-computer-use`

Skips the `cua-driver` (Computer Use) install. The official installer treats a
failed driver download as a warning and continues; you can install later with
`hermes computer-use install`.

This repo: not in the recommended command. On a headless host you may add it —
there is no desktop to drive, and the driver install is best-effort. Leave it
off for a full official install.

#### `--no-skills`

Seeds no bundled skills and writes `$HERMES_HOME/.no-bundled-skills`. Later
`hermes update` also skips bundled skills.

This repo: **do not use**. The self-hosted path expects the official skill set.

#### `--no-venv`

Does not create a virtual environment. The agent then uses whatever `python`
is on `PATH`.

This repo: **do not use**. The venv is the supported layout
(`~/.hermes/hermes-agent/venv`).

### Pin source

Default clone is branch `main` from the official repo.

#### `--branch NAME`

Install that git branch instead of `main`.

This repo: leave unset (official `main`). Custom Cursor trees are a different
path — see [testing-custom-forks.md](../forks/testing-custom-forks.md).

#### `--commit SHA` / `--force-commit`

`--commit` pins the checkout to a hex SHA (7–40 chars) after clone/update.
If the existing install is already newer, the pin is ignored unless you also
pass `--force-commit` (that rolls the tree backwards).

This repo: leave unset unless you are reproducing a known commit.

### Paths and root

#### `--dir PATH` / `--hermes-home PATH`

| Flag | Default (unprivileged) | What lives there |
|------|------------------------|------------------|
| `--dir` | `~/.hermes/hermes-agent` | Agent code + venv |
| `--hermes-home` | `~/.hermes` (or `$HERMES_HOME`) | Config, sessions, logs, `.env` |

`--dir` also honors `$HERMES_INSTALL_DIR` when you do not pass the flag.

This repo: keep the defaults so docs, gateway linger, and uninstall stay aligned.

#### Root / FHS (do not use here)

As **root on Linux** the installer uses FHS: code in
`/usr/local/lib/hermes-agent`, launcher in `/usr/local/bin/hermes`. Data stays
in `$HERMES_HOME` (default `/root/.hermes`). An existing
`$HERMES_HOME/hermes-agent` tree is left in place.

This repo installs as the unprivileged `hermes` user — **do not run the
installer as root**.

### Desktop bootstrap (not used on this path)

`--manifest`, `--stage NAME`, `--json`, and `--include-desktop` are the
desktop / Hermes-Setup stage protocol. They do not replace the recommended
CLI install on Debian.

| Flag | What it does |
|------|----------------|
| `--manifest` | Print the stage list as JSON and exit (no install) |
| `--stage NAME` | Run one stage and exit |
| `--json` | After `--stage`, print a JSON result frame (`ok`, `stage`, `skipped`) |
| `--include-desktop` | Also build `apps/desktop` → `Hermes.app` (macOS desktop app) |

With `--non-interactive`, `--stage setup` and `--stage gateway` are skipped
(those two `needs_user_input`). `--include-desktop` adds a `desktop` stage to
the manifest.

This repo: **do not use**. Headless Debian does not build `Hermes.app`.
Gateway setup is a later step on this page, not an installer stage.

### Install dependencies only

`--ensure DEPS` installs **only** the listed extras and then exits. It does
**not** clone the repo or create a venv. Comma-separated; supported values:
`node`, `browser`, `ripgrep`, `ffmpeg`.

Examples:

```bash
# Node only
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --ensure node

# Several
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --ensure node,ripgrep,ffmpeg
```

`browser` needs Node first (`--ensure node` or Node already on `PATH`).
`ripgrep` / `ffmpeg` go through the installer's apt path (needs sudo if missing).

This repo: **do not use as the install**. Bootstrap already installs
`ripgrep` and `ffmpeg` as admin. The `hermes` user has no sudo, so
`--ensure ripgrep,ffmpeg` as `hermes` fails if those binaries are absent.

## Gateway (24/7 access)

To make Hermes accessible from messaging platforms (Telegram, Discord, etc.):

```bash
# Configure platforms
hermes gateway setup

# Start gateway in background
hermes gateway install
hermes gateway start

# Check status
hermes gateway status
```

Linger for `hermes` is enabled by [bootstrap](../BOOTSTRAP.md), so the user unit survives logout and reboot. Hosts bootstrapped before that (`Linger=no`):

```bash
sudo loginctl enable-linger hermes
```

## Future automation

A dedicated `install-hermes.sh` script may be added later to wrap the **non-interactive** official installer:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive
```

and extend it with:

- Pre-configured API keys
- Gateway auto-start as a systemd user service
- Pre-loaded skills for the target environment
- Config file templating

## Custom Cursor trees

This page is **official Nous only**. For `to-ge-da/hermes-agent` (legacy) or
`to-ge-da/hermes-agent-sdk` (latest + #88212), see
[testing-custom-forks.md](../forks/testing-custom-forks.md). One instance per host;
do not share `~/.hermes` with a fork checkout.

## Uninstall

To stop the gateway and remove the agent, config, and data, see
[uninstall.md](uninstall.md).

## Reference

- Official docs: https://hermes-agent.nousresearch.com/docs/
- CLI reference: https://hermes-agent.nousresearch.com/docs/reference/cli-commands
- Gateway setup: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/
- Updating & uninstalling: https://hermes-agent.nousresearch.com/docs/getting-started/updating
