# System-wide Mise Activation

Make mise-managed tools (`yq`, `gh`, etc.) available to **all users** on the server automatically — no manual `PATH` export needed per session.

## How It Works

The script creates `/etc/profile.d/mise.sh`, which is sourced by all Bourne-compatible login shells on Debian. It does two things:

1. **Adds mise shims to PATH** — tools installed via mise become available as regular commands
2. **Activates mise** — enables completions, aliases, and other mise features

Because `/etc/profile.d/` runs for every user during login, this works for SSH sessions, console logins, and `sudo -i` without any per-user configuration.

## Installation

Run the installation script as root:

```bash
sudo ./scripts/install-mise-system-wide.sh
```

This creates `/etc/profile.d/mise.sh` with the appropriate content and permissions.

### Idempotency

The script is safe to run multiple times. If the configuration already exists, it skips re-creation. If the file exists but has different content, it prompts for confirmation (interactive mode) or exits with an error (non-interactive mode).

## Verification

Open a **new** SSH session (or login shell) and check:

```bash
# Check that mise shims are in PATH
echo "$PATH" | grep mise

# Verify mise is activated
mise doctor

# Check a tool installed via mise
which yq
gh --version
```

No manual `export PATH="..."` or `eval "$(mise activate bash)"` in `~/.bashrc` is needed.

## Uninstallation

```bash
sudo ./scripts/install-mise-system-wide.sh --remove
```

This deletes `/etc/profile.d/mise.sh`. Changes take effect in new login sessions.

## Manual Alternative

If you prefer per-user configuration instead of system-wide, add this to each user's `~/.bashrc`:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate bash)"
```

## Technical Notes

- `/etc/profile.d/` scripts are sourced (not executed) during login shell initialization
- The `${HOME}` variable expands to each user's home directory at runtime
- The `mise activate bash` command is guarded with `command -v mise` to avoid errors if mise is not installed for a user
- The file has permissions `644` (readable by all, writable by root)
- This approach follows Debian/Ubuntu conventions for system-wide shell configuration
- Alternative considered: modifying `/etc/profile` directly (rejected — less maintainable)

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---|---|---|
| Tools not found in new SSH session | Profile.d not sourced | Check that your shell is Bourne-compatible (bash, sh, zsh) |
| `mise: command not found` at login | Mise not installed for that user | Verify mise is installed system-wide or install per-user |
| PATH shows duplicate entries | Script sourced multiple times | This is harmless; mise shims are idempotent in PATH |

## References

- [mise documentation](https://mise.jdx.dev/)
- Debian Policy Manual: [Shell scripts](https://www.debian.org/doc/debian-policy/ch-files.html#s-scripts)
- [Hardening script](../scripts/hardening.sh)
