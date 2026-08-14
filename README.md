# ArchCustomWidgets

> Factory of installable **widgets & services** extending Caelestia (HyDE 3.x) on Arch Linux / Hyprland / Wayland.

<div align="center">

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-44A3F5?style=flat-square&logo=hyprland&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-5B3F8E?style=flat-square&logo=wayland&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![OpenSpec](https://img.shields.io/badge/OpenSpec-333333?style=flat-square&logo=markdown&logoColor=white)
![Caelestia](https://img.shields.io/badge/Caelestia-00BB31?style=flat-square&logoColor=white)
![7 units](https://img.shields.io/badge/7_units-0033A1?style=flat-square&logoColor=white)

</div>

---

## What it does

Spec-driven factory: every unit starts as an **OpenSpec proposal** → spec → factory scaffold → validated install. Each unit is self-contained: `manifest.json`, scripts, styles, an idempotent `install.sh`, and a `README.md`.

### Features

- **Copy, never symlinks** — plain file copies into `~/.config`, idempotent, reversible (`--remove` leaves no trace).
- **No hardcoded colors** — every unit consumes the active wallbash / Caelestia palette via CSS variables or env tokens.
- **Bash first** — no frameworks, no build step; python3 only as JSON helper when bash genuinely cannot express it.
- **Spec-driven lifecycle** — proposals, delta specs with `SHALL`/`MUST` requirements, factory scaffolding.
- **Sudo only where needed** — system-level files (vpn-surfshark) prompt for sudo; everything else is user-level.

---

## Architecture

```mermaid
flowchart TD
    subgraph Factory ["📦 Factory"]
        CLI["⚙️ factory/ CLI"]
        UNITS["🧩 widgets/ + services/"]
        CLI --> UNITS
    end

    subgraph Install ["📄 Install Layer"]
        INSTALL["🚀 install.sh"]
        INSTALL_LABEL["copy · idempotent · --remove"]
        UNITS --> INSTALL
        INSTALL --- INSTALL_LABEL
    end

    subgraph Target ["🎯 Target System"]
        CFG["📁 ~/.config/acw/<unit>/"]
        SD["🔄 systemd --user enable --now"]
        SYS["🔒 /etc systemd units\nsudo · vpn-surfshark"]
    end

    INSTALL --> CFG
    INSTALL --> SD
    INSTALL --> SYS

    CFG --> THEME["🎨 theme tokens\nwallbash palette"]
    SD --> THEME
    SYS --> THEME

    classDef factoryNode fill:#E8F0FE,stroke:#0033A1,stroke-width:2px,color:#0033A1
    classDef unitNode fill:#E8F0FE,stroke:#0033A1,stroke-width:2px,color:#0033A1
    classDef installNode fill:#E6F9ED,stroke:#00BB31,stroke-width:2px,color:#1a6e24
    classDef installLabel fill:none,stroke:none,color:#545B64
    classDef targetNode fill:#FFF8E1,stroke:#F59E0B,stroke-width:1px,color:#78350F
    classDef themeNode fill:#F3E8FF,stroke:#7C3AED,stroke-width:2px,color:#5B21B6

    class CLI factoryNode
    class UNITS unitNode
    class INSTALL installNode
    class INSTALL_LABEL installLabel
    class CFG,SD,SYS targetNode
    class THEME themeNode
```

---

## Units

| Unit | Type | What it does | Notes |
|---|---|---|---|
| `wallpaper` | service | Wallhaven downloader + rofi wallpaper selector + auto-theme pipeline (systemd `.path` → matugen + scheme set) | Keybinds `Ctrl+Super+T`, `Shift+Super+T`, `Ctrl+Shift+T` — wire manually |
| `scheme-rotator` | widget | Rotates the active color scheme | Keybind `Super+Alt+T` — wire manually |
| `waybar-power` | widget | Power menu module: lock / power / quit / reboot | |
| `waybar-theme` | widget | Theme switcher module for waybar | |
| `clipboard-rofi` | widget | Rofi clipboard manager | Keybind `Super+V` — wire manually |
| `vpn-surfshark` | service | Surfshark VPN quick-toggle (Caelestia quick-toggles `utilities.vpn`), `surfshark-connect`/`surfshark-disconnect` units | System-level files → sudo install. Known bug: fix reserved in change `fix-vpn-surfshark` |
| `quickshell-watchdog` | service | Watchdog for quickshell, systemd user unit + timer | |

---

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

---

## Contract & docs

- [`AGENTS.md`](AGENTS.md) — unit contract + "done means 100% functional" validation checklist.
- `docs/archcustomwidgets.html` — full technical documentation (single-file, PDF-ready).
- `openspec/` — spec-driven lifecycle (specs, changes, archive). Active change: `fix-vpn-surfshark`.
