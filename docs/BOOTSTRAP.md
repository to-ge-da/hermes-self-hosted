# Bootstrap

Initial system setup for a fresh Debian Server installation.

## What it does

| Step | Description |
||------|-------------|
|| System update | `apt update && apt upgrade` |
|| Essential packages | sudo, openssh-server, curl, wget, git, vim, ufw, unattended-upgrades, apt-listchanges, tree, nmap |
|| Hostname | Set server hostname |
|| Timezone | Configure timezone interactively |
|| Locale | Set to `en_US.UTF-8` |
|| Admin user | Detected via `$SUDO_USER` — pre-existing from Debian install, no changes made |
|| Hermes user | Creates a dedicated agent user `hermes` (no sudo, key-only) |
|| Root lock | Locks root account |
|| SSH drop-in dir | Creates `/etc/ssh/sshd_config.d/` |

## Essential packages

These packages are installed during bootstrap. They form the minimal toolset for server management.

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
| `nmap` | Network scanner — used by `scan-lan.sh` |

## Usage

```bash
# Copy script to the server
scp scripts/bootstrap.sh <user>@<server-ip>:/home/<user>/

# SSH in and run with sudo
ssh <user>@<server-ip>
chmod +x /home/<user>/bootstrap.sh
sudo ./bootstrap.sh
```

The script is interactive — it will ask for:
- Hostname
- SSH public key for hermes user

The admin user is **detected automatically** via `$SUDO_USER` — the user invoking `sudo`. This is the user already created during Debian OS installation. SSH key for the admin is not configured by this script.

## Users after bootstrap

| User | Sudo | Password | Auth |
|------|------|----------|------|
| `<your-user>` | Yes (via sudo group, from OS install) | As configured during Debian install | SSH key (from Debian install or manual) |
| `hermes` | No | Disabled | SSH key only |

## After running

Verify SSH access for both users before disconnecting:

```bash
ssh <user>@<server-ip>
ssh hermes@<server-ip>
```

Then proceed to [hardening](HARDENING.md).
