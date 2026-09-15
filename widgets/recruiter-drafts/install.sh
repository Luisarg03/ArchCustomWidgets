#!/usr/bin/env bash
# recruiter-drafts installer: copies scripts + env.conf into ~/.config/acw,
# seeds the Gmail app password (0600, never echoed) and nothing else.
# No systemd units: the keybind is the trigger.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"
# shellcheck source=../../factory/lib.sh
source "$SCRIPT_DIR/../../factory/lib.sh"

seed_app_password() {
    if [ -s "$GMAIL_APP_PASSWORD_FILE" ]; then
        chmod 600 "$GMAIL_APP_PASSWORD_FILE"
        echo "app password already configured: $GMAIL_APP_PASSWORD_FILE"
        return 0
    fi

    local pw=""
    if [ -n "${GMAIL_APP_PASSWORD:-}" ]; then
        pw="$GMAIL_APP_PASSWORD"
    elif [ -t 0 ]; then
        printf 'Gmail app password (16 chars, input hidden): ' >&2
        read -rsp '' pw || true
        printf '\n' >&2
    fi

    printf '%s' "$pw" > "$GMAIL_APP_PASSWORD_FILE"
    chmod 600 "$GMAIL_APP_PASSWORD_FILE"
    if [ -n "$pw" ]; then
        echo "app password stored in $GMAIL_APP_PASSWORD_FILE (mode 600)"
    else
        echo "WARN: no app password provided; write it yourself:"
        echo "      printf '%s' '<app-password>' > $GMAIL_APP_PASSWORD_FILE && chmod 600 $GMAIL_APP_PASSWORD_FILE"
    fi
}

install() {
    mkdir -p "$INSTALL_ROOT/src"
    for src in "$SCRIPT_DIR"/src/*; do
        [ -f "$src" ] || continue
        backup_and_copy "$src" "$INSTALL_ROOT/src/$(basename "$src")"
    done
    chmod 755 "$INSTALL_ROOT/src/"*.sh "$INSTALL_ROOT/src/"*.py
    backup_and_copy "$SCRIPT_DIR/env.conf" "$INSTALL_ROOT/env.conf"
    echo "installed unit files to $INSTALL_ROOT"

    seed_app_password

    command -v node >/dev/null 2>&1 || \
        echo "WARN: node not found; the dsh headless run will fail"
    [ -f "$DSH_ROOT/apps/cli/src/bin.ts" ] || \
        echo "WARN: DeepSeek Harness not found at $DSH_ROOT; set DSH_ROOT in env.conf"
    [ -d "$HOME/.dsh/profiles/$DSH_PROFILE" ] || \
        echo "WARN: dsh profile '$DSH_PROFILE' missing; see 'LLM profile' in the unit README"
    command -v qs >/dev/null 2>&1 || \
        echo "WARN: quickshell (qs) not found; the popup will not open"

    echo
    echo "Wire the keybind manually (never auto-applied):"
    echo "  hl.bind(\"SUPER\" .. \" + \" .. \"H\", hl.dsp.exec_cmd(\"qs -p $INSTALL_ROOT/src/capture.qml\"))"
    echo "Then verify connectivity: $INSTALL_ROOT/src/draft_from_job.sh --check"
}

remove() {
    rm -rf "$INSTALL_ROOT"
    echo "removed $INSTALL_ROOT"
}

case "${1:-}" in
    --remove) remove ;;
    "" | install) install ;;
    *)
        echo "usage: $0 [install|--remove]" >&2
        exit 1
        ;;
esac
