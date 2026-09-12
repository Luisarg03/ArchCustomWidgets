#!/usr/bin/env bash
# Restart the Caelestia shell if it died.
#
# The check looks for the shell's own config, not for any process named "qs":
# standalone widgets (`qs -p capture.qml`) are also `qs`, so `pgrep -x qs`
# reports "alive" while the actual shell is down - which is exactly when this
# watchdog is needed.
if ! pgrep -f "qs -c caelestia" > /dev/null; then
    notify-send -u critical "Caelestia" "Quickshell no está corriendo, reiniciando..." 2>/dev/null || true
    caelestia shell -d 2>/dev/null || true
fi
