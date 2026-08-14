# scheme-rotator

Rotate Caelestia color schemes sequentially.

## Usage

`src/caelestia-auto-theme.sh -n` advances to the next scheme. It cycles through 10 schemes and applies the active one via matugen, notifying with `notify-send`.

## Keybind (wire manually in hyprland.conf)

Super+Alt T → `~/.config/acw/scheme-rotator/src/caelestia-auto-theme.sh -n`

## State

The current scheme index lives in `~/.local/state/caelestia-theme-state`.

## Install / Remove

```sh
./install.sh          # install scripts to ~/.config/acw/scheme-rotator/src
./install.sh --remove # remove; deletes the install root, leaves no trace
```

Install root override: `INSTALL_ROOT=/path ./install.sh`
