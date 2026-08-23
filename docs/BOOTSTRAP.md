# Bootstrap

## Purpose

[`scripts/bootstrap.sh`](../scripts/bootstrap.sh) prepares a **fresh Debian host** for one Hermes Agent instance — the first-boot step in the install path.

It exists to turn a bare Debian install into a consistent base:

- Apply hostname, timezone, and locale from a YAML config
- Install packages in four groups (host baseline, network stack, Hermes deps, Docker)
- Create the **hermes** agent user (key-only SSH, no sudo by default)
- Add **admin and hermes** to the `docker` group
- Install one host SSH public key on **admin and hermes** (append if missing)
- Lock the root account and ensure SSH drop-in config dir exists
- Record a state file so re-runs are safe and idempotent

It is **config-driven** (YAML via `--config`, no interactive prompts) and **idempotent** (safe to re-run; completed steps are skipped).

Bootstrap is **not**:

| Concern | Where it lives |
|---|---|
| Security hardening (firewall, SSH lockdown, kernel) | [HARDENING.md](HARDENING.md) / `hardening.sh` |
| Installing Hermes Agent or the gateway | [install.md](hermes/install.md) |
| Installing or activating mise | [MISE.md](MISE.md) (bootstrap only *requires* mise + yq already present) |

Ordered install path: [INSTALLATION.md](INSTALLATION.md).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Config](#config)
- [Path resolution](#path-resolution)
- [Usage](#usage)
- [What it does](#what-it-does)
- [State and re-runs](#state-and-re-runs)
- [Packages](#packages)
- [Users after bootstrap](#users-after-bootstrap)
- [After running](#after-running)
- [Standalone / out-of-repo](#standalone--out-of-repo)
- [Related](#related)

## Prerequisites

1. Fresh Debian Server with an admin user created during OS install
2. A filled-in YAML config based on `config/bootstrap.example.yaml`
3. **mise + host yq already installed** for the admin user — bootstrap does **not** install them
4. Run bootstrap from a directory that contains `mise.host.toml` (e.g. the project root)

`curl` (and `git` if you clone on the host) must already be installed — see [INSTALLATION.md](INSTALLATION.md#prerequisites).

One-time tool setup (from the repo root):

```bash
./scripts/mise.sh install
# or method 2 (shared /usr/local/bin/mise + profile.d):
# sudo ./scripts/mise.sh install --system-wide
```

Full mise guide: [MISE.md](MISE.md). Method 1 is enough for bootstrap (`yq` for `$SUDO_USER`). Method 2 is what other login users need to see `mise`.

Copy the example and edit (do **not** commit real keys):

```bash
cp config/bootstrap.example.yaml ./bootstrap.yaml
# edit hostname, timezone, ssh.public_key (or ssh.public_key_file)
```

Generate an SSH key for the hermes user — see [SSH-KEYS.md](SSH-KEYS.md).  
Copy config/keys to the host if needed — see [FILE-TRANSFER.md](FILE-TRANSFER.md).

Bootstrap uses `mise -E host exec -- yq` (root `mise.toml` ignored) to parse YAML — not Debian’s apt `yq`, which is a different tool. Host vs local toolchain: [MISE.md](MISE.md).

## Config

### Fields

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `hostname` | string | yes | — | Desired server hostname |
| `timezone` | string | no | `"UTC"` | Valid IANA TZ identifier (`timedatectl list-timezones`) |
| `ssh.public_key` | string | no* | — | Inline host SSH public key (admin + hermes) |
| `ssh.public_key_file` | string | no* | — | Path to an SSH public key file |
| `hermes.user` | string | no | `hermes` | Hermes agent system account name |

**\*Mutual exclusivity:** Choose exactly one of `ssh.public_key` or `ssh.public_key_file`. Setting both is an error. Setting neither skips SSH key setup (warning); neither user will have the config key until one is added.

Old `hermes.ssh_public_key` / `hermes.ssh_public_key_file` still work as a read alias (bootstrap warns). Do not set both generations at once.

### Example

```yaml
hostname: hermes-server
timezone: UTC
ssh:
  public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0Gj..."
hermes:
  user: hermes
```

### Validation (summary)

- **Hostname** — non-empty, valid for `hostnamectl`
- **Timezone** — must appear in `timedatectl list-timezones`
- **SSH key** — `ssh-ed25519`, `ssh-rsa`, or `ecdsa-sha2-nistp*` patterns; trailing comment allowed
- **SSH key file** — must exist, be a regular file, readable by the admin user; content validated like an inline key

## Path resolution

Config is injected; there is no required directory name such as `config/`.

1. **`--config PATH`** — absolute or relative to the current working directory  
2. **Script sibling** — `$SCRIPT_DIR/bootstrap.yaml` only if `--config` was omitted  
3. **Failure** — short error asking for `--config` or a sibling file  

No repo-root or `../config` fallback.

## Usage

```bash
cd /path/to/hermes-self-hosted

# Recommended: explicit config path
sudo ./scripts/bootstrap.sh --config ./bootstrap.yaml
sudo ./scripts/bootstrap.sh --config /etc/hermes/host.yaml

# Or place bootstrap.yaml next to bootstrap.sh and omit --config
sudo ./scripts/bootstrap.sh
```

If config or mise/yq is missing, bootstrap exits immediately — before changing the host.

Current flags: `--config PATH`, `-h` / `--help`.

Legacy flags (`--hostname`, `--timezone`, `--ssh-key`) and interactive prompts are removed — use the YAML config.

## What it does

| Step | Description |
|------|-------------|
| Preflight | Resolves config; requires mise + yq (no tool installs) |
| Config load | Parses and validates the YAML config |
| System update | `apt update && apt upgrade` |
| Packages | Four apt groups (including `docker.io`) — see [Packages](#packages) |
| Hostname | From config |
| Timezone | From config (default `UTC`) |
| Locale | `en_US.UTF-8` |
| User PATH | Writes `/etc/profile.d/00-local-bin.sh` — every login user gets `~/.local/bin` on `PATH` |
| Admin user | Detected via `$SUDO_USER` — existing account, not created; `docker` group; creates `~/.local/bin` |
| Hermes user | Creates agent user from config (default `hermes`, no sudo, key-only); `docker` group; creates `~/.local/bin` |
| SSH key | Same host key (`ssh.public_key` or `ssh.public_key_file`) appended on **hermes and admin** if missing |
| Root lock | Locks root account |
| SSH drop-in dir | Creates `/etc/ssh/sshd_config.d/` |
| State file | Writes `~/.hermes-self-hosted/bootstrap.state` |

## State and re-runs

### Location

```
~/.hermes-self-hosted/bootstrap.state
```

`~` is the home of `$SUDO_USER` (the admin who ran `sudo`), not root.

### Format

```ini
COMPLETED_AT=2026-06-29T12:00:00Z
SCRIPT_VERSION=2.0.0
HOSTNAME=hermes-server
ADMIN_USER=admin
HERMES_USER=hermes
PREVIOUS_HOSTNAME=debian-default
CONFIG_HASH=<sha256-of-config-file-contents>
MISE_VERSION=2024.x.x
```

- **CONFIG_HASH** — SHA-256 of config **file contents** (not the path); changes are logged on re-run  
- **Idempotency** — hostname / user / SSH key / `00-local-bin.sh` / docker group steps skip when already applied
- **Partial runs** — state is written only on success  

### Legacy migration

If `/var/lib/hermes-self-hosted/bootstrap.state` exists, bootstrap migrates it to the new location when possible (or warns if it cannot). Old fields are copied; `PREVIOUS_HOSTNAME` is set from the old hostname; `CONFIG_HASH` / `MISE_VERSION` may be empty after migration.

## Packages

Four `apt` groups. Only packages missing from Debian 13 netinst + SSH server + standard system utilities.

Already on the OS (not listed below): `openssh-server`, `wget`, `apt-listchanges`, `iproute2`, `sudo`. `ufw` is installed by [HARDENING.md](HARDENING.md). The official Hermes installer does **not** install Docker.

### Host baseline

Downloads, git, rsync, unattended upgrades, and `tree`.

| Package | Purpose |
|---------|---------|
| `curl` | Downloads |
| `git` | Version control |
| `rsync` | File transfer (host side) |
| `unattended-upgrades` | Auto security updates — configured in hardening |
| `tree` | Directory listing |

### Network stack

Tools for the Hermes host. Debian already ships `iproute2` (`ip`, `ss`); this group adds the classic extras.

| Package | Purpose |
|---------|---------|
| `nmap` | Network scanner |
| `net-tools` | `ifconfig`, `netstat`, `route` |

### Hermes Agent system packages

Prepare the host for [install.md](hermes/install.md) so the official installer does not prompt the passwordless `hermes` user for `sudo`.

| Package | Purpose |
|---------|---------|
| `build-essential`, `python3-dev`, `libffi-dev` | Python build deps (unprivileged install) |
| `ripgrep`, `ffmpeg` | Optional tools the installer looks for (fast search, TTS) |

### Docker

Debian `docker.io` (engine + CLI). Not the Docker Inc. vendor repo. **admin and hermes** are added to the `docker` group so the CLI works without sudo after a new login.

| Package | Purpose |
|---------|---------|
| `docker.io` | Docker engine and CLI for container work on the host |

`systemctl enable --now docker` runs after the package install. Group membership is applied after both users exist (admin already does; hermes is created just before).

## Users after bootstrap

| User | Sudo | Password | Auth | Extra groups |
|------|------|----------|------|--------------|
| `<admin>` (`$SUDO_USER`) | Yes (from OS install) | As configured during Debian install | Same host SSH key as hermes (appended if not already present) | `docker` |
| `hermes` (or config override) | No | Disabled | Same host SSH key from config | `docker` |

Bootstrap writes `/etc/profile.d/00-local-bin.sh` once:

```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

SSH logins pick it up. Why the `00-` prefix: [MISE.md](MISE.md).

## After running

Verify SSH for both users before disconnecting.

```bash
ssh <admin>@<server-ip>
ssh -i ~/.ssh/hermes_vbox hermes@<server-ip>
```

On the host (hermes home is not world-readable):

```bash
sudo cat /home/hermes/.ssh/authorized_keys
sudo ssh-keygen -lf /home/hermes/.ssh/authorized_keys
```

Bootstrap **appends** the config key when that type+blob is missing; it does not replace other keys. To remove a key, edit `authorized_keys` — see [SSH-KEYS.md](SSH-KEYS.md).

Docker: after a **new login** as admin or `hermes`, `docker version` (or `docker info`) works without sudo. An existing session will not see the `docker` group until you reconnect.

Then proceed to [HARDENING.md](HARDENING.md).

## Standalone / out-of-repo

Copy `bootstrap.sh` anywhere and inject a config:

```bash
sudo ./bootstrap.sh --config /path/to/any-host.yaml
```

Or place `bootstrap.yaml` next to the script. Run from a directory with `mise.host.toml` after `./scripts/mise.sh install` so host `yq` is available. Use `config/bootstrap.example.yaml` as a format template — it is not a required path.

## Related

- [INSTALLATION.md](INSTALLATION.md) — ordered self-hosted path  
- [MISE.md](MISE.md) — mise install (per-user or shared binary), system-wide `profile.d`, uninstall  
- [SSH-KEYS.md](SSH-KEYS.md) — generate keys for the hermes user  
- [FILE-TRANSFER.md](FILE-TRANSFER.md) — copy config/keys to the host  
- [HARDENING.md](HARDENING.md) — next step after bootstrap  

