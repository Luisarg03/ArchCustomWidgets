# docs

- [`archcustomwidgets.md`](archcustomwidgets.md) — source for the technical reference (edit here). Styled PDF-ready HTML is in [`archcustomwidgets.html`](archcustomwidgets.html) (generated / kept in sync).
- [`keybinds-map.md`](keybinds-map.md) — authoritative live Hyprland keybind map. Check before adding any new combo; re-run `hyprctl binds -j | jq` to refresh.
- Unit READMEs: `widgets/*/README.md`, `services/*/README.md` — per-unit docs (What / Prereqs / Install / Keybinds / Config / Remove).

> `docs/archcustomwidgets.html` header comment marks the source file. Prefer editing the `.md` and running `factory/docs` (falls back to `pandoc` or `cat`) to regenerate.

