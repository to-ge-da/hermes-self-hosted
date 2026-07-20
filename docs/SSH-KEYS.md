# SSH Keys for Hermes

The `hermes` agent user is **key-only** (password locked). Generate a key on your
workstation, put the **public** key in bootstrap config, keep the **private** key
on the workstation, and connect with `ssh -i`.

See also: [BOOTSTRAP.md](BOOTSTRAP.md), [FILE-TRANSFER.md](FILE-TRANSFER.md).

## Method 1 — Ed25519 (recommended)

```bash
ssh-keygen -t ed25519 -C "hermes@$(hostname)" -f ~/.ssh/hermes_vbox -N ""
cat ~/.ssh/hermes_vbox.pub
```

## Method 2 — RSA 4096 (if required by a client or policy)

```bash
ssh-keygen -t rsa -b 4096 -C "hermes@$(hostname)" -f ~/.ssh/hermes_rsa -N ""
cat ~/.ssh/hermes_rsa.pub
```

## Method 3 — Reuse an existing key

```bash
# Prefer ed25519 if present
cat ~/.ssh/id_ed25519.pub
# or
cat ~/.ssh/id_rsa.pub
```

Use the matching private key later with `ssh -i` (default paths are tried automatically
if you use the standard `id_ed25519` / `id_rsa` names).

## Put the public key into bootstrap config

**Option A — inline** (in `bootstrap.yaml`):

```yaml
hermes:
  user: hermes
  ssh_public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... hermes@laptop"
```

**Option B — file on the host** (copy the `.pub` with scp/rsync first):

```yaml
hermes:
  user: hermes
  ssh_public_key_file: /home/agentx/.ssh/hermes_vbox.pub
```

Do **not** put the private key in YAML. Do **not** commit real keys.

## Connect

```bash
ssh -i ~/.ssh/hermes_vbox hermes@HOST
```

## Replace a bad or old authorized_keys

Bootstrap **skips** SSH key install if `/home/hermes/.ssh/authorized_keys` already
exists and is non-empty. To replace:

```bash
sudo rm /home/hermes/.ssh/authorized_keys
sudo ./scripts/bootstrap.sh --config ./bootstrap.yaml
```

Verify on the host (admin needs `sudo` — hermes’s home is not world-readable):

```bash
sudo cat /home/hermes/.ssh/authorized_keys
sudo ssh-keygen -lf /home/hermes/.ssh/authorized_keys
```
