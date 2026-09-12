# wallpaper

Wallhaven downloader, rofi wallpaper selector and auto-theme pipeline for Caelestia (Hyprland).

## What it does

- `src/wallhaven-wallpaper` — fetch a random Wallhaven wallpaper matching the environment filters and apply it.
- `src/wallpaper-select.sh` — rofi picker to choose and set a wallpaper from the local collection.
- `src/wallpaper-auto-theme.sh` — regenerate the color scheme (matugen + Caelestia scheme) from the current wallpaper.
- Systemd user units: `acw-wallpaper-theme.path` watches `~/.local/state/caelestia/wallpaper/path.txt`; on change it triggers the oneshot `acw-wallpaper-theme.service`, which runs the auto-theme script. The path unit is enabled and started at install, so the scheme regenerates automatically on every wallpaper change.

## Install

```sh
./install.sh
```

Installs the scripts to `~/.config/acw/wallpaper/src/` and the two systemd user units, then enables and starts `acw-wallpaper-theme.path`.

## Keybinds (wire manually in hyprland.conf)

- Ctrl+Super+T → `~/.config/acw/wallpaper/src/wallhaven-wallpaper new`
- Shift+Super+T → `~/.config/acw/wallpaper/src/wallpaper-select.sh`

## Config

- The Wallhaven filters are environment variables read by `wallhaven-wallpaper`
  (`WALLHAVEN_QUERY`, `WALLHAVEN_RESOLUTION`, `WALLHAVEN_RATIOS`,
  `WALLHAVEN_SORTING`, `WALLHAVEN_TOPRANGE`, `WALLHAVEN_PURITY`,
  `WALLHAVEN_CATEGORIES`, `WALLHAVEN_API_KEY`, `WALL_DIR`). Set them in the
  keybind or export them; run `wallhaven-wallpaper help` for the defaults.
- Install root override: `INSTALL_ROOT=/path ./install.sh`

## Remove

```sh
./install.sh --remove
```

Disables and stops the path unit, deletes the systemd user units, and removes `~/.config/acw/wallpaper`. Leaves no trace.
