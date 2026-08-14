#!/usr/bin/env sh

# Script para seleccionar wallpapers desde ~/Pictures/Wallpapers
# Compatible con Caelestia Shell

WallDir="$HOME/Pictures/wallpapers"
RofiConf="$HOME/.config/rofi/themeselect.rasi"

# Verificar que el directorio existe
if [ ! -d "$WallDir" ]; then
    notify-send "Error" "Directorio $WallDir no existe"
    exit 1
fi

# set rofi override
elem_border=10
icon_border=8
r_override="element{border-radius:${elem_border}px;} element-icon{border-radius:${icon_border}px;}"

# Crear lista de wallpapers con preview
WallSel=$(find "$WallDir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | while read wallpath; do
    echo -en "${wallpath}\x00icon\x1f${wallpath}\n"
done | rofi -dmenu -theme-str "${r_override}" -config "$RofiConf" -p "Select Wallpaper" -format "s")

# Si se seleccionó algo, aplicar con caelestia
if [ ! -z "$WallSel" ]; then
    if [ -f "$WallSel" ]; then
        caelestia wallpaper -f "$WallSel"
        wallname=$(basename "$WallSel")
        notify-send "Wallpaper Changed" "$wallname"
    fi
fi
