#!/usr/bin/env bash
#
# wallpaper-auto-theme.sh
# Aplica automáticamente el esquema de colores basado en el wallpaper actual.
# Se ejecuta via systemd path unit cuando caelestia cambia el wallpaper.
#

set -euo pipefail

WALLPAPER_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/path.txt"
# ponytail: the LAST_WALLPAPER cache stays — measured, PathChanged fires on mtime,
# not on content, so re-writing the same path (caelestia does it on every set)
# re-runs matugen for nothing. The .path unit does not dedup that.
LAST_WALLPAPER_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/last-processed.txt"

if [ ! -f "$WALLPAPER_FILE" ]; then
    echo "Error: No se encontró el archivo de estado del wallpaper: $WALLPAPER_FILE" >&2
    exit 1
fi

WALLPAPER=$(tr -d '\n' < "$WALLPAPER_FILE")

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    echo "Error: Wallpaper no válido: '$WALLPAPER'" >&2
    exit 1
fi

if [ -f "$LAST_WALLPAPER_FILE" ] && [ "$WALLPAPER" = "$(tr -d '\n' < "$LAST_WALLPAPER_FILE")" ]; then
    echo "Wallpaper sin cambios ($WALLPAPER), omitiendo..."
    exit 0
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
    # Nudge the running shell so it picks the regenerated scheme up.
    caelestia shell ipc call "TEST_ALIVE" 2>/dev/null || true
else
    echo "Advertencia: caelestia no está disponible" >&2
fi

notify-send -i preferences-desktop-theme \
    "Tema automático aplicado" \
    "Wallpaper: $WALLPAPER_NAME" \
    -t 3000 2>/dev/null || true

echo "✓ Esquema de colores aplicado automáticamente"
