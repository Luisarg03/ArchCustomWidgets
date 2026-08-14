# migrate-custom-units

## Why

The live Caelestia (HyDE 3.x) setup on this machine has grown a set of hand-customized widgets, scripts and services: a wallpaper downloader + theme color pipeline, waybar custom modules (todo, countdown, power), a Surfshark VPN quick-toggle button, systemd user services and more. They live scattered across `~/.config` with no versioning, no contract, and some broken leftovers. This change brings them into the ArchCustomWidgets factory as first-class units (manifest, install.sh, README) so they are versioned, installable, uninstallable and reproducible.

## What Changes

New factory units under `widgets/` and `services/` (per the AGENTS.md unit contract):

| Unit | Type | Source (live setup) |
|---|---|---|
| `wallpaper` | service | `~/.config/hypr/scripts/wallhaven-wallpaper`, `wallpaper-select.sh`, `wallpaper-auto-theme.sh` + systemd `.path`/`.service`, `wallchange-color.sh` |
| `scheme-rotator` | widget | `~/.config/hypr/scripts/caelestia-auto-theme.sh` |
| `waybar-todo` | widget | `~/.config/waybar/scripts/todo/` |
| `waybar-countdown` | widget | `~/.config/waybar/scripts/countdown/` |
| `vpn-surfshark` | widget + service | `~/.config/caelestia/shell.json` `utilities.vpn` entry + system-level `surfshark-connect`/`surfshark-disconnect` units |
| `waybar-power` | widget | `~/.config/waybar/scripts/lock.sh`, `power.sh` |
| `waybar-theme` | widget | `~/.config/waybar/scripts/theme.sh` |
| `clipboard-rofi` | widget | `~/.config/hypr/scripts/clipboard-rofi.sh` |
| `quickshell-watchdog` | service | `~/.config/hypr/scripts/caelestia-watchdog.sh` + `.timer` |
| `opencode-stats` | service | `caelestia-opencode-stats.service` + `.timer` |

Plus minimal factory tooling: manifest schema + `factory/validate` so every unit is validated at install time.

## Implementation Plan

1. Factory bootstrap: manifest.json schema + `factory/validate` script.
2. Migrate units one by one, in order: wallpaper, scheme-rotator, waybar-todo, waybar-countdown, vpn-surfshark, waybar-power, waybar-theme, clipboard-rofi, quickshell-watchdog, opencode-stats.
3. Each unit: copy source scripts into `src/`, write `manifest.json` (id, type, deps, stack, entrypoint), `install.sh` (idempotent copy; `--remove` leaves no trace), `README.md`. Keep scripts byte-identical first; refactor only where the contract requires (config paths, theme tokens).
4. Validation per unit: full AGENTS.md validation checklist (bash -n, manifest valid, clean install/uninstall, services is-enabled && is-active, visual smoke test).

## Non-goals

- No migration of the 23 broken HyDE stock scripts in `~/.config/hypr/scripts` (missing `globalcontrol.sh`); they stay out.
- No migration of the waybar `vpn` module (NetWorkLayerProtect chain) — VPN is exclusively the Caelestia quick-toggle button (decision D1).
- External repos (`NetWorkLayerProtect`, `ObsidianWitget`, `openclaw`) are NOT vendored; referenced as deps in manifests where needed.
- No changes to the Caelestia shell itself; the vpn unit only ships the shell.json config delta it owns.
