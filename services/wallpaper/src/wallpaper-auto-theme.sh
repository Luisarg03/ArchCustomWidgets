#!/usr/bin/env bash
#
# wallpaper-auto-theme.sh
# Aplica automáticamente el esquema de colores basado en el wallpaper actual.
# Se ejecuta via systemd path unit cuando caelestia cambia el wallpaper.
#

set -euo pipefail

WALLPAPER_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/path.txt"
# ponytail: LAST_WALLPAPER cache removed — matugen is idempotent, .path already dedups

if [ ! -f "$WALLPAPER_FILE" ]; then
    echo "Error: No se encontró el archivo de estado del wallpaper: $WALLPAPER_FILE" >&2
    exit 1
fi

WALLPAPER=$(tr -d '\n' < "$WALLPAPER_FILE")

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    echo "Error: Wallpaper no válido: '$WALLPAPER'" >&2
    exit 1
fi

WALLPAPER_NAME=$(basename "$WALLPAPER")

echo "Wallpaper detectado: $WALLPAPER_NAME"

if command -v matugen &>/dev/null; then
    echo "Generando esquema de colores con matugen..."
    matugen image "$WALLPAPER" --prefer darkness || echo "Advertencia: matugen falló, continuando..." >&2
else
    echo "Advertencia: matugen no está instalado" >&2
fi

if command -v caelestia &>/dev/null; then
    echo "Aplicando esquema dinámico..."
    caelestia scheme set -n dynamic || echo "Advertencia: No se pudo aplicar esquema dinámico" >&2
else
    echo "Advertencia: caelestia no está disponible" >&2
fi

notify-send -i preferences-desktop-theme \
    "Tema automático aplicado" \
    "Wallpaper: $WALLPAPER_NAME" \
    -t 3000 2>/dev/null || true

echo "✓ Esquema de colores aplicado automáticamente"
