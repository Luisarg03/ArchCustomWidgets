#!/usr/bin/env bash
#
# wallpaper-auto-theme.sh
# Aplica automáticamente el esquema de colores basado en el wallpaper actual.
# Se ejecuta via systemd path unit cuando caelestia cambia el wallpaper.
#

set -euo pipefail

WALLPAPER_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/path.txt"
LAST_WALLPAPER_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/last-processed.txt"

if [ ! -f "$WALLPAPER_FILE" ]; then
    echo "Error: No se encontró el archivo de estado del wallpaper: $WALLPAPER_FILE" >&2
    exit 1
fi

WALLPAPER=$(cat "$WALLPAPER_FILE" | tr -d '\n')

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    echo "Error: Wallpaper no válido: '$WALLPAPER'" >&2
    exit 1
fi

if [ -f "$LAST_WALLPAPER_FILE" ]; then
    LAST_WALLPAPER=$(cat "$LAST_WALLPAPER_FILE" | tr -d '\n' || true)
    if [ "$WALLPAPER" = "$LAST_WALLPAPER" ]; then
        echo "Wallpaper sin cambios ($WALLPAPER), omitiendo..."
        exit 0
    fi
fi

echo "$WALLPAPER" > "$LAST_WALLPAPER_FILE"

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

if command -v caelestia &>/dev/null; then
    echo "Recargando caelestia..."
    caelestia shell ipc call "TEST_ALIVE" 2>/dev/null || true
fi

notify-send -i preferences-desktop-theme \
    "Tema automático aplicado" \
    "Wallpaper: $WALLPAPER_NAME" \
    -t 3000 2>/dev/null || true

echo "✓ Esquema de colores aplicado automáticamente"
