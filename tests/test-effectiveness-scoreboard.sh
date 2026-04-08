#!/bin/bash
# Test effectiveness scoreboard: seed data quality + analytics correctness
#
# Validates:
# - Seed JSONL format and required fields
# - Analytics DDE (Defect Detection Effectiveness) calculation
# - Analytics escape rate derivation
# - Analytics severity breakdown
# - Edge cases (empty file, single entry)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATCHES_FILE="$REPO_ROOT/.metrics/catches.jsonl"
ANALYTICS="$REPO_ROOT/tests/e2e/catch-analytics.sh"

PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

echo "=== Effectiveness Scoreboard Tests ==="
echo ""

# --- Seed Data Quality ---

# Test 1: Seed JSONL exists and is non-empty
test_seed_exists() {
    if [ -f "$CATCHES_FILE" ] && [ -s "$CATCHES_FILE" ]; then
        pass "Seed JSONL exists and is non-empty"
    else
        fail "Seed JSONL should exist at .metrics/catches.jsonl and be non-empty"
    fi
}

# Test 2: Every line in seed data is valid JSON
test_seed_valid_jsonl() {
    local bad_lines=0
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if ! echo "$line" | jq -e '.' > /dev/null 2>&1; then
            bad_lines=$((bad_lines + 1))
        fi
    done < "$CATCHES_FILE"
    if [ "$bad_lines" -eq 0 ] && [ "$line_num" -gt 0 ]; then
        pass "All $line_num lines are valid JSON"
    else
        fail "$bad_lines of $line_num lines are invalid JSON"
    fi
}

# Test 3: Every entry has required fields
test_seed_required_fields() {
    local missing=0
    while IFS= read -r line; do
        local has_all
        has_all=$(echo "$line" | jq -e 'has("id") and has("timestamp") and has("layer") and has("severity") and has("pr") and has("description")' 2>/dev/null)
        if [ "$has_all" != "true" ]; then
            missing=$((missing + 1))
        fi
    done < "$CATCHES_FILE"
    if [ "$missing" -eq 0 ]; then
        pass "All entries have required fields (id, timestamp, layer, severity, pr, description)"
    else
        fail "$missing entries missing required fields"
    fi
}

# Test 4: All layer values are valid
test_seed_valid_layers() {
    local invalid
    invalid=$(jq -r '.layer' "$CATCHES_FILE" | grep -cvE '^(self-review|cross-model-review|ci-review|hook)$' || true)
    if [ "$invalid" -eq 0 ]; then
        pass "All layer values are valid"
    else
        fail "$invalid entries have invalid layer values"
    fi
}

# Test 5: All severity values are valid
test_seed_valid_severities() {
    local invalid
    invalid=$(jq -r '.severity' "$CATCHES_FILE" | grep -cvE '^(P0|P1|P2)$' || true)
    if [ "$invalid" -eq 0 ]; then
        pass "All severity values are valid"
    else
        fail "$invalid entries have invalid severity values"
    fi
}

# Test 6: Seed data covers at least 3 layers
test_seed_layer_coverage() {
    local layer_count
    layer_count=$(jq -r '.layer' "$CATCHES_FILE" | sort -u | wc -l | tr -d ' ')
    if [ "$layer_count" -ge 3 ]; then
        pass "Seed data covers $layer_count layers (>= 3 required)"
    else
        fail "Seed data should cover at least 3 layers, found $layer_count"
    fi
}

# Test 7: Seed has at least 40 entries (we extracted 52)
test_seed_minimum_entries() {
    local count
    count=$(wc -l < "$CATCHES_FILE" | tr -d ' ')
    if [ "$count" -ge 40 ]; then
        pass "Seed has $count entries (>= 40 required)"
    else
        fail "Seed should have at least 40 entries, found $count"
    fi
}

# --- Analytics Script Quality ---

# Test 8: Analytics script exists and is executable
test_analytics_exists() {
    if [ -x "$ANALYTICS" ]; then
        pass "catch-analytics.sh exists and is executable"
    else
        fail "catch-analytics.sh should exist and be executable"
    fi
}

# Test 9: Analytics DDE calculation on known fixture
test_analytics_dde() {
    local fixture
    fixture=$(mktemp "${TMPDIR:-/tmp}/catches-fixture-XXXXXX")
    # 4 catches: 2 self-review, 1 cross-model, 1 ci-review → DDE: 50%, 25%, 25%
    echo '{"id":"t1","timestamp":"2026-01-01T00:00:00Z","layer":"self-review","severity":"P1","pr":"#1","description":"bug1"}' >> "$fixture"
    echo '{"id":"t2","timestamp":"2026-01-02T00:00:00Z","layer":"self-review","severity":"P2","pr":"#2","description":"bug2"}' >> "$fixture"
    echo '{"id":"t3","timestamp":"2026-01-03T00:00:00Z","layer":"cross-model-review","severity":"P1","pr":"#3","description":"bug3"}' >> "$fixture"
    echo '{"id":"t4","timestamp":"2026-01-04T00:00:00Z","layer":"ci-review","severity":"P0","pr":"#4","description":"bug4"}' >> "$fixture"

    local output
    output=$(bash "$ANALYTICS" --history "$fixture" 2>/dev/null)
    # self-review should show 50%
    if echo "$output" | grep -q "self-review" && echo "$output" | grep -q "50"; then
        pass "Analytics DDE: self-review shows 50% on 2/4 fixture"
    else
        fail "Analytics DDE should show self-review at 50% (output: $(echo "$output" | head -5))"
    fi
    rm -f "$fixture"
}

# Test 10: Analytics escape rate derivation
test_analytics_escape_rate() {
    local fixture
    fixture=$(mktemp "${TMPDIR:-/tmp}/catches-fixture-XXXXXX")
    # 1 catch at ci-review → escaped self-review AND cross-model-review
    echo '{"id":"t1","timestamp":"2026-01-01T00:00:00Z","layer":"ci-review","severity":"P0","pr":"#1","description":"bug escaped to CI"}' >> "$fixture"
    echo '{"id":"t2","timestamp":"2026-01-02T00:00:00Z","layer":"self-review","severity":"P2","pr":"#2","description":"caught early"}' >> "$fixture"

    local output
    output=$(bash "$ANALYTICS" --history "$fixture" 2>/dev/null)
    # Should show escape info — ci-review catch means upstream layers missed it
    if echo "$output" | grep -qi "escape"; then
        pass "Analytics shows escape rate information"
    else
        fail "Analytics should show escape rate (output: $(echo "$output" | head -5))"
    fi
    rm -f "$fixture"
}

# Test 11: Analytics severity breakdown
test_analytics_severity() {
    local fixture
    fixture=$(mktemp "${TMPDIR:-/tmp}/catches-fixture-XXXXXX")
    echo '{"id":"t1","timestamp":"2026-01-01T00:00:00Z","layer":"self-review","severity":"P0","pr":"#1","description":"critical"}' >> "$fixture"
    echo '{"id":"t2","timestamp":"2026-01-02T00:00:00Z","layer":"self-review","severity":"P1","pr":"#2","description":"major"}' >> "$fixture"
    echo '{"id":"t3","timestamp":"2026-01-03T00:00:00Z","layer":"self-review","severity":"P2","pr":"#3","description":"minor"}' >> "$fixture"

    local output
    output=$(bash "$ANALYTICS" --history "$fixture" 2>/dev/null)
    if echo "$output" | grep -q "P0" && echo "$output" | grep -q "P1" && echo "$output" | grep -q "P2"; then
        pass "Analytics shows severity breakdown (P0, P1, P2)"
    else
        fail "Analytics should show P0, P1, P2 breakdown"
    fi
    rm -f "$fixture"
}

# Test 12: Analytics handles empty file gracefully
test_analytics_empty() {
    local fixture
    fixture=$(mktemp "${TMPDIR:-/tmp}/catches-fixture-XXXXXX")
    local output exit_code
    output=$(bash "$ANALYTICS" --history "$fixture" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    if [ "$exit_code" -eq 0 ]; then
        pass "Analytics handles empty file gracefully (exit 0)"
    else
        fail "Analytics should handle empty file without crashing (exit=$exit_code)"
    fi
    rm -f "$fixture"
}

# Test 13: Analytics on seed data produces DDE for each layer
test_analytics_seed_data() {
    local output
    output=$(bash "$ANALYTICS" --history "$CATCHES_FILE" 2>/dev/null)
    local ok=true
    echo "$output" | grep -qi "self-review" || ok=false
    echo "$output" | grep -qi "cross-model" || ok=false
    echo "$output" | grep -qi "ci-review" || ok=false
    if [ "$ok" = true ]; then
        pass "Analytics on seed data shows DDE for all layers"
    else
        fail "Analytics on seed data should show DDE for self-review, cross-model, ci-review"
    fi
}

# Test 14: Analytics --report outputs markdown
test_analytics_report_mode() {
    local output
    output=$(bash "$ANALYTICS" --history "$CATCHES_FILE" --report 2>/dev/null)
    if echo "$output" | grep -q "|" && echo "$output" | grep -qF -- "---"; then
        pass "Analytics --report outputs markdown tables"
    else
        fail "Analytics --report should output markdown with table separators"
    fi
}

# --- Run all tests ---

test_seed_exists
test_seed_valid_jsonl
test_seed_required_fields
test_seed_valid_layers
test_seed_valid_severities
test_seed_layer_coverage
test_seed_minimum_entries
test_analytics_exists
test_analytics_dde
test_analytics_escape_rate
test_analytics_severity
test_analytics_empty
test_analytics_seed_data
test_analytics_report_mode

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
