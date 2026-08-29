#!/usr/bin/env bash
# Set a note's type in place to one of task|idea|thought (manual reclassification
# from the dashboard). Rewrites only the matching line, so the processor's line
# offsets stay valid. Clears `error` because a manual type is authoritative.
# Usage: set_type.sh <note-id> <task|idea|thought>
# Store path: $NOTES_FILE env, defaults to $HOME/.local/state/caelestia/notes.jsonl
set -euo pipefail

NOTES_FILE="${NOTES_FILE:-$HOME/.local/state/caelestia/notes.jsonl}"

if [ $# -lt 2 ]; then
    echo "usage: $(basename "$0") <note-id> <task|idea|thought>" >&2
    exit 1
fi

# Same lock as capture/toggle/processor: read-modify-write must be serialized.
LOCK_FILE="$NOTES_FILE.lock"
exec 9>"$LOCK_FILE"
flock -w 10 9

python3 -c '
import json
import sys

note_id, ntype, path = sys.argv[1], sys.argv[2], sys.argv[3]

if ntype not in ("task", "idea", "thought"):
    print(f"error: invalid type {ntype!r} (expected task|idea|thought)", file=sys.stderr)
    sys.exit(1)

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
        note["type"] = ntype
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
' "$1" "$2" "$NOTES_FILE"
