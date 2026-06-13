# Bootstrap

Initial system setup for a fresh Debian Server installation.

## What it does

| Step | Description |
|------|-------------|
| System update | `apt update && apt upgrade` |
| Essential packages | sudo, openssh-server, curl, wget, git, vim, ufw, unattended-upgrades |
| Hostname | Set server hostname |
| Timezone | Configure timezone interactively |
| Locale | Set to `en_US.UTF-8` |
| Admin user | Creates a sudo user with SSH key |
| Hermes user | Creates a dedicated agent user (no sudo, key-only) |
| Sudoers | Passwordless sudo for admin user |
| Root lock | Locks root account |
| SSH drop-in dir | Creates `/etc/ssh/sshd_config.d/` |

## Usage

```bash
# Copy script to the server
scp scripts/bootstrap.sh root@<server-ip>:/root/

# SSH in and run
ssh root@<server-ip>
chmod +x /root/bootstrap.sh
./bootstrap.sh
```

The script is interactive — it will ask for:
- Hostname
- Admin username (default: `admin`)
- SSH public key for admin user
- SSH public key for hermes user

## Users created

| User | Sudo | Password | Auth |
|------|------|----------|------|
| `admin` | Yes (NOPASSWD) | Disabled | SSH key only |
| `hermes` | No | Disabled | SSH key only |

## After running

Verify SSH access for both users before disconnecting:

```bash
ssh admin@<server-ip>
ssh hermes@<server-ip>
```

Then proceed to [hardening](hardening.md).
