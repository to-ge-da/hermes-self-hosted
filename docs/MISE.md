# Mise

How this repository uses [mise](https://mise.jdx.dev/) for the local toolchain, host first-boot pins, optional system-wide install, and full uninstall.

Two config files (mise only loads the `mise*.toml` names):

| File | Audience | How it loads |
|---|---|---|
| [`mise.toml`](../mise.toml) | Workstation / clone | default `mise install` |
| [`mise.host.toml`](../mise.host.toml) | First-boot host | `mise -E host`, with root `mise.toml` ignored |

`yq` is host-only (`mise.host.toml`). Root `mise.toml` pins `shellcheck` for the local toolchain.

One script, two official [installer](https://mise.jdx.dev/installing-mise.html) paths:

| Command | Method | Binary |
|---|---|---|
| [`scripts/mise.sh`](../scripts/mise.sh) `install` | **1 — per-user** | `curl https://mise.run \| sh` → `~/.local/bin/mise` for the admin user |
| `install --system-wide` | **2 — shared** | `curl https://mise.run \| MISE_INSTALL_PATH=/usr/local/bin/mise sh` → `/usr/local/bin/mise` + `/etc/profile.d/mise.sh` |
| `system-wide` | **2 — shared** | Install `/usr/local/bin/mise` if missing, then write `profile.d` |
| `uninstall` | method 1 cleanup | Admin tools + `~/.local/bin/mise`. Leaves the shared binary and `profile.d` |

```bash
./scripts/mise.sh --help
```

Method 1 does **not** give other users (`hermes`, later `adduser`) a `mise` binary. Claim “all users” only for method 2.

## Role in this repo

Bootstrap does **not** install mise. It expects the admin user (`$SUDO_USER`) to already have mise and the host pins from [`mise.host.toml`](../mise.host.toml).

Today that pins:

```toml
[tools]
yq = "4.53.3"
```

Bootstrap runs `mise -E host exec -- yq` (root `mise.toml` ignored) to parse the YAML config. Details: [BOOTSTRAP.md](BOOTSTRAP.md) (purpose and prerequisites).

Root [`mise.toml`](../mise.toml) is the **local toolchain** — what you get with `mise install` in a clone. Today that pins `shellcheck`. Those tools must not land on a fresh Debian host.

Host pins stay on the **admin user** even with method 2. After install, that user also gets `mise use -g --pin` so login shims resolve (`yq` works without `-E host`). This script installs the **mise binary** for every login (method 2); it does not run `mise install --system` for tools.

### Why not bare `mise -E host`

mise config environments **merge**. Load order (top wins, all still load):

1. `mise.{ENV}.local.toml`
2. `mise.local.toml`
3. `mise.{ENV}.toml`
4. `mise.toml`

So `mise -E host install` alone still installs `[tools]` from root `mise.toml`. Host wrappers always set `MISE_IGNORED_CONFIG_PATHS` to that file. Do **not** document or run bare `mise -E host` as the host path.

## Install mise and tools

Requires `curl` on the host — see [INSTALLATION.md](INSTALLATION.md#prerequisites).

### Host (first-boot) — method 1

As the admin user (not root), once per host, from the repo root (directory with `mise.toml` and `mise.host.toml`):

```bash
./scripts/mise.sh install
```

Official installer as that user → `~/.local/bin/mise`, then host pins. Other login users do **not** get `mise`.

Idempotent: skips the official installer if mise is already present (user or shared binary); `mise -E host install` is safe to re-run.

Then run bootstrap as documented in [BOOTSTRAP.md](BOOTSTRAP.md).

### Host (first-boot) — method 2

Shared binary plus `profile.d`, and host pins for the admin user:

```bash
sudo ./scripts/mise.sh install --system-wide
```

This is what makes `command -v mise` work for every login user (Debian already has `/usr/local/bin` on the default `PATH`). Bootstrap still only needs host `yq` for `$SUDO_USER`.

Shared binary only (no host pins):

```bash
sudo ./scripts/mise.sh system-wide
```

Idempotent: skips the download if `/usr/local/bin/mise` already exists. Does **not** copy or symlink a user `~/.local/bin/mise`.

### Workstation (local toolchain)

From the repo root, no wrapper:

```bash
mise install
```

That reads `mise.toml` only (no `-E`). Use this in a clone. Do not use `./scripts/mise.sh install` when you want laptop tools.

### Verify

```bash
mise --version
command -v mise
# method 2: /usr/local/bin/mise  |  method 1: ~/.local/bin/mise

# workstation toolchain (clone; not installed by mise.sh)
mise exec -- shellcheck --version

# host pins (admin user, after mise.sh install)
yq --version
```

After method 2, verify as a **different** login user (new login shell):

```bash
command -v mise   # /usr/local/bin/mise
```

## System-wide install (method 2, optional)

Method 2 installs the official binary at `/usr/local/bin/mise` and writes `/etc/profile.d/mise.sh`. That is what “available to all users on login” means.

### How it works

1. Official installer with `MISE_INSTALL_PATH=/usr/local/bin/mise` (root)
2. `/etc/profile.d/mise.sh` (Bourne-compatible login shells on Debian):
   - Adds mise shims to `PATH`
   - Runs `mise activate bash` when `mise` is on `PATH`

`~/.local/bin` is bootstrap’s job (`00-local-bin.sh`, see [BOOTSTRAP.md](BOOTSTRAP.md)). The `00-` prefix runs before `mise.sh` so `mise activate` keeps that path. `--remove` deletes `profile.d` only — the shared binary stays.

Works for SSH, console logins, and `sudo -i` without editing each user’s `~/.bashrc`.

Bootstrap does **not** depend on system-wide mise.

### Enable

```bash
sudo ./scripts/mise.sh system-wide
```

Or combine with host pins: `sudo ./scripts/mise.sh install --system-wide`.

`profile.d` is idempotent: skips if the file already has the expected content. If the file differs, prompts interactively or exits in non-interactive mode (use `--remove` first to start fresh).

### Disable (profile.d only)

```bash
sudo ./scripts/mise.sh system-wide --remove
```

Deletes `/etc/profile.d/mise.sh`. Takes effect in new login sessions. Does **not** remove `/usr/local/bin/mise`, host pins, or `00-local-bin.sh`.

### Manual per-user alternative

Instead of method 2, use method 1 and add to that user’s `~/.bashrc`:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate bash)"
```

That still only covers users who already have a `mise` binary.

## Full uninstall

`uninstall` removes mise from the admin account:

1. `mise uninstall --all` — remove installed tool versions
2. `mise unuse -g …` — clear global tool config (the pins `install` wrote with `mise use -g`)
3. Capture paths from `mise implode -n --config` and delete them (skips `/usr/local/bin/mise` unless `--system-wide`)
4. Remove well-known user paths (`~/.local/bin/mise`, `~/.local/share/mise`, …)
5. Strip `mise activate` lines from `~/.bashrc` (backup: `~/.bashrc.bak`)

```bash
./scripts/mise.sh uninstall
sudo ./scripts/mise.sh uninstall --system-wide   # also deletes shared binary + profile.d
```

Without `--system-wide`, leftovers stay:

```bash
sudo ./scripts/mise.sh system-wide --remove   # profile.d only
sudo ./scripts/mise.sh uninstall --system-wide
```

Then open a new login session so PATH no longer references mise shims.

## Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| Bootstrap: mise/yq not ready | Tools not installed for `$SUDO_USER` | `./scripts/mise.sh install` |
| `No version is set for shim: yq` | Host pin installed but not `use -g` | Re-run `./scripts/mise.sh install` (do not `mise use -g` by hand) |
| Other user: `mise: command not found` | Method 1 only (`~/.local/bin/mise`) | `sudo ./scripts/mise.sh system-wide` (method 2) |
| Login PATH is only mise shims + `/usr/bin` (no `~/.local/bin`) | Missing `/etc/profile.d/00-local-bin.sh`, or it sourced after `mise.sh` | Re-run bootstrap (plants the `00-` file), then a new login |
| `~/.local/bin` appears twice on login PATH | Stock `~/.profile` plus `00-local-bin.sh` or a stray `~/.bashrc` export | Re-run bootstrap (makes `.profile` skip duplicates, strips the bashrc line), then a new login |
| Tools missing in new SSH session | `profile.d` not sourced | Use a login shell; confirm Bourne-compatible shell |
| `mise: command not found` at login | Binary gone but `profile.d` remains | `sudo ./scripts/mise.sh system-wide --remove` |
| PATH still has mise after uninstall | System-wide file left behind | Same `--remove` step, then new login |

## Technical notes

- Method 1: official installer as the admin user (`$SUDO_USER` under sudo), never as root → `~/.local/bin/mise`
- Method 2: official installer as root with `MISE_INSTALL_PATH=/usr/local/bin/mise`. Never copy/symlink a user binary into `/usr/local/bin`
- Script PATH under sudo includes `/usr/local/bin` (not only `~/.local/bin:/usr/bin:/bin`)
- `/etc/profile.d/` scripts are sourced during login shell init
- `${HOME}` in `profile.d/*.sh` expands per user at runtime
- `~/.local/bin` is owned by bootstrap (`00-local-bin.sh`), not `mise.sh`
- `mise activate` is guarded with `command -v mise`
- System-wide file permissions: `644`
- Prefer `profile.d` over editing `/etc/profile` directly

## References

- [mise documentation](https://mise.jdx.dev/)
- [Installing mise](https://mise.jdx.dev/installing-mise.html) — both `mise.run` paths
- [BOOTSTRAP.md](BOOTSTRAP.md) — first-boot setup; requires mise + yq
