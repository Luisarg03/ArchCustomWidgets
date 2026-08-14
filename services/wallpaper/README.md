# wallpaper

Wallhaven downloader, rofi wallpaper selector and auto-theme pipeline for Caelestia (Hyprland).

## What it does

- `src/wallhaven-wallpaper` — download wallpapers from Wallhaven by query/tag.
- `src/wallpaper-select.sh` — rofi picker to choose and set a wallpaper from the local collection.
- `src/wallpaper-auto-theme.sh` — regenerate the color scheme (matugen + Caelestia scheme) from the current wallpaper.
- `src/wallchange-color.sh` — manually re-run the theme generation for the current wallpaper.
- Systemd user units: `acw-wallpaper-theme.path` watches `~/.local/state/caelestia/wallpaper/path.txt`; on change it triggers the oneshot `acw-wallpaper-theme.service`, which runs the auto-theme script. The path unit is enabled and started at install, so the scheme regenerates automatically on every wallpaper change.

## Install

```sh
./install.sh
```

Installs the scripts to `~/.config/acw/wallpaper/src/` and the two systemd user units, then enables and starts `acw-wallpaper-theme.path`.

## Keybinds (wire manually in hyprland.conf)

- Ctrl+Super+T → `~/.config/acw/wallpaper/src/wallhaven-wallpaper new`
- Shift+Super+T → `~/.config/acw/wallpaper/src/wallpaper-select.sh`
- Ctrl+Shift+T → `~/.config/acw/wallpaper/src/wallchange-color.sh`

## Config

- Wallhaven settings (API key, download directories) stay at `~/.config/wallhaven-wallpaper/config`; the downloader reads them from there. This unit copies no config.
- Install root override: `INSTALL_ROOT=/path ./install.sh`

## Remove

```sh
./install.sh --remove
```

Disables and stops the path unit, deletes the systemd user units, and removes `~/.config/acw/wallpaper`. Leaves no trace.
