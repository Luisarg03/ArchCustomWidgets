# recruiter-drafts Specification

## Purpose
Job-application drafting for Gmail: a keybind opens a Quickshell popup where a job posting is pasted, an LLM writes a tailored application email from the candidate profile, and the result is saved as a Gmail draft (CV attached, HTML signature included) for the user to review and send. The unit never sends mail, never stores credentials in the repository, and never loses a posting or a generated message.

## Requirements
### Requirement: Capture MUST open a standalone Quickshell window

The unit MUST ship a standalone Quickshell window (`qs -p`, `src/capture.qml`) with a multiline text area for the job posting and an optional recipient override field. The keybind that opens it MUST be documented in the README and MUST NOT be auto-applied by the installer. Submitting MUST hand the work to a detached process and close the window immediately: the unit MUST NOT keep a progress UI open, MUST NOT block closing while the run proceeds, and MUST quit the process (not only hide the window) when it closes. The outcome MUST be reported by desktop notification only.

#### Scenario: Job posting submitted

- Given the unit installed and the keybind mapped
- When the user pastes a job posting and submits
- Then the window closes at once and the drafting pipeline keeps running in the background

#### Scenario: Escape does not cancel the run

- Given a run started from the popup
- When the user presses Escape or closes the window
- Then the run continues and still reports by notification

#### Scenario: Keybind documented, not auto-applied

- Given a fresh install
- When the installer finishes
- Then no keybind was written to any Hyprland config, and the README documents the combo to add manually

### Requirement: The email MUST be drafted by DeepSeek Harness from the candidate profile

The unit MUST call a DeepSeek Harness headless profile (`dsh --profile <name> <payload>`, one fresh session per submission) with a prompt (`src/prompt.md`) that carries the candidate profile file and the job posting, and MUST require a single JSON object with keys `to`, `subject`, `body`, `lang`, `company`, `role`. The profile MUST run `deepseek-official / deepseek-flash` with `reasoningEffort: low` and MUST mount the memory MCP read-only, and the prompt MUST instruct the model to read the candidate's profile from that MCP before writing and never to write to memory. The prompt MUST also cap the draft at 80-130 words with at most two bullet lines, and MUST instruct the model to answer a requirement it cannot evidence with ONE short sentence naming the closest tool or architecture the profile does have. The prompt MUST require the email to be written in the candidate's voice: first person, short declarative sentences, no filler or buzzwords, no exclamation marks, no emoji, correct spelling and accents, a formal rioplatense register (usted, never vos), technical names kept in English, and no signature block. It MUST fix the opening line — `Hola <nombre>, espero que se encuentre bien.` when the posting names a contact, `Hola, espero que se encuentren bien.` when it does not — and the closing line `Quedo atento, saludos.` (English equivalents), allowing no other variant. It MUST keep the honesty gate: no invented metrics, no experience the profile does not show, no employer-internal names or brands. The subject MUST follow `Postulación - <role> - <company>` in Spanish and `Application - <role> - <company>` in English. `DSH_ROOT`, the profile name, the profile path and the prompt path MUST be configurable through `env.conf`.

#### Scenario: Valid LLM JSON

- Given a job posting and a reachable model
- When the pipeline runs
- Then a JSON object with a non-empty subject and body is produced and used to build the message

#### Scenario: Short, evidence-backed draft

- Given a posting asking for a technology the profile does not list
- When the draft is written
- Then the body stays within the word budget, claims no missing skill, and names the closest transferable tool in one sentence

#### Scenario: Voice of the candidate

- Given any posting
- When the draft is written
- Then the body is first person, short and declarative, carries no filler, no exclamation marks and no emoji, writes the accents, uses the formal *usted* register, opens with the fixed formal greeting and closes with `Quedo atento, saludos.` (or the English equivalent)

#### Scenario: Profile read from memory, never written

- Given a run with the memory MCP mounted
- When the model drafts the email
- Then it reads the candidate profile through the MCP and performs no memory write

#### Scenario: Invalid or failed LLM output

- Given the model returning non-JSON, invalid JSON, a non-zero exit, or exceeding `LLM_TIMEOUT` (180 s by default)
- When the pipeline runs
- Then the raw output is stored under the state dir, a critical notification names the cause and the file, and no draft is created

#### Scenario: Job posting is never lost

- Given any run that reaches the drafting stage
- When the LLM call starts
- Then the submitted posting has already been written to `<state>/jobs/<timestamp>.txt`

### Requirement: The drafted message MUST be saved as a Gmail draft over IMAP

The unit MUST build an RFC 5322 message with `From`, `To` (when a valid recipient is known), `Subject`, `Date`, a `text/plain` part, a `text/html` part carrying the HTML signature, a disclosure footer stating that an AI agent generated the message, and the CV PDF as an attachment taken from the canonical render, not a stale mirror. The footer MUST be produced by the message builder (never by the model), MUST follow the language of the email, and MUST close both MIME parts. The unit MUST `APPEND` the message to the account's Drafts mailbox over IMAPS (`imap.gmail.com:993`) using an app password. The drafts mailbox MUST be discovered through the `\Drafts` LIST attribute, with name fallbacks. The unit MUST NOT contain any SMTP or send path.

#### Scenario: Draft appears in Gmail

- Given valid credentials and a reachable IMAP server
- When the pipeline runs without `--dry-run`
- Then the message is appended to the Drafts mailbox and shows up in Gmail as a draft

#### Scenario: Localized drafts folder

- Given a Gmail account whose folders are not in English
- When the drafts mailbox is looked up
- Then it is found by the `\Drafts` attribute or by the name fallbacks

#### Scenario: Missing recipient

- Given a posting with no usable email address and no override
- When the draft is created
- Then the draft is still created without `To` and the run reports that no recipient was detected

#### Scenario: Disclosure footer

- Given any drafted message
- When the message is built
- Then `text/plain` and `text/html` both end with the AI-disclosure notice, in the language of the email, and an unknown or missing `lang` yields the Spanish notice

#### Scenario: Current CV attached

- Given a CV path in `env.conf`
- When the message is built
- Then the attachment is the file at that path, renamed for the recruiter, and a missing file only warns

#### Scenario: Degraded attachments

- Given a missing CV or signature file
- When the message is built
- Then the run warns, omits that part and still creates the draft

### Requirement: Credentials MUST stay out of the repository and out of process arguments

The Gmail app password MUST live in a `0600` file under the install root, MUST be read by the helper from that file, and MUST NOT be passed through argv, printed, or logged. The repo's `.gitignore` MUST cover the password filename.

#### Scenario: Missing or empty password file

- Given no app password configured
- When the pipeline runs
- Then it fails with an explicit instruction and creates no draft

#### Scenario: Installer seeds the password

- Given `GMAIL_APP_PASSWORD` in the environment or an interactive terminal
- When `install.sh` runs without an existing password file
- Then the file is created with mode `0600` and its content is never echoed

### Requirement: Every run MUST be inspectable and repeatable

The unit MUST write the generated message to `<state>/<date>-<company>-<role>.eml` on every successful build, MUST append the stdout/stderr of every detached run to `<state>/last.log`, and MUST expose `--check` (IMAP login + drafts mailbox discovery), `--dry-run` (build and write the `.eml`, skip IMAP) and `--json FILE` (use a canned LLM response). The job posting MUST be accepted from `--text`, from `--job FILE`, or from the popup, and `--detach` MUST return immediately after handing the run to a new session.

#### Scenario: Dry run leaves no server trace

- Given `--dry-run`
- When the pipeline runs
- Then the `.eml` is written locally and no IMAP connection is opened

#### Scenario: Connectivity check

- Given `--check`
- When credentials and IMAP access are valid
- Then it prints the drafts mailbox and exits 0; otherwise it exits non-zero with the server's reason

### Requirement: Install MUST be idempotent and reversible

The installer MUST follow the AGENTS.md contract: copy scripts and `env.conf` into `~/.config/acw/recruiter-drafts/`, back up any file it overwrites as `<target>.bak-<timestamp>`, seed the app password only when absent, and `--remove` MUST delete exactly the install root, leaving no trace.

#### Scenario: Reinstall

- Given the unit already installed
- When `install.sh` runs again
- Then it succeeds, keeps the existing app password, and backs up any changed file before overwriting

#### Scenario: Remove

- Given the unit installed
- When `install.sh --remove` runs
- Then the install root is gone and no unit file remains anywhere else
