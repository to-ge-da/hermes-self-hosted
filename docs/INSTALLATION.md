# Installation

Ordered path to deploy **one** Hermes Agent instance on Debian. Follow this page on a fresh VM. Linked guides are detail, not extra steps.

**Today:** self-hosted (local machine or local VM) only.  
**Not covered yet:** VPS, Amazon EC2, multi-instance.

Work as the **admin** user (the account created at Debian install — e.g. `testnet`). Do not run the Hermes installer as root.

## Prerequisites

- Fresh Debian Server with an admin user
- `git` and `curl`:

  ```bash
  sudo apt install -y git curl
  ```

  No git: copy the repo with [FILE-TRANSFER.md](FILE-TRANSFER.md) (`scp`). `curl` is still required.

## 1. Clone (or copy) the repo

```bash
git clone https://github.com/to-ge-da/hermes-self-hosted.git
cd hermes-self-hosted
```

## 2. Mise host tools

Shared `/usr/local/bin/mise` + `profile.d` so admin and `hermes` both see it. Host-pinned `yq` from `mise.host.toml`.

```bash
sudo ./scripts/mise.sh install --system-wide
```

Detail: [MISE.md](MISE.md).

## 3. Bootstrap config

```bash
cp config/bootstrap.example.yaml ./bootstrap.yaml
# edit hostname, timezone, ssh.public_key (or ssh.public_key_file)
```

SSH key: [SSH-KEYS.md](SSH-KEYS.md). Copy files to the host: [FILE-TRANSFER.md](FILE-TRANSFER.md).

## 4. Bootstrap

```bash
sudo ./scripts/bootstrap.sh --config ./bootstrap.yaml
```

Creates the `hermes` user (no password, no sudo), packages, PATH, SSH key on admin + hermes. Detail: [BOOTSTRAP.md](BOOTSTRAP.md).

## 5. Hardening (recommended)

Skip on a throwaway smoke VM if you want.

```bash
sudo ./scripts/hardening.sh
```

Detail: [HARDENING.md](HARDENING.md).

## 6. Network (as needed)

Static IP / DNS: [NETWORK.md](NETWORK.md).

## 7. Install Hermes Agent

Stay logged in as **admin**. Install **as** `hermes` (`-H` sets `HOME=/home/hermes`). Do not use `sudo -E` (keeps admin `HOME`). Do not run the installer as root.

```bash
sudo -u hermes -H bash -lc 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive'
```

Equivalent: `ssh hermes@<host>` then the same `curl | bash` (see [install.md](hermes/install.md)).

Check:

```bash
sudo -u hermes -H bash -lc 'hermes --version'
# must not exist:
# ls /home/<admin>/.hermes  /root/.hermes
```

Code: `/home/hermes/.hermes/hermes-agent/`. CLI: `/home/hermes/.local/bin/hermes`. Packages already came from bootstrap — `hermes` must not call `sudo`.

Playwright OS libs (admin): [install.md](hermes/install.md#playwright--chromium). Provider/API key: same file.

## Related

- Deployment targets: [README.md](../README.md)
- Uninstall: [uninstall.md](hermes/uninstall.md)
- Dashboard service: [dashboard-service.md](hermes/dashboard-service.md)
