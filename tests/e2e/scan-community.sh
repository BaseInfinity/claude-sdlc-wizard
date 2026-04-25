#!/bin/bash
# Roadmap #207: community feature-discovery scanner.
#
# Scans transcript text for /slash-command mentions and emits any not in the
# known-allowlist. Designed to be run by the maintainer on a Max subscription
# against transcripts pulled from Reddit / HN / Discord / CC GitHub Discussions
# (per #231 Phase 3 plan: "scan-community → port to tests/e2e/scan-community.sh").
#
# Usage:
#   ./scan-community.sh path/to/transcript.txt [path/to/another.txt ...]
#   ./scan-community.sh -                       # read stdin
#
# Output: JSON to stdout
#   { "scan_date": "YYYY-MM-DD",
#     "input_files": [...],
#     "candidates": [
#       { "slash": "/newthing",
#         "count": 3,
#         "sample": "Reddit r/ClaudeAI: Did you all see /newthing in CC..." }
#     ] }
#
# Exit codes:
#   0 - scan completed (candidates may be empty)
#   1 - input not readable / no input given

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLIST="$SCRIPT_DIR/known-slash-commands.txt"

if [ "$#" -eq 0 ]; then
    echo "error: no input given. Usage: $0 path/to/transcript.txt [...] | $0 -" >&2
    exit 1
fi

if [ ! -f "$ALLOWLIST" ]; then
    echo "error: allowlist file missing: $ALLOWLIST" >&2
    exit 1
fi

# Working files. Keep these in TMPDIR so test sandboxes that allow $TMPDIR work.
TMP="${TMPDIR:-/tmp}"
ALLOW_TMP=$(mktemp "$TMP/scan-allow.XXXXXX")
INPUT_TMP=$(mktemp "$TMP/scan-input.XXXXXX")
MATCHES_TMP=$(mktemp "$TMP/scan-matches.XXXXXX")
trap 'rm -f "$ALLOW_TMP" "$INPUT_TMP" "$MATCHES_TMP" 2>/dev/null' EXIT

# Build the allowlist set (strip comments + blank lines, lowercase).
/usr/bin/grep -vE '^[[:space:]]*(#|$)' "$ALLOWLIST" | tr '[:upper:]' '[:lower:]' | sort -u > "$ALLOW_TMP"

# Concatenate all inputs into one buffer for scanning.
input_files=()
for arg in "$@"; do
    if [ "$arg" = "-" ]; then
        cat >> "$INPUT_TMP"
        input_files+=("(stdin)")
    elif [ -f "$arg" ]; then
        # Use redirection rather than `cat "$arg"` so dash-leading filenames
        # like "-notes.txt" aren't interpreted as cat options.
        cat < "$arg" >> "$INPUT_TMP"
        echo "" >> "$INPUT_TMP"  # ensure newline boundary between files
        input_files+=("$arg")
    else
        echo "error: input file not readable: $arg" >&2
        exit 1
    fi
done

# Build input_files JSON array via python.
input_files_json=$(printf '%s\n' "${input_files[@]}" | python3 -c "
import sys, json
print(json.dumps([line.rstrip() for line in sys.stdin if line.strip()]))
")

SCAN_DATE=$(date +%Y-%m-%d)

# Extract each slash-command + a sample window around it (for context).
# Pattern: '/' followed by [a-z], then [a-z0-9-]*. Length >= 4 (drop /a, /ab,
# /a1 noise that's almost always a path fragment or unrelated). Match is done
# on a lowercased copy of the line so /Help and /HELP normalize to /help and
# get filtered through the allowlist correctly.
# Output format: <slash><tab><sample-window>
# The sample-window is up to 100 chars before + 100 chars after the matched
# slash command, drawn from the ORIGINAL line (preserving case in the sample
# even though matching is case-insensitive).
awk '
{
    orig = $0
    line_lc = tolower($0)
    s = line_lc
    offset = 0
    while (match(s, /\/[a-z][a-z0-9-]*/)) {
        rstart_in_orig = offset + RSTART
        token_lc = substr(s, RSTART, RLENGTH)
        if (length(token_lc) >= 4) {
            # Extract sample window around the match in the original line.
            sample_start = rstart_in_orig - 100
            if (sample_start < 1) sample_start = 1
            sample_len = RLENGTH + 200
            sample = substr(orig, sample_start, sample_len)
            # Strip trailing/leading whitespace and newlines from the sample.
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", sample)
            printf "%s\t%s\n", token_lc, sample
        }
        offset = offset + RSTART + RLENGTH - 1
        s = substr(s, RSTART + RLENGTH)
    }
}
' "$INPUT_TMP" > "$MATCHES_TMP"

# Build the candidates JSON via python (cleaner than awk/jq for sample context).
CANDIDATES_JSON=$(ALLOW="$ALLOW_TMP" MATCHES="$MATCHES_TMP" python3 -c "
import json, os

with open(os.environ['ALLOW']) as f:
    allow = {ln.strip() for ln in f if ln.strip()}

counts, samples = {}, {}
with open(os.environ['MATCHES']) as f:
    for line in f:
        parts = line.rstrip('\n').split('\t', 1)
        if len(parts) != 2:
            continue
        slash, ctx = parts
        if slash in allow:
            continue
        counts[slash] = counts.get(slash, 0) + 1
        if slash not in samples:
            samples[slash] = ctx.strip()[:200]

candidates = sorted(
    [{'slash': s, 'count': counts[s], 'sample': samples[s]} for s in counts],
    key=lambda c: (-c['count'], c['slash'])
)
print(json.dumps(candidates))
")

# Final assembly.
SCAN="$SCAN_DATE" FILES="$input_files_json" CANDS="$CANDIDATES_JSON" python3 -c "
import json, os
out = {
    'scan_date': os.environ['SCAN'],
    'input_files': json.loads(os.environ['FILES']),
    'candidates': json.loads(os.environ['CANDS']),
}
print(json.dumps(out, indent=2))
"
