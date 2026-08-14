#!/usr/bin/env bash
# Flip a note status between "open" and "done", rewriting the line in place
# (same number of lines, so the processor's line offsets stay valid).
# Usage: toggle_note.sh <id>
# Store path: $NOTES_FILE env, defaults to $HOME/.local/state/caelestia/notes.jsonl
set -euo pipefail

NOTES_FILE="${NOTES_FILE:-$HOME/.local/state/caelestia/notes.jsonl}"

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") <note-id>" >&2
    exit 1
fi

python3 -c '
import json
import sys

note_id = sys.argv[1]
path = sys.argv[2]

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
        note["status"] = "done" if note.get("status") != "done" else "open"
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
' "$1" "$NOTES_FILE"
