# ArchCustomWidgets — Factory of widgets & services for Caelestia Hyprland

## Purpose

Monorepo factory producing installable widgets and services that extend Caelestia (HyDE 3.x-based) on Arch Linux / Hyprland (Wayland). Units plug into an existing Caelestia setup: waybar modules, standalone widgets, systemd user services.

## Gold Rule

Simplicity first. The shortest thing that works. Bash over compiled languages. Copy over symlinks. No new dependency without justification. If a solution needs a paragraph to explain itself, it is too complex — rewrite it.

## Stack

- Primary language: bash (bash 5+, `set -euo pipefail` in scripts)
- No framework, no build step, no node/rust/go in the unit path.
- Exception: python3 allowed in helper scripts only when bash genuinely cannot express it (e.g., parsing complex JSON).

## Install model: copy

- Units install by COPYING files into `~/.config`. Never symlinks.
- `install.sh` must be idempotent (safe to re-run).
- Each unit ships uninstall support (`install.sh --remove`) that removes exactly what it installed, leaving no trace.
- Never overwrite an existing user file silently: back it up to `<target>.bak-<timestamp>` first.

## Services: systemd user units

- Services ship as systemd `--user` units (unit file copied to `~/.config/systemd/user/`).
- They must start with the system: `install.sh` runs `systemctl --user enable --now`.
- Naming: `<vendor>-<unit>.service`.
- Validation: `systemctl --user is-enabled` and `is-active` must both succeed after install.

## Unit contract

Every unit (widget or service) is a self-contained directory:

```
<unit>/
  manifest.json   # id, type (widget|service), deps, stack, entrypoint
  src/            # scripts
  styles/         # CSS / style fragments
  install.sh      # idempotent copy installer
  README.md       # what it does, config, how to remove
```

## Theme contract

- NEVER hardcode colors. Every unit consumes the active palette (wallbash / Caelestia theme) through CSS variables or env tokens.
- A unit needing its own colors exposes them as config, never as literals in code.

## Config

- Centralized per unit: `manifest.json` `config` section or a single `env.conf` at unit root.
- No scattered config files.

## Lifecycle

New unit: change proposal → OpenSpec spec → factory scaffold → implementation → validation. Factory tooling lives in `factory/` (bash scripts: scaffold, install, update, validate).

## Validation — done means 100% functional

A unit is DONE only when ALL pass:

1. `bash -n` clean on every script.
2. `manifest.json` validates against the schema (`factory/validate`).
3. Clean install: `install.sh` runs on a fresh target.
4. Uninstall: `install.sh --remove` leaves no trace.
5. Service units: `systemctl --user is-enabled` && `is-active` after install.
6. Unit consumes the current theme (visual check against active wallbash palette).
7. Interactive/visual units: manual smoke test performed, noted in README.

## OpenSpec workflow

- `specs/` holds capability specs; every unit traces to a spec.
- `changes/` holds proposals; review before implementation.
- The factory scaffolds new units from specs.

## Layout

```
factory/     # CLI scripts: scaffold, install, update, validate
widgets/     # widget units
services/    # service units
shared/      # theme bridge, common libs
specs/       # openspec specs
docs/        # documentation
```

## Language

- Code, comments, docs, commit messages: English.
- User-facing chat: Spanish.

## Git

- Repo is git. Commit per unit milestone. Short messages.
