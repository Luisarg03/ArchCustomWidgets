#!/usr/bin/env bash
if ! pgrep -x "qs" > /dev/null; then
    notify-send -u critical "Caelestia" "Quickshell no está corriendo, reiniciando..." 2>/dev/null || true
    caelestia shell -d 2>/dev/null || true
fi
