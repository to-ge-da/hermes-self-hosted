# Bootstrap Configuration Design

> Design reference for the config-driven bootstrap refactoring.
> This document describes **what** and **why**. Implements issue #30.

---

## Table of Contents

- [Schema Reference](#schema-reference)
- [Validation Rules](#validation-rules)
- [Path Resolution](#path-resolution)
- [Mise Tool Manager](#mise-tool-manager)
- [State File](#state-file)
- [Legacy State Migration](#legacy-state-migration)
- [CLI Specification (for #31 / #32)](#cli-specification-for-31--32)
- [Out-of-Repo Case](#out-of-repo-case)

---

## Schema Reference

### `bootstrap.yaml` fields

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `hostname` | string | yes | — | Desired server hostname |
| `timezone` | string | no | `"UTC"` | Valid TZ identifier (e.g. `America/Sao_Paulo`, `Europe/Berlin`) |
| `hermes.user` | string | no | `hermes` | Hermes agent system account name |
| `hermes.ssh_public_key` | string | no* | — | Inline SSH public key (e.g. `ssh-ed25519 AAAA...`) |
| `hermes.ssh_public_key_file` | string | no* | — | Path to an SSH public key file on disk |

**\*Mutual exclusivity:** Choose exactly one of `ssh_public_key` or `ssh_public_key_file`.
Setting both is a validation error. Setting neither is allowed (SSH setup is skipped),
but the resulting server will not be accessible via SSH key for the hermes user until
one is added manually.

### Example

```yaml
hostname: hermes-server
timezone: America/Sao_Paulo
hermes:
  user: hermes
  ssh_public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0Gj..."
```

---

## Validation Rules

### Hostname
- Must be a valid hostname per `hostnamectl` constraints (non-empty, no spaces, valid characters).

### Timezone
- Validated against `timedatectl list-timezones`.
- If the value is not in the list, bootstrap exits with an error listing valid options.

### SSH key (`ssh_public_key`)
- Must match one of the following patterns:
  - `ssh-ed25519 AAAA...`
  - `ssh-rsa AAAA...`
  - `ecdsa-sha2-nistp256 AAAA...`
  - `ecdsa-sha2-nistp384 AAAA...`
  - `ecdsa-sha2-nistp521 AAAA...`
- Trailing comment/email portion is allowed and ignored.

### SSH key file (`ssh_public_key_file`)
- Path must exist, be a regular file, and be readable by the admin user.
- File content is read and validated against the same SSH key patterns as above.

### XOR enforcement
- If both `ssh_public_key` and `ssh_public_key_file` are set, bootstrap exits with:
  > Error: Both ssh_public_key and ssh_public_key_file are set.
  > Choose one or the other — not both.
- If neither is set: SSH key setup is skipped entirely (a warning is emitted).

---

## Path Resolution

The config file is resolved in the following order. The first match wins.

1. **Explicit path** — `--config /path/to/bootstrap.yaml`
2. **Working directory** — `./config/bootstrap.yaml` (typical when run from repo clone)
3. **Script-relative** — `$SCRIPT_DIR/../config/bootstrap.yaml` (where `$SCRIPT_DIR` is the directory containing `scripts/bootstrap.sh`)
4. **Failure** — If none of the above exist, bootstrap exits with:
   > Error: No bootstrap configuration found.
   > Use --config PATH to specify a config file.
   > See config/bootstrap.example.yaml for an example.

### Why this order?

- Explicit flag is the most predictable — ideal for automation and out-of-repo usage.
- CWD-relative covers the common case of `cd repo-clone && sudo ./scripts/bootstrap.sh --config config/bootstrap.yaml` (omitted flag style).
- Script-relative covers the case of `sudo ./scripts/bootstrap.sh` from the repo root without specifying `--config`.

---

## Mise Tool Manager

### Role

[Mise](https://mise.jdx.dev) is the host's per-user tool manager. It provides isolated,
version-pinned tool installations without requiring system-wide package manager dependencies.
Bootstrap uses mise to run `yq` for YAML parsing — avoiding the apt version of yq
(which is a different, incompatible implementation).

### `mise.toml` at repo root

The file `mise.toml` at the repository root declares tool dependencies:

```toml
[tools]
yq = "4.53.3"
```

Adding new tools (Node.js, Python, etc.) is as simple as appending a line.

### Bootstrap integration

1. At script start, bootstrap checks if mise is installed for `$SUDO_USER`.
2. If absent, it installs mise for `$SUDO_USER` (not system-wide).
3. Bootstrap `cd`s to the repo root and runs `mise install` to fetch pinned tools.
4. All YAML parsing uses `mise exec -- yq eval ...` — no shell aliases or PATH tweaks needed.
5. Bootstrap does **not** depend on `install-mise-system-wide.sh`. That script is optional
   and provided separately for environments that want all users to have mise in PATH.

### Why not apt yq?

Debian's `yq` package provides a Python-based YAML processor with a different CLI interface
and feature set. The Go-based `yq` (mikefarah/yq) is the standard for shell-based YAML
manipulation. Mise pins the correct version.

---

## State File

### Location

```
~/.hermes-self-hosted/bootstrap.state
```

The `~` is resolved to the home directory of `$SUDO_USER` (the admin user who invoked
`sudo ./bootstrap.sh`), not `root`.

### Format

Key=value format (easy to parse with bash `source` or `grep`, and with yq for consistency):

```ini
COMPLETED_AT=2026-06-29T12:00:00Z
SCRIPT_VERSION=1.0.0
HOSTNAME=hermes-server
ADMIN_USER=admin
HERMES_USER=hermes
PREVIOUS_HOSTNAME=debian-default
CONFIG_HASH=<sha256-of-config-file-contents>
MISE_VERSION=2024.x.x
```

### New fields (vs. current `/var/lib/` state)

| Field | Purpose |
|---|---|
| `PREVIOUS_HOSTNAME` | Previous hostname before this run (for future uninstall) |
| `CONFIG_HASH` | SHA-256 of the **config file contents** (not the path) for change detection |
| `MISE_VERSION` | Mise version at bootstrap time (for upgrade awareness) |

On re-run, bootstrap recomputes the content hash and logs whether the config
changed since the last successful run. Idempotent step checks (hostname match,
user exists, etc.) remain the source of truth for what to apply.

---

## Legacy State Migration

### Detection

If the old state file exists at `/var/lib/hermes-self-hosted/bootstrap.state`, bootstrap
detects it during startup and either:

- **Migrates automatically**: copies values to the new location and removes the old file.
  A log message confirms the migration.
- **Warns and skips**: if migration is not possible (permission issue, etc.), a warning
  is emitted advising manual cleanup.

### Migration map

| Old field | New field | Notes |
|---|---|---|
| `COMPLETED_AT` | `COMPLETED_AT` | Copied as-is |
| `SCRIPT_VERSION` | `SCRIPT_VERSION` | Copied as-is |
| `HOSTNAME` | `HOSTNAME` | Copied as-is |
| `ADMIN_USER` | `ADMIN_USER` | Copied as-is |
| — | `PREVIOUS_HOSTNAME` | Set from old `HOSTNAME` |
| — | `CONFIG_HASH` | Set to empty (unknown) |
| — | `MISE_VERSION` | Set to empty (unknown) |

---

## CLI Specification (for #31 / #32)

After the config-driven refactor (#31), the CLI for `scripts/bootstrap.sh` will be:

```
sudo ./bootstrap.sh [--config PATH] [--check | --dry-run]
```

### Flags

| Flag | Description |
|---|---|
| `--config PATH` | Path to the bootstrap YAML configuration (see path resolution above) |
| `--check` | Validate config and preconditions only — no mutations (added in #32) |
| `--dry-run` | Preview planned steps — no mutations (added in #32) |
| `-h`, `--help` | Show usage and exit |

### Removed

- `--hostname` — use `config.yaml: hostname`
- `--timezone` — use `config.yaml: timezone`
- `--ssh-key` — use `config.yaml: hermes.ssh_public_key` / `hermes.ssh_public_key_file`

### Deferred

- `--uninstall` — future issue

---

## Out-of-Repo Case

When `bootstrap.sh` is copied outside the repository clone (without `mise.toml`,
`config/`, or other collateral), the explicit `--config` flag is **required**.
The working-directory and script-relative fallbacks will not find anything
(since `config/` and `mise.toml` are not present).

Documentation for standalone usage:

```
sudo ./bootstrap.sh --config /path/to/bootstrap.yaml
```

The example config at `config/bootstrap.example.yaml` should also be copied alongside
`bootstrap.sh` for reference.
