#!/usr/bin/env bash
# Idempotent copy installer for the waybar-power unit.
# Usage: ./install.sh [--remove]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_NAME="waybar-power"

# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"
# shellcheck source=../../factory/lib.sh
source "$SCRIPT_DIR/../../factory/lib.sh"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.config/acw/waybar-power}"

install_files() {
    echo "Installing $UNIT_NAME -> $INSTALL_ROOT"
    mkdir -p "$INSTALL_ROOT/src"

    local f
    for f in "$SCRIPT_DIR"/src/*; do
        [[ -f "$f" ]] || continue
        backup_and_copy "$f" "$INSTALL_ROOT/src/$(basename "$f")"
    done

    chmod +x "$INSTALL_ROOT"/src/*.sh
    echo "Done. Wire the lock/power/quit/reboot waybar modules as described in the README."
}

remove_files() {
    if [[ "$INSTALL_ROOT" != "$HOME"/* ]]; then
        echo "Error: refusing to remove '$INSTALL_ROOT' (outside \$HOME)" >&2
        exit 1
    fi
    echo "Removing $UNIT_NAME from $INSTALL_ROOT"
    rm -rf -- "$INSTALL_ROOT"
    echo "Done."
}

case "${1:-}" in
    --remove) remove_files ;;
    "") install_files ;;
    *) echo "Usage: $0 [--remove]" >&2; exit 1 ;;
esac
