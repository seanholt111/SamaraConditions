"""python -m samara fixture|live|tides"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

from samara.build import ROOT, build_fixture, build_live, publish, validate, write_document


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build conditions.json")
    sub = parser.add_subparsers(dest="cmd", required=True)

    fixture = sub.add_parser("fixture")
    fixture.add_argument("--out", type=Path, default=ROOT / "fixtures" / "conditions.fixture.json")

    live = sub.add_parser("live")
    live.add_argument("--out", type=Path, default=ROOT / "site" / "conditions.json")
    live.add_argument("--previous", type=Path, default=None)

    args = parser.parse_args(argv)
    if args.cmd == "fixture":
        document = build_fixture()
        errors = validate(document)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        write_document(args.out, document)
        print(f"wrote {args.out}")
        return 0

    previous_path = args.previous or args.out
    previous = json.loads(previous_path.read_text()) if previous_path.exists() else None
    try:
        candidate = build_live(datetime.now(), previous)
    except Exception as exc:
        print(f"build failed: {exc}", file=sys.stderr)
        if previous is None:
            return 1
        print("keeping the previous file")
        return 0
    try:
        document, replaced = publish(candidate, previous_path if previous_path.exists() else None)
    except Exception as exc:
        print(exc, file=sys.stderr)
        return 1
    if replaced:
        write_document(args.out, document)
        print(f"wrote {args.out}")
    else:
        print("kept the previous file")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
