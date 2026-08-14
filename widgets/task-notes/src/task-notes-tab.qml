import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Dashboard tab listing notes from the shared JSONL store.
// Pattern references:
//   - OpenCodeCostTab.qml: FileView + watchChanges auto-refresh
//   - WeatherTab.qml: tab structure, style tokens (Tokens.*, Colours.palette)
// Store path must match the scripts' default:
//   $NOTES_FILE = $HOME/.local/state/caelestia/notes.jsonl
Item {
    id: root

    readonly property string notesPath: Paths.state + "/notes.jsonl"
    property var notes: []

    // Cap tab height at ~400px; internal scroll handles many notes
    implicitWidth: 840
    implicitHeight: 440

    FileView {
        id: notesFile

        path: root.notesPath
        watchChanges: true

        onFileChanged: reload()

        onLoaded: root.notes = parseNotes(text())

        onLoadFailed: root.notes = [] // missing file = empty list, not an error
    }

    // Fallback refresh: watchChanges may miss rapid writes from execDetached
    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: notesFile.reload()
    }

    // Trim the file:// protocol prefix (same helper as the shell's FileUtils).
    function trimFileProtocol(str) {
        return str.startsWith("file://") ? str.slice(7) : str;
    }

    // JSONL is append-only: newest note is the last line, so iterate in reverse.
    // Malformed lines are skipped, missing fields fall back to defaults.
    function parseNotes(content) {
        const result = [];
        const lines = content.split("\n");
        for (let i = lines.length - 1; i >= 0; i--) {
            const line = lines[i].trim();
            if (line === "")
                continue;
            let note;
            try {
                note = JSON.parse(line);
            } catch (e) {
                continue; // tolerate malformed lines
            }
            if (note && typeof note === "object" && note.id) {
                result.push({
                    id: note.id,
                    title: note.title || note.raw || "(untitled)",
                    type: note.type || "thought",
                    status: note.status || "open",
                    error: note.error || null
                });
            }
        }
        return result;
    }

    Flickable {
        id: notesFlickable

        anchors.fill: parent
        anchors.topMargin: Tokens.spacing.large
        anchors.bottomMargin: Tokens.spacing.large

        clip: true
        flickableDirection: Flickable.VerticalFlick
        contentHeight: notesColumn.implicitHeight

        ColumnLayout {
            id: notesColumn

            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: root.notes
                delegate: NoteRow {}
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.large
                visible: root.notes.length === 0
                text: qsTr("No notes yet")
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
            }
        }

        StyledScrollBar {
            flickable: notesFlickable
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
    }

    component NoteRow: StyledRect {
        id: row

        required property var modelData

        Layout.fillWidth: true
        implicitHeight: Math.max(rowContent.implicitHeight + Tokens.padding.medium * 2, 42)
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        opacity: modelData.status === "done" ? 0.5 : 1.0

        RowLayout {
            id: rowContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            // Checkbox: click toggles the note status
            Item {
                width: 32
                height: 32

                Rectangle {
                    readonly property bool done: row.modelData.status === "done"
                    readonly property bool hovered: checkMouse.containsMouse

                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 5
                    color: done
                        ? Colours.palette.m3primary
                        : (hovered ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.12) : "transparent")
                    border.color: done
                        ? Colours.palette.m3primary
                        : (hovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant)
                    border.width: done ? 0 : 1.5

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    MaterialIcon {
                        visible: parent.done
                        anchors.centerIn: parent
                        text: "check"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3onSurface
                    }
                }

                MouseArea {
                    id: checkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // ponytail: absolute path — Qt.resolvedUrl resolves relative to QML file,
                        // but installed QML lives in a different dir than the script.
                        Quickshell.execDetached([
                            Paths.home + "/.config/acw/task-notes/src/toggle_note.sh",
                            row.modelData.id
                        ]);
                        refreshTimer.start();
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: row.modelData.title
                font.family: Tokens.font.body.medium.family
                font.pixelSize: Tokens.font.body.medium.pixelSize
                font.weight: Tokens.font.body.medium.weight
                font.strikeout: row.modelData.status === "done"
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            // Warning icon when LLM processing failed
            MaterialIcon {
                visible: row.modelData.error
                text: "warning"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3error
            }

            // Type badge
            StyledText {
                text: row.modelData.type
                font: Tokens.font.body.small
                color: {
                    if (row.modelData.type === "task")
                        return Colours.palette.m3primary;
                    if (row.modelData.type === "idea")
                        return Colours.palette.m3tertiary;
                    return Colours.palette.m3secondary; // thought, default
                }
            }
        }
    }
}
