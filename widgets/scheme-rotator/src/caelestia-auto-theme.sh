#!/usr/bin/env bash
#
# caelestia-auto-theme.sh
# Aplica esquemas de color de forma secuencial
#

set -euo pipefail

# Archivo para guardar el estado del esquema actual
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-theme-state"
mkdir -p "$(dirname "$STATE_FILE")"

# Lista de esquemas en orden secuencial
declare -a SCHEMES=(
    "dynamic:default"
    "catppuccin:mocha"
    "catppuccin:frappe"
    "catppuccin:macchiato"
    "gruvbox:medium"
    "gruvbox:soft"
    "rosepine:main"
    "rosepine:moon"
    "onedark:default"
    "oldworld:default"
)

# Verificar que caelestia está disponible
if ! command -v caelestia &> /dev/null; then
    echo "Error: caelestia no está instalado" >&2
    notify-send -u critical "Error" "caelestia no está instalado" 2>/dev/null || true
    exit 1
fi

# Verificar que quickshell está ejecutándose
if ! pgrep -x "qs" > /dev/null && ! pgrep -x "quickshell" > /dev/null; then
    echo "Error: caelestia shell no está ejecutándose" >&2
    notify-send -u critical "Error" "caelestia shell no está ejecutándose" 2>/dev/null || true
    exit 1
fi

# Función para obtener el siguiente esquema
get_next_scheme() {
    local current_index=0

    if [ -f "$STATE_FILE" ]; then
        current_index=$(cat "$STATE_FILE")
    fi

    current_index=$((current_index + 1))
    if [ $current_index -ge ${#SCHEMES[@]} ]; then
        current_index=0
    fi

    echo "$current_index" > "$STATE_FILE"
    echo "${SCHEMES[$current_index]}"
}

# Variables
SCHEME_NAME=""
FLAVOUR=""
USE_NEXT=false

show_help() {
    cat << 'HELP'
Uso: caelestia-auto-theme.sh [OPCIONES]

Aplica esquemas de color de forma secuencial.
Esta unidad no cambia el wallpaper: para eso están
wallpaper-select.sh y wallhaven-wallpaper del servicio wallpaper.

Opciones:
    -h, --help              Muestra esta ayuda
    -n, --next              Cambiar al siguiente esquema (secuencial) [USO PRINCIPAL]
    -s, --scheme NAME       Usa un esquema específico
    -f, --flavour FLAVOUR   Variante del esquema

Esquemas en rotación:
    1. dynamic (basado en wallpaper)
    2. catppuccin mocha
    3. catppuccin frappe
    4. catppuccin macchiato
    5. gruvbox medium
    6. gruvbox soft
    7. rosepine main
    8. rosepine moon
    9. onedark
    10. oldworld

Ejemplos:
    caelestia-auto-theme.sh -n                       # Siguiente esquema
    caelestia-auto-theme.sh -s catppuccin -f mocha   # Esquema específico
HELP
}

# Parsear opciones
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--next)
            USE_NEXT=true
            shift
            ;;
        -s|--scheme)
            SCHEME_NAME="${2:?--scheme necesita un nombre}"
            shift 2
            ;;
        -f|--flavour)
            FLAVOUR="${2:?--flavour necesita una variante}"
            shift 2
            ;;
        *)
            echo "Error: opción desconocida: $1" >&2
            exit 1
            ;;
    esac
done

# Usar --next para obtener siguiente esquema
if [ "$USE_NEXT" = true ]; then
    NEXT_SCHEME=$(get_next_scheme)
    SCHEME_NAME="${NEXT_SCHEME%%:*}"
    FLAVOUR="${NEXT_SCHEME##*:}"

    if [ "$FLAVOUR" = "default" ]; then
        FLAVOUR=""
    fi

    echo "Siguiente esquema: $SCHEME_NAME${FLAVOUR:+ ($FLAVOUR)}"
fi

# Si no se especificó esquema, usar dynamic
if [ -z "$SCHEME_NAME" ]; then
    SCHEME_NAME="dynamic"
fi

# Aplicar esquema
echo "Aplicando esquema: $SCHEME_NAME${FLAVOUR:+ ($FLAVOUR)}"

SCHEME_CMD=(caelestia scheme set -n "$SCHEME_NAME")
if [ -n "$FLAVOUR" ]; then
    SCHEME_CMD+=(-f "$FLAVOUR")
fi

if "${SCHEME_CMD[@]}" 2>/dev/null; then
    if [ "$SCHEME_NAME" = "dynamic" ]; then
        notify-send -i preferences-desktop-theme "Tema" "Esquema dinámico" -t 2000 2>/dev/null || true
    else
        notify-send -i preferences-desktop-theme "Tema" "$SCHEME_NAME${FLAVOUR:+ ($FLAVOUR)}" -t 2000 2>/dev/null || true
    fi

    # Recargar Kitty si está corriendo
    pkill -USR1 kitty 2>/dev/null || true
else
    echo "Error al aplicar esquema" >&2
    exit 1
fi

echo "¡Listo!"
