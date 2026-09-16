# Hermes serve as a headless backend

Day 2. Keep `hermes serve` running on this Debian box so a workstation client can attach **without** serving the dashboard SPA. For the browser admin UI, stay on [dashboard-service.md](dashboard-service.md).

## What it is

`hermes serve` starts the **same HTTP/WebSocket server** as `hermes dashboard`, but headless — no SPA, no browser.

Default bind: `http://127.0.0.1:9119`.

A workstation Hermes Desktop can attach to this backend. This box never runs Desktop.

The messaging gateway is a **different** process. Its systemd **user** unit is already in [install.md](install.md#gateway-247-access) (`hermes gateway install`). Do not treat `hermes serve` as a gateway daemon.

Official CLI: https://hermes-agent.nousresearch.com/docs/reference/cli-commands

## dashboard vs serve vs gateway

| Command | UI | Sockets | Default port | Who starts it |
|---------|----|---------|--------------|---------------|
| `hermes dashboard` | Browser SPA | `/api/ws`, `/api/pty` | `9119` | You (tmux or user unit on this box) |
| `hermes serve` | None (headless) | `/api/ws`, `/api/pty` | `9119` | You (tmux or user unit on this box) |
| `hermes gateway` | Messaging apps | Not the dashboard sockets | Not `9119` | You ([gateway user unit](install.md#gateway-247-access)) |

Pick **either** dashboard **or** serve on port `9119`. Gateway stays separate either way. If the dashboard unit is already running, you do not need serve.

Official docs disagree on which command is “the” remote process: Desktop names `hermes serve`, the web dashboard page names `hermes dashboard`. Either works; this page is serve, [dashboard-service.md](dashboard-service.md) is the SPA.

## Prerequisites

- Hermes Agent installed as the **hermes** user ([install.md](install.md)). Check: `hermes --version`.
- `[web]` extra (FastAPI + Uvicorn):

  ```bash
  cd ~/.hermes/hermes-agent && uv pip install -e ".[web]"
  ```

- Chat socket (`/api/pty`): also `[pty]`:

  ```bash
  cd ~/.hermes/hermes-agent && uv pip install -e ".[web,pty]"
  ```

If `hermes serve --help` already works, skip the extras install — the CLI will tell you if `[web]` is missing.

- Option A: `tmux` (installed by [bootstrap](../BOOTSTRAP.md))
- Option B: systemd user session (default on this path)

## Flags

Verified against `hermes serve --help` (Hermes Agent v0.21.3). `--no-open` is omitted: serve never opens a browser. The CLI accepts the flag as a hidden no-op so legacy callers do not error; it is not in `--help`.

| Flag | Meaning |
|------|---------|
| `--host` | Bind address (default `127.0.0.1`) |
| `--port` | Port (default `9119`) |
| `--stop` | Stop running Hermes web server processes and exit |
| `--status` | List running Hermes web server processes and exit |
| `--skip-build` | Skip the web UI build; serve existing `dist` |
| `--insecure` | Deprecated no-op. A non-loopback bind still requires an auth provider. |

## Option A: tmux

```bash
tmux new-session -d -s hermes-serve 'hermes serve'
# equivalent: ~/.local/bin/hermes serve

hermes serve --status
hermes serve --stop
```

Attach: `tmux attach -t hermes-serve`. Detach: Ctrl-b then d.

Does not start on login/reboot unless you add your own hook.

## Option B: systemd user unit (preferred)

Survives logout (linger is already on from [bootstrap](../BOOTSTRAP.md)), restarts on failure, and logs to the journal.

### 1. Create the unit

```bash
mkdir -p ~/.config/systemd/user
```

Create `~/.config/systemd/user/hermes-serve.service`:

```ini
[Unit]
Description=Hermes headless backend (serve)
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/.hermes/hermes-agent
ExecStart=/home/hermes/.local/bin/hermes serve
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

Default bind is loopback (`127.0.0.1:9119`). Check linger: `loginctl show-user hermes -p Linger`.

### 2. Enable and start

```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-serve
hermes serve --status
```

## Managing the service

| Action | Command |
|--------|---------|
| Hermes process status | `hermes serve --status` |
| Stop via Hermes | `hermes serve --stop` |
| systemd status | `systemctl --user status hermes-serve` |
| Restart (systemd) | `systemctl --user restart hermes-serve` |
| Stop (systemd) | `systemctl --user stop hermes-serve` |
| Follow logs | `journalctl --user -u hermes-serve -f` |

Prefer **either** `systemctl --user` stop/restart **or** `hermes serve --stop` — not both. Mixing them can leave systemd trying to restart a process you just killed. With Option B, use `systemctl --user stop|restart hermes-serve`.

## Port 9119

Do not run `hermes dashboard` and `hermes serve` together. They share port `9119`. If the port is already held, serve prints `BACKEND_PORT_IN_USE` and exits `75`. If you already have the dashboard unit, you do not need serve.

```bash
hermes serve --status
```

## Remote access

Same gate as the dashboard (same `HERMES_DASHBOARD_*` env names). Full auth and proxy recipes live on [dashboard-service.md](dashboard-service.md) and the [official Web Dashboard docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard) — do not copy them here.

- **Preferred:** keep the loopback default and tunnel from the workstation: `ssh -L 9119:127.0.0.1:9119 hermes@<host>`
- **Off-loopback:** same basic-auth env as dashboard; load it with `EnvironmentFile=%h/.hermes/.env` on the unit
- **HTTPS proxy:** same `public_url` / `trusted_proxies` as dashboard

## Desktop attach

On the workstation: Settings → Gateways → Remote gateway. Set the URL to `http://127.0.0.1:9119` through the SSH tunnel (or the tailnet URL). Sign-in uses whatever provider the backend advertises. Official: [Connecting to a remote backend](https://hermes-agent.nousresearch.com/docs/user-guide/desktop#connecting-to-a-remote-backend).

## Reference

- CLI: https://hermes-agent.nousresearch.com/docs/reference/cli-commands
- Web dashboard (auth, SPA): https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard
- Desktop: https://hermes-agent.nousresearch.com/docs/user-guide/desktop
- Nix serve vs dashboard (one-liner): https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup/
