# task-notes Specification

## Purpose
Quick note capture (floating Quickshell window) with LLM classification into tasks/ideas/thoughts and an organized, sortable Tasks tab in the Caelestia shell dashboard. Classification must be correctable from the UI and safe under concurrent writes.
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

The unit MUST store notes in `~/.local/state/caelestia/notes.jsonl`, one JSON object per line, with at least: `id`, `raw`, `status`, `created_at`. Enriched fields (`title`, `type`) MUST be added by processing without losing the original `raw`. Every writer (capture, processor, toggle, type fix) MUST serialize access to the store with a shared `flock`.

#### Scenario: New note appended

- Given the store file
- When a note is captured
- Then a new line with `id`, `raw`, `status: open`, `created_at` is appended

#### Scenario: Raw text survives enrichment

- Given a processed note
- When enrichment completes
- Then the record still contains the original `raw` text

### Requirement: Processing MUST rewrite and classify with the configured LLM

The unit MUST process new notes through the user's opencode providers (`opencode run`, e.g. `-m opencode-go/deepseek-v4-flash`) to produce a `title` and a `type` in `task|idea|thought`, enriched with `priority` (`low|medium|high`, default `medium`), `tags` (array of 2-4 lowercase keywords, may be empty) and `due` (ISO-8601 date `YYYY-MM-DD` or `null`). The prompt MUST instruct the LLM to answer in the note's own language, and `due` MUST only be set when the note explicitly mentions a date or deadline. If the LLM call fails or returns invalid JSON, the note MUST be kept with an `error` field and MUST NOT be lost; malformed `priority`/`tags`/`due` values fall back to defaults instead of failing.

The processor MUST support `--retry` (reprocess only errored or unenriched lines) and `--reclassify` (reprocess every line, preserving `id`/`raw`/`status`/`created_at`; on failure keep the previous enriched fields and set `error`). All pending notes MUST be classified in a single batched `opencode run --pure` call (one spawn, one LLM request) rather than one call per note.

#### Scenario: Raw note gets enriched

- Given a raw note in the store
- When the processing service runs
- Then the record gains `title`, `type` (task, idea or thought), `priority`, `tags` and `due`

#### Scenario: Title keeps the note's language and due is evidence-only

- Given a Spanish note without any date mention
- When the LLM classifies it
- Then the title is in Spanish and `due` is `null`

#### Scenario: Reclassify reprocesses enriched notes

- Given an enriched note whose type is wrong
- When `process_notes.sh --reclassify` runs
- Then the note is reprocessed and its `id`, `raw`, `status` and `created_at` are unchanged

#### Scenario: LLM failure keeps the note

- Given the LLM call failing or returning invalid JSON
- When processing attempts to enrich
- Then the note remains in the store with an `error` field and its original `raw`

### Requirement: Shell dashboard tab MUST organize notes in sections and sort them

The Tasks tab MUST group notes into sections: unclassified (errored or not yet classified) first, then `task`, `idea`, `thought`, and a collapsed-by-default `done` section at the end. Task/idea/thought sections MUST be sorted by priority (high → low), then due date (ascending, notes without due last), then creation time. Each row MUST show its priority, due date and tags. Due dates MUST be highlighted when overdue or due within two days.

#### Scenario: Sections and ordering

- Given a store with notes of several types, statuses and priorities
- When the dashboard Tasks tab renders
- Then notes appear under their type section, sorted by priority then due date, and done notes sit in a collapsed section at the bottom

#### Scenario: Done section collapses

- Given a rendered done section
- When its header is clicked
- Then the section expands and collapses without losing its notes

### Requirement: Dashboard tab MUST allow check toggle, manual reclassification and retry

The tab MUST list stored notes with their type, and a check control that marks a note done; the list MUST refresh when the store changes. Clicking a note's type badge MUST cycle its type through `task → idea → thought` and persist it via `set_type.sh` (which MUST also clear `error`). Notes with an `error` field MUST offer a retry action that re-runs the processor on errored notes and refreshes the list.

#### Scenario: Tab renders notes

- Given the shell override installed
- When the dashboard is opened
- Then a Tasks tab is present and lists stored notes with type badge

#### Scenario: Check marks note done

- Given a note listed as open
- When its check control is clicked
- Then the note's status flips to done in the store and the list reflects it

#### Scenario: Manual type fix

- Given a note misclassified as `idea`
- When its type badge is clicked twice
- Then its type becomes `thought` in the store and the list reflects it

#### Scenario: Retry errored note

- Given a note with an `error` field
- When its Reintentar control is clicked
- Then the processor retries classification and the row updates or keeps the error

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
