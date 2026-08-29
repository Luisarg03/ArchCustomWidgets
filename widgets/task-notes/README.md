# task-notes

Quick note capture with automatic title/type classification and a Tasks tab in the Caelestia dashboard.

## What it does

- `capture.qml` (Ctrl+Super+G) opens a floating Quickshell window; the note you type is appended to the notes store.
- A systemd user `.path` unit watches the store and fires a oneshot that classifies pending notes in **one batched `opencode run --pure` call** (single cold boot + single LLM call — a batch of 12 notes classifies in ~15s): short `title` + `type` (`task | idea | thought`) + `priority`, `tags` and `due`. The title keeps the note's language; `due` is only set when the note explicitly mentions a date (no invented deadlines).
- The classified notes appear in a **Tasks** tab of the Caelestia dashboard (`TaskWidget.qml`), live-reloaded with `FileView.watchChanges`, organized in collapsible sections:
  - **Sin clasificar** (errored / not yet classified) at the top
  - **Tareas** / **Ideas** / **Pensamientos**, sorted by priority (`high → low`), then due date, then creation time
  - **Completadas** (done), collapsed by default
- Each row shows its priority (colored dot), due date (red when overdue, amber when due within 2 days) and tags.
- Fixes from the tab itself: click a row's checkbox to toggle `done`, click the type badge to cycle `task → idea → thought` (manual reclassification), and click **Reintentar** on an errored row to retry its LLM classification.

## Architecture

```
capture.qml (Ctrl+Super+G)
      |
      v append raw line (flocked)
~/.local/state/caelestia/notes.jsonl   (append-only JSONL, one JSON object per line)
      |
      v PathChanged
acw-task-notes.path -> acw-task-notes.service (oneshot)
      |
      v offset-based (no re-processing), flocked read-modify-write
process_notes.sh -> one batched `opencode run --pure` call
                -> lines rewritten in place (title/type/error)
      |
      v
~/.config/quickshell/caelestia/modules/dashboard/TaskWidget.qml  (dashboard Tasks tab)
      |
      +-- toggle_note.sh  (checkbox: open/done)
      +-- set_type.sh     (badge click: task/idea/thought)
```

All writers of the store (`capture_append.sh`, `process_notes.sh`, `toggle_note.sh`,
`set_type.sh`) take the same `flock` on `$NOTES_FILE.lock`, so concurrent rewrites
cannot lose notes.

Record contract (shared by capture, processor and toggle):

```json
{"id":"a1b2c3","raw":"texto crudo original","title":"Titulo corto","type":"task","priority":"medium","tags":["config","hyprland"],"due":"2026-08-20","status":"open","created_at":"2026-08-14T17:20:00","error":null}
```

- `raw` always present; `title`/`type`/`priority`/`tags`/`due` added by the processor; `error` set (string) only when classification failed; `status` toggled `open`/`done` by `toggle_note.sh`.
- `title`: short title, max 8 words. `type`: `task | idea | thought`. `priority`: `low | medium | high` (default `medium` if the LLM omits it). `tags`: array of 2-4 lowercase keywords (may be `[]`). `due`: ISO-8601 date `YYYY-MM-DD` or `null` — set only when the note implies a deadline.
- The processor rewrites lines **in place** (same line count); its progress lives in `$INSTALL_ROOT/.state` (a line offset), so the re-trigger caused by its own rewrite is a no-op.

## Config

`env.conf` at the install root (`~/.config/acw/task-notes/env.conf`):

| Var | Default |
|---|---|
| `INSTALL_ROOT` | `~/.config/acw/task-notes` |
| `NOTES_FILE` | `~/.local/state/caelestia/notes.jsonl` |
| `MODEL` | `opencode-go/muse-spark-1.2-contributor` |

All are overridable per-invocation via the environment (same names).

## Keybind (wire manually in ~/.config/hypr/custom/keybinds.conf)

Ctrl+Super+G is **not** auto-applied; add it yourself:

```
bind = CTRL SUPER, G, exec, qs -p ~/.config/acw/task-notes/src/capture.qml
```

The combo was chosen from `docs/keybinds-map.md`: Super+G is taken by togglegroup.

## See the Tasks tab

The dashboard override is picked up when the shell starts. Restart the shell after installing:

```
qs -c caelestia
```

or use the widgets restart keybind (Ctrl+Super+R).

## Retry failed classifications

A note whose classification failed keeps its `error` field and is not retried automatically (the offset advances past it). To retry all errored/raw notes:

```
~/.config/acw/task-notes/src/process_notes.sh --retry
```

or click **Reintentar** on the row in the Tasks tab.

## Reclassify existing notes

After a prompt change (or to fix old misclassifications), reprocess every note —
already-enriched lines included. `id`, `raw`, `status` and `created_at` are
preserved; on failure the previous fields are kept and only `error` is set:

```
~/.config/acw/task-notes/src/process_notes.sh --reclassify
```

A single misclassified note can be fixed from the Tasks tab by clicking its type
badge, or from a terminal:

```
~/.config/acw/task-notes/src/set_type.sh <note-id> task
```

## Install / Remove

```sh
./install.sh          # install unit + systemd user units (enable --now the .path) + dashboard override
./install.sh --remove # remove; leaves no trace
```

- Install backs up any existing file it would overwrite as `<target>.bak-<timestamp>` (including a pre-existing `~/.config/quickshell/caelestia/modules/dashboard/` tree).
- `--remove` deletes the dashboard override **only** if it is ours (marker: `TaskWidget.qml`); a user's unrelated `quickshell` config is left untouched. Backups created by install are kept.
- Install root override: `INSTALL_ROOT=/path ./install.sh`

## Shell override re-sync (fork-drift, accepted)

Caelestia has no widget plugin mechanism; the Tasks tab ships as an override of the whole `modules/dashboard/` tree in the user config dir. Quickshell prefers the user dir, so the override survives `caelestia-shell` package updates — but it also **freezes**: upstream changes to `modules/dashboard/` will not reach your copy.

To re-sync after a shell update:

1. Compare against upstream: `pacman -Ql caelestia-shell | grep modules/dashboard`
2. Re-apply the `Content.qml` patch (Tasks tab entry + `taskComponent`) and refresh `TaskWidget.qml` — or back up your override, delete it, and run `./install.sh` again (it re-copies the tree from `/etc/xdg` and re-patches idempotently).
