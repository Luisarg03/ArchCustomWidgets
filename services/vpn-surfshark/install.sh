#!/usr/bin/env bash
set -euo pipefail

# vpn-surfshark installer: Caelestia VPN quick-toggle + system-level
# WireGuard/nft units (kill switch). Idempotent, ships --remove.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"

UNIT_FILES=(surfshark-connect.service surfshark-disconnect.service)
NFTABLES_SRC="$SCRIPT_DIR/src/nftables.conf"
SHELL_JSON="$HOME/.config/caelestia/shell.json"

info() { echo "==> $*"; }
warn() { echo "WARN: $*"; }

# shellcheck source=../../factory/lib.sh
source "$SCRIPT_DIR/../../factory/lib.sh"

install() {
    info "Copying unit files to $INSTALL_ROOT/src"
    mkdir -p "$INSTALL_ROOT/src"
    for f in "$SCRIPT_DIR"/src/*; do
        [ -f "$f" ] || continue
        backup_and_copy "$f" "$INSTALL_ROOT/src/$(basename "$f")"
    done

    info "Patching Caelestia shell.json (VPN quick-toggle + provider)"
    if [ -f "$SHELL_JSON" ]; then
        python3 "$INSTALL_ROOT/src/patch-shell.py"
    else
        warn "shell.json not found at $SHELL_JSON; skipping shell.json patch"
    fi

    info "Installing system-level units (sudo)"
    echo "sudo is needed to place unit files in /etc/systemd/system and overwrite /etc/nftables.conf."
    sudo -v
    for f in "${UNIT_FILES[@]}"; do
        sudo_copy_with_backup "$SCRIPT_DIR/src/$f" "/etc/systemd/system/$f"
    done
    if [ -e /etc/nftables.conf ] && ! cmp -s "$NFTABLES_SRC" /etc/nftables.conf; then
        sudo cp /etc/nftables.conf "/etc/nftables.conf.bak-$(date +%s)"
        info "Backed up /etc/nftables.conf"
    fi
    sudo cp "$NFTABLES_SRC" /etc/nftables.conf
    sudo systemctl daemon-reload
    info "Service NOT started: toggle it with the Caelestia VPN button (or systemctl start surfshark-connect)"

    if [ -f /etc/wireguard/surfshark.conf ]; then
        info "WireGuard config found: /etc/wireguard/surfshark.conf"
    else
        warn "/etc/wireguard/surfshark.conf missing - wg-quick needs it. Create it manually (see README)."
    fi
}

remove() {
    info "Reverting shell.json delta"
    if [ -f "$INSTALL_ROOT/src/patch-shell.py" ]; then
        python3 "$INSTALL_ROOT/src/patch-shell.py" --remove
    else
        warn "patch-shell.py not found at $INSTALL_ROOT; skipping shell.json revert"
    fi

    info "Removing system-level units (sudo)"
    sudo -v
    for f in "${UNIT_FILES[@]}"; do
        if [ -f "/etc/systemd/system/$f" ]; then
            sudo rm -f "/etc/systemd/system/$f"
            info "Removed /etc/systemd/system/$f"
        else
            info "/etc/systemd/system/$f already absent"
        fi
    done
    local nft_backup
    nft_backup="$(ls -1t /etc/nftables.conf.bak-* 2>/dev/null | head -n 1 || true)"
    if [ -n "$nft_backup" ]; then
        sudo cp "$nft_backup" /etc/nftables.conf
        info "Restored /etc/nftables.conf from $nft_backup"
    elif [ -e /etc/nftables.conf ]; then
        sudo rm -f /etc/nftables.conf
        warn "/etc/nftables.conf removed (no backup found to restore)"
    else
        info "/etc/nftables.conf already absent"
    fi
    sudo systemctl daemon-reload

    if [ -d "$INSTALL_ROOT" ]; then
        rm -rf "$INSTALL_ROOT"
        info "Removed $INSTALL_ROOT"
    else
        info "$INSTALL_ROOT already absent"
    fi
}

case "${1:-install}" in
    install) install ;;
    --remove) remove ;;
    *)
        echo "Usage: $0 [install|--remove]"
        exit 1
        ;;
esac
