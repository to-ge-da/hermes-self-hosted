# Hardening

Server security hardening. Run **after** [bootstrap](bootstrap.md).

## What it does

| Category | What it applies |
|----------|----------------|
| SSH | Key-only auth, no root login, rate limiting |
| Firewall | UFW — deny inbound, allow only SSH (22/tcp) |
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

## SSH behavior after hardening

- Root login: **disabled**
- Password auth: **disabled**
- Only SSH keys accepted
- Max 3 attempts, 20s login grace time
- Users allowed: `admin`, `hermes`

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
