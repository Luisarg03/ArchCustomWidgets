//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

// Standalone capture popup: launch with `qs -p capture.qml`.
// Pattern reference: ~/.config/quickshell/ii/welcome.qml (standalone app with
// Process/SplitParser from Quickshell.Io).
ApplicationWindow {
    id: root

    readonly property string captureScript: trimFileProtocol(Qt.resolvedUrl("capture_append.sh"))
    property bool submitting: false

    // Trim the file:// protocol prefix (no FileUtils singleton in standalone mode)
    function trimFileProtocol(str) {
        return str.startsWith("file://") ? str.slice(7) : str;
    }

    width: 600
    height: 140
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    // Top-center of the primary screen
    x: Screen.primaryScreen.virtualX + (Screen.primaryScreen.virtualWidth - width) / 2
    y: Screen.primaryScreen.virtualY + Screen.primaryScreen.virtualHeight * 0.15

    Component.onCompleted: {
        requestActivate();
        noteInput.forceActiveFocus();
    }

    Rectangle {
        id: background

        anchors.fill: parent
        radius: 16
        color: "#F2111111"
        border.color: "#33FFFFFF"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "Task Notes"
                color: "#EEFFFFFF"
                font.pixelSize: 14
                font.bold: true
            }

            TextField {
                id: noteInput

                Layout.fillWidth: true
                Layout.preferredHeight: 44

                placeholderText: "Type a note... (Enter to save, Esc to cancel)"
                placeholderTextColor: "#88FFFFFF"
                color: "#FFFFFFFF"
                selectionColor: "#33FFFFFF"

                background: Rectangle {
                    radius: 8
                    color: "#33111111"
                    border.color: "#33FFFFFF"
                }

                onAccepted: root.submit()
                Keys.onEscapePressed: root.close()
            }

            Text {
                id: errorLabel

                visible: false
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: "#FF6B6B" // functional error color
            }
        }
    }

    Process {
        id: captureProc

        // command array passes the text as one argv entry: no shell quoting needed
        command: [root.captureScript, noteInput.text]

        stderr: SplitParser {
            onRead: data => root.showError(data.trim())
        }

        onExited: code => {
            root.submitting = false;
            if (code === 0) {
                root.close();
            } else if (errorLabel.text === "") {
                root.showError("Failed to save note (exit code " + code + ")");
            }
        }
    }

    function submit() {
        if (root.submitting)
            return;
        const text = noteInput.text.trim();
        if (text === "")
            return;
        errorLabel.visible = false;
        errorLabel.text = "";
        root.submitting = true;
        captureProc.command = [root.captureScript, noteInput.text];
        captureProc.running = true;
    }

    function showError(message) {
        errorLabel.visible = true;
        errorLabel.text = message;
    }
}
