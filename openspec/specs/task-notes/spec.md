# task-notes Specification

## Purpose
TBD - created by archiving change add-task-notes. Update Purpose after archive.
## Requirements
### Requirement: Capture MUST open a standalone Quickshell window

The unit MUST ship a standalone Quickshell window (`qs -p`) with a textbox that appends the raw note to the JSONL store when submitted. The keybind that opens it MUST be documented in the README and MUST NOT be auto-applied by the installer.

#### Scenario: Note captured via key combo

- Given the unit installed and the keybind mapped
- When the user presses the combo and submits a raw note
- Then the raw note is appended to the notes JSONL file

#### Scenario: Keybind documented, not auto-applied

- Given a fresh install
- When the installer finishes
- Then no keybind was written to hyprland config, and the README documents the combo to add manually

### Requirement: Notes MUST persist as append-only JSONL

The unit MUST store notes in `~/.local/state/caelestia/notes.jsonl`, one JSON object per line, with at least: `id`, `raw`, `status`, `created_at`. Enriched fields (`title`, `type`) MUST be added by processing without losing the original `raw`.

#### Scenario: New note appended

- Given the store file
- When a note is captured
- Then a new line with `id`, `raw`, `status: open`, `created_at` is appended

#### Scenario: Raw text survives enrichment

- Given a processed note
- When enrichment completes
- Then the record still contains the original `raw` text

### Requirement: Processing MUST rewrite and classify with the configured LLM

The unit MUST process new notes through the user's opencode providers (`opencode run`, e.g. `-m opencode-go/deepseek-v4-flash`) to produce a `title` and a `type` in `task|idea|thought`, enriched with `priority` (`low|medium|high`, default `medium`), `tags` (array of 2-4 lowercase keywords, may be empty) and `due` (ISO-8601 date `YYYY-MM-DD` or `null`). If the LLM call fails or returns invalid JSON, the note MUST be kept with an `error` field and MUST NOT be lost; malformed `priority`/`tags`/`due` values fall back to defaults instead of failing.

#### Scenario: Raw note gets enriched

- Given a raw note in the store
- When the processing service runs
- Then the record gains `title`, `type` (task, idea or thought), `priority`, `tags` and `due`

#### Scenario: LLM failure keeps the note

- Given the LLM call failing or returning invalid JSON
- When processing attempts to enrich
- Then the note remains in the store with an `error` field and its original `raw`

### Requirement: Shell dashboard tab MUST render the list with a check toggle

The unit MUST add a Tasks tab to the Caelestia shell dashboard (via the user-dir `modules/dashboard/` override) listing stored notes with their type, and a check control that marks a note done. The list MUST refresh when the store changes.

#### Scenario: Tab renders notes

- Given the shell override installed
- When the dashboard is opened
- Then a Tasks tab is present and lists stored notes with type badge

#### Scenario: Check marks note done

- Given a note listed as open
- When its check control is clicked
- Then the note's status flips to done in the store and the list reflects it

### Requirement: Install MUST be idempotent and reversible

The installer MUST follow the AGENTS.md contract: idempotent copy with `.bak-<timestamp>` backups, and `--remove` MUST remove exactly what it installed — including the shell dashboard module override — leaving no trace.

#### Scenario: Reinstall with existing override

- Given the shell override already present in the user quickshell dir
- When install runs again
- Then it succeeds and backs up the pre-existing user files before patching

#### Scenario: Remove restores the shell

- Given the unit installed with the shell override
- When `install.sh --remove` runs
- Then the override tree and the systemd user units are removed, restoring the system shell behavior

