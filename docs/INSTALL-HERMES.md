# Install Hermes Agent

Official installation of Hermes Agent on the server.

## Prerequisites

- [Bootstrap](BOOTSTRAP.md) completed (users created, SSH configured)
- [Hardening](HARDENING.md) completed (system secured)
- Server has internet access

## Installation

### Step 1: SSH in as hermes user

```bash
ssh hermes@<server-ip>
```

### Step 2: Install Hermes Agent

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

This installs Hermes under `~/.hermes/` in the hermes user's home directory.

### Step 3: Verify installation

```bash
hermes --version
hermes doctor
```

### Step 4: Set up provider and model

```bash
# Interactive model/provider picker
hermes model

# Or set directly
hermes config set model.provider openrouter
```

Set your API key in `~/.hermes/.env`:

```bash
echo "OPENROUTER_API_KEY=your-key-here" >> ~/.hermes/.env
```

### Step 5: Test

```bash
hermes chat -q "Hello, are you working?"
```

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

Enable lingering so the gateway survives logout:

```bash
sudo loginctl enable-linger hermes
```

## Future automation

A dedicated `install-hermes.sh` script may be added later to automate:

- One-command install with pre-configured API keys
- Gateway auto-start as a systemd user service
- Pre-loaded skills for the target environment
- Config file templating

## Uninstall

To stop the gateway and remove the agent, config, and data, see
[hermes-uninstall.md](hermes-uninstall.md).

## Reference

- Official docs: https://hermes-agent.nousresearch.com/docs/
- CLI reference: https://hermes-agent.nousresearch.com/docs/reference/cli-commands
- Gateway setup: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/
- Updating & uninstalling: https://hermes-agent.nousresearch.com/docs/getting-started/updating
