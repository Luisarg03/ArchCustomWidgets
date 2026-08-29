# ArchCustomWidgets — Factory Technical Reference (source)

> Source for `docs/archcustomwidgets.html`. Edit this file; regenerate HTML with `factory/docs` (or keep HTML in sync manually). The HTML keeps the styled cover/print layout; this markdown is the maintainable single source.

## 1. Introduction

Monorepo factory for Caelestia (HyDE 3.x) on Arch/Hyprland/Wayland. Bash first, copy-install, no hardcoded colors.

- Stack: bash 5+ `set -euo pipefail`, python3 only for JSON.
- Gold rule: shortest thing that works.

## 2. Architecture

Factory `factory/validate` → units `widgets/`+`services/` → copy to `~/.config/acw/<unit>` + systemd user units.

## 3. Unit contract

`manifest.json` (id, type, description, stack, entrypoint) validated by `factory/manifest.schema.json`. `install.sh` idempotent, backs up to `.bak-<ts>`, `--remove` leaves no trace.

## 4. Unit catalog (8 units: 3 services, 5 widgets)

wallpaper, vpn-surfshark, quickshell-watchdog, scheme-rotator, waybar-power, waybar-theme, clipboard-rofi, task-notes.

## 5. Install model

`cd <unit> && ./install.sh` → copy → `systemctl --user enable --now` → validate.

## 6. Services & systemd

`acw-<unit>.service` in `~/.config/systemd/user/`; vpn system units via sudo in `/etc/systemd/system/`.

## 7. Theming

Never hardcode colors; consume Caelestia wallbash palette via CSS vars / env tokens.

## 8. Validation

7 checks: bash -n, manifest schema, clean install, uninstall no trace, is-enabled/is-active, theme, smoke test.

## 9. Lifecycle & OpenSpec

change proposal → spec (`SHALL/MUST`) → scaffold → impl → validate → archive.

## 10. Security & publishing

Gitignored: `nftables.conf`, `**/notes.jsonl`, `*.bak-*`, `.opencode/`, `openspec/changes/`. Secrets never shipped.

*Generated from this file — do not edit HTML directly without syncing.*
