#!/usr/bin/env bash
# Idempotent offset-based processor for the caelestia notes store.
#
# Triggered by acw-task-notes.path on every write to the notes JSONL.
# New (or previously failed) lines are classified via `opencode run` with a
# strict-JSON prompt and rewritten in place with title/type (or an error field).
# The processed offset is persisted in $INSTALL_ROOT/.state, so the re-trigger
# caused by our own rewrite of the file is a no-op.
#
# --retry: ignore the offset and reprocess every line that still needs work
# (errored or not yet enriched). Enriched lines are skipped without an LLM call.
set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.config/acw/task-notes}"
if [ -f "$INSTALL_ROOT/env.conf" ]; then
    # shellcheck source=/dev/null
    . "$INSTALL_ROOT/env.conf"
fi
NOTES_FILE="${NOTES_FILE:-$HOME/.local/state/caelestia/notes.jsonl}"
MODEL="${MODEL:-opencode-go/deepseek-v4-flash}"
STATE_FILE="$INSTALL_ROOT/.state"

# systemd user units run with a minimal PATH; opencode usually lives in ~/.opencode/bin.
if ! command -v opencode >/dev/null 2>&1 && [ -x "$HOME/.opencode/bin/opencode" ]; then
    export PATH="$HOME/.opencode/bin:$PATH"
fi

RETRY=0
if [ "${1:-}" = "--retry" ]; then
    RETRY=1
fi

[ -f "$NOTES_FILE" ] || exit 0
mkdir -p "$INSTALL_ROOT"

OFFSET=0
if [ -f "$STATE_FILE" ]; then
    OFFSET="$(cat "$STATE_FILE")"
fi

export ACW_NOTES_FILE="$NOTES_FILE" ACW_STATE_FILE="$STATE_FILE" \
       ACW_OFFSET="$OFFSET" ACW_MODEL="$MODEL" ACW_RETRY="$RETRY"

python3 - <<'PY'
import datetime
import json
import os
import subprocess
import sys
import tempfile

NOTES_FILE = os.environ["ACW_NOTES_FILE"]
STATE_FILE = os.environ["ACW_STATE_FILE"]
MODEL = os.environ["ACW_MODEL"]
OFFSET = int(os.environ["ACW_OFFSET"])
RETRY = os.environ["ACW_RETRY"] == "1"

VALID_TYPES = {"task", "idea", "thought"}
VALID_PRIORITIES = {"low", "medium", "high"}
PROMPT = (
    'Classify the following note for a personal task manager. Reply with ONLY '
    'a JSON object with exactly these fields: "title" (short title, max 8 words), '
    '"type" (one of: task, idea, thought), "priority" (one of: low, medium, high), '
    '"tags" (array of 2-4 short lowercase keywords), "due" (ISO-8601 date YYYY-MM-DD '
    'or null — only if the note implies a deadline or time constraint, otherwise null). '
    'Definitions: task = something to do or fix; idea = a possibility, question, or '
    'spontaneous thought to explore later; thought = a general observation or note with '
    'no action implied. Examples: "comprar leche y pan" -> {"title": "Buy milk and bread", '
    '"type": "task", "priority": "medium", "tags": ["shopping"], "due": null}; '
    '"llamar al dentista manana" -> {"title": "Call dentist", "type": "task", '
    '"priority": "high", "tags": ["health"], "due": "2026-08-15"}; '
    '"que pasaria si migramos a postgres" -> {"title": "Consider migrating to postgres", '
    '"type": "idea", "priority": "low", "tags": ["database"], "due": null}. '
    'No markdown, no explanation, no extra text. Raw note: '
)


def clean_tags(tags):
    """Normalize to a deduped list of up to 4 short lowercase strings; [] on junk."""
    if not isinstance(tags, list):
        return []
    cleaned = []
    for t in tags:
        if isinstance(t, str):
            t = t.strip().lower()
            if t and t not in cleaned:
                cleaned.append(t)
    return cleaned[:4]


def clean_due(due):
    """Return the due date as YYYY-MM-DD if valid, else None."""
    if not isinstance(due, str):
        return None
    due = due.strip()
    try:
        datetime.date.fromisoformat(due)
    except ValueError:
        return None
    return due


def classify(raw):
    """Run the LLM. Returns (fields dict, None) on success, (None, error_msg) on failure."""
    try:
        proc = subprocess.run(
            ["opencode", "run", "-m", MODEL, PROMPT + raw],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except FileNotFoundError:
        return None, "opencode not installed"
    except subprocess.TimeoutExpired:
        return None, "opencode timeout (60s)"
    if proc.returncode != 0:
        msg = "opencode failed"
        err = (proc.stderr or "").strip().splitlines()
        if err:
            msg += ": " + err[-1][:60]
        return None, msg
    out = proc.stdout.strip()
    # Tolerate markdown fences / trailing noise: full parse, then brace-substring.
    try:
        obj = json.loads(out)
    except json.JSONDecodeError:
        try:
            obj = json.loads(out[out.index("{"):out.rindex("}") + 1])
        except (ValueError, json.JSONDecodeError):
            return None, "invalid LLM JSON"
    title = obj.get("title")
    ntype = obj.get("type")
    if not isinstance(title, str) or not title.strip():
        return None, "missing title"
    if ntype not in VALID_TYPES:
        return None, "invalid type: %s" % (ntype,)
    words = title.strip().split()
    if len(words) > 8:
        title = " ".join(words[:8])
    # priority/tags/due are tolerated: bad values fall back to defaults, not errors.
    priority = obj.get("priority", "medium")
    if priority not in VALID_PRIORITIES:
        priority = "medium"
    fields = {
        "title": title,
        "type": ntype,
        "priority": priority,
        "tags": clean_tags(obj.get("tags")),
        "due": clean_due(obj.get("due")),
    }
    return fields, None


def main():
    try:
        with open(NOTES_FILE, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        print("notes file unreadable: %s" % NOTES_FILE)
        return

    lines = text.splitlines()
    total = len(lines)
    start = 0 if RETRY else min(OFFSET, total)

    new_offset = start
    changed = False
    processed = 0

    for i in range(start, total):
        line = lines[i].strip()
        if not line:
            new_offset = i + 1
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            break  # partial append in flight; wait for it to complete
        if rec.get("title") and rec.get("type") in VALID_TYPES and not rec.get("error"):
            new_offset = i + 1  # already enriched; skip without an LLM call
            continue
        fields, err = classify(rec.get("raw", ""))
        if fields is not None:
            rec.update(fields)
            rec["error"] = None
            print("processed %s: %s (%s)" % (rec.get("id", "?"), fields["title"], fields["type"]))
        else:
            rec["error"] = err
            print("failed %s: %s" % (rec.get("id", "?"), err))
        lines[i] = json.dumps(rec, ensure_ascii=False)
        new_offset = i + 1
        changed = True
        processed += 1

    if changed:
        # Rewrite in place preserving the line count (offset contract).
        payload = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(NOTES_FILE), text=True)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(payload)
        os.replace(tmp, NOTES_FILE)

    # Advance the offset atomically — also on failure, so a failing line is not
    # retried on every trigger (manual retry: process_notes.sh --retry).
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(STATE_FILE), text=True)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(str(new_offset))
    os.replace(tmp, STATE_FILE)

    if processed:
        print("processed %d note(s), offset %d -> %d" % (processed, start, new_offset))


if __name__ == "__main__":
    main()
PY
