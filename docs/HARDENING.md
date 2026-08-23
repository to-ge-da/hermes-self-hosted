# Hardening

Server security hardening. Run **after** [bootstrap](BOOTSTRAP.md).

## What it does

| Category | What it applies |
|----------|----------------|
| SSH | Key-only auth, no root login, rate limiting |
| Firewall | UFW — deny inbound, allow SSH (22/tcp); ping stays allowed via UFW `before.rules` |
| Brute-force | Fail2Ban — 3 attempts, 1h ban |
| Auto-updates | Unattended security upgrades (no auto-reboot) |
| Kernel | 16 sysctl parameters (ASLR, SYN cookies, pointer restrictions, etc.) |
| Resource limits | Disable core dumps for all users |
| Mandatory access | AppArmor enforced on all profiles |
| Auditing | auditd — monitor auth, user/group changes, sudo, cron, time, kernel modules |
| Integrity | AIDE file integrity database |
| Rootkits | rkhunter with updated signatures |
| File permissions | `/root` 700, `/etc/shadow` 600, crontab restricted to root |
| Shared memory | `/dev/shm` mounted noexec, nosuid, nodev |
| Services | Disable avahi, cups, nfs, rpcbind, bluetooth |

## Usage

```bash
# Copy script to the server
scp scripts/hardening.sh admin@<server-ip>:/home/admin/

# SSH in as admin and run
ssh admin@<server-ip>
chmod +x /home/admin/hardening.sh
sudo ./hardening.sh
```

## SSH hardening — detailed rationale

Each SSH parameter applied by the script is explained below. This is general Linux server knowledge — not specific to Hermes Agent — and applies to any Debian server exposed to a network.

### PermitRootLogin no

**What it does:** Blocks direct SSH login as `root`.

**Why:** `root` is the first target of any automated attack. Every Linux system has a `root` user, so bots don't need to guess the username — they only need the password or key. Forcing all access through a named user (with `sudo`) adds an extra layer: an attacker must first guess or obtain **both** a valid username AND a credential.

### PasswordAuthentication no

**What it does:** Disables password-based login entirely. Only SSH keys are accepted.

**Why:** Passwords are the weakest link in SSH security. They can be:
- Brute-forced (automated guessing)
- Reused across services (credential stuffing)
- Phished or keylogged
- Weak by human choice

SSH keys (Ed25519 or RSA 4096-bit) are cryptographically impractical to brute-force. Disabling passwords eliminates the entire class of password-based attacks.

### PubkeyAuthentication yes

**What it does:** Enables SSH key authentication.

**Why:** This is the mechanism that replaces passwords. Each key pair provides ~128 bits of security (Ed25519) — equivalent to a 26-character random password. The private key never leaves the client; the server only stores the public half, which is worthless to an attacker.

### PermitEmptyPasswords no

**What it does:** Blocks accounts that have no password set from logging in.

**Why:** A user account created with `--disabled-password` could technically be accessed if this isn't explicitly denied. Combined with `PasswordAuthentication no`, this is a defense-in-depth measure — it ensures there's no edge case where an empty password slips through.

### MaxAuthTries 3

**What it does:** Closes the connection after 3 failed authentication attempts.

**Why:** Lowers the ceiling on brute-force attacks per connection. Without this, an attacker can try dozens of keys or passwords in a single TCP session. At 3 attempts, they must reconnect after every 3 failures — drastically slowing down any brute-force attempt. Combined with Fail2Ban (which bans IPs after 3 failures in 10 minutes), this makes brute-force attacks infeasible.

### LoginGraceTime 20

**What it does:** Gives the client 20 seconds to authenticate before the server closes the connection.

**Why:** The default is 120 seconds. Reducing it to 20 seconds limits the window for:
- SYN flood attacks holding connections open
- Slow brute-force attempts that space out tries to avoid detection
- Resource exhaustion from dangling unauthenticated sessions

Legitimate users authenticate in under a second. A 20-second window is generous without being wasteful.

### ClientAliveInterval 300 + ClientAliveCountMax 2

**What it does:** Sends a keepalive message every 300 seconds (5 minutes). If 2 consecutive keepalives go unanswered (10 minutes total), the server terminates the session.

**Why:** Prevents "ghost sessions" — connections that appear active but whose client has disconnected without properly closing (laptop lid closed, network dropped, VPN disconnected). Without this, dead sessions accumulate indefinitely, consuming resources and appearing in `who`/`w` output. Ten minutes is a practical timeout: enough to survive brief network blips, short enough to clean up real disconnects.

### AllowUsers (dynamic)

**What it does:** Whitelist — only usernames with a non-empty `~/.ssh/authorized_keys` (plus `hermes`) are permitted to authenticate via SSH.

The script scans `/home/*/.ssh/authorized_keys` and writes `AllowUsers` from that list. If only `hermes` has a key, it **exits** unless you pass `--force` — otherwise disabling `PasswordAuthentication` can lock out the admin.

After bootstrap, the admin already has the host config key (appended if it was missing). You should not need a manual copy before hardening.

**Why:** This is the simplest SSH access control. System accounts (`www-data`, `git`, …) stay out. Do not run `--force` on a remote host unless you have console access.

### X11Forwarding no

**What it does:** Disables X11 graphical forwarding over SSH.

**Why:** A headless server has no display server. X11 forwarding is:
- Unnecessary — there's no GUI to forward
- A potential attack surface if X11 libraries are present
- Adds protocol complexity with no benefit on a server

### Port 22

**What it does:** Explicitly sets the SSH port to 22 (the default).

**Why:** Explicit is better than implicit. While changing the port to something non-standard (e.g., 2222) reduces noise from automated scanners, it's **security through obscurity** — not a real defense. A determined attacker will scan all ports. Keeping port 22 and hardening authentication is the correct approach. UFW already restricts inbound traffic to this port only.

## Verifying the hardening

```bash
# Check SSH config
sshd -T | grep -E "(permitroot|passwordauth|pubkey)"

# Check firewall
sudo ufw status verbose

# Check Fail2Ban
sudo fail2ban-client status sshd

# Check kernel params
sudo sysctl -a | grep -E "(rp_filter|syncookies|kptr|dmesg|randomize)"

# Check auditd
sudo auditctl -l

# Check /dev/shm
mount | grep /dev/shm
```

## Reboot

A reboot is needed to apply all kernel and mount changes:

```bash
sudo reboot
```
