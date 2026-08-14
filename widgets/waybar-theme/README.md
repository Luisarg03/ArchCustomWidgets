# waybar-theme

Waybar (and wofi) style rotator. Each run switches to the next theme in a
fixed list of 11 (`style_1.css` … `style_11.css`), copies it over
`~/.config/waybar/style.css` (the file waybar actually loads), restarts
waybar, and persists the current selection in
`~/.config/waybar/.current_style_index`. If the matching
`~/.config/wofi/themes/wofi_style_N.css` exists, it is applied to wofi too.

## Install

```bash
./install.sh
```

Copies the unit to `$INSTALL_ROOT` (default `~/.config/acw/waybar-theme`),
including the bundled `styles/style_1.css` … `style_11.css` reference set.
Idempotent: existing differing files are backed up as `<file>.bak-<timestamp>`.

Remove (leaves no trace):

```bash
./install.sh --remove
```

## Usage

Run the rotator (e.g. bound to a keybind in your WM config):

```bash
~/.config/acw/waybar-theme/src/theme.sh
```

Each invocation advances one theme and restarts waybar.

## Bundled styles vs. live styles

The `styles/` directory here is a **reference snapshot** of the styles that
lived in `~/.config/waybar/styles/` when this unit was packaged. The script
itself operates on the **live** `~/.config/waybar/styles/` directory (paths are
hardcoded at the top of `src/theme.sh`) — it reads `style_N.css` files from
there and writes `~/.config/waybar/style.css`.

If the live styles have changed since packaging (new look, added or removed
style files):

- To keep the live set as-is, nothing to do — the rotator uses whatever is in
  `~/.config/waybar/styles/`.
- To refresh the bundled reference set, copy the live styles back:
  ```bash
  cp ~/.config/waybar/styles/style_*.css <repo>/widgets/waybar-theme/styles/
  ```
- To use a different set of styles, edit the `STYLES=(...)` list and the
  paths at the top of `src/theme.sh`.

`.current_style_index` is created on first run by the script and stores the
index of the current theme (0-based).
