#!/bin/bash
# Power actions for the waybar modules, each behind a zenity confirmation.
#
#   power.sh --shutdown    confirm, then systemctl poweroff
#   power.sh --reboot      confirm, then systemctl reboot
#   power.sh --logout      confirm, then exit the Hyprland session
set -euo pipefail

SHUTDOWN_CMD=(systemctl poweroff)
REBOOT_CMD=(systemctl reboot)
LOGOUT_CMD=(hyprctl dispatch exit)

# Ask for confirmation, then run the command. $1 title, $2 text, $3 ok label.
confirm() {
    if zenity --question --title="$1" --text="$2" --ok-label="$3" --cancel-label="Cancel"; then
        shift 3
        echo "Running: $*"
        "$@"
    else
        echo "Cancelled."
    fi
}

if ! command -v zenity &> /dev/null; then
    echo "Error: zenity is not installed. Please install it." >&2
    notify-send "Error: zenity is not installed. Please install it." 2>/dev/null || true
    exit 1
fi

case "${1:-}" in
    --shutdown)
        confirm "System Shutdown Confirmation" \
            "Are you sure you want to SHUTDOWN the system?" "Shutdown" "${SHUTDOWN_CMD[@]}"
        ;;
    --reboot)
        confirm "System Reboot Confirmation" \
            "Are you sure you want to REBOOT the system?" "Reboot" "${REBOOT_CMD[@]}"
        ;;
    --logout)
        confirm "Session Logout Confirmation" \
            "Do you want to exit session?" "Exit" "${LOGOUT_CMD[@]}"
        ;;
    *)
        echo "Usage: $0 {--shutdown | --reboot | --logout}" >&2
        exit 1
        ;;
esac
