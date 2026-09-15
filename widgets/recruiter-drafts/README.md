# recruiter-drafts

Paste a job posting, press a key, get a ready-to-send application email **as a Gmail draft** — written by the configured LLM from the candidate profile, with the CV attached and the HTML signature included.

## What it does

- `capture.qml` (**Super+H**) opens a floating Quickshell window: a multiline area for the job posting, an optional "To" override, and a **Generar borrador** button (`Ctrl+Enter`).
- `draft_from_job.sh` persists the posting, then calls the user's opencode CLI **once** (`opencode run --pure -m <MODEL>`) with `src/prompt.md` + the candidate profile + the posting, and requires a single JSON object: `{to, subject, body, lang, company, role}`.
- `gmail_draft.py` (python3 stdlib, no dependencies) builds the message:
  - `multipart/alternative` → `text/plain` body + `text/html` body with the HTML signature inlined;
  - the CV PDF as an attachment, renamed for the recruiter;
  - the message is written to an `.eml` backup **and** appended to the Gmail Drafts mailbox over IMAPS with an app password.
- Nothing is ever sent: the unit has no SMTP path. You open Gmail, review the draft, and send it yourself.
- The window stays open while the LLM runs (a counter shows the elapsed seconds) and refuses to close mid-run, so an accidental `Esc` cannot kill a draft. A desktop notification reports the outcome either way.

## Architecture

```
capture.qml (Super+H)
      |
      v argv: --text <posting> [--to <override>]
draft_from_job.sh
      +-- $STATE_DIR/jobs/<ts>.txt          posting persisted BEFORE the LLM call
      +-- opencode run --pure -m $MODEL     prompt.md + profile.yaml + posting
      |        +-- $STATE_DIR/raw-<ts>.txt  raw model output
      v stdin: LLM JSON
gmail_draft.py
      +-- $STATE_DIR/<date>-<company>-<role>.eml    always written
      v IMAP APPEND (\Draft)
Gmail > Drafts   (review + send by hand)
```

## Prerequisites

| Need | Why |
|---|---|
| `quickshell` (`qs`) | the capture popup |
| `opencode` | the LLM call; `MODEL` must be an id printed by `opencode models` |
| `python3` | the message builder (stdlib only) |
| `libnotify` (`notify-send`) | success/failure notifications |
| Gmail **2-Step Verification** + an **app password** | IMAP login (a normal password is rejected) |
| Gmail **IMAP access** enabled | Settings → Forwarding and POP/IMAP → Enable IMAP |
| A candidate profile YAML, a CV PDF, an HTML signature | content sources, configurable paths |

## Install

```sh
./install.sh          # copies scripts + env.conf into ~/.config/acw/recruiter-drafts/
./install.sh --remove # removes the install root (including the app password), leaving no trace
```

`install.sh` copies files idempotently (backing up anything it overwrites as `<target>.bak-<timestamp>`), then asks for the Gmail app password with hidden input and stores it at `~/.config/acw/recruiter-drafts/gmail-app-password` with mode `600`. In a non-interactive shell pass it in the environment instead:

```sh
GMAIL_APP_PASSWORD='xxxx xxxx xxxx xxxx' ./install.sh
```

Create the app password at <https://myaccount.google.com/apppasswords> (16 characters; requires 2FA). The password is never printed, never passed through argv, and lives outside this repository.

Verify the account before using the popup:

```sh
~/.config/acw/recruiter-drafts/src/draft_from_job.sh --check
# IMAP OK as luis.m.paz.03@gmail.com; drafts mailbox: [Gmail]/Drafts
```

## Keybinds

None auto-applied: the installer never touches your Hyprland config (check `docs/keybinds-map.md` first). Add it to `~/.config/hypr/custom/keybinds.lua`:

```lua
hl.bind("SUPER" .. " + " .. "H", hl.dsp.exec_cmd("qs -p ~/.config/acw/recruiter-drafts/src/capture.qml"))
```

Hyprland 0.56 runs the Lua config (`configProvider: lua`); the `.conf` twins are legacy mirrors, so a `bind = SUPER, H, ...` line added there does nothing. Reload with `hyprctl reload`; `hyprctl binds -j` should then list `modmask 64 / key H`.

## Usage

1. Copy the whole posting (including the address it says to apply to).
2. `Super+H`, paste, optionally fill **Para**, then click **Generar borrador** or press `Ctrl+Enter`.
3. Wait ~30–60 s. The notification says which draft was created; the popup closes on success and shows the error in place on failure.
4. Open Gmail → Drafts, review, send.

Command line, for re-runs and debugging:

```sh
src/draft_from_job.sh --job aviso.md                 # full run (LLM + Gmail draft)
src/draft_from_job.sh --text "..." --to rrhh@x.com   # explicit recipient wins
src/draft_from_job.sh --job aviso.md --lang en       # force the email language
src/draft_from_job.sh --job aviso.md --dry-run       # build the .eml, no IMAP
src/draft_from_job.sh --job aviso.md --json llm.json --dry-run   # no LLM either (canned response)
```

## Config

`env.conf` at the install root (`~/.config/acw/recruiter-drafts/env.conf`); every value is overridable per-invocation through the environment.

| Var | Default |
|---|---|
| `INSTALL_ROOT` | `~/.config/acw/recruiter-drafts` |
| `GMAIL_USER` | `luis.m.paz.03@gmail.com` |
| `GMAIL_FROM_NAME` | `Luis Meyehen Paz` |
| `GMAIL_APP_PASSWORD_FILE` | `$INSTALL_ROOT/gmail-app-password` |
| `PROFILE_FILE` | `~/Private/Projects/MyCv/assets/profile.yaml` |
| `CV_FILE` | `~/Private/Projects/MyCv/assets/cv.pdf` |
| `CV_NAME` | `Luis Meyehen Paz - CV.pdf` |
| `SIGNATURE_FILE` | `~/Private/Projects/MyCv/outputs/signature/signature.html` |
| `PROMPT_FILE` | `$INSTALL_ROOT/src/prompt.md` |
| `STATE_DIR` | `~/.local/state/acw/recruiter-drafts` |
| `MODEL` | `opencode/muse-spark-1.2-contributor-free` |
| `MAX_JOB_CHARS` | `20000` (longer postings are truncated, with a warning) |

State kept under `$STATE_DIR`:

| Path | Content |
|---|---|
| `jobs/<ts>.txt` | every posting as submitted (written before the LLM call) |
| `raw-<ts>.txt` | raw model output (kept for every real LLM run) |
| `<date>-<company>-<role>.eml` | every generated message |
| `raw-<ts>.txt.err` | opencode stderr when the call fails |

## Remove

```sh
./install.sh --remove   # deletes ~/.config/acw/recruiter-drafts (app password included)
```

`$STATE_DIR` (postings, raw outputs, `.eml` files) is not touched — delete it by hand if you want it gone. The keybind lives in your Hyprland config and must be removed there.

## Smoke test

```sh
test/smoke.sh   # canned LLM response, no network, no credentials; asserts on the .eml
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Stuck on "Generando borrador..." for minutes | opencode scans its working directory as the project, and a popup launched from the keybind inherits `cwd=$HOME`. The script runs the model in an empty `$STATE_DIR/run` instead — if it still stalls, check the last `directory=` in `~/.local/share/opencode/log/opencode.log`. The call is capped at 180 s, after which the popup shows the error. |
| `IMAP login failed: [AUTHENTICATIONFAILED]` | Wrong/expired app password, or 2FA is off. Generate a new one and rewrite the password file (mode `600`). |
| `IMAP login failed: ... IMAP access is disabled` | Enable IMAP in Gmail settings. |
| `app password file ... is mode 644` | `chmod 600 <file>` — the helper refuses a group/world-readable secret. |
| `cannot append to any drafts mailbox` | The account's Drafts folder is not reachable; run `--check` and compare the reported mailbox with Gmail's folder list. |
| `opencode failed with model ...` | The model id does not exist: check `opencode models` and set `MODEL` in `env.conf`. |
| `the model returned no JSON object` | Model misbehaving; the raw output is under `$STATE_DIR/raw-*.txt`. Re-run with the same posting (`jobs/<ts>.txt`). |
| `no recipient detected` warning | The posting had no usable address: the draft is created with an empty **To**, fill it in Gmail, or use the popup's **Para** field. |
| Notification says the CV or signature is missing | Fix `CV_FILE` / `SIGNATURE_FILE`; the draft is still created without that part. |
| Popup does not open | `qs` not installed, or the keybind was not added (see Keybinds). Check `qs -p ~/.config/acw/recruiter-drafts/src/capture.qml` in a terminal. |
