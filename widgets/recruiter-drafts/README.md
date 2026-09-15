# recruiter-drafts

Paste a job posting, press a key, get a ready-to-send application email **as a Gmail draft** — a short, concrete pitch written by DeepSeek Harness from the candidate's real profile and skills, with the CV attached and the HTML signature included.

## What it does

- `capture.qml` (**Super+H**) opens a floating Quickshell window: a multiline area for the job posting, an optional "To" override, and a **Generar borrador** button (`Ctrl+Enter`).
- `draft_from_job.sh` persists the posting, then runs **one headless DeepSeek Harness session** (`dsh --profile recruiter`) with `src/prompt.md` + the structured profile + the posting, and requires a single JSON object: `{to, subject, body, lang, company, role}`.
  - The `recruiter` profile mounts the **memory MCP read-only**, so the model pulls the candidate's full professional profile from the vault before writing.
  - The draft is deliberately **short** (80–130 words, at most 2 bullets). When the posting asks for something the profile does not have, the model names the closest tool or architecture it does have and says the experience transfers — one sentence, never a paragraph.
- `gmail_draft.py` (python3 stdlib, no dependencies) builds the message:
  - `multipart/alternative` → `text/plain` body + `text/html` body with the HTML signature inlined;
  - the CV PDF as an attachment, renamed for the recruiter;
  - the message is written to an `.eml` backup **and** appended to the Gmail Drafts mailbox over IMAPS with an app password.
- Nothing is ever sent: the unit has no SMTP path. You open Gmail, review the draft, and send it yourself.
- The window stays open while the model runs (a counter shows the elapsed seconds) and refuses to close mid-run, so an accidental `Esc` cannot kill a draft. A desktop notification reports the outcome either way.

## Architecture

```
capture.qml (Super+H)
      |
      v argv: --text <posting> [--to <override>]
draft_from_job.sh
      +-- $STATE_DIR/jobs/<ts>.txt          posting persisted BEFORE the model call
      +-- dsh --profile recruiter <payload>  prompt.md + profile.yaml + posting
      |        +-- mcp__memory__get_profile  vault profile (read-only)
      |        +-- $STATE_DIR/raw-<ts>.txt   raw model output
      v stdin: LLM JSON
gmail_draft.py
      +-- $STATE_DIR/<date>-<company>-<role>.eml    always written
      v IMAP APPEND (\Draft)
Gmail > Drafts   (review + send by hand)
```

## LLM profile

The model is not configured in this unit: it lives in a dsh profile (default `recruiter`) under `$DSH_HOME/profiles/`. Model: `deepseek-official / deepseek-flash` (**DeepSeek-V41-Flash**) with `reasoningEffort: low`. Recreate it after a format:

```sh
cd ~/Private/deepseek-harness
pnpm dsh --profile recruiter --from-default-profile headless --dump-config   # create (no boot)
pnpm dsh plugin --profile recruiter add ~/Private/Projects/dsh-memory-vault/packages/memory-mcp
cat > ~/.dsh/profiles/recruiter/cordis.patch.yml <<'YML'
- id: memory-mcp
  config:
    serverName: memory
    transport: stdio
    command: uv
    args: [run, --directory, /home/hiro03/Private/Projects/dsh-memory-vault/memory-vault-server, python, server.py]
    cwd: /home/hiro03/Private/Projects/dsh-memory-vault/memory-vault-server
    env:
      MEMORY_PATH: /home/hiro03/.memories
      UV_CACHE_DIR: /tmp/uv-cache
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
    reasoningEffort: low
YML
```

Check it without the widget:

```sh
cd ~/Private/deepseek-harness
node --import tsx/esm apps/cli/src/bin.ts --profile recruiter "Responde exactamente: OK"
```

The unit calls exactly that command (`DSH_ROOT` + `DSH_PROFILE` in `env.conf`); the invoking directory is the harness checkout, which is also the session workspace.

## Prerequisites

| Need | Why |
|---|---|
| `quickshell` (`qs`) | the capture popup |
| `node` | runs the dsh launcher (`/usr/bin/node`; Hyprland's PATH has no pnpm) |
| a DeepSeek Harness checkout + the `recruiter` profile | the LLM call (see *LLM profile*) |
| the memory MCP with the vault | the model reads the professional profile read-only |
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
# IMAP OK as luis.m.paz.03@gmail.com; drafts mailbox: [Gmail]/Borradores
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
3. Wait ~20–40 s (a memory lookup adds a round trip). The notification says which draft was created; the popup closes on success and shows the error in place on failure.
4. Open Gmail → Drafts, review, send.

Command line, for re-runs and debugging:

```sh
src/draft_from_job.sh --job aviso.md                 # full run (model + Gmail draft)
src/draft_from_job.sh --text "..." --to rrhh@x.com   # explicit recipient wins
src/draft_from_job.sh --job aviso.md --lang en       # force the email language
src/draft_from_job.sh --job aviso.md --dry-run       # build the .eml, no IMAP
src/draft_from_job.sh --job aviso.md --json llm.json --dry-run   # no model either (canned response)
```

Handy while tuning the prompt: `~/.local/state/acw/recruiter-drafts/raw-<ts>.txt` holds the raw model answer of every real run.

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
| `DSH_ROOT` | `~/Private/deepseek-harness` |
| `DSH_PROFILE` | `recruiter` |
| `LLM_TIMEOUT` | `180` (seconds; the whole dsh run) |
| `MAX_JOB_CHARS` | `20000` (longer postings are truncated, with a warning) |

State kept under `$STATE_DIR`:

| Path | Content |
|---|---|
| `jobs/<ts>.txt` | every posting as submitted (written before the model call) |
| `raw-<ts>.txt` | raw model output (kept for every real run) |
| `<date>-<company>-<role>.eml` | every generated message |
| `raw-<ts>.txt.err` | dsh stderr (reasoning + errors) when the run fails |

## Remove

```sh
./install.sh --remove   # deletes ~/.config/acw/recruiter-drafts (app password included)
```

`$STATE_DIR` (postings, raw outputs, `.eml` files) is not touched — delete it by hand if you want it gone. The keybind lives in your Hyprland config and must be removed there; the dsh profile stays under `~/.dsh/profiles/recruiter`.

## Smoke test

```sh
test/smoke.sh   # canned LLM response, no network, no credentials; asserts on the .eml
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `DeepSeek Harness not found at ...` | `DSH_ROOT` points at the wrong checkout; fix it in `env.conf`. |
| `dsh run failed (profile recruiter, 180s)` | Read the tail printed in the notification and `$STATE_DIR/raw-*.txt.err`. The profile may be missing (`dsh --profile recruiter --dump-config`), the vault MCP may fail to start (`uv` missing), or the model call timed out. |
| Draft comes out long | The prompt sets the budget; if the model ignores it the notification carries `body is long (N chars)`. Tighten `src/prompt.md` (installed copy) and re-run. |
| Draft mentions a skill the candidate does not have | The prompt forbids claiming missing skills; check the installed `prompt.md` was not replaced by an older copy (`./install.sh` refreshes it). |
| `IMAP login failed: [AUTHENTICATIONFAILED]` | Wrong/expired app password, or 2FA is off. Generate a new one and rewrite the password file (mode `600`). |
| `IMAP login failed: ... IMAP access is disabled` | Enable IMAP in Gmail settings. |
| `app password file ... is mode 644` | `chmod 600 <file>` — the helper refuses a group/world-readable secret. |
| `cannot append to any drafts mailbox` | The account's Drafts folder is not reachable; run `--check` and compare the reported mailbox with Gmail's folder list. |
| `the model returned no JSON object` | The model answered prose; the raw output is under `$STATE_DIR/raw-*.txt`. Re-run with the same posting (`jobs/<ts>.txt`). |
| `no recipient detected` warning | The posting had no usable address: the draft is created with an empty **To**, fill it in Gmail, or use the popup's **Para** field. |
| Notification says the CV or signature is missing | Fix `CV_FILE` / `SIGNATURE_FILE`; the draft is still created without that part. |
| Popup does not open | `qs` not installed, or the keybind was not added (see Keybinds). Check `qs -p ~/.config/acw/recruiter-drafts/src/capture.qml` in a terminal. |
