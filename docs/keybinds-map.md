# Keybind map — hiro03 Hyprland (Caelestia 3.x)

Authoritative map of LIVE keybinds, verified 2026-08-14 via `hyprctl binds` (109 distinct live binds) + config inventory. **Check this file before assigning any new key combo.**

## How to read this

- **LIVE** binds come from exactly two sourced files (verified: `~/.config/hypr/hyprland.conf` sources these at L154-166):
  - `~/.config/hypr/keybindings.conf` (user layer)
  - `~/.config/hypr/custom/keybinds.conf` (custom overrides, sourced last — wins on conflicts)
- **DEAD** binds: `~/.config/hypr/hyprland/keybinds.conf` (Caelestia's file) is NOT sourced. Do not use combos only claimed there as "free" — they are reserved intent, and would conflict if that file is ever re-enabled.

## Live binds

| Combo | Action | Source |
|---|---|---|
| *(bare)* F10/F11/F12 | vol down/up/mute | keybindings.conf:42-44 |
| *(bare)* XF86* | volume/brightness/screenshot | keybindings.conf:45-61 |
| *(bare)* Caps_Lock / Num_Lock | caelestia:refreshDevices | custom/keybinds.conf |
| *(bare)* Lid Switch | suspend | keybindings.conf:156 |
| Alt+F4 | close (dontkillsteam) | keybindings.conf:21 |
| Alt+Tab | movefocus d | keybindings.conf:77 |
| Alt+Return | fullscreen | keybindings.conf:25 |
| Shift+Ctrl+T | wallchange-color | custom/keybinds.conf:18 |
| Super+0-9 | workspace 1-10 | keybindings.conf:80-89 |
| Super+B | firefox | keybindings.conf:33 |
| Super+C | code | keybindings.conf:32 |
| Super+E | dolphin | keybindings.conf:31 |
| Super+G | togglegroup | keybindings.conf:24 |
| Super+J | layoutmsg togglesplit | keybindings.conf:141 |
| Super+K | keyboardswitch | keybindings.conf:69 |
| Super+L | lock-session | keybindings.conf:26 |
| Super+M | thunderbird | keybindings.conf:34 |
| Super+P | caelestia screenshot -r | keybindings.conf:59 |
| Super+Q | close (dontkillsteam) | keybindings.conf:20 |
| Super+R | wofi run | keybindings.conf:39 |
| Super+S | togglespecialworkspace | keybindings.conf:138 |
| Super+Space | caelestia:launcher | custom/keybinds.conf:13 |
| Super+T | kitty | keybindings.conf:30 |
| Super+V | clipboard (rofi) | custom/keybinds.conf:14 |
| Super+W | togglefloating | keybindings.conf:23 |
| Super+backspace | logout | keybindings.conf:27 |
| Super+delete | exit session | keybindings.conf:22 |
| Super+arrows/mouse | focus/move/resize | keybindings.conf:73-76,129-134 |
| Super+period | caelestia:emoji | custom/keybinds.conf:15 |
| Super+tab | hyprspace overview | custom/keybinds.conf:19 |
| Super+Alt+0-9 | movetoworkspacesilent | keybindings.conf:144-153 |
| Super+Alt+G | gamemode | keybindings.conf:64 |
| Super+Alt+S | scratchpad | keybindings.conf:137 |
| Super+Alt+T | caelestia-auto-theme | keybindings.conf:163 |
| Super+Ctrl+R | caelestia:reload | custom/keybinds.conf:16 |
| Super+Ctrl+Slash | edit shell.json | custom/keybinds.conf:4 |
| Super+Ctrl+T | wallhaven new | custom/keybinds.conf:17 |
| Super+Ctrl+arrows/down | workspace r±1/empty | keybindings.conf:92-96 |
| Super+Ctrl+Alt+Slash | edit keybinds.conf | custom/keybinds.conf:5 |
| Super+Shift+0-9 | movetoworkspace | keybindings.conf:105-114 |
| Super+Shift+A | rofiselect | keybindings.conf:66 |
| Super+Shift+G | gamelauncher | keybindings.conf:70 |
| Super+Shift+S | screenshot freeze | keybindings.conf:60 |
| Super+Shift+T | wallpaper-select | keybindings.conf:65 |
| Super+Shift+W | wallpaper-select | keybindings.conf:67 |
| Super+Shift+arrows | movewindow/resizeactive | keybindings.conf:99-102,117-126 |
| Super+Shift+Ctrl+arrows | movewindow | keybindings.conf:123-126 |

## Reserved (commented or dead-caelestia — do not use)

| Combo | Action | Why |
|---|---|---|
| Super+Shift+N | fix-notifications | commented intent, keybindings.conf:160 |
| Super (hold) | overview/launcher | dead caelestia file |
| Super+A/O/N/M/K | shell sidebars/osd/media/osk toggles | dead caelestia file |
| Super+D | fullscreen | dead caelestia file |
| Super+F/X/I | fullscreen/text-editor/settings | dead caelestia file |

## Free combos (verified 2026-08-14)

Safest `Super+letter`: **H, U, Y, Z** (never referenced in any layer, live or dead).
Next-safest: **D, F** (dead-caelestia only; free today).
`Super+Shift+letter` free: everything except A, G, S, T, W — safest **U, Y, Z**.
`Ctrl+Super+letter` free: everything except R, T — safest **G, U, Y, Z**.
`Alt+Super+letter` free: everything except G, S, T — safest **U, Y, Z**.

## Assigned by ArchCustomWidgets units

| Combo | Unit | Action |
|---|---|---|
| Ctrl+Super+G | task-notes | capture note (qs -p capture.qml) — added 2026-08-14; was Super+G until conflict found (Super+G = togglegroup) |

## Verification command

```bash
hyprctl binds -j | jq -r '.[] | .modmask + "+" + .key + " -> " + .handler'
```
Run this before assigning any new combo.
