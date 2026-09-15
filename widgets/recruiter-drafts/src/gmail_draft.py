#!/usr/bin/env python3
"""Build the job-application email and save it as a Gmail draft.

stdin : the LLM JSON  {"to","subject","body","lang","company","role"}
stdout: "warn: ..." lines plus one summary line
stderr: one actionable line per failure (exit 1 generic, 2 config, 3 IMAP)

Never sends mail: the only network write is IMAP APPEND into the Drafts
mailbox. The app password is read from a 0600 file, never from argv or env.
"""

import argparse
import html
import imaplib
import json
import re
import sys
import time
from email.message import EmailMessage
from email.utils import formataddr, formatdate
from pathlib import Path

IMAP_HOST = "imap.gmail.com"
IMAP_PORT = 993
DRAFTS_FALLBACKS = ("[Gmail]/Drafts", "[Gmail]/Borradores", "Drafts")
EMAIL_RE = re.compile(r"^[^@\s,;<>]+@[^@\s,;<>]+\.[^@\s,;<>]+$")
MBOX_RE = re.compile(r'"([^"]*)"\s*$')


def die(message, code=1):
    print(message, file=sys.stderr)
    raise SystemExit(code)


def flat(err, limit=200):
    """One short line, no credentials, no multi-line dumps."""
    text = err.decode("utf-8", "replace") if isinstance(err, bytes) else str(err)
    return " ".join(text.split())[:limit]


def read_password(path):
    p = Path(path)
    if not p.is_file():
        die(
            "app password file not found: %s\n"
            "  create one (2FA required) at https://myaccount.google.com/apppasswords then:\n"
            "  printf '%%s' '<app-password>' > %s && chmod 600 %s" % (path, path, path),
            2,
        )
    mode = p.stat().st_mode & 0o777
    if mode & 0o077:
        die("app password file %s is mode %03o; run: chmod 600 %s" % (path, mode, path), 2)
    password = p.read_text(encoding="utf-8").replace(" ", "").strip()
    if not password:
        die("app password file %s is empty" % path, 2)
    return password


def valid_email(value):
    return value.strip() if isinstance(value, str) and EMAIL_RE.match(value.strip()) else ""


def paragraphs(body):
    return [p.strip() for p in re.split(r"\n\s*\n", body) if p.strip()]


def html_body(body):
    out = []
    for para in paragraphs(body):
        lines = "<br>".join(html.escape(line) for line in para.splitlines())
        out.append("<p>%s</p>" % lines)
    return "\n".join(out)


def inner_body(path):
    """The signature file is a full HTML document: keep only its <body> content."""
    p = Path(path) if path else None
    if not p or not p.is_file():
        return ""
    raw = p.read_text(encoding="utf-8")
    match = re.search(r"<body[^>]*>(.*)</body>", raw, re.S | re.I)
    return (match.group(1) if match else raw).strip()


def build_message(args, data):
    warnings = []
    to = valid_email(args.to_override) or valid_email(data.get("to"))
    if not to:
        warnings.append("warn: no recipient detected; the draft has an empty To")
    subject = (data.get("subject") or "").strip() if isinstance(data.get("subject"), str) else ""
    body = (data.get("body") or "").strip() if isinstance(data.get("body"), str) else ""
    if not subject:
        die("the LLM returned no subject")
    if not body:
        die("the LLM returned no body")

    msg = EmailMessage()
    msg["From"] = formataddr((args.from_name, args.user)) if args.from_name else args.user
    if to:
        msg["To"] = to
    msg["Subject"] = subject
    msg["Date"] = formatdate(localtime=True)

    plain = body + "\n\n"
    if args.from_name:
        plain += args.from_name + "\n"
    plain += args.user
    msg.set_content(plain)

    signature = inner_body(args.signature)
    if not signature and args.signature:
        warnings.append("warn: signature file missing (%s); HTML part omitted" % args.signature)
    if signature:
        msg.add_alternative(html_body(body) + "\n" + signature, subtype="html")

    if args.attach:
        cv = Path(args.attach)
        if cv.is_file():
            subtype = cv.suffix.lstrip(".").lower() or "pdf"
            msg.add_attachment(
                cv.read_bytes(),
                maintype="application",
                subtype=subtype,
                filename=args.attach_name or cv.name,
            )
        else:
            warnings.append("warn: CV not found (%s); draft has no attachment" % args.attach)

    return msg, to, subject, warnings


def mailbox_name(line):
    match = MBOX_RE.search(line)
    return match.group(1) if match else line.strip().strip('"')


def drafts_candidates(imap):
    """\\Drafts attribute first (folder names are localized), then name fallbacks."""
    names = []
    try:
        typ, boxes = imap.list()
    except imaplib.IMAP4.error:
        boxes, typ = [], "NO"
    for raw in boxes or []:
        line = raw.decode("utf-8", "replace") if isinstance(raw, bytes) else str(raw)
        if "\\Drafts" in line:
            names.append(mailbox_name(line))
    for name in DRAFTS_FALLBACKS:
        if name not in names:
            names.append(name)
    return names


def connect(args):
    password = read_password(args.password_file)
    try:
        imap = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT)
        imap.login(args.user, password)
    except imaplib.IMAP4.error as err:
        die(
            "IMAP login failed: %s\n"
            "  check the app password (2-Step Verification required) and that IMAP access is\n"
            "  enabled in Gmail: Settings > Forwarding and POP/IMAP > Enable IMAP" % flat(err),
            3,
        )
    except OSError as err:
        die("cannot reach %s:%s: %s" % (IMAP_HOST, IMAP_PORT, flat(err)), 3)
    return imap


def append_draft(imap, raw):
    last = ""
    for name in drafts_candidates(imap):
        try:
            typ, _ = imap.append(
                '"%s"' % name, "(\\Draft)", imaplib.Time2Internaldate(time.time()), raw
            )
        except imaplib.IMAP4.error as err:
            last = flat(err)
            continue
        if typ == "OK":
            return name
        last = "server answered %s" % typ
    die("cannot append to any drafts mailbox: %s" % (last or "unknown error"), 3)


def default_eml(state_dir, data):
    def slug(value, fallback):
        text = re.sub(r"[^a-z0-9]+", "-", str(value or "").lower()).strip("-")
        return text[:40] or fallback

    name = "%s-%s-%s.eml" % (
        time.strftime("%Y-%m-%d"),
        slug(data.get("company"), "empresa"),
        slug(data.get("role"), "puesto"),
    )
    return Path(state_dir) / name


def parse_args():
    p = argparse.ArgumentParser(description="Save the application email as a Gmail draft.")
    p.add_argument("--user", required=True, help="Gmail address to authenticate as")
    p.add_argument("--from-name", default="", help="display name for the From header")
    p.add_argument("--password-file", required=True)
    p.add_argument("--attach", default="", help="file to attach (the CV)")
    p.add_argument("--attach-name", default="", help="attachment filename shown to the recruiter")
    p.add_argument("--signature", default="", help="HTML signature file")
    p.add_argument("--to-override", default="", help="recipient that wins over the LLM value")
    p.add_argument("--state-dir", default=".", help="where the .eml backup is written")
    p.add_argument("--eml", default="", help="explicit .eml path")
    p.add_argument("--dry-run", action="store_true", help="build the .eml and skip IMAP")
    p.add_argument("--check", action="store_true", help="verify IMAP login and drafts mailbox")
    return p.parse_args()


def main():
    args = parse_args()

    if args.check:
        imap = connect(args)
        try:
            names = drafts_candidates(imap)
            print("IMAP OK as %s; drafts mailbox: %s" % (args.user, names[0]))
        finally:
            try:
                imap.logout()
            except (imaplib.IMAP4.error, OSError):
                pass
        return 0

    raw_in = sys.stdin.read()
    # Tolerate markdown fences or stray prose around the object.
    text = raw_in.strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError as err:
        try:
            data = json.loads(text[text.index("{"):text.rindex("}") + 1])
        except (ValueError, json.JSONDecodeError):
            die("invalid LLM JSON on stdin: %s" % flat(err))
    if not isinstance(data, dict):
        die("invalid LLM JSON on stdin: root is not an object")

    msg, to, subject, warnings = build_message(args, data)
    raw = msg.as_bytes()

    eml = Path(args.eml) if args.eml else default_eml(args.state_dir, data)
    eml.parent.mkdir(parents=True, exist_ok=True)
    eml.write_bytes(raw)

    for warning in warnings:
        print(warning)

    if args.dry_run:
        print("dry-run: wrote %s" % eml)
        return 0

    imap = connect(args)
    try:
        mailbox = append_draft(imap, raw)
    finally:
        try:
            imap.logout()
        except (imaplib.IMAP4.error, OSError):
            pass

    print(
        "draft saved to %s | to: %s | subject: %s | %.1f KB | %s"
        % (mailbox, to or "(empty)", subject, len(raw) / 1024, eml)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
