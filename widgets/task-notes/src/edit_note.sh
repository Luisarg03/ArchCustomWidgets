#!/usr/bin/env bash
# Edit one note in place: flip its status, or set its type by hand.
#
#   edit_note.sh <note-id> status                     toggle open <-> done
#   edit_note.sh <note-id> type <task|idea|thought>    set the type manually
#
# Rewrites only the matching line and keeps the line count, so the processor's
# offsets stay valid. Setting a type clears `error`: a manual type is
# authoritative. Store path: $NOTES_FILE, default
# $HOME/.local/state/caelestia/notes.jsonl
set -euo pipefail

NOTES_FILE="${NOTES_FILE:-$HOME/.local/state/caelestia/notes.jsonl}"

usage() {
    echo "usage: $(basename "$0") <note-id> status | <note-id> type <task|idea|thought>" >&2
}

[ $# -ge 2 ] || { usage; exit 1; }

NOTE_ID="$1"
FIELD="$2"
VALUE="${3:-}"

case "$FIELD" in
    status) ;;
    type)
        case "$VALUE" in
            task | idea | thought) ;;
            *)
                echo "error: invalid type '$VALUE' (expected task|idea|thought)" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        usage
        echo "error: unknown field '$FIELD' (expected status|type)" >&2
        exit 1
        ;;
esac

# Same lock as capture/processor: read-modify-write must be serialized.
LOCK_FILE="$NOTES_FILE.lock"
exec 9>"$LOCK_FILE"
flock -w 10 9

python3 -c '
import json
import sys

note_id, field, value, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

try:
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
except FileNotFoundError:
    print(f"error: notes file not found: {path}", file=sys.stderr)
    sys.exit(1)

found = False
out = []
for line in lines:
    stripped = line.rstrip("\n")
    note = None
    try:
        if stripped.strip():
            note = json.loads(stripped)
    except json.JSONDecodeError:
        pass  # keep malformed lines untouched
    if note and note.get("id") == note_id:
        if field == "status":
            note["status"] = "done" if note.get("status") != "done" else "open"
        else:
            note["type"] = value
            note["error"] = None
        found = True
        stripped = json.dumps(note, ensure_ascii=False)
    out.append(stripped)

if not found:
    print(f"error: note with id {note_id!r} not found in {path}", file=sys.stderr)
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    f.write("\n".join(out))
    if out:
        f.write("\n")
' "$NOTE_ID" "$FIELD" "$VALUE" "$NOTES_FILE"
