# fix-vpn-surfshark

## Why

The Caelestia quick-toggles VPN button (unit `vpn-surfshark`) does not work as expected: pressing connect never brings up the `surfshark` WireGuard interface. Diagnosis (2026-08-14, read-only):

- Both Surfshark daemons are dead and disabled: `surfsharkd` (user) and `surfsharkd2` (system) → `inactive (dead)`, `disabled`.
- `journalctl --user -u surfsharkd` shows `JS ERROR: Gio.DBusError ... ServiceUnknown: The name is not activatable` (4x) — the gjs daemon tried to activate a D-Bus service that is not registered.
- `ip link show`: no `surfshark` interface; `wg show`: no WireGuard interfaces.
- Live systemd units match repo copies verbatim (no drift): connect = `wg-quick up surfshark` + nft kill-switch (output chain policy drop), disconnect = `nft -f /etc/nftables.conf` + `wg-quick down surfshark`.
- Gaps requiring root: `/etc/wireguard/surfshark.conf` (unreadable, PostUp/PreDown unverified), live `nft list ruleset` state, polkit rules for user-triggered system unit start.

## What Changes

Fix the toggle path so connect reliably brings up the tunnel and disconnect tears it down cleanly. Scope: `services/vpn-surfshark/` unit (systemd units, install.sh, shell.json delta) and/or enablement of Surfshark daemons — decision pending investigation.

## Implementation Plan

Not started by design — this change is reserved. Investigate first (tasks.md), then implement the fix once the root cause is confirmed.

## Non-goals

- No redesign of the WireGuard + nft kill-switch approach.
- No changes to the Surfshark GUI app.
- No secret handling: `/etc/wireguard/surfshark.conf` stays out of the repo.
