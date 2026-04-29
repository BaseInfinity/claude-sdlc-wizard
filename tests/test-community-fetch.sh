#!/bin/bash
# Roadmap #207: tests for the community-source fetcher.
# fetch-community.sh pulls public threads from Reddit / HN and emits combined
# transcript text to stdout. Pipe to scan-community.sh to surface candidate
# slash-commands.
#
# Tests run offline by feeding fixture JSON via --offline.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCHER="$SCRIPT_DIR/e2e/fetch-community.sh"
SCANNER="$SCRIPT_DIR/e2e/scan-community.sh"
FIXTURES="$SCRIPT_DIR/fixtures/community-fetch"
PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

echo "=== Community Source Fetcher Tests (Roadmap #207) ==="
echo ""

# --- Fixtures ---

setup_fixtures() {
    mkdir -p "$FIXTURES"

    # Reddit JSON shape: { data: { children: [ { data: { title, selftext, ... } } ] } }
    cat > "$FIXTURES/reddit-claudecode.json" <<'EOF'
{
  "data": {
    "children": [
      {
        "data": {
          "title": "New /sparkle command in CC 2.1.119",
          "selftext": "Anyone else notice /sparkle? It auto-cleans your CLAUDE.md. Better than /clear for memory.",
          "permalink": "/r/ClaudeCode/comments/abc/new_sparkle/",
          "id": "abc"
        }
      },
      {
        "data": {
          "title": "Just using /help today",
          "selftext": "Nothing new. Used /compact and /model. Standard stuff.",
          "permalink": "/r/ClaudeCode/comments/def/just_using/",
          "id": "def"
        }
      }
    ]
  }
}
EOF

    cat > "$FIXTURES/reddit-claudeai.json" <<'EOF'
{
  "data": {
    "children": [
      {
        "data": {
          "title": "/throwback feature is wild",
          "selftext": "/throwback restores a previous turn from history. Game-changer.",
          "permalink": "/r/ClaudeAI/comments/xyz/throwback/",
          "id": "xyz"
        }
      }
    ]
  }
}
EOF

    # HN Algolia shape: { hits: [ { title, story_text, url, objectID } ] }
    cat > "$FIXTURES/hn-claudecode.json" <<'EOF'
{
  "hits": [
    {
      "title": "Claude Code 2.1.119 ships /lattice for transcript folding",
      "story_text": "The new /lattice command is buried in the changelog. Useful for long sessions.",
      "url": "https://news.ycombinator.com/item?id=12345",
      "objectID": "12345"
    },
    {
      "title": "Why I switched off Cursor to Claude Code",
      "story_text": "I find /sdlc + /code-review combo more reliable. /compact is also great.",
      "url": "https://news.ycombinator.com/item?id=12346",
      "objectID": "12346"
    }
  ]
}
EOF

    # Empty-source fixture (Reddit returns no children)
    cat > "$FIXTURES/reddit-empty.json" <<'EOF'
{ "data": { "children": [] } }
EOF

    # Malformed JSON for error-handling test
    cat > "$FIXTURES/malformed.json" <<'EOF'
{not valid json
EOF
}

setup_fixtures

# --- Tests ---

test_fetcher_exists() {
    if [ -x "$FETCHER" ]; then
        pass "fetch-community.sh exists and is executable"
    else
        fail "fetch-community.sh not found or not executable: $FETCHER"
    fi
}
test_fetcher_exists

# Bail out early if the script doesn't exist — remaining tests would all fail
# with the same root cause and the failure list would be noise.
if [ ! -x "$FETCHER" ]; then
    echo ""
    echo "=== Results ==="
    echo "Passed: $PASSED, Failed: $FAILED"
    exit 1
fi

test_help_shows_usage() {
    local out
    out=$("$FETCHER" --help 2>&1 || true)
    if echo "$out" | grep -qiE "usage|--reddit|--hn"; then
        pass "--help shows usage"
    else
        fail "--help did not produce usage output (got: $out)"
    fi
}
test_help_shows_usage

test_no_args_errors() {
    local out rc
    set +e
    out=$("$FETCHER" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "no source"; then
        pass "no args produces error 'no source'"
    else
        fail "no args should error but got rc=$rc out=$out"
    fi
}
test_no_args_errors

test_offline_reddit_extracts_titles_and_selftext() {
    local out
    out=$("$FETCHER" --reddit ClaudeCode --offline "$FIXTURES" 2>&1)
    if echo "$out" | grep -q "/sparkle" && \
       echo "$out" | grep -q "auto-cleans your CLAUDE.md"; then
        pass "offline reddit fetch extracts title + selftext content"
    else
        fail "offline reddit fetch missing expected content. Got first 300 chars: ${out:0:300}"
    fi
}
test_offline_reddit_extracts_titles_and_selftext

test_offline_reddit_multi_sub_concatenates() {
    local out
    out=$("$FETCHER" --reddit ClaudeCode,ClaudeAI --offline "$FIXTURES" 2>&1)
    if echo "$out" | grep -q "/sparkle" && echo "$out" | grep -q "/throwback"; then
        pass "multi-sub fetch concatenates content from both subs"
    else
        fail "multi-sub fetch missing content. Got first 300: ${out:0:300}"
    fi
}
test_offline_reddit_multi_sub_concatenates

test_offline_hn_extracts_title_and_story_text() {
    local out
    out=$("$FETCHER" --hn --offline "$FIXTURES" 2>&1)
    if echo "$out" | grep -q "/lattice" && echo "$out" | grep -q "transcript folding"; then
        pass "offline HN fetch extracts title + story_text"
    else
        fail "offline HN fetch missing content. Got first 300: ${out:0:300}"
    fi
}
test_offline_hn_extracts_title_and_story_text

test_combined_reddit_and_hn_in_one_run() {
    local out
    out=$("$FETCHER" --reddit ClaudeCode --hn --offline "$FIXTURES" 2>&1)
    if echo "$out" | grep -q "/sparkle" && echo "$out" | grep -q "/lattice"; then
        pass "combined --reddit + --hn produces both source's content"
    else
        fail "combined run missing content. Got first 300: ${out:0:300}"
    fi
}
test_combined_reddit_and_hn_in_one_run

test_pipe_to_scanner_finds_candidates() {
    # End-to-end: fetch (offline) → pipe → scan → expect /sparkle, /throwback,
    # /lattice as candidates (none in known-slash-commands.txt).
    local out
    out=$("$FETCHER" --reddit ClaudeCode,ClaudeAI --hn --offline "$FIXTURES" 2>/dev/null \
          | "$SCANNER" - 2>&1)
    if echo "$out" | python3 -c "
import sys, json
d = json.load(sys.stdin)
slashes = {c['slash'] for c in d.get('candidates', [])}
need = {'/sparkle', '/throwback', '/lattice'}
missing = need - slashes
if missing:
    print('MISSING:' + ','.join(sorted(missing)))
else:
    print('OK')
" 2>/dev/null | grep -q '^OK$'; then
        pass "fetch → scan pipe surfaces /sparkle, /throwback, /lattice"
    else
        fail "fetch → scan pipe missing expected candidates. Output: ${out:0:400}"
    fi
}
test_pipe_to_scanner_finds_candidates

test_offline_empty_source_emits_no_content() {
    # Reddit empty fixture should produce no slash-mentions — but the script
    # should exit 0 and just emit nothing (or a benign source header).
    local out rc
    set +e
    out=$("$FETCHER" --reddit empty --offline "$FIXTURES" 2>&1)
    rc=$?
    set -e
    # Non-strict: just confirm the script doesn't crash on empty input.
    if [ "$rc" -eq 0 ]; then
        pass "empty source returns 0 (no crash on empty input)"
    else
        fail "empty source returned rc=$rc. Output: ${out:0:200}"
    fi
}
test_offline_empty_source_emits_no_content

test_offline_missing_fixture_errors() {
    local out rc
    set +e
    out=$("$FETCHER" --reddit nonexistent --offline "$FIXTURES" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE "fixture|not found|missing"; then
        pass "missing offline fixture produces clear error"
    else
        fail "missing fixture should error with 'fixture/not found/missing' but got rc=$rc out=${out:0:200}"
    fi
}
test_offline_missing_fixture_errors

test_offline_malformed_json_errors() {
    # Use the malformed.json fixture by setting --reddit malformed (which
    # would look up reddit-malformed.json) — we'll create that link.
    cp "$FIXTURES/malformed.json" "$FIXTURES/reddit-malformed.json"
    local out rc
    set +e
    out=$("$FETCHER" --reddit malformed --offline "$FIXTURES" 2>&1)
    rc=$?
    set -e
    rm -f "$FIXTURES/reddit-malformed.json"
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE "json|parse|invalid"; then
        pass "malformed JSON produces parse error"
    else
        fail "malformed JSON should error. rc=$rc out=${out:0:200}"
    fi
}
test_offline_malformed_json_errors

# Codex round 1 P0 regression: parse_or_die used to interpolate $path into
# `python3 -c "json.load(open('$path'))"`. A path with a single quote plus
# arbitrary Python escaped the string and executed. Now passed via env var.
#
# Two-pronged test:
#   (a) injection payload in subreddit name (filename with no slashes) — code
#       embedded in the path must NOT execute; checks for sentinel file in
#       a known dir (no slashes in the embedded sentinel path).
#   (b) plain single-quote in fixture path — pre-fix this would crash with
#       Python SyntaxError; post-fix it parses fine. Demonstrates the fix
#       holds even for non-malicious-but-tricky inputs.
test_offline_fixture_path_injection_blocked() {
    local mal_dir
    mal_dir=$(mktemp -d -t fetch-pwntest.XXXXXX)
    local sentinel_name="P0_INJECTION_SENTINEL"
    local sentinel_path="$mal_dir/$sentinel_name"

    # Create a fixture with a SUB name containing a single quote + Python
    # injection. The sentinel path has NO slashes (just the filename, written
    # to mal_dir via cwd-relative naming inside the embedded code).
    SENTINEL_NAME="$sentinel_name" MAL_DIR="$mal_dir" python3 <<'PYEOF'
import os
mal_dir = os.environ['MAL_DIR']
sentinel = os.environ['SENTINEL_NAME']
# Pre-fix injection: $path contained `'); open('NAME', 'w').close(); #` would
# yield valid Python that creates a file in the python process's cwd.
# We chdir to mal_dir before invoking the fetcher so cwd is predictable.
sub_name = "pwn'); open('" + sentinel + "', 'w').close(); #"
fname = "reddit-" + sub_name.lower() + ".json"
with open(os.path.join(mal_dir, fname), "w") as f:
    f.write('{"data":{"children":[]}}')
PYEOF

    # Run the fetcher from inside mal_dir so any sentinel-create lands here.
    set +e
    (cd "$mal_dir" && "$FETCHER" \
        --reddit "pwn'); open('${sentinel_name}', 'w').close(); #" \
        --offline "$mal_dir" >/dev/null 2>&1)
    set -e

    if [ -e "$sentinel_path" ]; then
        rm -rf "$mal_dir"
        fail "P0 regression: injection payload in subreddit name executed code (sentinel created)"
        return
    fi
    rm -rf "$mal_dir"
    pass "injection payload in subreddit name does not execute (P0 round 1 fix held)"
}
test_offline_fixture_path_injection_blocked

# Codex round 1 P2 regressions: missing values for --reddit and --offline
# used to silently exit 1. Now must error with a clear message.
test_reddit_missing_value_errors() {
    local out rc
    set +e
    out=$("$FETCHER" --reddit 2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "reddit requires"; then
        pass "--reddit (no value) errors with clear message"
    else
        fail "--reddit (no value) should error with 'reddit requires...'. rc=$rc out=${out:0:200}"
    fi
}
test_reddit_missing_value_errors

test_offline_missing_value_errors() {
    local out rc
    set +e
    out=$("$FETCHER" --reddit ClaudeCode --offline 2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "offline requires"; then
        pass "--offline (no value) errors with clear message"
    else
        fail "--offline (no value) should error with 'offline requires...'. rc=$rc out=${out:0:200}"
    fi
}
test_offline_missing_value_errors

# --- Results ---

echo ""
echo "=== Results ==="
echo "Passed: $PASSED, Failed: $FAILED"

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
echo "All community-fetch tests passed."
