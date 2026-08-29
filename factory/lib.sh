#!/usr/bin/env bash
# factory/lib.sh — shared helpers for install.sh (sourced, not executed)
# ponytail: single source for backup_and_copy to avoid 8 duplications.
set -euo pipefail

backup_and_copy() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp "$dst" "$dst.bak-$(date +%s)"
        echo "backed up existing: $dst"
    fi
    cp "$src" "$dst"
}

sudo_copy_with_backup() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        sudo cp "$dst" "$dst.bak-$(date +%s)"
        echo "backed up existing (sudo): $dst"
    fi
    sudo cp "$src" "$dst"
}
