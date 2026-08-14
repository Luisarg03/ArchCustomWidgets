# clipboard-rofi

Rofi clipboard picker backed by cliphist and wl-copy.

## Usage

`src/clipboard-rofi.sh` opens a rofi menu with the clipboard history; the selected entry is copied back to the clipboard with `wl-copy`.

## Keybind (wire manually in hyprland.conf)

Super+V → `~/.config/acw/clipboard-rofi/src/clipboard-rofi.sh`

## Install / Remove

```sh
./install.sh          # install script to ~/.config/acw/clipboard-rofi/src
./install.sh --remove # remove; deletes the install root, leaves no trace
```

Install root override: `INSTALL_ROOT=/path ./install.sh`
