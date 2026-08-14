#!/usr/bin/env bash
# Idempotent copy installer for the waybar-theme unit.
# Usage: ./install.sh [--remove]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_NAME="waybar-theme"

# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.config/acw/waybar-theme}"

# Copy a file, backing up an existing different destination first.
copy_with_backup() {
    local src="$1" dst="$2"
    if [[ -e "$dst" ]] && ! cmp -s "$src" "$dst"; then
        local ts
        ts="$(date +%s)"
        cp "$dst" "$dst.bak-$ts"
        echo "  backed up $dst -> $dst.bak-$ts"
    fi
    cp "$src" "$dst"
}

install_files() {
    echo "Installing $UNIT_NAME -> $INSTALL_ROOT"
    mkdir -p "$INSTALL_ROOT/src" "$INSTALL_ROOT/styles"

    local f
    for f in "$SCRIPT_DIR"/src/*; do
        [[ -f "$f" ]] || continue
        copy_with_backup "$f" "$INSTALL_ROOT/src/$(basename "$f")"
    done
    for f in "$SCRIPT_DIR"/styles/*; do
        [[ -f "$f" ]] || continue
        copy_with_backup "$f" "$INSTALL_ROOT/styles/$(basename "$f")"
    done

    chmod +x "$INSTALL_ROOT"/src/*.sh
    echo "Done. Bind the theme rotator to a keybind or waybar module (see README)."
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
