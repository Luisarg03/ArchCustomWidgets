#!/usr/bin/env bash
set -euo pipefail

# quickshell-watchdog installer: systemd user timer that restarts Caelestia
# quickshell if it dies. Idempotent, ships --remove.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"

SERVICE=acw-quickshell-watchdog.service
TIMER=acw-quickshell-watchdog.timer
USER_UNITS_DIR="$HOME/.config/systemd/user"

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
    chmod +x "$INSTALL_ROOT/src/caelestia-watchdog.sh"

    info "Installing systemd user units"
    mkdir -p "$USER_UNITS_DIR"
    backup_and_copy "$SCRIPT_DIR/src/$SERVICE" "$USER_UNITS_DIR/$SERVICE"
    backup_and_copy "$SCRIPT_DIR/src/$TIMER" "$USER_UNITS_DIR/$TIMER"

    systemctl --user daemon-reload
    systemctl --user enable --now "$TIMER"
    info "Timer enabled: $TIMER"

    if systemctl --user is-enabled "$TIMER" >/dev/null 2>&1 \
        && systemctl --user is-active "$TIMER" >/dev/null 2>&1; then
        info "Validation passed: $TIMER is enabled and active"
    else
        warn "Validation failed: check 'systemctl --user status $TIMER'"
    fi
}

remove() {
    info "Disabling timer"
    systemctl --user disable --now "$TIMER" 2>/dev/null || true

    info "Removing systemd user units"
    rm -f "$USER_UNITS_DIR/$SERVICE" "$USER_UNITS_DIR/$TIMER"
    info "Removed $SERVICE and $TIMER from $USER_UNITS_DIR"
    systemctl --user daemon-reload

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
