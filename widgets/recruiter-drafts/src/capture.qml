//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.platform
import Quickshell
import Quickshell.Io

// Recruiter draft popup: launch with `qs -p capture.qml`.
// The job posting is pasted here; draft_from_job.sh writes the email with the
// configured LLM and saves it as a Gmail draft. Colors come from the Caelestia
// wallbash scheme at runtime.
ApplicationWindow {
    id: root

    readonly property string draftScript: trimFileProtocol(Qt.resolvedUrl("draft_from_job.sh"))
    property bool submitting: false
    property string lastError: ""
    property int elapsed: 0

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

    width: 780
    height: 560
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    // Closing while the LLM runs would kill the draft: only quit when idle.
    // Qt.quit() (not just hide) — a hidden window would strand a ~350 MB `qs`.
    onClosing: function(close) {
        if (root.submitting)
            close.accepted = false;
        else
            Qt.quit();
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Shortcut {
        sequences: ["Ctrl+Return", "Ctrl+Enter"]
        onActivated: root.submit()
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: jobArea.forceActiveFocus()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.submitting
        onTriggered: root.elapsed += 1
    }

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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Recruiter Draft"
                    color: root.colOnSurface
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Text {
                    text: "Super+H  ·  Ctrl+Enter"
                    color: root.colOnSurfaceVariant
                    font.pixelSize: 11
                    opacity: 0.7
                }
            }

            // Optional recipient override
            TextField {
                id: toField

                Layout.fillWidth: true
                Layout.preferredHeight: 40

                placeholderText: "Para (opcional) — si el aviso no trae el mail del reclutador"
                placeholderTextColor: root.colOnSurfaceVariant
                color: root.colOnSurface
                selectionColor: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.3)
                font.pixelSize: 13
                enabled: !root.submitting

                background: Rectangle {
                    radius: 10
                    color: root.colSurfaceHigh
                    border.color: toField.activeFocus ? root.colPrimary : root.colOutline
                    border.width: toField.activeFocus ? 1.5 : 1
                }
            }

            // Job posting
            ScrollView {
                id: jobScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                TextArea {
                    id: jobArea

                    width: jobScroll.availableWidth
                    height: Math.max(implicitHeight, jobScroll.availableHeight)

                    wrapMode: TextArea.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    enabled: !root.submitting

                    placeholderText: "Pegá el aviso completo de la posición (con el mail de postulación si está)..."
                    placeholderTextColor: root.colOnSurfaceVariant
                    color: root.colOnSurface
                    selectionColor: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.3)
                    font.pixelSize: 13

                    background: Rectangle {
                        radius: 10
                        color: root.colSurfaceHigh
                        border.color: jobArea.activeFocus ? root.colPrimary : root.colOutline
                        border.width: jobArea.activeFocus ? 1.5 : 1
                    }
                }
            }

            // Error label
            Text {
                id: errorLabel

                visible: root.lastError !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: root.colError
                text: root.lastError
            }

            // Footer: status + generate button
            RowLayout {
                Layout.fillWidth: true

                Text {
                    id: statusLabel

                    Layout.fillWidth: true
                    font.pixelSize: 11
                    color: root.colOnSurfaceVariant
                    text: root.submitting
                        ? "Generando borrador... " + root.elapsed + "s (no cierres la ventana)"
                        : ""
                }

                Rectangle {
                    id: generateButton

                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 32
                    radius: 8
                    color: root.submitting
                        ? Qt.darker(root.colSurfaceHigh, 1.1)
                        : (generateMouseArea.pressed
                            ? Qt.darker(root.colPrimary, 1.15)
                            : (generateMouseArea.containsMouse
                                ? Qt.lighter(root.colPrimary, 1.08)
                                : root.colPrimary))

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.submitting ? "Generando..." : "Generar borrador"
                        color: root.submitting ? root.colOnSurfaceVariant : root.colOnPrimary
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: generateMouseArea
                        anchors.fill: parent
                        hoverEnabled: !root.submitting
                        enabled: !root.submitting
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }
    }

    // --- Process ---
    Process {
        id: draftProc

        stderr: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line !== "")
                    root.lastError = line;
            }
        }

        onExited: code => {
            root.submitting = false;
            if (code === 0) {
                root.close();
            } else if (root.lastError === "") {
                root.lastError = "Falló la generación (exit " + code + "). Ver ~/.local/state/acw/recruiter-drafts/";
            }
        }
    }

    function submit() {
        if (root.submitting)
            return;
        var job = jobArea.text.trim();
        if (job === "")
            return;
        var to = toField.text.trim();
        root.lastError = "";
        root.elapsed = 0;
        root.submitting = true;
        draftProc.command = to === ""
            ? [root.draftScript, "--text", jobArea.text]
            : [root.draftScript, "--to", to, "--text", jobArea.text];
        draftProc.running = true;
    }
}
