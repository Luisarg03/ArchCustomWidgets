# factory-units

## Requirements

### Requirement: Factory validates unit manifests

The factory MUST ship a `factory/validate` script that checks a unit's `manifest.json` against the unit schema before install.

#### Scenario: Valid manifest passes

- Given a unit directory containing a valid `manifest.json`
- When `factory/validate <unit>` runs
- Then it exits 0 and reports the unit as valid

#### Scenario: Invalid manifest fails

- Given a unit directory containing a malformed `manifest.json`
- When `factory/validate <unit>` runs
- Then it exits non-zero and prints the schema errors

### Requirement: Custom units migrate as installable units

Every hand-customized widget/service from the live Caelestia setup (inventory in proposal.md) MUST ship as a unit directory following the AGENTS.md contract: `manifest.json`, `src/`, `install.sh` (idempotent copy, `--remove` leaves no trace), `README.md`.

#### Scenario: Install is idempotent and reversible

- Given a unit directory following the contract
- When `install.sh` runs twice on the same target
- Then the second run succeeds without errors and existing user files were backed up with a `.bak-<timestamp>` suffix

#### Scenario: Uninstall leaves no trace

- Given an installed unit
- When `install.sh --remove` runs
- Then every file and unit the installer created is removed

### Requirement: Wallpaper pipeline ships as a service unit

The `wallpaper` unit MUST bundle the Wallhaven downloader, the rofi wallpaper selector and the auto-theme pipeline (systemd `.path` triggering matugen + scheme set).

#### Scenario: Auto-theme triggers on wallpaper change

- Given the unit installed
- When `~/.local/state/caelestia/wallpaper/path.txt` changes
- Then the wallpaper-theme service runs and the active scheme is regenerated

### Requirement: VPN quick toggle ships as widget + service unit

The `vpn-surfshark` unit MUST ship the Caelestia quick-toggles shell.json delta (`utilities.vpn` provider) plus the system-level `surfshark-connect`/`surfshark-disconnect` units; system-level install steps run via `sudo` inside `install.sh`.

#### Scenario: Toggle activates the VPN

- Given the unit installed
- When the quick-toggles VPN button is pressed
- Then `systemctl start surfshark-connect` runs and the `surfshark` interface comes up

#### Scenario: Root steps run via sudo

- Given a user running `install.sh` for the unit
- When system-level files must be copied to `/etc/systemd/system/`
- Then the installer prompts for `sudo` only for those steps

### Requirement: Waybar modules ship as widget units

The `waybar-power` and `waybar-theme` units MUST ship their scripts, state/config files and waybar config fragments.

#### Scenario: Module produces JSON for waybar

- Given a waybar widget unit installed
- When waybar executes the module script
- Then it prints valid JSON with `text` (and `tooltip` where defined) on stdout

### Requirement: Support services ship as service units

The `quickshell-watchdog` unit MUST ship as a systemd user unit (`.service` + `.timer`), enabled with the system; the unit includes the missing `WantedBy=` fix.

#### Scenario: Services enabled with the system

- Given a service unit installed
- When `systemctl --user is-enabled` and `is-active` run
- Then both succeed

### Requirement: Every unit passes the AGENTS.md validation checklist

A unit MUST be DONE only when all pass: `bash -n` on every script, manifest validates, clean install on fresh target, uninstall leaves no trace, service units enabled and active, theme tokens consumed (no hardcoded colors).

#### Scenario: Full checklist passes

- Given a unit candidate for release
- When the AGENTS.md checklist runs against it
- Then all seven checks pass
