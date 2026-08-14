# Design: migrate-custom-units

## Decisions

- **D1 — Single VPN chain.** Keep only the Caelestia quick-toggles button (shell.json `utilities.vpn` → `systemctl start surfshark-connect`). The parallel waybar vpn module (NetWorkLayerProtect scripts) is dropped from the factory; existing install may stay on the machine but is not part of the repo.
- **D2 — Root for system-level units.** Units shipping system-wide units (`/etc/systemd/system/surfshark-connect.service`, `surfshark-disconnect.service`, `/etc/nftables.conf`) run those install steps via `sudo` inside `install.sh`, clearly documented in the unit README. User-space copies keep working without sudo.
- **D3 — External repos as deps.** `NetWorkLayerProtect`, `ObsidianWitget`, `openclaw` remain external; `manifest.json` `deps` field references them, install.sh fails with a clear message if a required external path is missing.
- **D4 — Contract-first copy.** Scripts migrate byte-identical; the only permitted edits at migration time are: config path centralization (env.conf), theme token consumption, and bug fixes flagged in the inventory (e.g. `quickshell-watchdog` missing `WantedBy=`).

## References

- Unit contract and validation checklist: AGENTS.md (repo root).
- Inventory source: exploration of the live system (2026-08-14), archived in memory.
