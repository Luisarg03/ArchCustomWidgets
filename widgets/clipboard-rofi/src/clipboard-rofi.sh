#!/usr/bin/env bash
set -euo pipefail

if ! command -v cliphist &>/dev/null; then
    notify-send -u critical "Error" "cliphist no está instalado" 2>/dev/null || true
    exit 1
fi

if ! command -v rofi &>/dev/null; then
    notify-send -u critical "Error" "rofi no está instalado" 2>/dev/null || true
    exit 1
fi

RofiConf="$HOME/.config/rofi/clipboard.rasi"
if [ ! -f "$RofiConf" ]; then
    RofiConf="$HOME/.config/rofi/config.rasi"
fi

selected=$(cliphist list | rofi -dmenu -config "$RofiConf" -p "Clipboard" -theme-str 'listview { lines: 10; }' 2>/dev/null)

if [ -n "$selected" ]; then
    echo "$selected" | cliphist decode | wl-copy
    notify-send "Clipboard" "Texto copiado al portapapeles" -t 2000 2>/dev/null || true
fi
