# Mise

How this repository uses [mise](https://mise.jdx.dev/) for host tools, optional system-wide activation, and full uninstall.

One script:

| Command | Purpose |
|---|---|
| [`scripts/mise.sh`](../scripts/mise.sh) `install` | Official installer + `mise install` (pinned tools) |
| `system-wide` | Create or remove `/etc/profile.d/mise.sh` |
| `uninstall` | Remove mise, its tools, and user activation |

```bash
./scripts/mise.sh --help
```

## Role in this repo

Bootstrap does **not** install mise. It expects the admin user (`$SUDO_USER`) to already have mise and the pinned tools from the repo’s [`mise.toml`](../mise.toml).

Today that pins:

```toml
[tools]
yq = "4.53.3"
```

Bootstrap runs `mise exec -- yq` to parse the YAML config. Details: [BOOTSTRAP.md](BOOTSTRAP.md) (purpose and prerequisites).

## Install mise and tools

Requires `curl` on the host — see [INSTALLATION.md](INSTALLATION.md#prerequisites).

As the admin user (not root), once per host (or workstation clone), from the repo root (directory with `mise.toml`):

```bash
./scripts/mise.sh install
```

First-boot one-liner (install + system-wide activation):

```bash
sudo ./scripts/mise.sh install --system-wide
```

Idempotent: skips the official installer if mise is already present; `mise install` is safe to re-run.

Verify:

```bash
mise --version
mise exec -- yq --version
```

Then run bootstrap as documented in [BOOTSTRAP.md](BOOTSTRAP.md).

## System-wide activation (optional)

Make mise-managed tools available to **all users** on login — no per-session `PATH` export.

### How it works

`system-wide` creates `/etc/profile.d/mise.sh`, sourced by Bourne-compatible login shells on Debian. It:

1. Adds mise shims to `PATH`
2. Runs `mise activate bash` when `mise` is on `PATH`

Works for SSH, console logins, and `sudo -i` without editing each user’s `~/.bashrc`.

Bootstrap does **not** depend on this.

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

Deletes `/etc/profile.d/mise.sh`. Takes effect in new login sessions. Does **not** uninstall mise or its tools.

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
| Tools missing in new SSH session | `profile.d` not sourced | Use a login shell; confirm Bourne-compatible shell |
| `mise: command not found` at login | Binary gone but `profile.d` remains | `sudo ./scripts/mise.sh system-wide --remove` |
| PATH still has mise after uninstall | System-wide file left behind | Same `--remove` step, then new login |

## Technical notes

- The official installer runs as the admin user (`$SUDO_USER` under sudo), never as root — binary lands in `~/.local/bin`
- `/etc/profile.d/` scripts are sourced during login shell init
- `${HOME}` in `profile.d/mise.sh` expands per user at runtime
- `mise activate` is guarded with `command -v mise`
- System-wide file permissions: `644`
- Prefer `profile.d` over editing `/etc/profile` directly

## References

- [mise documentation](https://mise.jdx.dev/)
- [BOOTSTRAP.md](BOOTSTRAP.md) — first-boot setup; requires mise + yq
