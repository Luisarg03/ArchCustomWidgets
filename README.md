# ArchCustomWidgets

Factory of installable widgets and services extending Caelestia (HyDE 3.x-based) on Arch Linux / Hyprland (Wayland).

## Quick start

```bash
# Validate every unit (widgets/ + services/)
factory/validate

# Install a unit (copies files into ~/.config; idempotent, backs up overwritten files)
cd <unit>
./install.sh

# Uninstall (removes exactly what it installed, leaves no trace)
./install.sh --remove
```

- System-level units (e.g. `vpn-surfshark`) run some install steps via `sudo` and prompt only for those.
- Install model is copy, never symlinks. Safe to re-run.

## Unit index

| Unit | Type | What it does | Notes |
|---|---|---|---|
| `wallpaper` | service | Wallhaven downloader + rofi wallpaper selector + auto-theme pipeline (systemd `.path` → matugen + scheme set) | Keybinds `Ctrl+Super+T`, `Shift+Super+T`, `Ctrl+Shift+T` — wire manually |
| `scheme-rotator` | widget | Rotates the active color scheme | Keybind `Super+Alt+T` — wire manually |
| `waybar-power` | widget | Power menu module: lock / power / quit / reboot | |
| `waybar-theme` | widget | Theme switcher module for waybar | |
| `clipboard-rofi` | widget | Rofi clipboard manager | Keybind `Super+V` — wire manually |
| `vpn-surfshark` | service | Surfshark VPN quick-toggle (Caelestia quick-toggles `utilities.vpn`), `surfshark-connect`/`surfshark-disconnect` units | System-level files → sudo install |
| `quickshell-watchdog` | service | Watchdog for quickshell, systemd user unit + timer | |

## Contract

Every unit follows the contract in [`AGENTS.md`](AGENTS.md): `manifest.json` (id, type, deps, stack, entrypoint), `src/`, `install.sh` (idempotent copy, `--remove` support), `README.md`. Colors are never hardcoded — units consume the active wallbash/Caelestia palette through CSS variables or env tokens. Validation checklist lives in AGENTS.md.
