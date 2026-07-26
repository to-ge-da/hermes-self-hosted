# Install Hermes Agent

Official installation of Hermes Agent on the server. Run as the unprivileged **hermes** user (no sudo, no password) created by [bootstrap](BOOTSTRAP.md).

## Prerequisites

- [Bootstrap](BOOTSTRAP.md) completed (users created, SSH configured)
- [Hardening](HARDENING.md) completed (system secured) — recommended for production; VM smoke tests may skip
- Server has internet access
- **Admin system packages** installed before the hermes installer (see below)

### Admin: install system packages first

The official installer may prompt for `sudo` to install build tools and optional packages. The `hermes` user has **no password and no sudo**, so those prompts block or fail.

Install them once as **admin** before running the hermes installer:

```bash
# as admin (not hermes)
sudo apt install -y build-essential python3-dev libffi-dev ripgrep ffmpeg
```

| Package set | Why | How the installer detects them |
|-------------|-----|--------------------------------|
| `build-essential`, `python3-dev`, `libffi-dev` | Compile some Python deps into the venv | `dpkg` checks for `gcc`, `python3-dev`, `libffi-dev` |
| `ripgrep`, `ffmpeg` | Optional: fast file search + TTS | `rg` / `ffmpeg` on `PATH` |

These packages are **not** installed by current `bootstrap.sh`. If the installer still asks:

- `Install ripgrep … ffmpeg …? [Y/n]`
- `Install build tools? [Y/n]`

answer **`n`** as hermes (do not enter a sudo password). If stuck at `[sudo] password for hermes:`, press Ctrl+C or let sudo fail, install the packages as admin, then re-run the installer if the venv/deps step failed.

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

### Step 3: Reload PATH and verify

Ensure `~/.local/bin` is on `PATH`, then verify:

```bash
source ~/.bashrc   # or open a new SSH session
hermes --version
hermes doctor
```

If `hermes: command not found`, add to `~/.bashrc`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

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

## Reference

- Official docs: https://hermes-agent.nousresearch.com/docs/
- CLI reference: https://hermes-agent.nousresearch.com/docs/reference/cli-commands
- Gateway setup: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/
