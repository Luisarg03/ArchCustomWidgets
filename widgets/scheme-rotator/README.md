# scheme-rotator

Rotates Caelestia color schemes sequentially.

## What it does

`src/caelestia-auto-theme.sh -n` advances to the next of 10 schemes via `matugen`.

## Prerequisites

`caelestia-cli`, `matugen`, `notify-send` (optional).

## Install

```sh
./install.sh          # copies to ~/.config/acw/scheme-rotator/src
```

## Keybinds

Wire manually. Check `docs/keybinds-map.md`.

```
bind = SUPER ALT, T, exec, ~/.config/acw/scheme-rotator/src/caelestia-auto-theme.sh -n
```

## Config

State: `~/.local/state/caelestia-theme-state`. `INSTALL_ROOT` override: `INSTALL_ROOT=/path ./install.sh`.

## Remove

```sh
./install.sh --remove # deletes install root, leaves no trace
```
