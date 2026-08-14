#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"

backup_and_copy() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp "$dst" "$dst.bak-$(date +%s)"
        echo "backed up existing: $dst"
    fi
    cp "$src" "$dst"
}

install() {
    mkdir -p "$INSTALL_ROOT/src"
    for src in "$SCRIPT_DIR"/src/*; do
        [ -f "$src" ] || continue
        backup_and_copy "$src" "$INSTALL_ROOT/src/$(basename "$src")"
    done
    echo "installed scripts to $INSTALL_ROOT/src"
}

remove() {
    rm -rf "$INSTALL_ROOT"
    echo "removed $INSTALL_ROOT"
}

case "${1:-}" in
    --remove) remove ;;
    "" | install) install ;;
    *)
        echo "usage: $0 [install|--remove]" >&2
        exit 1
        ;;
esac
