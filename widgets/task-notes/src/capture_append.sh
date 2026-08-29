#!/usr/bin/env bash
# Append one JSON line to the notes store and print the created note id.
# Usage: capture_append.sh <text>
# Store path: $NOTES_FILE env, defaults to $HOME/.local/state/caelestia/notes.jsonl
set -euo pipefail

NOTES_FILE="${NOTES_FILE:-$HOME/.local/state/caelestia/notes.jsonl}"

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") <note text>" >&2
    exit 1
fi

mkdir -p "$(dirname "$NOTES_FILE")"

# Same lock as toggle/set_type/processor: appends must not race with rewrites.
LOCK_FILE="$NOTES_FILE.lock"
exec 9>"$LOCK_FILE"
flock -w 10 9

# python3 builds the JSON so text with quotes/newlines/unicode is escaped safely
python3 -c '
import json
import sys
import uuid
from datetime import datetime

note = {
    "id": uuid.uuid4().hex[:8],
    "raw": sys.argv[1],
    "status": "open",
    "created_at": datetime.now().isoformat(timespec="seconds"),
}
with open(sys.argv[2], "a", encoding="utf-8") as f:
    f.write(json.dumps(note, ensure_ascii=False) + "\n")
print(note["id"])
' "$1" "$NOTES_FILE"
