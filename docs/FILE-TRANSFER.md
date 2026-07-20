# File Transfer (Workstation → Host)

Copy files from your workstation to the Hermes Debian host (bare-metal or VirtualBox VM).

This page covers the two most common tools: **scp** and **rsync**. Other methods can be added later.

## Prerequisites

- SSH access to the host as the admin user (the account created during Debian install)
- Host address: LAN IP, hostname, or VirtualBox NAT forward (`127.0.0.1` + port)
- Paths below assume a clone at `~/repos/hermes-self-hosted` — adjust as needed

Find the guest IP on the host:

```bash
hostname -I
# or
ip -4 addr
```

## scp

Copy a single file (example: bootstrap config prepared on the workstation):

```bash
scp ./bootstrap.yaml USER@HOST:~/repos/hermes-self-hosted/bootstrap.yaml
```

Copy an SSH public key for the hermes user:

```bash
scp ~/.ssh/hermes_vbox.pub USER@HOST:~/.ssh/hermes_vbox.pub
```

Non-default SSH port (e.g. VirtualBox NAT port forward `2222` → guest `22`):

```bash
scp -P 2222 ./bootstrap.yaml USER@127.0.0.1:~/repos/hermes-self-hosted/bootstrap.yaml
```

## rsync

Good for retries and syncing directories.

Single file:

```bash
rsync -avP ./bootstrap.yaml USER@HOST:~/repos/hermes-self-hosted/bootstrap.yaml
```

Sync a local project tree to the host:

```bash
rsync -avP ./hermes-self-hosted/ USER@HOST:~/repos/hermes-self-hosted/
```

Custom SSH port:

```bash
rsync -avP -e 'ssh -p 2222' ./bootstrap.yaml USER@127.0.0.1:~/repos/hermes-self-hosted/bootstrap.yaml
```

## VirtualBox NAT note

With the default NAT network, the guest is not always reachable by LAN IP from the host OS. Use a **port forward** (Settings → Network → Advanced → Port Forwarding), for example:

| Name | Protocol | Host IP | Host Port | Guest IP | Guest Port |
|------|----------|---------|-----------|----------|------------|
| ssh  | TCP      |         | 2222      |          | 22         |

Then target `USER@127.0.0.1` with port `2222` as in the examples above.

Bridged networking gives the VM a LAN IP; then use `USER@<vm-lan-ip>` with the default SSH port.

## After copy

On the host, point bootstrap at the file you copied:

```bash
cd ~/repos/hermes-self-hosted
sudo ./scripts/bootstrap.sh --config ./bootstrap.yaml
```

See [BOOTSTRAP.md](BOOTSTRAP.md) for mise/yq prerequisites and full bootstrap usage.

## Other methods (TBD)

Reserved for later (shared folders, USB, etc.). Prefer `scp` / `rsync` for routine config and key transfer.
