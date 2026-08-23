# Mise

How this repository uses [mise](https://mise.jdx.dev/) for the local toolchain, host first-boot pins, optional system-wide activation, and full uninstall.

Two config files (mise only loads the `mise*.toml` names):

| File | Audience | How it loads |
|---|---|---|
| [`mise.toml`](../mise.toml) | Workstation / clone | default `mise install` |
| [`mise.host.toml`](../mise.host.toml) | First-boot host | `mise -E host`, with root `mise.toml` ignored |

`yq` is host-only (`mise.host.toml`). Root `mise.toml` pins `shellcheck` for the local toolchain.

One script (CLI verbs unchanged):

| Command | Purpose |
|---|---|
| [`scripts/mise.sh`](../scripts/mise.sh) `install` | Official installer + host pins (`mise.host.toml`) |
| `system-wide` | Create or remove `/etc/profile.d/mise.sh` |
| `uninstall` | Remove mise, its tools, and user activation |

```bash
./scripts/mise.sh --help
```

## Role in this repo

Bootstrap does **not** install mise. It expects the admin user (`$SUDO_USER`) to already have mise and the host pins from [`mise.host.toml`](../mise.host.toml).

Today that pins:

```toml
[tools]
yq = "4.53.3"
```

Bootstrap runs `mise -E host exec -- yq` (root `mise.toml` ignored) to parse the YAML config. Details: [BOOTSTRAP.md](BOOTSTRAP.md) (purpose and prerequisites).

Root [`mise.toml`](../mise.toml) is the **local toolchain** — what you get with `mise install` in a clone. Today that pins `shellcheck`. Those tools must not land on a fresh Debian host.

### Why not bare `mise -E host`

mise config environments **merge**. Load order (top wins, all still load):

1. `mise.{ENV}.local.toml`
2. `mise.local.toml`
3. `mise.{ENV}.toml`
4. `mise.toml`

So `mise -E host install` alone still installs `[tools]` from root `mise.toml`. Host wrappers always set `MISE_IGNORED_CONFIG_PATHS` to that file. Do **not** document or run bare `mise -E host` as the host path.

## Install mise and tools

Requires `curl` on the host — see [INSTALLATION.md](INSTALLATION.md#prerequisites).

### Host (first-boot)

As the admin user (not root), once per host, from the repo root (directory with `mise.toml` and `mise.host.toml`):

```bash
./scripts/mise.sh install
```

First-boot one-liner (install + system-wide activation):

```bash
sudo ./scripts/mise.sh install --system-wide
```

This installs **only** host pins. Idempotent: skips the official installer if mise is already present; `mise -E host install` is safe to re-run.

Then run bootstrap as documented in [BOOTSTRAP.md](BOOTSTRAP.md).

### Workstation (local toolchain)

From the repo root, no wrapper:

```bash
mise install
```

That reads `mise.toml` only (no `-E`). Use this in a clone. Do not use `./scripts/mise.sh install` when you want laptop tools.

### Verify

```bash
mise --version

# workstation toolchain
mise exec -- shellcheck --version

# host pins (same ignore as the wrappers)
MISE_IGNORED_CONFIG_PATHS="$PWD/mise.toml" mise -E host exec -- yq --version
```

## System-wide activation (optional)

Make mise-managed tools available to **all users** on login — no per-session `PATH` export.

### How it works

`system-wide` creates `/etc/profile.d/mise.sh`, sourced by Bourne-compatible login shells on Debian. It:

1. Adds mise shims to `PATH`
2. Runs `mise activate bash` when `mise` is on `PATH`

`~/.local/bin` is bootstrap’s job (`00-local-bin.sh`, see [BOOTSTRAP.md](BOOTSTRAP.md)). The `00-` prefix runs before `mise.sh` so `mise activate` keeps that path. `--remove` deletes `mise.sh` only.

Works for SSH, console logins, and `sudo -i` without editing each user’s `~/.bashrc`.

Bootstrap does **not** depend on system-wide mise.

### Enable

Requires root and an existing mise install for `$SUDO_USER`:

```bash
sudo ./scripts/mise.sh system-wide
```

Or combine with install: `sudo ./scripts/mise.sh install --system-wide`.

Idempotent: skips if the file already has the expected content. If the file differs, prompts interactively or exits in non-interactive mode (use `--remove` first to start fresh).

### Verify

Open a **new** login shell:

```bash
echo "$PATH" | grep mise
mise doctor
which yq
```

### Disable (profile.d only)

```bash
sudo ./scripts/mise.sh system-wide --remove
```

Deletes `/etc/profile.d/mise.sh`. Takes effect in new login sessions. Does **not** uninstall mise or its tools, and does **not** remove `00-local-bin.sh`.

### Manual per-user alternative

Instead of system-wide activation, add to each user’s `~/.bashrc`:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate bash)"
```

## Full uninstall

`uninstall` completely removes mise from the admin account:

1. `mise uninstall --all` — remove installed tool versions
2. `mise unuse -g …` — clear global tool config
3. Capture paths from `mise implode -n --config` and delete them
4. Remove well-known user paths (`~/.local/bin/mise`, `~/.local/share/mise`, …)
5. Strip `mise activate` lines from `~/.bashrc` (backup: `~/.bashrc.bak`)

```bash
./scripts/mise.sh uninstall
sudo ./scripts/mise.sh uninstall --system-wide   # also deletes profile.d
```

If you enabled system-wide activation and uninstall without `--system-wide`, remove the leftover file:

```bash
sudo ./scripts/mise.sh system-wide --remove
```

Then open a new login session so PATH no longer references mise shims.

## Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| Bootstrap: mise/yq not ready | Tools not installed for `$SUDO_USER` | `./scripts/mise.sh install` |
| Login PATH is only mise shims + `/usr/bin` (no `~/.local/bin`) | Missing `/etc/profile.d/00-local-bin.sh`, or it sourced after `mise.sh` | Re-run bootstrap (plants the `00-` file), then a new login |
| Tools missing in new SSH session | `profile.d` not sourced | Use a login shell; confirm Bourne-compatible shell |
| `mise: command not found` at login | Binary gone but `profile.d` remains | `sudo ./scripts/mise.sh system-wide --remove` |
| PATH still has mise after uninstall | System-wide file left behind | Same `--remove` step, then new login |

## Technical notes

- The official installer runs as the admin user (`$SUDO_USER` under sudo), never as root — binary lands in `~/.local/bin`
- `/etc/profile.d/` scripts are sourced during login shell init
- `${HOME}` in `profile.d/*.sh` expands per user at runtime
- `~/.local/bin` is owned by bootstrap (`00-local-bin.sh`), not `mise.sh`
- `mise activate` is guarded with `command -v mise`
- System-wide file permissions: `644`
- Prefer `profile.d` over editing `/etc/profile` directly

## References

- [mise documentation](https://mise.jdx.dev/)
- [BOOTSTRAP.md](BOOTSTRAP.md) — first-boot setup; requires mise + yq
