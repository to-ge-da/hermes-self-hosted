# Hermes Dashboard as a Background Service

Run the Hermes web dashboard (`hermes dashboard`) in the background on Debian / MX Linux so it stays up after you close the terminal.

> **Shallow clone warning:** The Hermes Agent source tree is large (~2 GB). Prefer a shallow clone when installing from source:
>
> ```bash
> gh repo clone to-ge-da/hermes-agent -- --depth 1
> ```

## Prerequisites

- Hermes Agent installed and working (`hermes --version` / `uv run hermes --version`)
- For Option A: `tmux`, `screen`, or `nohup` available (`tmux` is installed by [bootstrap](../BOOTSTRAP.md))
- For Option B: `systemd` user session (default on modern Debian; MX Linux with systemd)

There is **no built-in daemon flag** on `hermes dashboard`. Use tmux/nohup/screen or a systemd user unit. (`hermes serve` is a related headless backend — same bind/stop/status flags — not a dashboard daemon mode.)

Default bind: `http://127.0.0.1:9119`. Use `--no-open` when running unattended.

## Option A: Simple background (tmux / nohup / screen)

Good for quick local use. Does not start automatically on login/reboot unless you add your own hook.

### tmux (recommended for Option A)

```bash
cd ~/projects/hermes-agent   # or your install directory

tmux new-session -d -s hermes-dashboard 'uv run hermes dashboard --no-open'

# Attach to see logs
tmux attach -t hermes-dashboard

# Detach: Ctrl-b then d
# Stop the session
tmux kill-session -t hermes-dashboard
```

### nohup

```bash
mkdir -p ~/.hermes
cd ~/projects/hermes-agent

nohup uv run hermes dashboard --no-open > ~/.hermes/dashboard.log 2>&1 &
```

### screen

```bash
cd ~/projects/hermes-agent

screen -dmS hermes-dashboard bash -lc 'uv run hermes dashboard --no-open'

# Attach
screen -r hermes-dashboard
```

Built-in process helpers still work with these launches:

```bash
uv run hermes dashboard --status
uv run hermes dashboard --stop
```

## Option B: systemd user service (preferred)

Survives logout (with linger), restarts on failure, and logs to the journal.

### 1. Create the unit

Replace `USER` with your Linux username (e.g. `agentx` or `hermes`).

```bash
mkdir -p ~/.config/systemd/user
```

Create `~/.config/systemd/user/hermes-dashboard.service`:

```ini
[Unit]
Description=Hermes Agent Dashboard
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/USER/projects/hermes-agent
ExecStart=/home/USER/.local/bin/uv run hermes dashboard --no-open
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

Notes:

- Adjust `WorkingDirectory` if the agent lives elsewhere (official install may use `~/.hermes` / a venv instead of a git checkout).
- If `uv` is not under `~/.local/bin`, set `ExecStart` to the path from `command -v uv`.
- For a non-loopback bind (remote access), add flags and configure auth — see the [official Web Dashboard docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard). Example:

  ```ini
  ExecStart=/home/USER/.local/bin/uv run hermes dashboard --host 0.0.0.0 --port 9119 --no-open
  EnvironmentFile=%h/.hermes/.env
  ```

### 2. Enable and start

```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-dashboard
systemctl --user status hermes-dashboard
```

### 3. Survive logout (linger)

User units stop when the last session ends unless linger is enabled:

```bash
sudo loginctl enable-linger "$USER"
```

## Managing the service

| Action | Command |
|---|---|
| Hermes process status | `uv run hermes dashboard --status` |
| Stop via Hermes | `uv run hermes dashboard --stop` |
| systemd status | `systemctl --user status hermes-dashboard` |
| Restart (systemd) | `systemctl --user restart hermes-dashboard` |
| Stop (systemd) | `systemctl --user stop hermes-dashboard` |
| Disable on boot | `systemctl --user disable hermes-dashboard` |
| Follow logs | `journalctl --user -u hermes-dashboard -f` |

Prefer **either** systemd stop/restart **or** `hermes dashboard --stop` — mixing them can leave systemd trying to restart a process you just killed. With Option B, use `systemctl --user stop|restart hermes-dashboard`.

Open the UI locally: `http://127.0.0.1:9119`

## Troubleshooting

### Port already in use

Default port is `9119`.

```bash
uv run hermes dashboard --status
ss -ltnp | grep 9119
# or
lsof -i :9119
```

Stop the old process, or pick another port:

```bash
uv run hermes dashboard --stop
# or
uv run hermes dashboard --port 9120 --no-open
```

Update `ExecStart` in the unit if you change the port permanently, then:

```bash
systemctl --user daemon-reload
systemctl --user restart hermes-dashboard
```

### Permission / path issues

- Confirm `uv` and the working directory exist for the **same** user that owns the unit:

  ```bash
  command -v uv
  ls ~/projects/hermes-agent
  ```

- Run `systemctl --user status hermes-dashboard` and `journalctl --user -u hermes-dashboard -n 50` for `Permission denied`, missing `uv`, or wrong `WorkingDirectory`.
- Do not run the dashboard as root; use your normal or `hermes` service user.
- First launch may need a web UI build (`npm`). For non-interactive hosts, pre-build (`cd web && npm run build`) or use `--skip-build` only if `dist` already exists.

### Auth when binding off localhost

Binding `--host 0.0.0.0` engages the auth gate. Configure username/password or OAuth before starting as a service (non-interactive starts fail closed without a provider). Keep loopback + SSH tunnel if you only need local access.
