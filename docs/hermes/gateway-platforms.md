# Gateway platforms (day 2)

Optional. Day 1 ends at the gateway **user unit** ([INSTALLATION.md](../INSTALLATION.md) steps 9–10). This page is Telegram and SimpleX on that already-running unit.

Work as **`hermes`**. Write `~/.hermes/.env` (append; never replace a working file). Do **not** run `hermes gateway setup`. Never commit `.env`. Never `GATEWAY_ALLOW_ALL_USERS=true`. Never put tokens or contact IDs in `bootstrap.yaml` / git.

After any `.env` change:

```bash
hermes gateway restart
hermes gateway status
```

## Telegram

Bot token + numeric allowlist. No extra daemon.

1. [@BotFather](https://t.me/BotFather) → `/newbot` → `TELEGRAM_BOT_TOKEN` (looks like `123456789:AA…`; contains `:`, do **not** quote).
2. [@userinfobot](https://t.me/userinfobot) → numeric user ID. Not `@username`.
3. Append to `~/.hermes/.env`:

```bash
TELEGRAM_BOT_TOKEN=your-token-here
TELEGRAM_ALLOWED_USERS=123456789
```

Always set `TELEGRAM_ALLOWED_USERS`. Restart the gateway. Status should show Telegram connected; send one DM.

Groups, privacy mode, extra BotFather polish: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/telegram

## SimpleX

Local `simplex-chat` daemon on port 5225 + allowlist. No BotFather. Contacts are opaque `contactId`s (display name also works).

### Daemon

Install the official Linux binary (no Docker image). Ubuntu 22.04 build is what upstream documents:

```bash
mkdir -p ~/.local/bin
curl -L https://github.com/simplex-chat/simplex-chat/releases/latest/download/simplex-chat-ubuntu-22_04-x86_64 -o ~/.local/bin/simplex-chat
chmod +x ~/.local/bin/simplex-chat
```

First run needs a TTY (create the profile, share the invitation link). Then keep it up as a **user** unit — not `--system` (`hermes` has no sudo). Linger is already on from bootstrap.

```ini
# ~/.config/systemd/user/simplex-chat.service
[Unit]
Description=SimpleX Chat daemon
After=network.target

[Service]
ExecStart=%h/.local/bin/simplex-chat -p 5225
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now simplex-chat.service
```

`websockets` in the hermes venv (path from [uninstall.md](uninstall.md)):

```bash
~/.hermes/hermes-agent/venv/bin/pip install websockets
```

### Hermes

Append to `~/.hermes/.env`:

```bash
SIMPLEX_WS_URL=ws://127.0.0.1:5225
SIMPLEX_ALLOWED_USERS=4
```

`SIMPLEX_ALLOWED_USERS` accepts a numeric `contactId` and/or display name (`4,alice`). Always set it. Never `SIMPLEX_ALLOW_ALL_USERS=true`.

Fallback: message the bot → `hermes pairing approve simplex <code>`. Prefer writing the allowlist once the `contactId` is known.

Restart the gateway. Check the daemon is on `5225`, status shows SimpleX connected, send one DM.

Groups, attachments, cron, `hermes send`: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/simplex

## Reference

- Ordered path: [INSTALLATION.md](../INSTALLATION.md)
- Gateway unit: [install.md](install.md#gateway-247-access)
- Official index: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/
