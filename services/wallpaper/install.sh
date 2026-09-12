#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"
# shellcheck source=../../factory/lib.sh
source "$SCRIPT_DIR/../../factory/lib.sh"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
PATH_UNIT="acw-wallpaper-theme"

install() {
    mkdir -p "$INSTALL_ROOT/src"
    for src in "$SCRIPT_DIR"/src/*; do
        [ -f "$src" ] || continue
        backup_and_copy "$src" "$INSTALL_ROOT/src/$(basename "$src")"
    done
    echo "installed scripts to $INSTALL_ROOT/src"

    mkdir -p "$SYSTEMD_USER_DIR"
    backup_and_copy "$SCRIPT_DIR/src/$PATH_UNIT.service" "$SYSTEMD_USER_DIR/$PATH_UNIT.service"
    backup_and_copy "$SCRIPT_DIR/src/$PATH_UNIT.path" "$SYSTEMD_USER_DIR/$PATH_UNIT.path"
    echo "installed systemd user units to $SYSTEMD_USER_DIR"

    systemctl --user daemon-reload
    systemctl --user enable --now "$PATH_UNIT.path"

    systemctl --user is-enabled "$PATH_UNIT.path" >/dev/null
    systemctl --user is-active "$PATH_UNIT.path" >/dev/null
    echo "$PATH_UNIT.path enabled and active"
}

remove() {
    systemctl --user disable --now "$PATH_UNIT.path" 2>/dev/null || true
    rm -f "$SYSTEMD_USER_DIR/$PATH_UNIT.service" \
          "$SYSTEMD_USER_DIR/$PATH_UNIT.path" \
          "$SYSTEMD_USER_DIR/$PATH_UNIT.service".bak-* \
          "$SYSTEMD_USER_DIR/$PATH_UNIT.path".bak-*
    rm -rf "$INSTALL_ROOT"
    systemctl --user daemon-reload
    echo "removed $PATH_UNIT units and $INSTALL_ROOT"
}

case "${1:-}" in
    --remove) remove ;;
    "" | install) install ;;
    *)
        echo "usage: $0 [install|--remove]" >&2
        exit 1
        ;;
esac
