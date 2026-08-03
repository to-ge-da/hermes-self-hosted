# Hermes profile templates

Starter templates for Hermes Agent **USER.md** (user profile) and **MEMORY.md** (agent notes).

## What they are

| File | Purpose |
|---|---|
| `USER.md` | Persistent user profile: languages, communication style, preferred tools, and conventions |
| `MEMORY.md` | Agent notes: host environment, tool preferences, and other facts Hermes should remember across sessions |

Hermes reads these files so context survives between chats instead of being re-explained every time.

## Where they live

After install, place customized copies under the Hermes home directory:

- `~/.hermes/USER.md`
- `~/.hermes/MEMORY.md`

If you run Hermes as the `hermes` system user, that path is typically `/home/hermes/.hermes/`.

## How to use the templates

1. Copy the starters from this repo:

   ```bash
   mkdir -p ~/.hermes
   cp templates/USER.md.template ~/.hermes/USER.md
   cp templates/MEMORY.md.template ~/.hermes/MEMORY.md
   ```

2. Edit both files: replace `<placeholders>` with your real preferences and environment details.
3. Keep them updated when your setup or preferences change.

Template sources in this repository:

- [`templates/USER.md.template`](../templates/USER.md.template)
- [`templates/MEMORY.md.template`](../templates/MEMORY.md.template)

## Why they matter

Hermes uses profile and memory files as durable context. Filling them in once gives consistent language, tooling, and environment awareness across sessions without repeating the same setup notes in every conversation.
