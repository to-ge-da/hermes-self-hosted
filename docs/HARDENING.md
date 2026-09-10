# Hardening

Server security hardening. Run **after** [bootstrap](BOOTSTRAP.md).

## What it does

| Category | What it applies |
|----------|----------------|
| SSH | Key-only auth, no root login, rate limiting |
| Firewall | UFW — deny inbound, allow SSH (22/tcp); ping stays allowed via UFW `before.rules`. **Host traffic only** — see [UFW and Docker-published ports](#ufw-and-docker-published-ports) |
| Brute-force | Fail2Ban — 3 attempts, 1h ban |
| Auto-updates | Unattended security upgrades (no auto-reboot) |
| Kernel | 16 sysctl parameters (ASLR, SYN cookies, pointer restrictions, etc.) |
| Resource limits | Disable core dumps for all users |
| Mandatory access | AppArmor verified enabled. Distro-shipped profiles and modes are **not** modified — see [AppArmor](#apparmor) |
| Auditing | auditd — monitor auth, user/group changes, sudo, cron, time, kernel modules; rule load is verified |
| File permissions | `/root` 700, `/etc/shadow` 600, crontab restricted to root |
| Shared memory | `/dev/shm` mounted noexec, nosuid, nodev, verified |
| Integrity | AIDE file integrity database — baseline recorded **after** every other step above, so it reflects the final state |
| Rootkits | rkhunter with updated signatures — baseline recorded after every other step, same reasoning |
| Container runtime | Smoke test (`docker run --rm alpine:latest true`) — the script fails loudly if it does not pass |

## Usage

```bash
# Copy script to the server
scp scripts/hardening.sh admin@<server-ip>:/home/admin/

# SSH in as admin and run
ssh admin@<server-ip>
chmod +x /home/admin/hardening.sh
sudo ./hardening.sh
```

## UFW and Docker-published ports

`hardening.sh` enables UFW with `default deny incoming` and only `22/tcp` allowed. That guarantee covers **host** traffic — anything hitting the machine directly. It does **not** cover Docker-published container ports.

Docker's default `iptables=true` inserts its own `DOCKER` chains in `filter` and `nat`, plus a `FORWARD -j DOCKER` jump rule, and those are evaluated **before** UFW's forward chain. A container published with `-p 8080:80` (or `"8080:80"` in Compose) binds `0.0.0.0:8080` and is reachable from the whole LAN **regardless of UFW's `default deny incoming`**.

**Do not rely on UFW to protect a container port.** Instead, bind the port to localhost so it never leaves the host:

```yaml
ports:
  - "127.0.0.1:8080:80"   # host-local only — correct for anything not meant to be public
# NOT: "8080:80"          # binds 0.0.0.0 — reachable from the whole LAN, UFW does not stop it
```

If a service must be reachable from the LAN or the internet, publish it explicitly (`0.0.0.0:PORT:PORT` or the bare `PORT:PORT` form) and treat that as a deliberate, reviewed exposure — not something UFW is filtering for you.

This project does not recommend disabling Docker's iptables integration (`"iptables": false` in `/etc/docker/daemon.json`) to make UFW authoritative again. That is a heavier, non-default path that requires hand-written `DOCKER-USER` rules to avoid silently blocking all container traffic; the bind-address pattern above is simpler and does not require touching Docker's networking.

## AppArmor

`hardening.sh` **verifies** AppArmor is enabled (`aa-status --enabled`); it does not modify any profile. It fails loudly (`err`) if AppArmor is not enabled.

AppArmor on Debian is enabled by default, and many of the distro-shipped profiles are intentionally not in enforce mode — e.g. `runc`, `firefox`, and most Electron apps ship `flags=(unconfined)`, and `unprivileged_userns` ships `flags=(complain)`. Those flags exist so the process gets a *name* under AppArmor instead of running fully unconfined; they are not a bug to "fix".

An earlier version of this script ran `aa-enforce /etc/apparmor.d/* 2>/dev/null || true`. `aa-enforce` rewrites the matched profile file and **strips its mode flags** — it does not just "turn on enforce mode" for an already-working profile. On a real host this rewrote 95 of 97 distro profiles into empty, default-deny enforcing profiles, which broke `runc` (no container could start — Docker failed with `runc did not terminate successfully: exit status 127`, because AppArmor denied `runc` from even loading `libseccomp.so.2`) and broke unprivileged-userns sandboxes used by browsers and Electron apps. `2>/dev/null || true` hid the failure and the script still reported `✓ AppArmor enforced`.

Any future opt-in mode change for a specific profile must use an explicit, curated list of profile names — never a glob over `/etc/apparmor.d/*`.

### AppArmor recovery

If a host was hardened by a version of this script that ran `aa-enforce` on the glob, restore the distro-shipped profiles from the package:

```bash
sudo cp -a /etc/apparmor.d /root/apparmor.d.bak-$(date +%F)   # optional, keep the damaged copy
sudo apt-get install --reinstall -y -o Dpkg::Options::="--force-confnew" apparmor
sudo systemctl reload apparmor
sudo systemctl restart docker
docker run --rm alpine:latest true   # must exit 0
```

If the reload alone does not clear a stale compiled policy, force a reload through the parser and confirm the kernel's view directly:

```bash
sudo rm -rf /var/cache/apparmor/*
sudo apparmor_parser --write-cache --replace -- /etc/apparmor.d
grep -E '^(runc|unprivileged_userns) ' /sys/kernel/security/apparmor/profiles
```

A successful `systemctl reload apparmor` (or `active` service state) is **not** proof the kernel policy actually changed — always confirm with a real `docker run --rm alpine:latest true`, not a unit/service check.

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

# Check firewall (host traffic only — see UFW and Docker-published ports above)
sudo ufw status verbose

# Check Fail2Ban
sudo fail2ban-client status sshd

# Check kernel params
sudo sysctl -a | grep -E "(rp_filter|syncookies|kptr|dmesg|randomize)"

# Check AppArmor (should be "Y")
sudo aa-status --enabled && echo Y

# Check auditd
sudo auditctl -l

# Check /dev/shm
mount | grep /dev/shm

# Check the AIDE baseline is clean (recorded after every other step above)
sudo aide --check

# Container runtime smoke test — the same gate hardening.sh ends with.
# A hardened, working host prints "OK" and exits 0. If AppArmor profiles
# are damaged (see AppArmor recovery above), this is what will catch it —
# a healthy `docker info` / `systemctl is-active docker` will not.
docker run --rm alpine:latest echo OK
```

Expected output for the last command on a passing host:

```
OK
```

If it instead fails with something like `runc did not terminate successfully` or `OCI runtime create failed`, see [AppArmor recovery](#apparmor-recovery).

## Reboot

A reboot is needed to apply all kernel and mount changes:

```bash
sudo reboot
```
