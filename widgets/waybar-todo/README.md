# waybar-todo

Waybar module showing your top pending task. Click interactions:

- **Left click** — mark the top pending task done.
- **Right click** — open the interactive TUI manager (`todo_tui.sh`, runs in
  `kitty`): add, delete, toggle tasks, and configure settings.
- **Middle click** — run the configured middle-click action (delete completed or
  all tasks; set from the TUI settings menu).

## Install

```bash
./install.sh
```

Copies the unit to `$INSTALL_ROOT` (default `~/.config/acw/waybar-todo`).
Idempotent: existing differing files are backed up as `<file>.bak-<timestamp>`.

Remove (leaves no trace):

```bash
./install.sh --remove
```

## Waybar wiring

1. Install the unit (above).
2. Merge `styles/waybar-module.jsonc` into your waybar config
   (`~/.config/waybar/config.jsonc`) — it is a template; adjust paths if needed.
3. Add `custom/todo` to your `modules-left` / `modules-center` /
   `modules-right` array.
4. Reload waybar.

The module polls `todo.sh` every 5 seconds; left click marks done, right click
opens the TUI, middle click runs the configured cleanup action.

## Configuration

- `src/todo.conf` — settings: `SCHEDULED_TIME` / `SCHEDULED_ACTION` (daily
  auto-delete), `LAST_CHECKED_TIMESTAMP`, `MIDDLE_CLICK_ACTION`. Managed from
  the TUI settings menu; edit by hand if you prefer.
- Tasks live in `src/tasks.txt`, one per line, format
  `<priority>|<0|1>|<description>` (`1` = completed).

## Note on paths

The scripts hardcode their original locations
(`$HOME/.config/waybar/scripts/todo/`) and read/write the task and config
files there. The copies bundled in `src/` are a snapshot: on first run
`todo.sh` recreates the state/config files at the original location if missing.
To switch the data location, edit the `TODO_DIR` line at the top of
`src/todo.sh` and `src/todo_tui.sh`.
