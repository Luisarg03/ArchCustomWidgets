import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Dashboard tab listing notes from the shared JSONL store, organized in
// sections: unclassified (errored) / tasks / ideas / thoughts / done (collapsed
// by default). Tasks/ideas/thoughts are sorted by priority, then due date, then
// creation time. Pattern references:
//   - OpenCodeCostTab.qml: FileView + watchChanges auto-refresh
//   - WeatherTab.qml: tab structure, style tokens (Tokens.*, Colours.palette)
// Store path must match the scripts' default:
//   $NOTES_FILE = $HOME/.local/state/caelestia/notes.jsonl
Item {
    id: root

    readonly property string notesPath: Paths.state + "/notes.jsonl"
    property var notes: []
    property var sections: []
    property var collapsedSections: ({done: true})

    // Cap tab height at ~400px; internal scroll handles many notes
    implicitWidth: 840
    implicitHeight: 440

    FileView {
        id: notesFile

        path: root.notesPath
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            root.notes = parseNotes(text());
            root.refreshSections();
            if (!root.notes.some(function (n) {
                return n.error;
            }))
                retryTimer.stop();
        }

        onLoadFailed: {
            root.notes = [];
            root.refreshSections();
        }
    }

    // Fallback refresh: watchChanges may miss rapid writes from execDetached
    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: notesFile.reload()
    }

    // Classifying takes a whole LLM call (~10-20s), so one reload right after
    // the click would always show the old state. Poll until the error clears.
    Timer {
        id: retryTimer
        interval: 2000
        repeat: true
        property int polls: 0

        onTriggered: {
            polls += 1;
            notesFile.reload();
            if (polls >= 15)
                stop();
        }
        onRunningChanged: {
            if (!running)
                polls = 0;
        }
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
                    type: note.type || "",
                    status: note.status || "open",
                    error: note.error || null,
                    priority: note.priority || "",
                    tags: Array.isArray(note.tags) ? note.tags : [],
                    due: note.due || "",
                    createdAt: note.created_at || ""
                });
            }
        }
        return result;
    }

    function sectionOf(note) {
        if (note.status === "done")
            return "done";
        if (note.error || note.type === "")
            return "unclassified";
        return note.type;
    }

    function priorityRank(p) {
        if (p === "high")
            return 2;
        if (p === "medium")
            return 1;
        return 0;
    }

    function compareNotes(a, b) {
        const pa = priorityRank(a.priority), pb = priorityRank(b.priority);
        if (pa !== pb)
            return pb - pa;
        const da = a.due || "", db = b.due || "";
        if (da !== db) {
            if (da === "")
                return 1;
            if (db === "")
                return -1;
            return da < db ? -1 : 1;
        }
        const ca = a.createdAt || "", cb = b.createdAt || "";
        if (ca !== cb)
            return ca < cb ? 1 : -1;
        return 0;
    }

    function sortSection(list, key) {
        list.sort(function (a, b) {
            if (key === "done" || key === "unclassified") {
                const ca = a.createdAt || "", cb = b.createdAt || "";
                return ca < cb ? 1 : (ca > cb ? -1 : 0);
            }
            return compareNotes(a, b);
        });
        return list;
    }

    function refreshSections() {
        const defs = [
            { key: "unclassified", label: qsTr("Sin clasificar") },
            { key: "task", label: qsTr("Tareas") },
            { key: "idea", label: qsTr("Ideas") },
            { key: "thought", label: qsTr("Pensamientos") },
            { key: "done", label: qsTr("Completadas") }
        ];
        const result = [];
        for (let i = 0; i < defs.length; i++) {
            const def = defs[i];
            const items = sortSection(
                root.notes.filter(function (n) { return sectionOf(n) === def.key; }),
                def.key
            );
            if (items.length === 0)
                continue;
            result.push({
                key: def.key,
                label: def.label,
                notes: items,
                collapsed: root.collapsedSections[def.key] === true
            });
        }
        root.sections = result;
    }

    function toggleSection(key) {
        const next = {};
        for (const k in root.collapsedSections)
            next[k] = root.collapsedSections[k];
        next[key] = !next[key];
        root.collapsedSections = next;
        refreshSections();
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
                model: root.sections

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    SectionHeader {
                        Layout.fillWidth: true
                        label: modelData.label
                        count: modelData.notes.length
                        collapsed: modelData.collapsed
                        onClicked: root.toggleSection(modelData.key)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small
                        visible: !modelData.collapsed

                        Repeater {
                            model: modelData.notes
                            delegate: NoteRow {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.large
                visible: root.notes.length === 0
                text: qsTr("No hay notas todavía")
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

    // Collapsible section header with icon, label and count.
    component SectionHeader: Item {
        id: header

        required property string label
        required property int count
        required property bool collapsed
        signal clicked()

        implicitWidth: 200
        implicitHeight: 32

        RowLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: header.collapsed ? "chevron_right" : "expand_more"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: header.label
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
            }

            StyledText {
                text: String(header.count)
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: header.clicked()
        }
    }

    component NoteRow: StyledRect {
        id: row

        required property var modelData

        readonly property string noteType: row.modelData.type || ""
        readonly property string dueState: dueStateOf(row.modelData.due)

        Layout.fillWidth: true
        implicitHeight: Math.max(rowContent.implicitHeight + Tokens.padding.medium * 2, 42)
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        opacity: row.modelData.status === "done" ? 0.5 : 1.0

        // overdue = past, soon = due within 2 days, ok = scheduled later
        function dueStateOf(dueStr) {
            if (!dueStr)
                return "";
            const parts = dueStr.split("-");
            if (parts.length !== 3)
                return "";
            const y = parseInt(parts[0], 10);
            const m = parseInt(parts[1], 10);
            const d = parseInt(parts[2], 10);
            if (isNaN(y) || isNaN(m) || isNaN(d))
                return "";
            const target = new Date(y, m - 1, d);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            const diff = Math.round((target.getTime() - today.getTime()) / 86400000);
            if (diff < 0)
                return "overdue";
            if (diff <= 2)
                return "soon";
            return "ok";
        }

        function priorityColor() {
            if (row.modelData.priority === "high")
                return Colours.palette.m3error;
            if (row.modelData.priority === "medium")
                return Colours.palette.m3tertiary;
            return Colours.palette.m3onSurfaceVariant;
        }

        function dueColor() {
            if (row.dueState === "overdue")
                return Colours.palette.m3error;
            if (row.dueState === "soon")
                return Colours.palette.m3tertiary;
            return Colours.palette.m3onSurfaceVariant;
        }

        function typeColor() {
            if (row.noteType === "task")
                return Colours.palette.m3primary;
            if (row.noteType === "idea")
                return Colours.palette.m3tertiary;
            return Colours.palette.m3secondary; // thought, default
        }

        // Clicking the type badge cycles task -> idea -> thought -> task.
        function cycleType() {
            const order = ["task", "idea", "thought"];
            const idx = order.indexOf(row.noteType);
            return order[(idx + 1) % order.length];
        }

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
                            Paths.home + "/.config/acw/task-notes/src/edit_note.sh",
                            row.modelData.id,
                            "status"
                        ]);
                        refreshTimer.start();
                    }
                }
            }

            // Title + tags
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

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

                Text {
                    Layout.fillWidth: true
                    visible: row.modelData.tags.length > 0
                    text: row.modelData.tags.join(" · ")
                    font.family: Tokens.font.body.small.family
                    font.pixelSize: 10
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.8
                    elide: Text.ElideRight
                }
            }

            // Priority dot (high = error, medium = tertiary, low = muted)
            Rectangle {
                visible: row.modelData.priority !== ""
                width: 8
                height: 8
                radius: 4
                color: row.priorityColor()
                opacity: row.modelData.priority === "low" ? 0.45 : 1.0
            }

            // Due date (red when overdue, amber when due within 2 days)
            Text {
                visible: row.modelData.due !== ""
                text: row.modelData.due
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: row.dueColor()
            }

            // Retry chip for failed LLM classification
            Rectangle {
                visible: !!row.modelData.error
                Layout.preferredHeight: 24
                Layout.preferredWidth: retryLabel.implicitWidth + 16
                radius: 6
                color: retryMouse.containsMouse
                    ? Qt.rgba(Colours.palette.m3error.r, Colours.palette.m3error.g, Colours.palette.m3error.b, 0.15)
                    : "transparent"
                border.color: Colours.palette.m3error
                border.width: 1

                Text {
                    id: retryLabel
                    anchors.centerIn: parent
                    text: qsTr("Reintentar")
                    font.pixelSize: 10
                    color: Colours.palette.m3error
                }

                MouseArea {
                    id: retryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached([
                            Paths.home + "/.config/acw/task-notes/src/process_notes.sh",
                            "--retry"
                        ]);
                        retryTimer.restart();
                    }
                }
            }

            // Type badge: click to cycle task/idea/thought (manual reclassification)
            Item {
                visible: row.noteType !== ""
                implicitWidth: typeLabel.implicitWidth + 10
                implicitHeight: typeLabel.implicitHeight + 6

                StyledText {
                    id: typeLabel
                    anchors.centerIn: parent
                    text: row.noteType
                    font: Tokens.font.body.small
                    color: row.typeColor()
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached([
                            Paths.home + "/.config/acw/task-notes/src/edit_note.sh",
                            row.modelData.id,
                            "type",
                            row.cycleType()
                        ]);
                        refreshTimer.start();
                    }
                }
            }
        }
    }
}
