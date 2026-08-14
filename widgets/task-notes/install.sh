#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.conf
source "$SCRIPT_DIR/env.conf"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
UNIT="acw-task-notes"
QS_SRC_DIR="/etc/xdg/quickshell/caelestia/modules/dashboard"
QS_DASH_DIR="$HOME/.config/quickshell/caelestia/modules/dashboard"

backup_and_copy() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp "$dst" "$dst.bak-$(date +%s)"
        echo "backed up existing: $dst"
    fi
    cp "$src" "$dst"
}

# Idempotent: appends the Tasks tab entry + taskComponent to Content.qml.
# Skips entirely when taskComponent is already present.
patch_content_qml() {
    local qml="$1"
    [ -f "$qml" ] || { echo "WARN: $qml missing; patch skipped"; return 0; }
    if grep -q "taskComponent" "$qml"; then
        echo "Content.qml already patched (taskComponent present); skip"
        return 0
    fi
    python3 - "$qml" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    lines = f.read().splitlines(keepends=True)

tab_entry = [
    '                component: taskComponent,\n',
    '                iconName: "checklist",\n',
    '                text: qsTr("Tasks"),\n',
    '                enabled: true\n',
]
component = [
    '            Component {\n',
    '                id: taskComponent\n',
    '\n',
    '                TaskWidget {}\n',
    '            }\n',
]

# Tab entry: right after the last entry (weather), anchored on its enabled line.
for i, line in enumerate(lines):
    if "Config.dashboard.showWeather" in line:
        stripped = line.rstrip("\n").rstrip()
        lines[i] = (stripped + ",") if not stripped.endswith(",") else stripped
        lines[i] += "\n"
        for j, piece in enumerate(tab_entry):
            lines.insert(i + 1 + j, piece)
        break
else:
    print("WARN: weather tab entry not found; task tab not inserted")

# Component: right before the contentX behavior, after the last Component block.
for i, line in enumerate(lines):
    if line.lstrip().startswith("Behavior on contentX"):
        for j, piece in enumerate(component):
            lines.insert(i + j, piece)
        break
else:
    print("WARN: component anchor not found; task component not inserted")

with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
print("patched %s" % path)
PY
}

install() {
    # 1. Unit scripts + env.conf
    mkdir -p "$INSTALL_ROOT/src"
    for src in "$SCRIPT_DIR"/src/*; do
        [ -f "$src" ] || continue
        backup_and_copy "$src" "$INSTALL_ROOT/src/$(basename "$src")"
    done
    # Scripts are invoked by systemd (ExecStart) and keybinds; ensure exec bit.
    chmod +x "$INSTALL_ROOT/src/"*.sh
    backup_and_copy "$SCRIPT_DIR/env.conf" "$INSTALL_ROOT/env.conf"
    echo "installed unit files to $INSTALL_ROOT"

    # 2. systemd user units. Only the .path is enabled; the .service is a
    #    oneshot fired by PathChanged on every write to the notes store.
    mkdir -p "$SYSTEMD_USER_DIR"
    backup_and_copy "$SCRIPT_DIR/src/$UNIT.service" "$SYSTEMD_USER_DIR/$UNIT.service"
    backup_and_copy "$SCRIPT_DIR/src/$UNIT.path" "$SYSTEMD_USER_DIR/$UNIT.path"
    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT.path"
    systemctl --user is-enabled "$UNIT.path" >/dev/null
    systemctl --user is-active "$UNIT.path" >/dev/null
    echo "$UNIT.path enabled and active"

    # 3. Shell dashboard override: full modules/dashboard tree copy (relative
    #    imports break if only Content.qml is copied), then patch + TaskWidget.
    if [ ! -d "$QS_SRC_DIR" ]; then
        echo "WARN: $QS_SRC_DIR not found; dashboard override skipped"
        return 0
    fi
    if [ -d "$QS_DASH_DIR" ]; then
        local bak="$QS_DASH_DIR.bak-$(date +%s)"
        mv "$QS_DASH_DIR" "$bak"
        echo "backed up existing override: $bak"
    fi
    mkdir -p "$(dirname "$QS_DASH_DIR")"
    cp -r "$QS_SRC_DIR" "$QS_DASH_DIR"
    echo "copied dashboard module tree to $QS_DASH_DIR"

    patch_content_qml "$QS_DASH_DIR/Content.qml"

    if [ -f "$INSTALL_ROOT/src/task-notes-tab.qml" ]; then
        cp "$INSTALL_ROOT/src/task-notes-tab.qml" "$QS_DASH_DIR/TaskWidget.qml"
        echo "installed TaskWidget.qml"
    else
        echo "WARN: task-notes-tab.qml missing; TaskWidget.qml not installed (pending lane; re-run install.sh after it lands)"
    fi
}

remove() {
    systemctl --user disable --now "$UNIT.path" 2>/dev/null || true
    rm -f "$SYSTEMD_USER_DIR/$UNIT.service" \
          "$SYSTEMD_USER_DIR/$UNIT.path" \
          "$SYSTEMD_USER_DIR/$UNIT.service".bak-* \
          "$SYSTEMD_USER_DIR/$UNIT.path".bak-*
    rm -rf "$INSTALL_ROOT"
    # Remove the override tree only if it is ours (marker: TaskWidget.qml).
    if [ -f "$QS_DASH_DIR/TaskWidget.qml" ]; then
        rm -rf "$QS_DASH_DIR"
        echo "removed dashboard override $QS_DASH_DIR"
    else
        echo "WARN: no TaskWidget.qml marker in $QS_DASH_DIR; override left untouched"
    fi
    systemctl --user daemon-reload
    echo "removed $UNIT units and $INSTALL_ROOT"
}

case "${1:-}" in
    --remove) remove ;;
    "" | install) install ;;
    *)
        echo "usage: $0 [install|--remove]" >&2
        exit 1
        ;;
esac
