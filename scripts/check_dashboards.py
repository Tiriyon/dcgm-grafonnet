#!/usr/bin/env python3
"""Sanity-check rendered dashboard JSON files.

Checks:
  - Every dashboard has at least one panel.
  - The minimum panel y position is 0 (no empty space at the top from mis-rebased panels).

Prints a panel layout table for each dashboard so the output doubles as a
visual inspection aid.

Usage:
  python3 scripts/check_dashboards.py output/*.json
"""
import glob
import json
import sys


def check(path: str) -> list[str]:
    with open(path) as f:
        d = json.load(f)

    panels = d.get("panels", [])
    errors = []

    if not panels:
        errors.append(f"{path}: no panels found")
        return errors

    print(f"\n{path}  ({d.get('title', '?')})")
    for p in panels:
        gp = p["gridPos"]
        title = p.get("title") or p.get("type", "?")
        print(f"  y={gp['y']:3d}  h={gp['h']}  w={gp['w']:2d}  x={gp['x']:2d}  {title}")

    min_y = min(p["gridPos"]["y"] for p in panels)
    if min_y != 0:
        errors.append(
            f"{path}: first panel y={min_y}, expected 0 "
            f"(possible mis-rebased y positions)"
        )

    return errors


def main() -> None:
    paths = sorted(sys.argv[1:]) or sorted(glob.glob("output/*.json"))
    if not paths:
        print("No dashboard JSON files found.", file=sys.stderr)
        sys.exit(1)

    all_errors: list[str] = []
    for path in paths:
        all_errors.extend(check(path))

    if all_errors:
        print("\nFAIL:")
        for e in all_errors:
            print(f"  {e}", file=sys.stderr)
        sys.exit(1)

    print(f"\nOK — {len(paths)} dashboard(s) passed.")


if __name__ == "__main__":
    main()
