#!/usr/bin/env bash
# Draft a job-application email from a job posting and save it as a Gmail draft.
#
#   draft_from_job.sh --job aviso.md [--to mail@empresa.com] [--lang es|en]
#   draft_from_job.sh --text "texto del aviso"
#   draft_from_job.sh --check          # IMAP login + drafts mailbox discovery
#   draft_from_job.sh --job aviso.md --json llm.json --dry-run   # no LLM, no IMAP
#
# The posting is persisted before the LLM call, the raw model output is kept when
# parsing fails, and every generated message is written as an .eml under $STATE_DIR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.config/acw/recruiter-drafts}"
if [ -f "$INSTALL_ROOT/env.conf" ]; then
    # shellcheck source=/dev/null
    . "$INSTALL_ROOT/env.conf"
elif [ -f "$SCRIPT_DIR/../env.conf" ]; then
    # runnable straight from the repo, before install.sh
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/../env.conf"
fi

GMAIL_USER="${GMAIL_USER:-}"
GMAIL_FROM_NAME="${GMAIL_FROM_NAME:-}"
GMAIL_APP_PASSWORD_FILE="${GMAIL_APP_PASSWORD_FILE:-$INSTALL_ROOT/gmail-app-password}"
PROFILE_FILE="${PROFILE_FILE:-$HOME/Private/Projects/MyCv/assets/profile.yaml}"
CV_FILE="${CV_FILE:-}"
CV_NAME="${CV_NAME:-CV.pdf}"
SIGNATURE_FILE="${SIGNATURE_FILE:-}"
PROMPT_FILE="${PROMPT_FILE:-$INSTALL_ROOT/src/prompt.md}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/acw/recruiter-drafts}"
MODEL="${MODEL:-opencode/muse-spark-1.2-contributor-free}"
HELPER="$SCRIPT_DIR/gmail_draft.py"
# ponytail: fixed cut, raise it only if a legitimate posting ever hits it.
MAX_JOB_CHARS="${MAX_JOB_CHARS:-20000}"

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    local urgency="$1" title="$2" body="$3"
    notify-send -a recruiter-drafts -u "$urgency" -i mail-message-new "$title" "$body" || true
}

die() {
    printf 'error: %s\n' "$1" >&2
    notify critical "No se pudo crear el borrador" "$1"
    exit "${2:-1}"
}

JOB_TEXT=""
JOB_FILE=""
TO_OVERRIDE=""
LANG_HINT=""
LLM_JSON=""
DRY_RUN=0
CHECK=0

while [ $# -gt 0 ]; do
    case "$1" in
        --text) JOB_TEXT="${2:-}"; shift 2 ;;
        --job) JOB_FILE="${2:-}"; shift 2 ;;
        --to) TO_OVERRIDE="${2:-}"; shift 2 ;;
        --lang) LANG_HINT="${2:-}"; shift 2 ;;
        --json) LLM_JSON="${2:-}"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --check) CHECK=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) die "unknown argument: $1" 1 ;;
    esac
done

# systemd/keybind environments have a minimal PATH; opencode lives in ~/.opencode/bin.
if ! command -v opencode >/dev/null 2>&1 && [ -x "$HOME/.opencode/bin/opencode" ]; then
    export PATH="$HOME/.opencode/bin:$PATH"
fi

[ -x "$HELPER" ] || die "helper missing: $HELPER" 2
[ -n "$GMAIL_USER" ] || die "GMAIL_USER is not configured in $INSTALL_ROOT/env.conf" 2

# Resolved once, before any cd: STATE_DIR is handed to the helper as-is.
mkdir -p "$STATE_DIR"
STATE_DIR="$(cd "$STATE_DIR" && pwd)"

if [ "$CHECK" = 1 ]; then
    exec python3 "$HELPER" --user "$GMAIL_USER" --password-file "$GMAIL_APP_PASSWORD_FILE" --check
fi

# --- input -------------------------------------------------------------------
if [ -z "$JOB_TEXT" ] && [ -n "$JOB_FILE" ]; then
    [ -f "$JOB_FILE" ] || die "job posting not found: $JOB_FILE" 1
    JOB_TEXT="$(cat "$JOB_FILE")"
fi
[ -n "${JOB_TEXT//[[:space:]]/}" ] || die "no job posting given (use --text or --job)" 1

WARNINGS=""
if [ "${#JOB_TEXT}" -gt "$MAX_JOB_CHARS" ]; then
    JOB_TEXT="${JOB_TEXT:0:$MAX_JOB_CHARS}"
    WARNINGS="job posting truncated to $MAX_JOB_CHARS chars"
fi

mkdir -p "$STATE_DIR/jobs"
JOB_COPY="$STATE_DIR/jobs/$(date +%Y%m%d-%H%M%S).txt"
printf '%s\n' "$JOB_TEXT" > "$JOB_COPY"

# --- LLM ---------------------------------------------------------------------
if [ -n "$LLM_JSON" ]; then
    [ -f "$LLM_JSON" ] || die "canned LLM response not found: $LLM_JSON" 1
    LLM_RAW="$(cat "$LLM_JSON")"
else
    [ -f "$PROMPT_FILE" ] || die "prompt file missing: $PROMPT_FILE" 2
    [ -f "$PROFILE_FILE" ] || die "candidate profile missing: $PROFILE_FILE (set PROFILE_FILE in $INSTALL_ROOT/env.conf)" 2
    PROMPT="$(cat "$PROMPT_FILE")"
    PAYLOAD="$PROMPT

## CANDIDATE PROFILE
$(cat "$PROFILE_FILE")

## JOB POSTING
$JOB_TEXT"
    if [ -n "$LANG_HINT" ]; then
        PAYLOAD="$PAYLOAD

The language of this posting is: $LANG_HINT. Write the email in that language."
    fi

    RAW_OUT="$STATE_DIR/raw-$(date +%Y%m%d-%H%M%S).txt"
    ERR_OUT="$RAW_OUT.err"
    # opencode scans its working directory as the project. Launched from the
    # keybind the popup inherits cwd=$HOME, and scanning the whole home dir stalls
    # for minutes before the model is ever called. Run it in an empty dir.
    mkdir -p "$STATE_DIR/run"
    cd "$STATE_DIR/run"
    if ! LLM_RAW="$(timeout 180 opencode run --pure -m "$MODEL" "$PAYLOAD" 2>"$ERR_OUT")"; then
        tail_msg="$(sed -e 's/\x1b\[[0-9;]*m//g' "$ERR_OUT" | tr '\n' ' ' | cut -c1-300)"
        die "opencode failed with model $MODEL (${tail_msg:-no stderr}); posting kept at $JOB_COPY" 1
    fi
    printf '%s\n' "$LLM_RAW" > "$RAW_OUT"
    rm -f "$ERR_OUT"
    case "$LLM_RAW" in
        *"{"*) ;;
        *) die "the model returned no JSON object; raw output kept at $RAW_OUT" 1 ;;
    esac
fi

# --- message + draft ---------------------------------------------------------
PY_ARGS=(--user "$GMAIL_USER" --password-file "$GMAIL_APP_PASSWORD_FILE"
    --from-name "$GMAIL_FROM_NAME" --state-dir "$STATE_DIR"
    --attach "$CV_FILE" --attach-name "$CV_NAME" --signature "$SIGNATURE_FILE"
    --to-override "$TO_OVERRIDE")
if [ "$DRY_RUN" = 1 ]; then
    PY_ARGS+=(--dry-run)
fi

PY_ERR="$(mktemp)"
trap 'rm -f "$PY_ERR"' EXIT

if ! PY_OUT="$(printf '%s' "$LLM_RAW" | python3 "$HELPER" "${PY_ARGS[@]}" 2>"$PY_ERR")"; then
    PY_MSG="$(sed -e 's/\x1b\[[0-9;]*m//g' "$PY_ERR" | tr '\n' ' ' | cut -c1-300)"
    rm -f "$PY_ERR"
    trap - EXIT
    die "${PY_MSG:-the message builder failed}" 1
fi

rm -f "$PY_ERR"
trap - EXIT

SUMMARY="$(printf '%s\n' "$PY_OUT" | grep -v '^warn:' | tail -n 1)"
PY_WARN="$(printf '%s\n' "$PY_OUT" | sed -n 's/^warn: //p' | tr '\n' ' ')"
printf '%s\n' "$PY_OUT"

if [ "$DRY_RUN" = 1 ]; then
    notify normal "Borrador generado (dry-run)" "$SUMMARY"
else
    notify normal "Borrador listo en Gmail" "$SUMMARY
${PY_WARN}${WARNINGS}"
fi
