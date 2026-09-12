#!/usr/bin/env bash
# Patch Caelestia shell.json with the VPN quick-toggle and provider block.
#
# Ensures utilities.quickToggles holds the "vpn" entry and utilities.vpn holds
# the Surfshark provider block used by the quick-toggle button. Idempotent:
# nothing is written when the target state is already present, and entries a
# user edited are never overwritten or removed.
#
# Usage:
#   patch-shell.sh [--shell-json PATH]           ensure entries exist
#   patch-shell.sh --remove [--shell-json PATH]  remove only our entries
set -euo pipefail

SHELL_JSON="$HOME/.config/caelestia/shell.json"
REMOVE=0

TOGGLE='{"enabled":true,"id":"vpn"}'
PROVIDER='{"enabled":true,"provider":[{"connectCmd":["systemctl","start","surfshark-connect"],"disconnectCmd":["systemctl","start","surfshark-disconnect"],"displayName":"Surfshark","enabled":true,"iface":"surfshark","name":"wireguard"}]}'

usage() {
    cat <<'EOF'
Usage: patch-shell.sh [--shell-json PATH] [--remove]

  --shell-json PATH  shell.json to patch (default: ~/.config/caelestia/shell.json)
  --remove           remove this unit's entries instead of adding them
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --shell-json) SHELL_JSON="${2:?--shell-json requires a path}"; shift 2 ;;
        --remove) REMOVE=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

command -v jq >/dev/null 2>&1 || { echo "Error: jq is not installed" >&2; exit 1; }
[ -f "$SHELL_JSON" ] || { echo "Error: shell.json not found: $SHELL_JSON" >&2; exit 1; }
jq -e . "$SHELL_JSON" >/dev/null 2>&1 || { echo "Error: cannot parse $SHELL_JSON" >&2; exit 1; }

tmp="$(mktemp "$SHELL_JSON.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [ "$REMOVE" = 1 ]; then
    # Only entries that still match this unit's own values are removed.
    jq --indent 4 --argjson toggle "$TOGGLE" --argjson provider "$PROVIDER" '
        (if (.utilities.quickToggles | type) == "array"
         then .utilities.quickToggles |= map(select(. != $toggle)) else . end)
        | (if .utilities.vpn == $provider then del(.utilities.vpn) else . end)
    ' "$SHELL_JSON" >"$tmp" || { echo "Error: cannot patch $SHELL_JSON" >&2; exit 1; }
else
    jq --indent 4 --argjson toggle "$TOGGLE" --argjson provider "$PROVIDER" '
        .utilities //= {}
        | .utilities.quickToggles //= []
        | if (.utilities.quickToggles | type) != "array"
          then error("utilities.quickToggles is not an array") else . end
        | if any(.utilities.quickToggles[]?; .id == "vpn")
          then . else .utilities.quickToggles += [$toggle] end
        | if .utilities.vpn == null then .utilities.vpn = $provider else . end
    ' "$SHELL_JSON" >"$tmp" || { echo "Error: cannot patch $SHELL_JSON" >&2; exit 1; }
fi

# Warn about entries that look like ours but were edited, before deciding
# whether there is anything to write.
if [ "$REMOVE" = 1 ]; then
    if jq -e --argjson toggle "$TOGGLE" \
        'any(.utilities.quickToggles[]?; .id == "vpn" and . != $toggle)' "$SHELL_JSON" >/dev/null; then
        echo "WARN: vpn quick-toggle modified by user; not removed" >&2
    fi
elif jq -e --argjson provider "$PROVIDER" \
    '.utilities.vpn != null and .utilities.vpn != $provider' "$SHELL_JSON" >/dev/null; then
    echo "WARN: utilities.vpn exists with different values; left untouched" >&2
fi

# Canonical comparison: same content in different formatting is not a change.
if diff <(jq -S . "$SHELL_JSON") <(jq -S . "$tmp") >/dev/null; then
    if [ "$REMOVE" = 1 ]; then
        echo "Nothing to remove (entries missing or modified by user)"
    else
        echo "Already configured: no changes needed"
    fi
    exit 0
fi

backup="$SHELL_JSON.bak-$(date +%Y%m%d-%H%M%S)"
cp "$SHELL_JSON" "$backup"
mv "$tmp" "$SHELL_JSON"
trap - EXIT
echo "Backed up $SHELL_JSON -> $backup"
echo "Updated $SHELL_JSON"
