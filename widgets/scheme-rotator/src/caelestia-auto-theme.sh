#!/usr/bin/env bash
#
# caelestia-auto-theme.sh
# Aplica esquemas de color de forma secuencial
#

set -e

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

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Verificar que caelestia está disponible
if ! command -v caelestia &> /dev/null; then
    print_error "caelestia no está instalado"
    notify-send -u critical "Error" "caelestia no está instalado" 2>/dev/null || true
    exit 1
fi

# Verificar que quickshell está ejecutándose
if ! pgrep -x "qs" > /dev/null && ! pgrep -x "quickshell" > /dev/null; then
    print_error "caelestia shell no está ejecutándose"
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
WALLPAPER_PATH=""
SCHEME_NAME=""
FLAVOUR=""
RANDOM_WALLPAPER=false
CHANGE_WALLPAPER=false
USE_NEXT=false

show_help() {
    cat << 'HELP'
Uso: caelestia-auto-theme.sh [OPCIONES]

Aplica esquemas de color de forma secuencial.
Por defecto NO cambia el wallpaper (usa Super+Shift+T para eso).

Opciones:
    -h, --help              Muestra esta ayuda
    -n, --next              Cambiar al siguiente esquema (secuencial) [USO PRINCIPAL]
    -s, --scheme NAME       Usa un esquema específico
    -f, --flavour FLAVOUR   Variante del esquema
    -w, --wallpaper PATH    Cambia a un wallpaper específico y aplica esquema
    -r, --random            Wallpaper aleatorio + esquema

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
            SCHEME_NAME="$2"
            shift 2
            ;;
        -f|--flavour)
            FLAVOUR="$2"
            shift 2
            ;;
        -w|--wallpaper)
            WALLPAPER_PATH="$2"
            CHANGE_WALLPAPER=true
            shift 2
            ;;
        -r|--random)
            CHANGE_WALLPAPER=true
            RANDOM_WALLPAPER=true
            shift
            ;;
        *)
            print_error "Opción desconocida: $1"
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
    
    print_info "Siguiente esquema: $SCHEME_NAME${FLAVOUR:+ ($FLAVOUR)}"
fi

# Si no se especificó esquema, usar dynamic
if [ -z "$SCHEME_NAME" ]; then
    SCHEME_NAME="dynamic"
fi

# Cambiar wallpaper si se solicitó
if [ "$CHANGE_WALLPAPER" = true ]; then
    print_info "Cambiando wallpaper..."
    
    if [ "$RANDOM_WALLPAPER" = true ]; then
        if caelestia wallpaper -r 2>/dev/null; then
            print_success "Wallpaper aleatorio aplicado"
            notify-send -i preferences-desktop-wallpaper "Wallpaper" "Wallpaper aleatorio" -t 2000 2>/dev/null || true
        else
            print_error "Error al cambiar wallpaper"
            exit 1
        fi
    elif [ -n "$WALLPAPER_PATH" ]; then
        if [ ! -f "$WALLPAPER_PATH" ]; then
            print_error "Archivo no existe: $WALLPAPER_PATH"
            exit 1
        fi
        
        if caelestia wallpaper -f "$WALLPAPER_PATH" 2>/dev/null; then
            print_success "Wallpaper aplicado"
            notify-send -i preferences-desktop-wallpaper "Wallpaper" "Nuevo wallpaper" -t 2000 2>/dev/null || true
        else
            print_error "Error al aplicar wallpaper"
            exit 1
        fi
    fi
    
    sleep 0.5
fi

# Aplicar esquema
print_info "Aplicando esquema: $SCHEME_NAME${FLAVOUR:+ ($FLAVOUR)}"

SCHEME_CMD="caelestia scheme set -n $SCHEME_NAME"
if [ -n "$FLAVOUR" ]; then
    SCHEME_CMD="$SCHEME_CMD -f $FLAVOUR"
fi

if eval "$SCHEME_CMD" 2>/dev/null; then
    print_success "Esquema aplicado"
    
    if [ "$SCHEME_NAME" = "dynamic" ]; then
        notify-send -i preferences-desktop-theme "Tema" "Esquema dinámico" -t 2000 2>/dev/null || true
    else
        notify-send -i preferences-desktop-theme "Tema" "$SCHEME_NAME${FLAVOUR:+ ($FLAVOUR)}" -t 2000 2>/dev/null || true
    fi

    # Recargar Kitty si está corriendo
    pkill -USR1 kitty 2>/dev/null || true
else
    print_error "Error al aplicar esquema"
    exit 1
fi

print_success "¡Listo!"
