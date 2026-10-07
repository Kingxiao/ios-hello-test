#!/usr/bin/env python3
"""Export named XCTest screenshots and reject incomplete evidence."""
import argparse
import json
from pathlib import Path
import re
import shutil


def export(raw: Path, output: Path, prefix: str, with_flow: bool = False):
    expected = {
        f"{prefix}-{language}-{size}-{state}"
        for language in ("en", "zh-Hans")
        for size in ("default", "ax-xxxl")
        for state in ("count-2", "reset-0")
    }
    if with_flow:
        expected.update(
            f"{prefix}-flow-{step}"
            for step in (
                "01-launch", "02-increment", "03-decrement",
                "04-reset", "05-floor", "06-persistence",
            )
        )
    exported = set()
    output.mkdir(parents=True, exist_ok=True)
    for test in json.loads((raw / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            filename = attachment["exportedFileName"]
            if not filename.lower().endswith((".png", ".jpg", ".jpeg")):
                continue
            source = (raw / filename).resolve()
            if not source.is_relative_to(raw.resolve()):
                raise ValueError("Attachment path escapes export directory")
            name = re.sub(
                r"_\d+_[0-9A-Fa-f-]{36}\.\w+$", "",
                attachment["suggestedHumanReadableName"],
            )
            if name.startswith("Screenshot"):
                name = "failure-" + source.stem
            if Path(name).name != name:
                raise ValueError("Unsafe screenshot name")
            data = source.read_bytes()
            if filename.lower().endswith(".png") and not data.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError(f"Invalid PNG attachment: {filename}")
            target = output / (name + source.suffix.lower())
            if target.exists():
                raise ValueError(f"Duplicate screenshot name: {name}")
            shutil.copyfile(source, target)
            exported.add(name)
    missing = expected - exported
    if missing:
        raise ValueError("Missing screenshots: " + ", ".join(sorted(missing)))
    print(f"Evidence OK: {len(expected)} required screenshots exported")
    return exported


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("prefix")
    parser.add_argument("--with-flow", action="store_true")
    args = parser.parse_args()
    export(args.raw, args.output, args.prefix, args.with_flow)
