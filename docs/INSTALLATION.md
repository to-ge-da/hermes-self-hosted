# Installation

Ordered path to deploy **one** Hermes Agent instance on Debian. Follow this page on a fresh VM. Linked guides are detail, not extra steps.

**Today:** self-hosted (local machine or local VM) only.  
**Not covered yet:** VPS, Amazon EC2, multi-instance.

Work as the **admin** user (the account created at Debian install — e.g. `testnet`). Do not run the Hermes installer as root.

Keep the **private** SSH key on the workstation. Bootstrap plants the matching **public** key on admin and `hermes`. After hardening, password SSH is off — connect with `ssh -i`.

## Prerequisites

- Fresh Debian Server with an admin user
- `git` and `curl`:

  ```bash
  sudo apt install -y git curl
  ```

  No git: copy the repo with [FILE-TRANSFER.md](FILE-TRANSFER.md) (`scp`). `curl` is still required.

## 1. Clone (or copy) the repo

Run every later `./scripts/…` from this directory (repo root), not from `scripts/`.

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

Creates the `hermes` user (no password, no sudo), packages, PATH, SSH key on admin + hermes, linger on `hermes`. If the script says a reboot is required, `sudo reboot` and SSH back **before** step 5 (password SSH still works). Detail: [BOOTSTRAP.md](BOOTSTRAP.md).

Already bootstrapped without linger: `sudo loginctl enable-linger hermes`. Check: `loginctl show-user hermes -p Linger`.

## 5. Hardening (recommended)

Skip on a throwaway smoke VM if you want.

```bash
sudo ./scripts/hardening.sh
```

When you see `HARDENING COMPLETE`:

```bash
sudo reboot
```

SSH password auth is now off. From the workstation (same private key as the YAML):

```bash
ssh -i ~/.ssh/<private-key> <admin>@<host>
```

A `~/.ssh/config` `Host` alias only matches that name, not a raw `user@ip`. Detail: [HARDENING.md](HARDENING.md), [SSH-KEYS.md](SSH-KEYS.md).

## 6. Network (as needed)

Static IP / DNS: [NETWORK.md](NETWORK.md).

## 7. Install Hermes Agent

Stay logged in as **admin**. Install **as** `hermes` (`-H` sets `HOME=/home/hermes`). `cd` first: `bash -lc` does **not** change directory, so `uv` would see admin's `~/.venv` and fail. Do not use `sudo -E` (keeps admin `HOME`). Do not run the installer as root.

```bash
sudo -u hermes -H bash -lc 'cd && curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive'
```

Equivalent: `ssh -i ~/.ssh/<private-key> hermes@<host>` then the same `curl | bash` (see [install.md](hermes/install.md)).

Check:

```bash
sudo -u hermes -H bash -lc 'cd && hermes --version'
# must not exist:
# ls /home/<admin>/.hermes  /root/.hermes
```

Code: `/home/hermes/.hermes/hermes-agent/`. CLI: `/home/hermes/.local/bin/hermes`. Packages already came from bootstrap — `hermes` must not call `sudo`.

## 8. Playwright OS libraries

`hermes` has no sudo, so the installer skipped `--with-deps`. Chromium is already in the hermes cache. As **admin**, from the clone (do **not** `cd` into `/home/hermes` — it is not traversable):

```bash
sudo ./scripts/playwright.sh
```

Detail: [install.md](hermes/install.md#playwright--chromium).

## 9. Gateway user unit

Stay logged in as **admin**. Same `sudo -u hermes -H` + `cd` as step 7. Do not run `hermes gateway install` as admin — the unit lands in `/home/<admin>/`. `--system` needs sudo; `hermes` has none.

```bash
sudo -u hermes -H bash -lc 'cd && hermes gateway install --start-now --start-on-login && hermes gateway status'
```

`--start-now` / `--start-on-login` skip the TTY prompts and start the unit now. Bare `install` asks `Start the gateway now?` then boot-enable — that blocks this path. Linger is already on from bootstrap. Platforms are not this step; the unit runs empty until a token is in `~/.hermes/.env`. Day 2: [gateway-platforms.md](hermes/gateway-platforms.md).

Detail: [install.md](hermes/install.md#gateway-247-access).

## 10. Verify as `hermes`

```bash
ssh -i ~/.ssh/<private-key> hermes@<host>
hermes doctor
hermes gateway status
```

Look for Playwright Chromium. Gateway unit should be active. Provider / API key: [install.md](hermes/install.md).

## Related

- Deployment targets: [README.md](../README.md)
- Uninstall: [uninstall.md](hermes/uninstall.md)
- Dashboard service: [dashboard-service.md](hermes/dashboard-service.md)
- Day 2 — messaging apps: [gateway-platforms.md](hermes/gateway-platforms.md)
