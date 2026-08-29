# clipboard-rofi

Rofi clipboard picker backed by `cliphist` and `wl-copy`.

## What it does

`src/clipboard-rofi.sh` shows clipboard history in rofi; selecting an entry copies it with `wl-copy`.

## Prerequisites

`cliphist`, `wl-clipboard` (`wl-copy`), `rofi`, Hyprland.

## Install

```sh
./install.sh          # copies to ~/.config/acw/clipboard-rofi/src
```

Idempotent; existing differing files backed up as `.bak-<timestamp>`.

## Keybinds

Wire manually (never auto-applied). Check `docs/keybinds-map.md` before adding.

```
bind = SUPER, V, exec, ~/.config/acw/clipboard-rofi/src/clipboard-rofi.sh
```

## Config

`INSTALL_ROOT` override: `INSTALL_ROOT=/path ./install.sh`. No other config.

## Remove

```sh
./install.sh --remove # deletes install root, leaves no trace
```
