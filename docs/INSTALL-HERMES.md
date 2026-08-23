# Install Hermes Agent

Official installation of Hermes Agent on the server. Run as the unprivileged **hermes** user (no sudo, no password) created by [bootstrap](BOOTSTRAP.md).

## Prerequisites

- [Bootstrap](BOOTSTRAP.md) completed (users created, SSH configured) — installs Hermes system packages (`build-essential`, `python3-dev`, `libffi-dev`, `ripgrep`, `ffmpeg`)
- [Hardening](HARDENING.md) completed (system secured) — recommended for production; VM smoke tests may skip
- Server has internet access

### System packages (from bootstrap)

[Bootstrap](BOOTSTRAP.md) installs the apt packages the official installer would otherwise try to add via `sudo`. The `hermes` user has **no password and no sudo**, so those prompts would block or fail.

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
ssh -i ~/.ssh/hermes_vbox hermes@<server-ip>
# or: ssh hermes@<server-ip>
```

### Step 2: Install Hermes Agent (non-interactive)

Recommended for this repo — fully automated, no setup wizard:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive
```

- `--skip-setup` — skips the interactive provider/model wizard (needed over SSH: a TTY still exists even with `curl | bash`)
- `--non-interactive` — skips installer stages that need user input

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

## Installer flags

Show all options:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --help
```

| Flag | Purpose |
|------|---------|
| `--skip-setup` | Skip interactive setup wizard |
| `--non-interactive` | Skip stages that require user input |
| `--dir PATH` | Installation directory (default: `~/.hermes/hermes-agent`) |
| `--hermes-home PATH` | Data directory (default: `~/.hermes`) |
| `-h` / `--help` | Show installer help |

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

Enable lingering so the gateway survives logout (run as admin):

```bash
sudo loginctl enable-linger hermes
```

## Custom Cursor trees

This page is **official Nous only**. For `to-ge-da/hermes-agent` (legacy) or
`to-ge-da/hermes-agent-sdk` (latest + #88212), see
[testing-custom-forks.md](forks/testing-custom-forks.md). One instance per host;
do not share `~/.hermes` with a fork checkout.

## Uninstall

To stop the gateway and remove the agent, config, and data, see
[hermes-uninstall.md](hermes-uninstall.md).

## Reference

- Official docs: https://hermes-agent.nousresearch.com/docs/
- CLI reference: https://hermes-agent.nousresearch.com/docs/reference/cli-commands
- Gateway setup: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/
- Updating & uninstalling: https://hermes-agent.nousresearch.com/docs/getting-started/updating
