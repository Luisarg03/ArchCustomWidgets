# Tasks: add-task-notes

- [x] Scaffold unit `widgets/task-notes/` (manifest.json, src/, install.sh, README.md)
- [x] `src/capture.qml`: standalone Quickshell window (qs -p) with textbox; appends raw note to notes.jsonl
- [x] `src/process_notes.sh`: offset-based idempotent processing; opencode run strict-JSON rewrite + classify; error field on failure
- [x] `src/acw-task-notes.path` + `.service`: PathChanged on notes.jsonl → oneshot
- [x] `src/task-notes-tab.qml`: shell dashboard tab (FileView + watchChanges), type badge, check toggle
- [x] `src/toggle_note.sh`: flip status open/done
- [x] `install.sh`: unit install + systemd user units enable --now + shell modules/dashboard override (backup + patch Content.qml) + `--remove` reverses all
- [x] `manifest.json` + `README.md`: config, keybind (documented, not auto-applied), remove instructions, shell re-sync notes
- [x] Validation: bash -n, manifest validate, clean install/uninstall, services enabled+active, visual smoke test
