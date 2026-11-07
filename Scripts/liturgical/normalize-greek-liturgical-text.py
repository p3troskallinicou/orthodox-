#!/usr/bin/env python3
"""Conservative normalization for extracted Greek liturgical text."""

from __future__ import annotations

import argparse
import re
import unicodedata
from pathlib import Path


def normalize_text(text: str) -> str:
    """Preserve wording and polytonic Greek while normalizing encoding/spacing."""
    text = unicodedata.normalize("NFC", text.replace("\r\n", "\n").replace("\r", "\n"))
    lines = [re.sub(r"[ \t]+$", "", line) for line in text.split("\n")]
    text = "\n".join(lines)
    text = re.sub(r"\n{4,}", "\n\n\n", text)
    return text.strip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(normalize_text(args.input.read_text(encoding="utf-8")), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
