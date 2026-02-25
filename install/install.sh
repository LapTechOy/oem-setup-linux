#!/bin/bash
# install.sh — distro-tunnistus ja delegointi
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ID=""
ID_LIKE=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
fi

case "$ID" in
    fedora)
        exec "$SCRIPT_DIR/fedora.sh"
        ;;
    arch|endeavouros|cachyos|manjaro|garuda)
        exec "$SCRIPT_DIR/arch.sh"
        ;;
esac

if echo " $ID_LIKE " | grep -qi " fedora "; then
    exec "$SCRIPT_DIR/fedora.sh"
fi

if echo " $ID_LIKE " | grep -qi " arch "; then
    exec "$SCRIPT_DIR/arch.sh"
fi

# Fallback: generic (Debian/Ubuntu ym.)
exec "$SCRIPT_DIR/generic.sh"
