#!/bin/bash
WALLPAPER="${1:-$(caelestia wallpaper 2>/dev/null)}"
if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    echo "Error: No se encontró un wallpaper válido" >&2
    echo "Uso: $0 <ruta-del-wallpaper>" >&2
    exit 1
fi

echo "Cambiando wallpaper a: ${WALLPAPER}"
caelestia wallpaper -f "$WALLPAPER"
if command -v matugen &>/dev/null; then
    matugen image "$WALLPAPER"
fi
caelestia scheme set auto 2>/dev/null || true
caelestia shell reload 2>/dev/null || true
