# Uninstall Hermes Agent

Completely remove the official Hermes Agent installation from a Debian / MX Linux
host (self-hosted path from this repository).

Run these steps as the user that owns the install — typically the `hermes`
account created by bootstrap (`~/.hermes` under that home). Examples below use
`~`; substitute `/home/hermes` if you are managing the account via `sudo`.

## Overview

Uninstalling Hermes Agent removes:

| Artifact | Typical location |
|---|---|
| CLI symlink | `~/.local/bin/hermes` |
| Bundled Node shims (if present) | `~/.local/bin/{node,npm,npx}` → `~/.hermes/node/` |
| Agent code + Python venv | `~/.hermes/hermes-agent/` (venv at `hermes-agent/venv/`) |
| Config, secrets, sessions, skills, state | `~/.hermes/` (`config.yaml`, `.env`, `sessions/`, `skills/`, `state.db`, …) |
| Hermes-managed cron jobs | `~/.hermes/cron/` (and any user crontab lines that invoke `hermes`) |
| Gateway systemd user unit | `~/.config/systemd/user/hermes-gateway.service` |

It does **not** remove the OS `hermes` user created by bootstrap, SSH keys,
firewall rules, or mise. Those are host setup — see [BOOTSTRAP.md](../BOOTSTRAP.md),
[MISE.md](../MISE.md), and [HARDENING.md](../HARDENING.md).

**Preferred path:** use the built-in CLI when it still works:

```bash
hermes gateway stop
hermes gateway uninstall          # removes the systemd user unit
hermes uninstall                  # removes code + symlink; keeps ~/.hermes by default
# or wipe data too:
hermes uninstall --full -y
```

The rest of this guide is the **manual** procedure (broken CLI, partial
install, or you want an explicit checklist). Prefer a backup before deleting
`~/.hermes`.

## Step 1: Stop services

The messaging gateway is a **systemd user** service named
`hermes-gateway.service` (not a system-wide `hermes-agent` unit).

```bash
# As the Hermes install user
systemctl --user stop hermes-gateway.service
systemctl --user disable hermes-gateway.service

# Optional: confirm nothing is left running
systemctl --user status hermes-gateway.service
pgrep -af 'hermes_cli.main gateway' || true
```

If `hermes` still works:

```bash
hermes gateway stop
hermes gateway uninstall
```

**Legacy units:** older installs used `hermes.service`. Clean those up with:

```bash
hermes gateway migrate-legacy -y
# or manually:
systemctl --user stop hermes.service 2>/dev/null || true
systemctl --user disable hermes.service 2>/dev/null || true
rm -f ~/.config/systemd/user/hermes.service
systemctl --user daemon-reload
```

Multi-profile installs may also have `hermes-gateway-<profile>.service` units
under `~/.config/systemd/user/` — stop, disable, and remove each of them the
same way.

## Step 2: Remove cron jobs

Hermes schedules work in two places:

1. **Hermes cron store** — `~/.hermes/cron/` (removed with the home directory
   in Step 4). List jobs while the CLI still works: `hermes cron list`.
2. **User crontab** — optional entries that call `hermes` (updates, wrappers).

Check and edit the user crontab:

```bash
crontab -l | grep -i hermes || echo "No hermes crontab entries"
crontab -e   # delete any lines that invoke hermes, then save
```

Also check system cron drop-ins if you added any manually:

```bash
grep -ri hermes /etc/cron.* /var/spool/cron/crontabs 2>/dev/null || true
```

## Step 3: Remove the hermes binary

```bash
rm -f ~/.local/bin/hermes

# Official installer often adds Node shims pointing into ~/.hermes/node/
# Safe to remove if they link into that tree:
for cmd in node npm npx; do
  target=$(readlink -f ~/.local/bin/"$cmd" 2>/dev/null || true)
  case "$target" in
    "$HOME"/.hermes/*) rm -f ~/.local/bin/"$cmd" ;;
  esac
done
```

Optional shell PATH notes (not required aliases): some installs leave a comment
or PATH export related to Hermes in `~/.bashrc` / `~/.zshrc`. Remove those lines
if present:

```bash
grep -n -i hermes ~/.bashrc ~/.zshrc ~/.profile 2>/dev/null || true
```

## Step 4: Remove the hermes home

**Back up first** (Step 5) if you may reinstall or need sessions/skills/API keys.

```bash
# Destructive — deletes config, .env secrets, sessions, skills, venv, state DBs
rm -rf ~/.hermes
```

What that directory typically contains:

| Path | Role |
|---|---|
| `~/.hermes/config.yaml` | Settings |
| `~/.hermes/.env` | API keys and secrets |
| `~/.hermes/sessions/` | Conversation history |
| `~/.hermes/skills/` | Skills |
| `~/.hermes/cron/` | Scheduled jobs |
| `~/.hermes/hermes-agent/` | Cloned agent + `venv/` |
| `~/.hermes/state.db` | Runtime state |
| `~/.hermes/logs/` | Logs |

After removal, reload systemd so the missing unit file is cleared:

```bash
rm -f ~/.config/systemd/user/hermes-gateway.service
rm -f ~/.config/systemd/user/hermes-gateway-*.service
systemctl --user daemon-reload
```

## Step 5: Backup and restore

### Backup (before uninstall)

Built-in zip of config, skills, sessions, and data (excludes the agent codebase):

```bash
hermes backup -o ~/hermes-backup-$(date +%Y%m%d).zip

# Smaller snapshot of critical state only:
hermes backup --quick -o ~/hermes-backup-quick-$(date +%Y%m%d).zip
```

Or archive the whole home yourself:

```bash
tar -czf ~/hermes-home-$(date +%Y%m%d).tar.gz -C ~ .hermes
```

Store the archive **outside** `~/.hermes` (for example `~/` or another disk).

### Restore (after reinstall)

1. Reinstall Hermes ([INSTALL-HERMES.md](INSTALL-HERMES.md)).
2. Restore data:

```bash
# Official backup zip:
hermes import ~/hermes-backup-YYYYMMDD.zip
# or overwrite without prompts:
hermes import --force ~/hermes-backup-YYYYMMDD.zip

# Or from a tarball (stop the gateway first):
hermes gateway stop
tar -xzf ~/hermes-home-YYYYMMDD.tar.gz -C ~
hermes gateway start
```

## Step 6: Verify removal

```bash
which hermes || echo "hermes not on PATH (expected)"
command -v hermes && hermes --help   # should fail / not found
test -e ~/.hermes && echo "WARNING: ~/.hermes still exists" || echo "~/.hermes gone"
systemctl --user list-units --type=service --all | grep -i hermes || echo "No hermes user units"
ls ~/.config/systemd/user/*hermes* 2>/dev/null || echo "No hermes unit files"
crontab -l 2>/dev/null | grep -i hermes || echo "No hermes crontab lines"
```

Open a **new** shell (or `hash -r`) so a stale PATH cache does not still find
`hermes`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `hermes` still found after `rm` | Another copy on PATH, or shell hash | `type -a hermes`; `hash -r`; check `/usr/local/bin` |
| Gateway restarts after stop | Unit still enabled / lingering | `systemctl --user disable --now hermes-gateway`; `loginctl show-user "$USER" \| grep Linger` |
| `Failed to connect to bus` | No user systemd session | Log in on a real seat/SSH with lingering, or use `sudo -u hermes XDG_RUNTIME_DIR=/run/user/$(id -u hermes) systemctl --user …` |
| Service name not found | Legacy or profile unit | `systemctl --user list-unit-files \| grep hermes`; run `hermes gateway migrate-legacy` |
| Large leftover disk use | Missed `~/.hermes` or symlinks | `du -sh ~/.hermes ~/.local/bin/hermes 2>/dev/null`; remove remaining paths |
| Want OS user gone too | Bootstrap `hermes` account | Out of scope here — only after agent data is gone: remove user/home with care (`userdel`, etc.) |

Dry-run the official uninstaller without changing anything:

```bash
hermes uninstall --dry-run
```

## Re-installing

After a clean removal:

1. Follow [INSTALL-HERMES.md](INSTALL-HERMES.md) (official installer + gateway).
2. Or use the upstream one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

3. Restore a backup if needed (Step 5).
4. Official reference: [Updating & Uninstalling](https://hermes-agent.nousresearch.com/docs/getting-started/updating).

Host preparation (bootstrap / hardening) is unchanged — only re-run those if you
are rebuilding the machine, not for a normal agent reinstall.
