# quickshell-watchdog

Restarts the Caelestia quickshell (`qs`) if it dies. Systemd **user** timer
running the live watchdog script from
`~/.config/hypr/scripts/caelestia-watchdog.sh` (copied byte-identical).

## What it does

Every minute (and 1 minute after boot), the timer fires
`acw-quickshell-watchdog.service`, a oneshot that runs
`caelestia-watchdog.sh`: if no `qs` process is running it sends a critical
notification and relaunches via `caelestia shell -d`.

## WantedBy fix

The timer ships `WantedBy=timers.target` in its `[Install]` section. Without
it, `systemctl --user enable` creates the enablement symlink but the timer is
not pulled in by the default target, so it never starts on its own. This unit
adds the missing `WantedBy`, making `enable --now` work as expected.

## Install

```bash
./install.sh
```

1. Copies `src/*` to `$INSTALL_ROOT/src` (`~/.config/acw/quickshell-watchdog`).
2. Copies `.service` + `.timer` to `~/.config/systemd/user/` (differing
   targets get a `.bak-<timestamp>` first).
3. `systemctl --user daemon-reload`, then `enable --now` the timer and
   validates it is enabled and active.

## Remove

```bash
./install.sh --remove
```

Disables the timer, removes both unit files from `~/.config/systemd/user/`,
`daemon-reload`, and removes `$INSTALL_ROOT`.
