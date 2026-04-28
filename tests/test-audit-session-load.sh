#!/bin/bash
# Quality tests for scripts/audit-session-load.sh — token bloat audit phase 2.
# Tests use isolated fixture directories (no real repo state) so the "trim
# candidate" detection can be proven against known sizes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/../scripts/audit-session-load.sh"

PASSED=0
FAILED=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

make_temp() { mktemp -d "${TMPDIR:-/tmp}/audit-session-load-XXXXXX"; }

# Fixture builder: writes a session-loadable file at $1 with $2 chars of 'A'
make_file_with_size() {
    local path="$1" size="$2"
    mkdir -p "$(dirname "$path")"
    awk -v n="$size" 'BEGIN { for (i = 0; i < n; i++) printf "A"; }' > "$path"
}

echo "=== Token bloat audit phase 2 — quality tests ==="
echo ""

test_audit_exists_and_executable() {
    if [ -x "$AUDIT" ]; then
        pass "scripts/audit-session-load.sh exists and is executable"
    else
        fail "audit script missing or not executable: $AUDIT"
    fi
}

test_audit_flags_oversized_skill_as_trim_candidate() {
    local d
    d=$(make_temp)
    make_file_with_size "$d/skills/sdlc/SKILL.md" 25000
    make_file_with_size "$d/hooks/tiny.sh" 100
    local output
    output=$(SDLC_AUDIT_ROOT="$d" "$AUDIT" 2>&1)
    rm -rf "$d"
    if echo "$output" | awk '$4 == "TRIM" && $5 ~ /sdlc\/SKILL\.md/' | grep -q TRIM; then
        pass "audit flags 25K-char SKILL.md as TRIM candidate (proves >=5K-token detection)"
    else
        fail "audit should flag oversized skill as TRIM, got: $output"
    fi
}

test_audit_does_not_flag_small_files() {
    local d
    d=$(make_temp)
    make_file_with_size "$d/CLAUDE.md" 1000
    make_file_with_size "$d/SDLC.md" 500
    local output
    output=$(SDLC_AUDIT_ROOT="$d" "$AUDIT" 2>&1)
    rm -rf "$d"
    if echo "$output" | grep -q "TRIM"; then
        fail "audit should NOT flag <5K-token files as TRIM, got: $output"
    else
        pass "audit does not flag <5K-token files (250-token CLAUDE.md stays OK)"
    fi
}

test_audit_threshold_boundary_inclusive() {
    local d
    d=$(make_temp)
    make_file_with_size "$d/CLAUDE.md" 20000
    local output
    output=$(SDLC_AUDIT_ROOT="$d" "$AUDIT" 2>&1)
    rm -rf "$d"
    if echo "$output" | awk '$4 == "TRIM" && $5 ~ /CLAUDE\.md/' | grep -q TRIM; then
        pass "audit flags file AT threshold (20000 chars / 5000 tokens) as TRIM (inclusive)"
    else
        fail "threshold should be inclusive (>=5000 tokens flags), got: $output"
    fi
}

test_audit_json_output_includes_trim_count() {
    local d output
    d=$(make_temp)
    make_file_with_size "$d/skills/sdlc/SKILL.md" 25000
    make_file_with_size "$d/CLAUDE.md" 500
    output=$(SDLC_AUDIT_ROOT="$d" "$AUDIT" --json 2>&1)
    rm -rf "$d"
    if echo "$output" | grep -q '"trim_candidate_count": 1' \
        && echo "$output" | grep -q '"flag": "TRIM"' \
        && echo "$output" | grep -q '"flag": "OK"'; then
        pass "audit --json emits trim_candidate_count + per-entry flags"
    else
        fail "audit --json should emit machine-readable trim count, got: $output"
    fi
}

test_audit_threshold_override() {
    local d output
    d=$(make_temp)
    make_file_with_size "$d/CLAUDE.md" 10000
    output=$(SDLC_AUDIT_ROOT="$d" SDLC_AUDIT_THRESHOLD_TOKENS=1000 "$AUDIT" 2>&1)
    rm -rf "$d"
    if echo "$output" | awk '$4 == "TRIM" && $5 ~ /CLAUDE\.md/' | grep -q TRIM; then
        pass "audit respects SDLC_AUDIT_THRESHOLD_TOKENS override (1000-token threshold flags 2500-token file)"
    else
        fail "audit should honor threshold override, got: $output"
    fi
}

test_audit_empty_repo_no_crash() {
    local d output rc=0
    d=$(make_temp)
    output=$(SDLC_AUDIT_ROOT="$d" "$AUDIT" 2>&1) || rc=$?
    rm -rf "$d"
    if [ "$rc" -eq 0 ] && echo "$output" | grep -qiE 'no session-loaded assets|0 trim'; then
        pass "audit on empty repo exits cleanly (rc=0, sane message)"
    else
        fail "audit should handle empty repo gracefully (rc=$rc, got: $output)"
    fi
}

test_audit_ranks_by_size_descending() {
    local d output
    d=$(make_temp)
    make_file_with_size "$d/CLAUDE.md" 1000
    make_file_with_size "$d/SDLC.md" 5000
    make_file_with_size "$d/TESTING.md" 3000
    output=$(SDLC_AUDIT_ROOT="$d" "$AUDIT" 2>&1)
    rm -rf "$d"
    local first second third
    first=$(echo "$output" | awk 'NR==3 {print $5}')
    second=$(echo "$output" | awk 'NR==4 {print $5}')
    third=$(echo "$output" | awk 'NR==5 {print $5}')
    if [[ "$first" == *SDLC.md* ]] \
        && [[ "$second" == *TESTING.md* ]] \
        && [[ "$third" == *CLAUDE.md* ]]; then
        pass "audit ranks entries by size descending (5K SDLC > 3K TESTING > 1K CLAUDE)"
    else
        fail "audit should rank by size DESC (got order: $first, $second, $third)"
    fi
}

test_audit_exists_and_executable
test_audit_flags_oversized_skill_as_trim_candidate
test_audit_does_not_flag_small_files
test_audit_threshold_boundary_inclusive
test_audit_json_output_includes_trim_count
test_audit_threshold_override
test_audit_empty_repo_no_crash
test_audit_ranks_by_size_descending

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
if [ "$FAILED" -gt 0 ]; then exit 1; fi
echo "All token bloat audit tests passed!"
