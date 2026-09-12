# waybar-power

Waybar modules for locking and power actions. Two scripts, four modules:

| Module        | Command (on-click / exec)                                              | Action                                        |
|---------------|------------------------------------------------------------------------|-----------------------------------------------|
| `custom/lock` | `~/.config/acw/waybar-power/src/lock.sh`                               | Pick random wallpaper from `/usr/share/backgrounds/Live-wallpaper/`, write it into `~/.config/swaylock/swaylock.config`, then run `swaylock` |
| `custom/power`| `~/.config/acw/waybar-power/src/power.sh --shutdown`                   | Confirm then `systemctl poweroff`             |
| `custom/quit` | `~/.config/acw/waybar-power/src/power.sh --logout`                     | Confirm then exit the Hyprland session (`hyprctl dispatch exit`) |
| `custom/reboot`| `~/.config/acw/waybar-power/src/power.sh --reboot`                    | Confirm then `systemctl reboot`               |

## Install

```bash
./install.sh
```

Copies the unit to `$INSTALL_ROOT` (default `~/.config/acw/waybar-power`).
Idempotent: existing differing files are backed up as `<file>.bak-<timestamp>`.

Remove (leaves no trace):

```bash
./install.sh --remove
```

## Waybar wiring

Add one or more modules to your waybar config
(`~/.config/waybar/config.jsonc`). There is no config fragment for this unit —
the modules are plain `custom/*` entries. Example:

```jsonc
"custom/lock": {
    "exec": "~/.config/acw/waybar-power/src/lock.sh",
    "interval": "once",
    "on-click": "~/.config/acw/waybar-power/src/lock.sh",
    "format": " {} ",
    "tooltip": false
},
"custom/power": {
    "exec": "~/.config/acw/waybar-power/src/power.sh --shutdown",
    "interval": "once",
    "on-click": "~/.config/acw/waybar-power/src/power.sh --shutdown",
    "format": " {} ",
    "tooltip": false
}
```

Then add `custom/lock`, `custom/power`, `custom/quit`, `custom/reboot` to your
`modules-left` / `modules-center` / `modules-right` array and reload waybar.
Style the modules with `#custom-lock`, `#custom-power`, `#custom-quit`,
`#custom-reboot` selectors in `style.css`.

## Requirements

- `swaylock` (lock script) and `zenity` (confirmation dialogs). `zenity` is
  checked at runtime and the script aborts with an error if missing.
- The lock script needs a wallpaper directory with `jpg`/`jpeg`/`png`/`gif`
  files — edit `WALLPAPER_DIR` in `src/lock.sh` to match your setup.
- `power.sh` exits the session with `hyprctl dispatch exit` (Hyprland) — edit
  `LOGOUT_CMD` at the top of `src/power.sh` for another compositor.
