# Mise

How this repository uses [mise](https://mise.jdx.dev/) for host tools, optional system-wide activation, and full uninstall.

Scripts stay separate:

| Script | Purpose |
|---|---|
| [`scripts/install-mise-system-wide.sh`](../scripts/install-mise-system-wide.sh) | Create or remove `/etc/profile.d/mise.sh` |
| [`scripts/uninstall-mise.sh`](../scripts/uninstall-mise.sh) | Remove mise, its tools, and user activation |

## Role in this repo

Bootstrap does **not** install mise. It expects the admin user (`$SUDO_USER`) to already have mise and the pinned tools from the repo’s [`mise.toml`](../mise.toml).

Today that pins:

```toml
[tools]
yq = "4.53.3"
```

Bootstrap runs `mise exec -- yq` to parse the YAML config. Details: [BOOTSTRAP-CONFIG.md](BOOTSTRAP-CONFIG.md) (mise section) and [BOOTSTRAP.md](BOOTSTRAP.md) (prerequisites).

## Install mise and tools

As the admin user (not root), once per host (or workstation clone):

```bash
curl https://mise.run | sh
cd /path/to/hermes-self-hosted   # directory with mise.toml
mise install                     # installs pinned yq
```

Verify:

```bash
mise --version
mise exec -- yq --version
```

Then run bootstrap as documented in [BOOTSTRAP.md](BOOTSTRAP.md).

## System-wide activation (optional)

Make mise-managed tools available to **all users** on login — no per-session `PATH` export.

### How it works

[`install-mise-system-wide.sh`](../scripts/install-mise-system-wide.sh) creates `/etc/profile.d/mise.sh`, sourced by Bourne-compatible login shells on Debian. It:

1. Adds mise shims to `PATH`
2. Runs `mise activate bash` when `mise` is on `PATH`

Works for SSH, console logins, and `sudo -i` without editing each user’s `~/.bashrc`.

Bootstrap does **not** depend on this script.

### Install

Requires root and an existing `mise` on PATH:

```bash
sudo ./scripts/install-mise-system-wide.sh
```

Idempotent: skips if the file already has the expected content. If the file differs, prompts interactively or exits in non-interactive mode (use `--remove` first to start fresh).

### Verify

Open a **new** login shell:

```bash
echo "$PATH" | grep mise
mise doctor
which yq
```

### Remove system-wide config only

```bash
sudo ./scripts/install-mise-system-wide.sh --remove
```

Deletes `/etc/profile.d/mise.sh`. Takes effect in new login sessions. Does **not** uninstall mise or its tools.

### Manual per-user alternative

Instead of system-wide activation, add to each user’s `~/.bashrc`:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate bash)"
```

## Full uninstall

[`uninstall-mise.sh`](../scripts/uninstall-mise.sh) completely removes mise from the current account/environment:

1. `mise uninstall --all` — remove installed tool versions  
2. `mise unuse -g …` — clear global tool config  
3. Capture paths from `mise implode -n --config`  
4. Delete those paths (uses `sudo` if the binary is in `/usr/local/bin` or `/usr/bin`)  
5. Strip `mise activate` lines from `~/.bashrc` (backup: `~/.bashrc.bak`)

```bash
./scripts/uninstall-mise.sh
./scripts/uninstall-mise.sh --help
```

**Important:** this script does **not** remove `/etc/profile.d/mise.sh`. If you enabled system-wide activation, remove that first (or afterward) with:

```bash
sudo ./scripts/install-mise-system-wide.sh --remove
```

### Recommended cleanup order

If both system-wide activation and a local mise install were used:

```bash
sudo ./scripts/install-mise-system-wide.sh --remove
./scripts/uninstall-mise.sh
```

Then open a new login session so PATH no longer references mise shims.

## Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| Bootstrap: mise/yq not ready | Tools not installed for `$SUDO_USER` | As admin: `curl https://mise.run \| sh` then `mise install` in the repo root |
| Tools missing in new SSH session | `profile.d` not sourced | Use a login shell; confirm Bourne-compatible shell |
| `mise: command not found` at login | Binary gone but `profile.d` remains | Run `install-mise-system-wide.sh --remove` |
| PATH still has mise after uninstall | System-wide file left behind | Same `--remove` step, then new login |

## Technical notes

- `/etc/profile.d/` scripts are sourced during login shell init  
- `${HOME}` in `mise.sh` expands per user at runtime  
- `mise activate` is guarded with `command -v mise`  
- System-wide file permissions: `644`  
- Prefer `profile.d` over editing `/etc/profile` directly  

## References

- [mise documentation](https://mise.jdx.dev/)
- [BOOTSTRAP.md](BOOTSTRAP.md) — one-time tool setup before bootstrap  
- [BOOTSTRAP-CONFIG.md](BOOTSTRAP-CONFIG.md) — mise/yq integration details  
