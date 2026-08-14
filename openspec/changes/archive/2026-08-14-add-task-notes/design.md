# Design: add-task-notes

## Decisions

- **D1 — Capture surface: standalone Quickshell window.** `qs -p <capture.qml>` floats its own window; does not touch the Caelestia shell. Keybind Super+G (free combo, verified in keybinds.conf) documented in README, applied manually by the user.
- **D2 — Storage: append-only JSONL.** `~/.local/state/caelestia/notes.jsonl`, alongside existing notifs.json (established state home). Record: `{id, raw, title, type: task|idea|thought, status: open|done, created_at, error?}`. No sqlite3 — a few notes/day, grep/append is enough.
- **D3 — LLM backend: `opencode run` spawn per note.** `opencode run -m opencode-go/deepseek-v4-flash "<strict JSON prompt>"`. Reuses the user's opencode login (zen/go gateways), no new keys, no Ollama. ~5-15s cold boot is fine at low frequency. Fallback: if the call fails or returns invalid JSON, keep the raw record with `error` field — never lose the note; retried on next trigger.
- **D4 — Processing trigger: systemd user `.path` unit.** `PathChanged=~/.local/state/caelestia/notes.jsonl` → oneshot `acw-task-notes.service` runs process_notes.sh. Pattern copied from caelestia-wallpaper-theme.path (already proven). process_notes.sh tracks processed offset (`.state` file at unit root) for idempotency.
- **D5 — Render: Caelestia shell dashboard tab via module override.** Caelestia has NO widget plugin mechanism and tabs are a hardcoded JS array in `/etc/xdg/quickshell/caelestia/modules/dashboard/Content.qml` (L27-55 array, L130-190 components). Path: copy the FULL `modules/dashboard/` tree to `~/.config/quickshell/caelestia/modules/dashboard/` (relative imports like `import "dash"` break if only Content.qml is copied), patch Content.qml (append tab entry in `allTabs` + a `Component { id: taskComponent }`), add `task-notes-tab.qml` reusing the FileView+watchChanges watcher pattern from the dead OpenCodeCostTab.qml. install.sh backs up any pre-existing user files; `--remove` deletes the override tree (restoring system shell behavior).
- **D6 — Fork-drift cost (accepted).** Quickshell prefers the user dir when shell.qml exists, so the user's override survives `caelestia-shell` package updates — but it also freezes: new upstream tabs/API changes in `modules/dashboard/` won't reach the user copy. Re-sync is a manual merge of Content.qml + task-notes-tab.qml against `pacman -Ql caelestia-shell | grep modules/dashboard` changes. Documented in README.
- **D7 — Unit manifest type.** `type: "widget"` (primary entity is UI), service components ship inside the same unit dir per the opencode-stats pattern (service + timer inside one unit). Mirror vpn-surfshark's manifest if it declares a widget+service mix.

## References

- Unit contract + validation checklist: AGENTS.md (repo root).
- Caelestia shell structure: /etc/xdg/quickshell/caelestia/ (pacman-owned), modules/dashboard/Content.qml tabs array.
- Storage precedent: ~/.local/state/caelestia/ (notifs.json).
- .path pattern: ~/.config/systemd/user/caelestia-wallpaper-theme.path.
- LLM precedent: opencode CLI docs (spawn per call recommended at low frequency).
