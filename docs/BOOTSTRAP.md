# Bootstrap

Initial system setup for a fresh Debian Server installation.

> **Config-driven and idempotent.** Bootstrap reads a YAML file (no interactive
> prompts). Safe to run multiple times — already-configured steps are detected
> and skipped. State is written to `~/.hermes-self-hosted/bootstrap.state` for the
> admin user who ran `sudo` (`$SUDO_USER`).

See [BOOTSTRAP-CONFIG.md](BOOTSTRAP-CONFIG.md) for the full schema, path
resolution, mise/yq integration, and state migration details.

## Prerequisites

1. Fresh Debian Server with an admin user created during OS install
2. A filled-in YAML config (any path) based on `config/bootstrap.example.yaml`
3. **mise + yq already installed** (bootstrap does **not** install them)
4. Run bootstrap from a directory that contains `mise.toml` (e.g. the project root)

### One-time tool setup

```bash
# As the admin user (not root)
curl https://mise.run | sh
cd /path/to/hermes-self-hosted   # directory with mise.toml
mise install                     # installs pinned yq
```

Copy the example and edit values (do **not** commit real keys):

```bash
cp config/bootstrap.example.yaml ./bootstrap.yaml
# edit hostname, timezone, hermes.ssh_public_key (or ssh_public_key_file)
```

Generate an SSH key for the hermes user — see [SSH-KEYS.md](SSH-KEYS.md).
If you prepare `bootstrap.yaml` (or a `.pub` file) on your workstation, copy it
to the host with `scp` or `rsync` — see [FILE-TRANSFER.md](FILE-TRANSFER.md).

## Usage

```bash
cd /path/to/hermes-self-hosted

# Inject any config path (recommended)
sudo ./scripts/bootstrap.sh --config ./bootstrap.yaml
sudo ./scripts/bootstrap.sh --config /etc/hermes/host.yaml

# Or place bootstrap.yaml next to bootstrap.sh and omit --config
sudo ./scripts/bootstrap.sh
```

If config or mise/yq is missing, bootstrap exits immediately with a short error —
before changing the host.

Legacy flags (`--hostname`, `--timezone`, `--ssh-key`) and interactive prompts
are removed. Put those values in the YAML config. Path names are not special —
only the file contents must validate.

## What it does

| Step | Description |
|------|-------------|
| Preflight | Resolves config; requires mise + yq (no tool installs) |
| Config load | Parses and validates the YAML config |
| System update | `apt update && apt upgrade` |
| Essential packages | sudo, openssh-server, curl, wget, git, vim, ufw, unattended-upgrades, apt-listchanges, tree, nmap |
| Hostname | From config |
| Timezone | From config (default `UTC`) |
| Locale | Set to `en_US.UTF-8` |
| Admin user | Detected via `$SUDO_USER` — no changes made |
| Hermes user | Creates agent user from config (default `hermes`, no sudo, key-only) |
| SSH key | From `hermes.ssh_public_key` or `hermes.ssh_public_key_file` |
| Root lock | Locks root account |
| SSH drop-in dir | Creates `/etc/ssh/sshd_config.d/` |
| State file | Writes `~/.hermes-self-hosted/bootstrap.state` (content hash + metadata) |

## Re-running bootstrap

- **State file** — `/home/<admin>/.hermes-self-hosted/bootstrap.state` marks a completed run
- **Config hash** — SHA-256 of the config **file contents**; a change is logged on re-run
- **Legacy migration** — `/var/lib/hermes-self-hosted/bootstrap.state` is migrated automatically
- **Idempotency** — hostname/user/SSH key steps skip when already applied
- **Partial runs** — state is only written on success

## Essential packages

| Package | Purpose |
|---------|---------|
| `sudo` | Privilege escalation (may already be installed) |
| `openssh-server` | SSH daemon for remote access |
| `curl`, `wget` | Download files from the web |
| `git` | Version control, clone repositories |
| `vim` | Text editor |
| `ufw` | Uncomplicated Firewall — configured in hardening |
| `unattended-upgrades` | Automatic security updates — configured in hardening |
| `apt-listchanges` | Shows package changelogs during manual upgrades |
| `tree` | Visual directory listing |
| `nmap` | Network scanner |

## Users after bootstrap

| User | Sudo | Password | Auth |
|------|------|----------|------|
| `<admin>` (`$SUDO_USER`) | Yes (from OS install) | As configured during Debian install | SSH key (from Debian install or manual) |
| `hermes` (or config override) | No | Disabled | SSH key from config |

## After running

Verify SSH access for both users before disconnecting.

Admin (whatever key/password you use for `$SUDO_USER`):

```bash
ssh <admin>@<server-ip>
```

Hermes is **key-only** — use the private key that matches the public key in config:

```bash
ssh -i ~/.ssh/hermes_vbox hermes@<server-ip>
```

On the host, inspect the installed key with sudo (other users cannot read `/home/hermes`):

```bash
sudo cat /home/hermes/.ssh/authorized_keys
sudo ssh-keygen -lf /home/hermes/.ssh/authorized_keys
```

If bootstrap skipped key install because `authorized_keys` already existed, remove it
and re-run — see [SSH-KEYS.md](SSH-KEYS.md).

Then proceed to [hardening](HARDENING.md).
