#!/usr/bin/env bash
# Smallest runnable check for recruiter-drafts: runs the whole pipeline with a
# canned LLM response and no IMAP, then asserts on the generated .eml.
# Hermetic: no network, no credentials, no dependency on the MyCv files.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="$(dirname "$HERE")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf '%%PDF-1.4\nfixture\n' > "$TMP/cv.pdf"
cat > "$TMP/signature.html" <<'HTML'
<html><body><table id="fixture-signature"><tr><td>Smoke</td></tr></table></body></html>
HTML

INSTALL_ROOT="$TMP/install" \
GMAIL_USER="smoke@example.com" \
GMAIL_FROM_NAME="Smoke Test" \
CV_FILE="$TMP/cv.pdf" \
CV_NAME="Smoke CV.pdf" \
SIGNATURE_FILE="$TMP/signature.html" \
PROFILE_FILE="$HERE/fixtures/profile.yaml" \
PROMPT_FILE="$UNIT/src/prompt.md" \
STATE_DIR="$TMP/state" \
    "$UNIT/src/draft_from_job.sh" --job "$HERE/fixtures/job.md" --json "$HERE/fixtures/llm.json" --dry-run

EML="$(find "$TMP/state" -maxdepth 1 -name '*.eml' -print -quit)"
[ -n "$EML" ] || { echo "FAIL: no .eml written" >&2; exit 1; }

python3 - "$EML" <<'PY'
import sys
from email import policy
from email.parser import BytesParser


def check(condition, label):
    if not condition:
        sys.exit("FAIL: " + label)


with open(sys.argv[1], "rb") as fh:
    msg = BytesParser(policy=policy.default).parse(fh)

check(msg["To"] == "rrhh@empresa.com", "To header: %r" % msg["To"])
check(bool(str(msg["Subject"]).strip()), "Subject header")
check(msg["From"] == "Smoke Test <smoke@example.com>", "From header: %r" % msg["From"])
check(msg.get_content_type() == "multipart/mixed", "root content type: %s" % msg.get_content_type())

parts = list(msg.iter_parts())
alternative = [p for p in parts if p.get_content_type() == "multipart/alternative"]
attachments = [p for p in parts if p.get_content_type() == "application/pdf"]
check(len(alternative) == 1, "expected one multipart/alternative part")
check(len(attachments) == 1, "expected one PDF attachment")
check(attachments[0].get_filename() == "Smoke CV.pdf", "attachment filename: %r" % attachments[0].get_filename())
check(attachments[0].get_payload(decode=True).startswith(b"%PDF"), "attachment payload")

alt = list(alternative[0].iter_parts())
plain = [p for p in alt if p.get_content_type() == "text/plain"]
html = [p for p in alt if p.get_content_type() == "text/html"]
check(len(plain) == 1 and len(html) == 1, "expected text/plain + text/html parts")
check("Smoke Test" in plain[0].get_content(), "plain part carries the sender name")
check('id="fixture-signature"' in html[0].get_content(), "HTML part carries the signature body")
check("<p>" in html[0].get_content(), "HTML part wraps the body in paragraphs")

print("smoke ok: %s" % sys.argv[1])
PY
