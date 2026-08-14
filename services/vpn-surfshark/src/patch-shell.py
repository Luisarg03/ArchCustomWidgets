#!/usr/bin/env python3
"""Patch Caelestia shell.json with the VPN quick-toggle and provider block.

Adds the "vpn" entry to utilities.quickToggles and the utilities.vpn
provider block used by the Surfshark button. Idempotent: never writes when
the target state is already present, and never overwrites user edits.

CLI:
    patch-shell.py [--shell-json PATH]        # ensure entries exist
    patch-shell.py --remove [--shell-json PATH]  # remove only our entries
"""

import argparse
import copy
import json
import shutil
import sys
import time
from pathlib import Path

DEFAULT_SHELL_JSON = Path.home() / ".config" / "caelestia" / "shell.json"

VPN_TOGGLE = {"enabled": True, "id": "vpn"}

VPN_PROVIDER = {
    "enabled": True,
    "provider": [
        {
            "connectCmd": ["systemctl", "start", "surfshark-connect"],
            "disconnectCmd": ["systemctl", "start", "surfshark-disconnect"],
            "displayName": "Surfshark",
            "enabled": True,
            "iface": "surfshark",
            "name": "wireguard",
        }
    ],
}


def load_shell_json(path: Path) -> dict:
    """Read and parse shell.json, exiting with a clear message on failure."""
    if not path.is_file():
        sys.exit(f"ERROR: shell.json not found: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        sys.exit(f"ERROR: cannot parse {path}: {exc}")


def write_with_backup(path: Path, data: dict) -> None:
    """Back up the current file, then write the patched data."""
    backup = path.with_name(f"{path.name}.bak-{time.strftime('%Y%m%d-%H%M%S')}")
    shutil.copy2(path, backup)
    path.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
    print(f"Backed up {path} -> {backup}")
    print(f"Updated {path}")


def toggle_present(toggles: list) -> bool:
    """Return True when a vpn entry already exists in quickToggles."""
    return any(isinstance(t, dict) and t.get("id") == "vpn" for t in toggles)


def apply_install(data: dict) -> bool:
    """Add the vpn toggle and provider block when missing. Never clobber."""
    if not isinstance(data, dict):
        sys.exit("ERROR: shell.json root is not an object")
    utilities = data.setdefault("utilities", {})
    if not isinstance(utilities, dict):
        sys.exit("ERROR: utilities section is not an object")
    toggles = utilities.setdefault("quickToggles", [])
    if not isinstance(toggles, list):
        sys.exit("ERROR: utilities.quickToggles is not an array")

    changed = False
    if not toggle_present(toggles):
        toggles.append(copy.deepcopy(VPN_TOGGLE))
        print("Added vpn quick-toggle entry")
        changed = True
    else:
        print("vpn quick-toggle entry already present")

    if "vpn" not in utilities:
        utilities["vpn"] = copy.deepcopy(VPN_PROVIDER)
        print("Added utilities.vpn provider block")
        changed = True
    elif utilities["vpn"] == VPN_PROVIDER:
        print("utilities.vpn provider block already present")
    else:
        print("WARN: utilities.vpn exists with different values; left untouched")
    return changed


def apply_remove(data: dict) -> bool:
    """Remove only entries that exactly match this unit's own values."""
    if not isinstance(data, dict):
        sys.exit("ERROR: shell.json root is not an object")
    utilities = data.get("utilities")
    if not isinstance(utilities, dict):
        print("No utilities section; nothing to remove")
        return False

    changed = False
    toggles = utilities.get("quickToggles")
    if isinstance(toggles, list):
        for entry in list(toggles):
            if entry == VPN_TOGGLE:
                toggles.remove(entry)
                print("Removed vpn quick-toggle entry")
                changed = True
            elif isinstance(entry, dict) and entry.get("id") == "vpn":
                print("WARN: vpn quick-toggle modified by user; not removed")

    vpn = utilities.get("vpn")
    if vpn == VPN_PROVIDER:
        del utilities["vpn"]
        print("Removed utilities.vpn provider block")
        changed = True
    elif vpn is not None:
        print("WARN: utilities.vpn modified by user; not removed")
    return changed


def parse_args(argv: list | None = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--shell-json",
        type=Path,
        default=DEFAULT_SHELL_JSON,
        help="Path to the Caelestia shell.json file",
    )
    parser.add_argument(
        "--remove",
        action="store_true",
        help="Remove this unit's entries instead of adding them",
    )
    return parser.parse_args(argv)


def main(argv: list | None = None) -> None:
    """Entry point."""
    args = parse_args(argv)
    data = load_shell_json(args.shell_json)
    changed = apply_remove(data) if args.remove else apply_install(data)
    if changed:
        write_with_backup(args.shell_json, data)
    elif args.remove:
        print("Nothing to remove (entries missing or modified by user)")
    else:
        print("Already configured: no changes needed")


if __name__ == "__main__":
    main()
