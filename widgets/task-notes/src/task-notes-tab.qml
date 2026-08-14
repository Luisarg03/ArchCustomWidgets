import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

// Dashboard tab listing notes from the shared JSONL store.
// Pattern references:
//   - OpenCodeCostTab.qml: FileView + watchChanges auto-refresh
//   - WeatherTab.qml: tab structure, style tokens (Tokens.*, Colours.palette)
// Store path must match the scripts' default:
//   $NOTES_FILE = $HOME/.local/state/caelestia/notes.jsonl
Item {
    id: root

    readonly property string notesPath: FileUtils.trimFileProtocol(
        StandardPaths.standardLocations(StandardPaths.StateLocation)[0] + "/caelestia/notes.jsonl")
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
            flickable: parent
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
            Rectangle {
                readonly property bool done: row.modelData.status === "done"

                width: 18
                height: 18
                radius: 4
                color: done ? Colours.palette.m3primary : "transparent"
                border.color: done ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                border.width: 1

                MaterialIcon {
                    visible: parent.done
                    anchors.centerIn: parent
                    text: "check"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurface
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached([
                        FileUtils.trimFileProtocol(Qt.resolvedUrl("toggle_note.sh")),
                        row.modelData.id
                    ])
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: row.modelData.title
                font: Tokens.font.body.medium
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
