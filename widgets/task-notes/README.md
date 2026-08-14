# task-notes

Quick note capture with automatic title/type classification and a Tasks tab in the Caelestia dashboard.

## What it does

- `capture.qml` (Super+G) opens a floating Quickshell window; the note you type is appended to the notes store.
- A systemd user `.path` unit watches the store and fires a oneshot that classifies each new note via `opencode run` (strict-JSON prompt): short `title` + `type` (`task | idea | thought`).
- The classified notes appear in a new **Tasks** tab of the Caelestia dashboard (`TaskWidget.qml`), live-reloaded with `FileView.watchChanges`.

## Architecture

```
capture.qml (Super+G)
      |
      v append raw line
~/.local/state/caelestia/notes.jsonl   (append-only JSONL, one JSON object per line)
      |
      v PathChanged
acw-task-notes.path -> acw-task-notes.service (oneshot)
      |
      v offset-based (no re-processing)
process_notes.sh -> opencode run -> line rewritten in place (title/type/error)
      |
      v
~/.config/quickshell/caelestia/modules/dashboard/TaskWidget.qml  (dashboard Tasks tab)
```

Record contract (shared by capture, processor and toggle):

```json
{"id":"a1b2c3","raw":"texto crudo original","title":"Titulo corto","type":"task","status":"open","created_at":"2026-08-14T17:20:00","error":null}
```

- `raw` always present; `title`/`type` added by the processor; `error` set (string) only when classification failed; `status` toggled `open`/`done` by `toggle_note.sh`.
- The processor rewrites lines **in place** (same line count); its progress lives in `$INSTALL_ROOT/.state` (a line offset), so the re-trigger caused by its own rewrite is a no-op.

## Config

`env.conf` at the install root (`~/.config/acw/task-notes/env.conf`):

| Var | Default |
|---|---|
| `INSTALL_ROOT` | `~/.config/acw/task-notes` |
| `NOTES_FILE` | `~/.local/state/caelestia/notes.jsonl` |
| `MODEL` | `opencode-go/deepseek-v4-flash` |

All are overridable per-invocation via the environment (same names).

## Keybind (wire manually in ~/.config/hypr/custom/keybinds.conf)

Super+G is **not** auto-applied; add it yourself:

```
bind = SUPER, G, exec, qs -p ~/.config/acw/task-notes/src/capture.qml
```

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
