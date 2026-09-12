#!/usr/bin/env bash
# Idempotent offset-based processor for the caelestia notes store.
#
# Triggered by acw-task-notes.path on every write to the notes JSONL.
# Lines that still need work (new, errored, or all with --reclassify) are sent
# as ONE batch to `opencode run --pure` (one cold boot + one LLM call instead of
# one spawn per note) and rewritten in place with title/type (or an error field).
# The processed offset is persisted in $INSTALL_ROOT/.state, so the re-trigger
# caused by our own rewrite of the file is a no-op.
#
# --retry:      ignore the offset and reprocess every line that still needs work
#               (errored or not yet enriched). Enriched lines are skipped.
# --reclassify: like --retry but ALSO reprocess already-enriched lines (used after
#               prompt changes or to fix misclassifications). On failure the
#               previous fields are kept and only `error` is set.
set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.config/acw/task-notes}"
if [ -f "$INSTALL_ROOT/env.conf" ]; then
    # shellcheck source=/dev/null
    . "$INSTALL_ROOT/env.conf"
fi
NOTES_FILE="${NOTES_FILE:-$HOME/.local/state/caelestia/notes.jsonl}"
MODEL="${MODEL:-opencode/muse-spark-1.2-contributor-free}"
STATE_FILE="$INSTALL_ROOT/.state"

# systemd user units run with a minimal PATH; opencode usually lives in ~/.opencode/bin.
if ! command -v opencode >/dev/null 2>&1 && [ -x "$HOME/.opencode/bin/opencode" ]; then
    export PATH="$HOME/.opencode/bin:$PATH"
fi

RETRY=0
RECLASSIFY=0
for arg in "${@:-}"; do
    case "$arg" in
        --retry) RETRY=1 ;;
        --reclassify) RECLASSIFY=1 ;;
    esac
done

[ -f "$NOTES_FILE" ] || exit 0
mkdir -p "$INSTALL_ROOT"

OFFSET=0
if [ -f "$STATE_FILE" ]; then
    OFFSET="$(cat "$STATE_FILE")"
fi

# Serialize every read-modify-write of the store (capture, edit_note and this
# processor share the same lock) so concurrent rewrites cannot lose notes.
LOCK_FILE="$NOTES_FILE.lock"
exec 9>"$LOCK_FILE"
flock -w 15 9

python3 - "$NOTES_FILE" "$STATE_FILE" "$MODEL" "$OFFSET" "$RETRY" "$RECLASSIFY" <<'PY'
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile

NOTES_FILE, STATE_FILE, MODEL = sys.argv[1], sys.argv[2], sys.argv[3]
OFFSET = int(sys.argv[4])
RETRY = sys.argv[5] == "1"
RECLASSIFY = sys.argv[6] == "1"

VALID_TYPES = {"task", "idea", "thought"}
VALID_PRIORITIES = {"low", "medium", "high"}


def _tomorrow():
    return (datetime.date.today() + datetime.timedelta(days=1)).isoformat()


def _next_friday(today):
    d = datetime.date.fromisoformat(today)
    days_ahead = (4 - d.weekday()) % 7 or 7
    return (d + datetime.timedelta(days=days_ahead)).isoformat()


TODAY = datetime.date.today().isoformat()
PROMPT = (
    "Today is %s. You classify notes for a personal task manager. Reply with "
    "ONLY a JSON array (no markdown, no explanation, no extra text) with exactly "
    'one object per input note, echoing its "id", each object with exactly these '
    'fields: "id", "title" (short title, max 8 words, in the SAME language as '
    'the note; start tasks with a verb), "type" (one of: task, idea, thought), '
    '"priority" (one of: low, medium, high), "tags" (array of 2-4 short lowercase '
    'keywords, reusing domain words present in the note such as galicia, ibk, '
    'pipeline, blog), "due" (ISO-8601 date YYYY-MM-DD or null).\n'
    "Type rules: task = something to do or fix (an action, instruction, "
    'deliverable or pending work); idea = a possibility, question or exploration '
    'to consider later ("que pasaria si", "idea:", "podriamos"); thought = an '
    "observation or note with no action implied. Prefer task when the note "
    "implies doing something.\n"
    "Important: the output MUST use the exact lowercase English tokens for the \"type\" field: 'task', 'idea', or 'thought'. Do NOT translate these tokens or substitute synonyms; follow them literally.\n"
    'Due rules: set a date ONLY when the note explicitly mentions a date, day '
    'of the week or deadline ("manana", "viernes", "antes del 20", "2026-08-30"). '
    "Otherwise null. Never guess or invent dates.\n"
    "Priority rules: high = deadline or urgency words; low = exploration, "
    '"algun dia", questions; medium otherwise.\n'
    "Examples (input -> output):\n"
    '[{"id":"e1","raw":"comprar leche y pan"},{"id":"e2","raw":"llamar al dentista manana"},'
    '{"id":"e3","raw":"que pasaria si migramos a postgres"},'
    '{"id":"e4","raw":"Galicia: armar hojas opera antes del viernes"}] ->\n'
    '[{"id":"e1","title":"Comprar leche y pan","type":"task","priority":"medium","tags":["compras"],"due":null},'
    '{"id":"e2","title":"Llamar al dentista","type":"task","priority":"high","tags":["salud"],"due":"%s"},'
    '{"id":"e3","title":"Migrar a postgres","type":"idea","priority":"low","tags":["database"],"due":null},'
    '{"id":"e4","title":"Armar hojas opera","type":"task","priority":"high","tags":["galicia","opera"],"due":"%s"}]\n'
    "Input notes (JSON array): "
) % (TODAY, _tomorrow(), _next_friday(TODAY))


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


def validate_fields(entry):
    """Validate one LLM entry. Returns (fields dict, None) or (None, error_msg)."""
    title = entry.get("title")
    # Tolerate casing and stray whitespace only: the prompt already demands the
    # exact tokens, and anything else becomes an error the UI can retry.
    raw_type = entry.get("type")
    ntype = raw_type.strip().lower() if isinstance(raw_type, str) else None
    if not isinstance(title, str) or not title.strip():
        return None, "missing title"
    if ntype not in VALID_TYPES:
        return None, "invalid type: %s" % (raw_type,)
    words = title.strip().split()
    if len(words) > 8:
        title = " ".join(words[:8])
    # priority/tags/due are tolerated: bad values fall back to defaults, not errors.
    priority = entry.get("priority", "medium")
    if priority not in VALID_PRIORITIES:
        priority = "medium"
    fields = {
        "title": title,
        "type": ntype,
        "priority": priority,
        "tags": clean_tags(entry.get("tags")),
        "due": clean_due(entry.get("due")),
    }
    return fields, None


def classify_batch(items):
    """Classify several notes in ONE LLM call.

    Returns {id: (fields, None)} on success or {id: (None, error_msg)} per item.
    """
    results = {}
    timeout = 120 if len(items) <= 10 else 180
    payload = PROMPT + json.dumps(items, ensure_ascii=False)
    try:
        proc = subprocess.run(
            ["opencode", "run", "--pure", "-m", MODEL, payload],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        for it in items:
            results[it["id"]] = (None, "opencode not installed")
        return results
    except subprocess.TimeoutExpired:
        for it in items:
            results[it["id"]] = (None, "opencode timeout (%ds)" % timeout)
        return results
    if proc.returncode != 0:
        # opencode pretty-prints its errors over several ANSI-coloured lines, so
        # taking the last line yields a lone "}". Collapse it into something the
        # note (and the dashboard chip) can actually show.
        flat = " ".join(re.sub(r"\x1b\[[0-9;]*m", "", proc.stderr or "").split())
        msg = "opencode failed"
        if flat:
            msg += ": " + flat[:140]
        for it in items:
            results[it["id"]] = (None, msg)
        return results
    out = proc.stdout.strip()
    # Tolerate markdown fences / trailing noise: full parse, then bracket-substring.
    try:
        obj = json.loads(out)
    except json.JSONDecodeError:
        try:
            obj = json.loads(out[out.index("["):out.rindex("]") + 1])
        except (ValueError, json.JSONDecodeError):
            for it in items:
                results[it["id"]] = (None, "invalid LLM JSON")
            return results
    by_id = {}
    if isinstance(obj, list):
        for entry in obj:
            if isinstance(entry, dict) and entry.get("id") is not None:
                by_id[str(entry["id"])] = entry
    elif isinstance(obj, dict):
        # tolerate an object keyed by id: {"a": {...}}
        by_id = {str(k): v for k, v in obj.items() if isinstance(v, dict)}
    for it in items:
        entry = by_id.get(it["id"])
        if not isinstance(entry, dict):
            results[it["id"]] = (None, "missing id in LLM output")
            continue
        fields, err = validate_fields(entry)
        results[it["id"]] = (fields, err)
    return results


def main():
    try:
        with open(NOTES_FILE, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        print("notes file unreadable: %s" % NOTES_FILE)
        return

    lines = text.splitlines()
    total = len(lines)
    start = 0 if (RETRY or RECLASSIFY) else min(OFFSET, total)

    new_offset = start
    work = []            # (index, record) needing classification
    was_enriched = {}    # index -> bool (reclassify failure keeps old fields)

    for i in range(start, total):
        line = lines[i].strip()
        if not line:
            new_offset = i + 1
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            break  # partial append in flight; wait for it to complete
        enriched = bool(
            rec.get("title") and rec.get("type") in VALID_TYPES and not rec.get("error")
        )
        if enriched and not RECLASSIFY:
            new_offset = i + 1  # already enriched; skip without an LLM call
            continue
        work.append((i, rec))
        was_enriched[i] = enriched

    if work:
        items = [
            {"id": rec.get("id", ""), "raw": rec.get("raw", "")} for _, rec in work
        ]
        results = classify_batch(items)
        processed = 0
        for i, rec in work:
            fields, err = results.get(rec.get("id", ""), (None, "missing id in LLM output"))
            if fields is not None:
                rec.update(fields)
                rec["error"] = None
                print("processed %s: %s (%s)" % (rec.get("id", "?"), fields["title"], fields["type"]))
            elif was_enriched[i]:
                # Reclassify failure: keep the previous good fields, only flag it.
                rec["error"] = err
                print("kept %s: %s" % (rec.get("id", "?"), err))
            else:
                rec["error"] = err
                print("failed %s: %s" % (rec.get("id", "?"), err))
            lines[i] = json.dumps(rec, ensure_ascii=False)
            new_offset = i + 1
            processed += 1

    if work:
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

    if work:
        print("processed %d note(s), offset %d -> %d" % (len(work), start, new_offset))


if __name__ == "__main__":
    main()
PY
