# opencode-stats

Fetches opencode usage statistics into
`~/.local/share/caelestia/opencode_stats.json`, the file the Caelestia shell
widget reads to display monthly cost and token usage.

## What it does

Every 5 minutes (and 2 minutes after boot), the user timer fires
`acw-opencode-stats.service`: a oneshot running
`fetch_opencode_stats.py` (copied byte-identical from the live Caelestia
install at `/etc/xdg/quickshell/caelestia/scripts/`) with its stdout
redirected to the stats file. The script reads `~/.local/share/opencode/opencode.db`
read-only and always emits valid JSON, including an `error` field when the
database is missing or locked.

## Output path contract

The output path is `~/.local/share/caelestia/opencode_stats.json` (via
`$HOME`), identical to the live setup, so the existing quickshell widget keeps
reading it without changes. The unit creates the directory on each run
(`ExecStartPre`).

## Install

```bash
./install.sh
```

1. Copies `src/*` to `$INSTALL_ROOT/src` (`~/.config/acw/opencode-stats`).
2. Copies `.service` + `.timer` to `~/.config/systemd/user/` (differing
   targets get a `.bak-<timestamp>` first).
3. `systemctl --user daemon-reload`, then `enable --now` the timer and
   validates it is enabled and active.

## Remove

```bash
./install.sh --remove
```

Disables the timer, removes both unit files from `~/.config/systemd/user/`,
`daemon-reload`, and removes `$INSTALL_ROOT`. The generated
`opencode_stats.json` is left in place (the widget may still want it).
