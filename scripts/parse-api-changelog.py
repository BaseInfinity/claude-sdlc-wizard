#!/usr/bin/env python3
"""Parse Anthropic API changelog markdown and print new entries since a date.

Source: https://platform.claude.com/docs/en/release-notes/api.md
Appending `.md` to Mintlify doc paths returns raw markdown — more stable than
HTML scraping (per Codex finding #3 on PR for roadmap #100).

Usage:
    parse-api-changelog.py <changelog.md> <last-iso-date>

Output (stdout, tab-separated):
    ISO_DATE\tORIGINAL_DATE_TEXT\tBULLET_SUMMARY
    ...

BULLET_SUMMARY captures the first 1-2 bullets under each date header, joined
with " | " and truncated to ~200 chars. Gives issue-body readers a hint of
WHAT changed without pulling the full changelog.

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

DATE_LINE = re.compile(r"^(#{2,4})\s+(.+?)\s*$", re.MULTILINE)
BULLET_LINE = re.compile(r"^\s*[-*+]\s+(.+?)\s*$")
ORDINAL = re.compile(r"(\d+)(st|nd|rd|th)", re.IGNORECASE)
DATE_FORMATS = ("%B %d, %Y", "%b %d, %Y")
BULLET_MAX = 200
BULLET_TAKE = 2


def _extract_bullets(lines: list[str], start: int, end: int) -> str:
    """Join first BULLET_TAKE bullets between lines[start:end] into a summary."""
    taken: list[str] = []
    for i in range(start, end):
        m = BULLET_LINE.match(lines[i])
        if not m:
            continue
        taken.append(m.group(1).strip())
        if len(taken) >= BULLET_TAKE:
            break
    if not taken:
        return ""
    joined = " | ".join(taken)
    if len(joined) > BULLET_MAX:
        joined = joined[: BULLET_MAX - 1].rstrip() + "…"
    return joined


def _try_parse_date(raw: str):
    """Return a date object if raw matches our accepted formats, else None."""
    normalized = ORDINAL.sub(r"\1", raw)
    for fmt in DATE_FORMATS:
        try:
            return datetime.strptime(normalized, fmt).date()
        except ValueError:
            continue
    return None


def parse_dates(markdown: str) -> list[tuple[str, str, str]]:
    """Return [(iso_date, original_header_text, bullet_summary), ...].

    Bullet search is bounded by the next DATE header, not any markdown header.
    Non-date sub-headers (e.g. `#### SDKs`) inside a release block don't
    terminate the search, so bullets after them are still captured.
    """
    lines = markdown.splitlines()
    # Scan once, keeping only date-parseable headers for boundary calculation.
    date_hits: list[tuple[int, str]] = []  # (line_idx, raw_header_text)
    for idx, line in enumerate(lines):
        m = DATE_LINE.match(line)
        if not m:
            continue
        raw = m.group(2).strip()
        if _try_parse_date(raw) is None:
            continue
        date_hits.append((idx, raw))

    results: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for i, (line_idx, raw) in enumerate(date_hits):
        parsed = _try_parse_date(raw)
        if parsed is None:
            continue  # defensive; filtered above
        iso = parsed.isoformat()
        if iso in seen:
            continue
        seen.add(iso)
        bullet_end = date_hits[i + 1][0] if i + 1 < len(date_hits) else len(lines)
        bullets = _extract_bullets(lines, line_idx + 1, bullet_end)
        results.append((iso, raw, bullets))
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

    new_entries = [(iso, raw, bullets) for iso, raw, bullets in entries if iso > last]
    for iso, raw, bullets in new_entries:
        print(f"{iso}\t{raw}\t{bullets}")

    # Order-independent: if Anthropic ever reshuffles the page we still get the
    # actual newest date instead of silently rewinding state on the next run.
    latest = max(iso for iso, _, _ in entries)
    (TMPDIR / "latest_date.txt").write_text(latest, encoding="utf-8")
    (TMPDIR / "new_count.txt").write_text(str(len(new_entries)), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
