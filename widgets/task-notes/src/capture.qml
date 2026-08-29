//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.platform
import Quickshell
import Quickshell.Io

// Standalone capture popup: launch with `qs -p capture.qml`.
// Colors loaded from Caelestia wallbash scheme at runtime.
ApplicationWindow {
    id: root

    readonly property string captureScript: trimFileProtocol(Qt.resolvedUrl("capture_append.sh"))
    property bool submitting: false

    // Active palette — populated from scheme.json, fallback if missing
    property color colBackground: "#1E1B1A"
    property color colSurface: "#221715"
    property color colSurfaceHigh: "#291D1B"
    property color colPrimary: "#F9B6AC"
    property color colOnPrimary: "#61332D"
    property color colOnSurface: "#F9E0DC"
    property color colOnSurfaceVariant: "#BCA6A3"
    property color colOutline: "#554441"
    property color colError: "#F97386"

    function trimFileProtocol(url) {
        var str = url.toString();
        return str.startsWith("file://") ? str.slice(7) : str;
    }

    width: 640
    height: 180
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    // Focus timer — wait for window to be active before stealing focus
    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: noteInput.forceActiveFocus()
    }

    // Top-center of primary screen (guard against missing screen in standalone)
    Component.onCompleted: {
        var screen = Screen.primaryScreen;
        if (screen) {
            root.x = screen.virtualX + (screen.virtualWidth - root.width) / 2;
            root.y = screen.virtualY + screen.virtualHeight * 0.15;
        }
        requestActivate();
        focusTimer.start();
    }

    // --- Theme loading from wallbash scheme ---
    FileView {
        id: schemeFile
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation)
              + "/.local/state/caelestia/scheme.json"
        watchChanges: false
        onLoaded: {
            try {
                var data = JSON.parse(text());
                var c = data.colours || {};
                root.colBackground = Qt.color(c.background ? "#" + c.background : "#1E1B1A");
                root.colSurface = Qt.color(c.surfaceContainer ? "#" + c.surfaceContainer : "#221715");
                root.colSurfaceHigh = Qt.color(c.surfaceContainerHigh ? "#" + c.surfaceContainerHigh : "#291D1B");
                root.colPrimary = Qt.color(c.primary ? "#" + c.primary : "#F9B6AC");
                root.colOnPrimary = Qt.color(c.onPrimary ? "#" + c.onPrimary : "#61332D");
                root.colOnSurface = Qt.color(c.onSurface ? "#" + c.onSurface : "#F9E0DC");
                root.colOnSurfaceVariant = Qt.color(c.onSurfaceVariant ? "#" + c.onSurfaceVariant : "#BCA6A3");
                root.colOutline = Qt.color(c.outline ? "#" + c.outline : "#554441");
                root.colError = Qt.color(c.error ? "#" + c.error : "#F97386");
            } catch (e) {
                console.warn("capture.qml: failed to parse scheme.json:", e);
            }
        }
        onLoadFailed: function(err) {
            console.warn("capture.qml: scheme.json load failed, using fallback palette");
        }
    }

    // --- Main card ---
    Rectangle {
        id: card

        anchors.fill: parent
        radius: 16
        color: root.colSurface
        border.color: root.colOutline
        border.width: 1

        // Subtle shadow via layered rectangle (no DropShadow dependency)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.15)
            border.width: 1
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Task Notes"
                    color: root.colOnSurface
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Text {
                    text: "Ctrl+Super+G"
                    color: root.colOnSurfaceVariant
                    font.pixelSize: 11
                    opacity: 0.7
                }
            }

            // Input field
            TextField {
                id: noteInput

                Layout.fillWidth: true
                Layout.preferredHeight: 40

                placeholderText: "Type a note..."
                placeholderTextColor: root.colOnSurfaceVariant
                color: root.colOnSurface
                selectionColor: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.3)
                font.pixelSize: 14

                background: Rectangle {
                    radius: 10
                    color: root.colSurfaceHigh
                    border.color: noteInput.activeFocus ? root.colPrimary : root.colOutline
                    border.width: noteInput.activeFocus ? 1.5 : 1

                    Behavior on border.color {
                        ColorAnimation { duration: 120 }
                    }
                }

                onAccepted: root.submit()
                Keys.onEscapePressed: root.close()
            }

            // Error label
            Text {
                id: errorLabel

                visible: false
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: root.colError
            }

            // Footer: status hint + Save button
            RowLayout {
                Layout.fillWidth: true

                Text {
                    id: statusLabel
                    Layout.fillWidth: true
                    font.pixelSize: 11
                    color: root.colOnSurfaceVariant
                    opacity: root.submitting ? 1.0 : 0.0

                    text: root.submitting ? "Saving..." : ""

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                Rectangle {
                    id: saveButton

                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 32
                    radius: 8
                    color: saveMouseArea.pressed
                        ? Qt.darker(root.colPrimary, 1.15)
                        : (saveMouseArea.containsMouse
                            ? Qt.lighter(root.colPrimary, 1.08)
                            : root.colPrimary)

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: root.colOnPrimary
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: saveMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }

                    // Keyboard shortcut hint
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 6
                        visible: false
                        text: "⏎"
                        color: root.colOnPrimary
                        font.pixelSize: 14
                        opacity: 0.6
                    }
                }
            }
        }
    }

    // --- Process ---
    Process {
        id: captureProc

        command: [root.captureScript, noteInput.text]

        stderr: SplitParser {
            onRead: data => root.showError(data.trim())
        }

        onExited: code => {
            root.submitting = false;
            if (code === 0) {
                root.close();
            } else if (errorLabel.text === "") {
                root.showError("Failed to save (exit " + code + ")");
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
