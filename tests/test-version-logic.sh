#!/bin/bash
# Test version comparison logic from weekly-update workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

echo "=== Version Logic Tests ==="
echo ""

# Test 1: Same version = no update needed
test_same_version() {
    LAST="v2.1.15"
    LATEST="v2.1.15"

    if [ "$LAST" = "$LATEST" ]; then
        NEEDS_UPDATE="false"
    else
        NEEDS_UPDATE="true"
    fi

    if [ "$NEEDS_UPDATE" = "false" ]; then
        pass "Same version detected correctly (no update needed)"
    else
        fail "Same version should not need update"
    fi
}

# Test 2: Different version = update needed
test_different_version() {
    LAST="v2.1.14"
    LATEST="v2.1.15"

    if [ "$LAST" = "$LATEST" ]; then
        NEEDS_UPDATE="false"
    else
        NEEDS_UPDATE="true"
    fi

    if [ "$NEEDS_UPDATE" = "true" ]; then
        pass "Different version detected correctly (update needed)"
    else
        fail "Different version should need update"
    fi
}

# Test 3: Initial state (v0.0.0) = update needed
test_initial_state() {
    LAST="v0.0.0"
    LATEST="v2.1.15"

    if [ "$LAST" = "$LATEST" ]; then
        NEEDS_UPDATE="false"
    else
        NEEDS_UPDATE="true"
    fi

    if [ "$NEEDS_UPDATE" = "true" ]; then
        pass "Initial state (v0.0.0) triggers update correctly"
    else
        fail "Initial state should need update"
    fi
}

# Test 4: Version file reading simulation
test_version_file_read() {
    # Create temp file
    TEMP_FILE=$(mktemp)
    echo "v2.1.16" > "$TEMP_FILE"

    VERSION=$(cat "$TEMP_FILE" | tr -d '\n')
    rm "$TEMP_FILE"

    if [ "$VERSION" = "v2.1.16" ]; then
        pass "Version file read correctly (no trailing newline)"
    else
        fail "Version file read incorrectly: got '$VERSION'"
    fi
}

# Test 5: Missing version file = v0.0.0 default
test_missing_version_file() {
    FAKE_PATH="/nonexistent/path/version.txt"

    if [ -f "$FAKE_PATH" ]; then
        VERSION=$(cat "$FAKE_PATH" | tr -d '\n')
    else
        VERSION="v0.0.0"
    fi

    if [ "$VERSION" = "v0.0.0" ]; then
        pass "Missing version file defaults to v0.0.0"
    else
        fail "Missing file should default to v0.0.0"
    fi
}

# Test 6: Branch name generation
test_branch_name() {
    VERSION="v2.1.16"
    BRANCH="auto-update/claude-code-${VERSION}"

    if [ "$BRANCH" = "auto-update/claude-code-v2.1.16" ]; then
        pass "Branch name generated correctly"
    else
        fail "Branch name incorrect: got '$BRANCH'"
    fi
}

# --- Intermediate release detection tests (jq semver filtering) ---

# The jq filter used in weekly-update.yml to find releases newer than last-checked
JQ_SEMVER_FILTER='[.[] | select(.tag_name != $last) | select(
  (.tag_name | ltrimstr("v") | split(".") | map(tonumber)) as $ver |
  ($last | ltrimstr("v") | split(".") | map(tonumber)) as $chk |
  ($ver[0] > $chk[0]) or
  ($ver[0] == $chk[0] and $ver[1] > $chk[1]) or
  ($ver[0] == $chk[0] and $ver[1] == $chk[1] and $ver[2] > $chk[2])
)] | reverse'

# Test 7: Semver filter — 3 releases newer than v2.1.80
test_semver_filter_basic() {
    local RELEASES='[
      {"tag_name":"v2.1.83","body":"release 83","published_at":"2026-03-25"},
      {"tag_name":"v2.1.82","body":"release 82","published_at":"2026-03-22"},
      {"tag_name":"v2.1.81","body":"release 81","published_at":"2026-03-20"},
      {"tag_name":"v2.1.80","body":"release 80","published_at":"2026-03-18"}
    ]'

    local COUNT
    COUNT=$(echo "$RELEASES" | jq --arg last "v2.1.80" "$JQ_SEMVER_FILTER | length")

    if [ "$COUNT" = "3" ]; then
        pass "Semver filter: 3 releases newer than v2.1.80"
    else
        fail "Semver filter: expected 3, got $COUNT"
    fi
}

# Test 8: Semver filter — same version yields 0 new releases
test_semver_filter_same_version() {
    local RELEASES='[{"tag_name":"v2.1.81","body":"release 81","published_at":"2026-03-20"}]'

    local COUNT
    COUNT=$(echo "$RELEASES" | jq --arg last "v2.1.81" "$JQ_SEMVER_FILTER | length")

    if [ "$COUNT" = "0" ]; then
        pass "Semver filter: same version yields 0 new releases"
    else
        fail "Semver filter: expected 0, got $COUNT"
    fi
}

# Test 9: Semver filter — major version jump
test_semver_filter_major_jump() {
    local RELEASES='[
      {"tag_name":"v3.0.0","body":"major","published_at":"2026-04-01"},
      {"tag_name":"v2.1.82","body":"patch","published_at":"2026-03-22"},
      {"tag_name":"v2.1.81","body":"current","published_at":"2026-03-20"}
    ]'

    local COUNT
    COUNT=$(echo "$RELEASES" | jq --arg last "v2.1.81" "$JQ_SEMVER_FILTER | length")

    if [ "$COUNT" = "2" ]; then
        pass "Semver filter: major version jump counted correctly"
    else
        fail "Semver filter: expected 2 (v2.1.82 + v3.0.0), got $COUNT"
    fi
}

# Test 10: Combined release body — single release (backward compatible)
test_combined_body_single() {
    local RELEASES='[{"tag_name":"v2.1.82","body":"Fixed a bug","published_at":"2026-03-22"}]'

    local BODY
    BODY=$(echo "$RELEASES" | jq -r '.[0].body // ""')

    if [ "$BODY" = "Fixed a bug" ]; then
        pass "Single release body: plain text (backward compatible)"
    else
        fail "Single release body format wrong: '$BODY'"
    fi
}

# Test 11: Combined release body — multiple releases have numbered sections
test_combined_body_multi() {
    local RELEASES='[
      {"tag_name":"v2.1.82","body":"Fixed bug A","published_at":"2026-03-22"},
      {"tag_name":"v2.1.83","body":"Added feature B","published_at":"2026-03-25"}
    ]'

    local BODY
    BODY=$(echo "$RELEASES" | jq -r '
      to_entries | .[] |
      "## Release \(.key + 1): \(.value.tag_name) (\(.value.published_at // "unknown"))\n\(.value.body // "(no release notes)")\n\n---\n"
    ')

    if echo "$BODY" | grep -q "## Release 1:" && echo "$BODY" | grep -q "## Release 2:"; then
        pass "Multi-release body: numbered sections with separators"
    else
        fail "Multi-release body format wrong"
    fi
}

# Test 12: Null/empty release body handled gracefully
test_empty_release_body() {
    local RELEASES='[{"tag_name":"v2.1.82","body":null,"published_at":"2026-03-22"}]'

    local BODY
    BODY=$(echo "$RELEASES" | jq -r '.[0].body // ""')

    if [ "$BODY" = "" ]; then
        pass "Null release body defaults to empty string"
    else
        fail "Null release body should be empty, got: '$BODY'"
    fi
}

# Test 13: Initial state (v0.0.0) catches all releases
test_semver_filter_initial_state() {
    local RELEASES='[
      {"tag_name":"v2.1.83","body":"latest","published_at":"2026-03-25"},
      {"tag_name":"v2.1.82","body":"previous","published_at":"2026-03-22"}
    ]'

    local COUNT
    COUNT=$(echo "$RELEASES" | jq --arg last "v0.0.0" "$JQ_SEMVER_FILTER | length")

    if [ "$COUNT" = "2" ]; then
        pass "Initial state (v0.0.0): all releases caught"
    else
        fail "Initial state: expected 2, got $COUNT"
    fi
}

# Run all tests
test_same_version
test_different_version
test_initial_state
test_version_file_read
test_missing_version_file
test_branch_name
test_semver_filter_basic
test_semver_filter_same_version
test_semver_filter_major_jump
test_combined_body_single
test_combined_body_multi
test_empty_release_body
test_semver_filter_initial_state

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All version logic tests passed!"
