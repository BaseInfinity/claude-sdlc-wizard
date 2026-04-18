#!/usr/bin/env python3
"""Parse Anthropic API changelog markdown and print new entries since a date.

Source: https://platform.claude.com/docs/en/release-notes/api.md
Appending `.md` to Mintlify doc paths returns raw markdown — more stable than
HTML scraping (per Codex finding #3 on PR for roadmap #100).

Usage:
    parse-api-changelog.py <changelog.md> <last-iso-date>

Output (stdout, tab-separated):
    ISO_DATE\tORIGINAL_DATE_TEXT
    ...

Also writes (to $TMPDIR if set, else /tmp):
    latest_date.txt — most recent ISO date found (or last-iso if none)
    new_count.txt   — integer count of entries newer than last-iso

Exit 0 on success (including 0 new entries). Non-zero only on parse failure.
"""
from __future__ import annotations

import os
import re
import sys
from datetime import datetime
from pathlib import Path

TMPDIR = Path(os.environ.get("TMPDIR", "/tmp"))

DATE_LINE = re.compile(r"^#{2,4}\s+(.+?)\s*$", re.MULTILINE)
ORDINAL = re.compile(r"(\d+)(st|nd|rd|th)", re.IGNORECASE)
DATE_FORMATS = ("%B %d, %Y", "%b %d, %Y")


def parse_dates(markdown: str) -> list[tuple[str, str]]:
    """Return [(iso_date, original_text), ...] in page order (newest first)."""
    results: list[tuple[str, str]] = []
    seen: set[str] = set()
    for match in DATE_LINE.finditer(markdown):
        raw = match.group(1).strip()
        normalized = ORDINAL.sub(r"\1", raw)
        for fmt in DATE_FORMATS:
            try:
                parsed = datetime.strptime(normalized, fmt).date()
            except ValueError:
                continue
            iso = parsed.isoformat()
            if iso in seen:
                break
            seen.add(iso)
            results.append((iso, raw))
            break
    return results


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: parse-api-changelog.py <markdown-file> <last-iso-date>", file=sys.stderr)
        return 2
    md_path = Path(sys.argv[1])
    last = sys.argv[2].strip()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", last):
        print(f"invalid last-iso-date: {last!r} (expected YYYY-MM-DD)", file=sys.stderr)
        return 2
    text = md_path.read_text(encoding="utf-8")
    entries = parse_dates(text)
    if not entries:
        print("no date headers found — source format may have changed", file=sys.stderr)
        return 1

    new_entries = [(iso, raw) for iso, raw in entries if iso > last]
    for iso, raw in new_entries:
        print(f"{iso}\t{raw}")

    latest = entries[0][0]  # newest in page order
    (TMPDIR / "latest_date.txt").write_text(latest, encoding="utf-8")
    (TMPDIR / "new_count.txt").write_text(str(len(new_entries)), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
