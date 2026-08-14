# vpn-surfshark

Surfshark VPN wired into the Caelestia quick-toggles button, with a system-level
WireGuard + nftables kill switch.

## What it ships

| File | Live source | Role |
|---|---|---|
| `src/surfshark-connect.service` | `/etc/systemd/system/` | `wg-quick up surfshark` + nft output kill-switch rules |
| `src/surfshark-disconnect.service` | `/etc/systemd/system/` | restore `/etc/nftables.conf` + `wg-quick down surfshark` |
| `src/nftables.conf` | `/etc/nftables.conf` | system nft config (explicit `output` chain for the kill switch) |
| `src/patch-shell.py` | authored | idempotent shell.json delta (VPN quick-toggle + provider) |

## Prerequisites

- `/etc/wireguard/surfshark.conf` must exist. `wg-quick up surfshark` reads it;
  without it the connect unit fails. It is **not** shipped (contains secrets).
- Packages: `wireguard-tools`, `nftables` (and the `surfshark` wg config set).

## Install

```bash
./install.sh
```

What it does, in order:

1. Copies `src/*` to `$INSTALL_ROOT/src` (`~/.config/acw/vpn-surfshark` by
   default). Existing differing targets get a `.bak-<timestamp>` first.
2. Runs `patch-shell.py`: ensures `utilities.quickToggles` contains
   `{"enabled": true, "id": "vpn"}` and `utilities.vpn` has the Surfshark
   WireGuard provider block. `shell.json` is backed up to
   `shell.json.bak-<timestamp>` before the first write. Never overwrites a
   provider block the user has changed.
3. sudo steps (password prompt once):
   - copies both `.service` units to `/etc/systemd/system/` (backup rule),
   - backs up `/etc/nftables.conf` if it differs, then overwrites it,
   - `systemctl daemon-reload`.
   The service is **not** started: the button starts/stops it on demand.
4. Checks `/etc/wireguard/surfshark.conf` exists and warns if not.

## How the button works

The Caelestia quick-toggle `vpn` reads `utilities.vpn` and runs
`connectCmd`/`disconnectCmd` from the provider block. Toggling it runs
`systemctl start surfshark-connect` (up + kill switch) or
`systemctl start surfshark-disconnect` (restore nft + down).

## Remove

```bash
./install.sh --remove
```

- Reverts shell.json via `patch-shell.py --remove` (only removes entries that
  exactly match this unit's values; user-modified entries are left and reported).
- Removes both units from `/etc/systemd/system/`, restores `/etc/nftables.conf`
  from the newest `.bak-*` (or removes it with a warning if no backup exists),
  `daemon-reload`.
- Removes `$INSTALL_ROOT`.

## Security note

`/etc/wireguard/` holds private keys and is intentionally not shipped. The
kill-switch rules in `src/nftables.conf` come from the live system; review them
before installing on a machine with different network needs (e.g. Docker or an
SSH server: see the comments in the file).
