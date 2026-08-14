# waybar-countdown

Waybar module showing a selected countdown with days (or %) remaining and a
tooltip table of every countdown. Interactions:

- **Scroll up / down** — switch the selected countdown.
- **Right click** — open the interactive TUI manager: add, edit, delete
  countdowns.

## Install

```bash
./install.sh
```

Copies the unit to `$INSTALL_ROOT` (default `~/.config/acw/waybar-countdown`).
Idempotent: existing differing files are backed up as `<file>.bak-<timestamp>`.

Remove (leaves no trace):

```bash
./install.sh --remove
```

## Waybar wiring

1. Install the unit (above).
2. Merge `styles/waybar-module.jsonc` into your waybar config
   (`~/.config/waybar/config.jsonc`) — it is a template; adjust paths if needed.
3. Add `custom/countdown` to your `modules-left` / `modules-center` /
   `modules-right` array.
4. Reload waybar.

The module refreshes every hour (3600 s). It emits a `percentage` value (0–100,
progress towards the end date) usable by waybar for a progress bar via
`class`/`state` rules if you add them.

## Data

- `countdowns.txt` — one countdown per line, format
  `<label>;<start YYYY-MM-DD>;<end YYYY-MM-DD>;<days|percentage>`. Created on
  first use by the script.
- `countdown.state` — index of the currently selected countdown. Created on
  first use. (The source tree currently ships no data/state file; the script
  creates both at the paths above on first run.)

Requires `bc` for percentage math.

## Note on paths

The script hardcodes its original location
(`$HOME/.config/waybar/scripts/countdown/`) and reads/writes `countdowns.txt`
and `countdown.state` there. The copy bundled in `src/` is a snapshot; to
change the data location, edit the `DATA_FILE` / `STATE_FILE` lines at the top
of `src/countdown.sh`.
