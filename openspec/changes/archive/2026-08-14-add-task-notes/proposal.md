# add-task-notes

## Why

The user wants a fast thought/idea/task annotator on the Caelestia (HyDE 3.x) desktop: press a key combo, a textbox opens, type a raw note, and a service classifies/rewrites it with an LLM and stores it, then a widget in the Caelestia shell dashboard renders the list with checkboxes to mark tasks done. LLM backend must reuse the already-configured opencode providers (zen/go gateways) — no new API keys, no Ollama.

## What Changes

New unit `widgets/task-notes` (mixed widget + service), following the AGENTS.md unit contract:

| Component | Kind | Detail |
|---|---|---|
| `src/capture.qml` | widget | Standalone Quickshell window (`qs -p`), textbox, appends raw note to JSONL |
| `src/process_notes.sh` | service | Called by `.path` unit; runs `opencode run -m opencode-go/deepseek-v4-flash` to rewrite + classify each new note |
| `src/toggle_note.sh` | script | Flips a note's status open/done (called by the shell tab) |
| `src/task-notes-tab.qml` | widget | Shell dashboard tab: note list with type badge + check toggle |
| `src/acw-task-notes.path/.service` | service | systemd user units: PathChanged on the JSONL → oneshot process |
| `install.sh` | — | Idempotent copy install; also copies the shell dashboard module override (see design.md D5) |

Storage: append-only JSONL at `~/.local/state/caelestia/notes.jsonl` (alongside existing notifs.json). Record schema: `{id, raw, title, type: task|idea|thought, status: open|done, created_at, error?}`.

## Implementation Plan

1. Write `capture.qml` (standalone Quickshell window, textbox, append to JSONL). Keybind Super+G documented in README, never auto-applied (repo rule).
2. Write `process_notes.sh`: read new raw lines (offset-based, idempotent), call `opencode run -m opencode-go/deepseek-v4-flash` with a strict-JSON prompt, enrich records, append enriched result.
3. Write `acw-task-notes.path/.service` systemd user units (pattern: caelestia-wallpaper-theme.path → oneshot).
4. Write `task-notes-tab.qml` (reuse FileView + watchChanges watcher pattern from the dead OpenCodeCostTab.qml) + `toggle_note.sh`.
5. install.sh: install unit files to `~/.config/acw/task-notes/`, install .path/.service to `~/.config/systemd/user/`, enable --now; copy full `modules/dashboard/` tree to `~/.config/quickshell/caelestia/modules/dashboard/` (backing up existing) and patch Content.qml to add the tab; `--remove` reverses everything.
6. manifest.json + README.md (config, keybind, how to remove, shell-override re-sync notes).
7. Full AGENTS.md validation checklist (bash -n, manifest valid, clean install/uninstall, services enabled+active, visual smoke test).

## Non-goals

- No new LLM backend: reuse opencode zen/go providers via `opencode run` spawn per note; no `opencode serve` daemon, no Ollama.
- No auto-merge of keybinds or shell.json — both documented in README, applied manually.
- No migration of the retired `waybar-todo` unit (recoverable from git) — this replaces it with a Quickshell-native flow.
- No touch of system files (no sudo) — all install targets are user-level.
- The shell override forks `modules/dashboard/` from upstream (known drift cost, see design.md D6); no attempt to patch `/etc/xdg` directly.
