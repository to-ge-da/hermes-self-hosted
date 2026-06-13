#!/bin/bash
#
# scan-lan.sh — Discover active devices on the local network
#
# Requires: nmap (apt install nmap)
#
# Usage:
#   chmod +x scan-lan.sh
#   ./scan-lan.sh
#   ./scan-lan.sh 192.168.1.0/24   # custom subnet

set -euo pipefail

SUBNET="${1:-192.168.1.0/24}"

echo "Scanning $SUBNET ..."
echo ""

# Check if nmap is installed
if ! command -v nmap &>/dev/null; then
    echo "nmap not found. Install it with: sudo apt install nmap"
    exit 1
fi

sudo nmap -sn "$SUBNET"

echo ""
echo "Done. Look at the IP column to see which addresses are in use."
echo "Pick an IP NOT in this list and outside your router's DHCP pool."
