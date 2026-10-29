#!/usr/bin/env python3
"""Checks that every built-in theme file and every _collection.json is valid JSON and only holds known settings."""
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
known = set(re.findall(r'key: "([A-Z_0-9]+)"', (root / "contents/ui/parameters.js").read_text()))
# Settings of the original HTML version that the wallpaper reads or ignores
known |= {"BG_COLOR", "COLORS", "RESET_AFTER_SECONDS", "CLICK_SPAWN_ENABLED", "CURSOR_SPARKS_ENABLED",
          "CURSOR_SPARK_RATE", "FPS_COUNTER_ENABLED", "FPS_COUNTER_POSITION", "FPS_COUNTER_SIZE",
          "FPS_COUNTER_COLOR", "TARGET_FPS"}

errors = 0
files = sorted((root / "contents/themes").rglob("*.json"))
for path in files:
    try:
        data = json.loads(path.read_text())
    except ValueError as error:
        print(f"{path.relative_to(root)}: invalid JSON ({error})")
        errors += 1
        continue
    if not isinstance(data, dict):
        print(f"{path.relative_to(root)}: not an object")
        errors += 1
        continue
    for key in data:
        if key not in known:
            print(f"{path.relative_to(root)}: unknown setting {key}")
            errors += 1

print(f"{len(files)} theme files checked, {errors} problem(s)")
sys.exit(1 if errors else 0)
