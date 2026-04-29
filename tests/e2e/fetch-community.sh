#!/bin/bash
# Roadmap #207: community source fetcher.
#
# Pulls public threads from Reddit + HN (Algolia) and emits combined transcript
# text to stdout. Pipe to scan-community.sh to surface candidate slash-commands.
#
# Usage:
#   ./fetch-community.sh --reddit ClaudeCode,ClaudeAI --hn
#   ./fetch-community.sh --reddit ClaudeCode --offline tests/fixtures/community-fetch
#   ./fetch-community.sh --reddit ClaudeCode | ./scan-community.sh -
#
# Sources:
#   --reddit SUBS    comma-separated list of subreddits (e.g. ClaudeCode,ClaudeAI)
#                    Hits https://www.reddit.com/r/${sub}.json
#   --hn             HN Algolia search for "claude code"
#                    Hits https://hn.algolia.com/api/v1/search
#
# Modes:
#   --offline DIR    read fixtures from DIR instead of HTTP. File names:
#                       reddit-${sub_lower}.json
#                       hn-claudecode.json
#                    Used by tests and for offline runs.
#
# Why no GH Discussions / Discord:
#   GH Discussions: GraphQL-only, single-source, deferred to v2 if value warrants.
#   Discord: requires bot setup + OAuth — not viable as a one-off scan.
#
# Output: each source emits a `=== source: NAME ===` header followed by thread
# titles + selftext + URLs, separated by blank lines. Designed to be readable
# by humans AND grep-friendly for scan-community.sh.
#
# Exit codes:
#   0 - fetch completed (output may be empty if all sources returned no hits)
#   1 - bad args / fixture missing / malformed response

set -e

FETCHER_USAGE="Usage: $0 [--reddit SUB1,SUB2,...] [--hn] [--offline FIXTURE_DIR]
  --reddit SUBS    pull public threads from r/SUB1, r/SUB2, ...
  --hn             pull HN Algolia search results for 'claude code'
  --offline DIR    read fixture JSON from DIR instead of HTTP
  --help           show this message

Pipe to scan-community.sh for slash-command surfacing:
  $0 --reddit ClaudeCode,ClaudeAI --hn | ./scan-community.sh -"

REDDIT_SUBS=""
DO_HN=false
OFFLINE_DIR=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --reddit)
            # Codex round 1 P2: --reddit (no value) used to silently exit 1.
            # Validate $2 exists and is non-empty before consuming it.
            if [ -z "${2:-}" ]; then
                echo "error: --reddit requires a value (e.g. --reddit ClaudeCode,ClaudeAI)" >&2
                echo "$FETCHER_USAGE" >&2
                exit 1
            fi
            REDDIT_SUBS="$2"
            shift 2
            ;;
        --hn)
            DO_HN=true
            shift
            ;;
        --offline)
            if [ -z "${2:-}" ]; then
                echo "error: --offline requires a fixture directory path" >&2
                echo "$FETCHER_USAGE" >&2
                exit 1
            fi
            OFFLINE_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "$FETCHER_USAGE"
            exit 0
            ;;
        *)
            echo "error: unknown arg: $1" >&2
            echo "$FETCHER_USAGE" >&2
            exit 1
            ;;
    esac
done

if [ -z "$REDDIT_SUBS" ] && [ "$DO_HN" = false ]; then
    echo "error: no source specified. Use --reddit and/or --hn." >&2
    echo "$FETCHER_USAGE" >&2
    exit 1
fi

# Validate JSON content using python3 (already a dependency of scan-community.sh).
# Path is passed via env var, NOT interpolated into Python source — interpolation
# would let a crafted path (single quotes, Python code) execute arbitrary code.
# (Codex round 1 P0, ROADMAP #207.)
parse_or_die() {
    local path="$1"
    if ! JSON_PATH="$path" python3 -c "import json, os; json.load(open(os.environ['JSON_PATH']))" >/dev/null 2>&1; then
        echo "error: invalid JSON in $path" >&2
        exit 1
    fi
}

# Fetch a single Reddit subreddit's recent threads.
# In offline mode, reads $OFFLINE_DIR/reddit-${sub_lc}.json.
fetch_reddit_sub() {
    local sub="$1"
    local sub_lc
    sub_lc=$(echo "$sub" | tr '[:upper:]' '[:lower:]')
    local input_file

    if [ -n "$OFFLINE_DIR" ]; then
        input_file="$OFFLINE_DIR/reddit-${sub_lc}.json"
        if [ ! -f "$input_file" ]; then
            echo "error: offline fixture not found: $input_file" >&2
            exit 1
        fi
        parse_or_die "$input_file"
    else
        if ! command -v curl >/dev/null 2>&1; then
            echo "error: curl is required for live mode" >&2
            exit 1
        fi
        input_file=$(mktemp -t fetch-reddit.XXXXXX)
        # Reddit asks for a unique User-Agent — reusing one looks like abuse.
        if ! curl -fsSL -A "sdlc-wizard-207/1.0 (community-scanner)" \
                "https://www.reddit.com/r/${sub}.json" -o "$input_file"; then
            rm -f "$input_file"
            echo "error: live Reddit fetch failed for r/${sub}" >&2
            exit 1
        fi
        parse_or_die "$input_file"
    fi

    INPUT_FILE="$input_file" SUB="$sub" python3 -c "
import json, os
sub = os.environ['SUB']
print(f'=== source: reddit r/{sub} ===')
print()
try:
    d = json.load(open(os.environ['INPUT_FILE']))
except Exception as e:
    print(f'(parse error: {e})')
    raise SystemExit(0)
children = (d.get('data') or {}).get('children') or []
for c in children:
    t = (c.get('data') or {})
    title = t.get('title') or ''
    body = t.get('selftext') or ''
    permalink = t.get('permalink') or ''
    print(f'--- r/{sub}: {title}')
    if body:
        print(body)
    if permalink:
        print(f'https://www.reddit.com{permalink}')
    print()
"
    if [ -z "$OFFLINE_DIR" ]; then
        rm -f "$input_file"
    fi
}

# Fetch HN Algolia search results.
# In offline mode, reads $OFFLINE_DIR/hn-claudecode.json.
fetch_hn() {
    local input_file

    if [ -n "$OFFLINE_DIR" ]; then
        input_file="$OFFLINE_DIR/hn-claudecode.json"
        if [ ! -f "$input_file" ]; then
            echo "error: offline fixture not found: $input_file" >&2
            exit 1
        fi
        parse_or_die "$input_file"
    else
        if ! command -v curl >/dev/null 2>&1; then
            echo "error: curl is required for live mode" >&2
            exit 1
        fi
        input_file=$(mktemp -t fetch-hn.XXXXXX)
        if ! curl -fsSL \
                'https://hn.algolia.com/api/v1/search?query=claude+code&tags=story&hitsPerPage=20' \
                -o "$input_file"; then
            rm -f "$input_file"
            echo "error: live HN fetch failed" >&2
            exit 1
        fi
        parse_or_die "$input_file"
    fi

    INPUT_FILE="$input_file" python3 -c "
import json, os
print('=== source: HN Algolia (claude code) ===')
print()
try:
    d = json.load(open(os.environ['INPUT_FILE']))
except Exception as e:
    print(f'(parse error: {e})')
    raise SystemExit(0)
hits = d.get('hits') or []
for h in hits:
    title = h.get('title') or ''
    body = h.get('story_text') or ''
    url = h.get('url') or ''
    print(f'--- HN: {title}')
    if body:
        print(body)
    if url:
        print(url)
    print()
"
    if [ -z "$OFFLINE_DIR" ]; then
        rm -f "$input_file"
    fi
}

# --- Main ---

if [ -n "$REDDIT_SUBS" ]; then
    IFS=',' read -ra SUBS <<< "$REDDIT_SUBS"
    for sub in "${SUBS[@]}"; do
        # Strip whitespace from comma-split values.
        sub=$(echo "$sub" | tr -d '[:space:]')
        [ -z "$sub" ] && continue
        fetch_reddit_sub "$sub"
    done
fi

if [ "$DO_HN" = true ]; then
    fetch_hn
fi
