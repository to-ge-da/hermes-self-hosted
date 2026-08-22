# Installation

Ordered path to deploy **one** Hermes Agent instance on Debian.

**Today:** self-hosted (local machine or local VM) only.  
**Not covered yet:** VPS, Amazon EC2, multi-instance.

This page is a map of steps and links. Each linked guide has the full procedure.

## Prerequisites

- Fresh Debian Server with an admin user
- `git` and `curl` on the host — Debian 13 netinst + SSH server + standard system utilities does **not** ship them:

  ```bash
  sudo apt install -y git curl
  ```

  `git` clones the repo on the host; `curl` installs mise. No git: copy the repo with [FILE-TRANSFER.md](FILE-TRANSFER.md) (`scp`). `curl` is still required. Bootstrap installs both again later (idempotent).
- Repo clone on the host (or files copied over — see [FILE-TRANSFER.md](FILE-TRANSFER.md))
- Mise + pinned tools installed for the admin user — see [MISE.md](MISE.md) and [BOOTSTRAP.md](BOOTSTRAP.md)

## Install order (self-hosted)

1. **Mise tools (prerequisite)** — Install mise and run `mise install` in the repo root so bootstrap can use pinned `yq`. See [MISE.md](MISE.md) and [BOOTSTRAP.md](BOOTSTRAP.md).
2. **File transfer (as needed)** — Copy config, keys, or the repo to the host with `scp` / `rsync`. See [FILE-TRANSFER.md](FILE-TRANSFER.md).
3. **Bootstrap** — Config-driven first-boot setup (`hostname`, hermes user, SSH keys). See [`scripts/bootstrap.sh`](../scripts/bootstrap.sh) and [BOOTSTRAP.md](BOOTSTRAP.md).
4. **Hardening** — Firewall, kernel, auditd, SSH lockdown. See [`scripts/hardening.sh`](../scripts/hardening.sh) and [HARDENING.md](HARDENING.md).
5. **Network** — Static IP and DNS. See [NETWORK.md](NETWORK.md).
6. **Install Hermes Agent** — Non-interactive official installer as the `hermes` user (system packages come from bootstrap). See [INSTALL-HERMES.md](INSTALL-HERMES.md).
7. **Optional: system-wide mise** — Make mise tools available to all users on login. See [MISE.md](MISE.md) (system-wide section).

## Related

- Deployment targets and limits: [README.md](../README.md)
- Uninstall Hermes Agent: [hermes-uninstall.md](hermes-uninstall.md)
- Run the dashboard as a background service: [hermes-dashboard-service.md](hermes-dashboard-service.md)
