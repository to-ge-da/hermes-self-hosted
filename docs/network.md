# Network Configuration

Static IP and DNS setup for a Debian home server.

## Why static IP?

A DHCP-assigned IP can change after a reboot or lease expiry. For a server running 24/7, a static IP ensures:

- SSH access remains stable
- Other services on the network can reach the server reliably

## How to avoid IP conflicts

Pick an IP outside your router's DHCP range. To find the DHCP range:

1. Open your router's admin panel (usually `192.168.1.1` in the browser)
2. Look for **LAN**, **DHCP Server**, or **Network Settings**
3. Find the **DHCP range** or **IP pool** (example: `192.168.1.100` to `192.168.1.200`)

Choose an IP **outside** that range:
- If DHCP is `.100` – `.200`, pick `.50`
- If DHCP is `.50` – `.150`, pick `.200`

This way the router will never assign your server's IP to another device.

No changes needed on the router — just pick an IP that's not in the pool.

```bash
ip addr show
ip route show default
cat /etc/resolv.conf
```

## Configuration

### Step 1: Identify the interface

```bash
ip link show
```

The primary interface is usually `eth0`, `enp2s0`, or similar. Note the exact name.

### Step 2: Configure static IP

Edit `/etc/network/interfaces`:

```
# Loopback
auto lo
iface lo inet loopback

# Primary interface — static IP
auto eth0
iface eth0 inet static
    address 192.168.1.50
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 1.1.1.1 8.8.8.8
```

**Replace:**
- `eth0` with your interface name
- `192.168.1.50` with your chosen static IP
- `192.168.1.1` with your router IP
- DNS servers as preferred (Cloudflare `1.1.1.1`, Google `8.8.8.8`)

### Step 3: Apply

```bash
sudo systemctl restart networking
```

Or reboot:

```bash
sudo reboot
```

### Step 4: Verify

```bash
ip addr show eth0
ip route show default
ping -c 3 1.1.1.1
ping -c 3 google.com
```

## Hosts file

Make sure the hostname resolves locally:

```bash
sudo nano /etc/hosts
```

Add or update the line:

```
127.0.1.1    your-hostname
```

Verify:

```bash
ping -c 1 $(hostname)
```

It should resolve to `127.0.1.1`.

## DNS over HTTPS (optional)

For encrypted DNS, install `dnscrypt-proxy` or use `systemd-resolved`:

```bash
sudo apt install systemd-resolved
sudo systemctl enable systemd-resolved
sudo systemctl start systemd-resolved
```

Edit `/etc/systemd/resolved.conf`:

```ini
[Resolve]
DNS=1.1.1.1 8.8.8.8
DNSOverTLS=yes
```

Apply:

```bash
sudo systemctl restart systemd-resolved
```

## Verify your IP is outside the DHCP pool

Check your router's admin panel to confirm the DHCP range, then verify your chosen IP is outside it.

No other router configuration is needed for local network access.

## Verification checklist

```bash
# Interface has correct IP
ip addr show eth0 | grep inet

# Default route is correct
ip route show default

# DNS works
nslookup google.com

# Hostname resolves
getent hosts $(hostname)

# SSH accessible from another machine
ssh admin@192.168.1.50
```

## Related docs

- [Bootstrap](bootstrap.md) — initial system setup
- [Hardening](hardening.md) — UFW firewall configuration
