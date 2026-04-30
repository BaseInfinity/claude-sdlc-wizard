#!/bin/bash
# Roadmap #96 Phase 2 — independent ground-truth verification.
# After a simulation runs, ground-truth.sh executes the fixture's test
# suite (`npm test`) to record whether the agent's edits actually work.
# Combined with the judge score, this catches "agent followed protocol
# but produced broken code" false-positives.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GT="$SCRIPT_DIR/e2e/ground-truth.sh"
PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

echo "=== Ground-Truth Verification Tests (Roadmap #96 Phase 2) ==="
echo ""

# ---- Helpers ----

# Make a tmp fixture with a package.json that defines the requested
# test script behavior.
make_fixture() {
    local kind="$1"
    local dir
    dir=$(mktemp -d -t gt-fixture.XXXXXX)
    case "$kind" in
        pass)
            cat > "$dir/package.json" <<'EOF'
{ "name": "gt-pass", "version": "1.0.0",
  "scripts": { "test": "echo PASS_OK && exit 0" } }
EOF
            ;;
        fail)
            cat > "$dir/package.json" <<'EOF'
{ "name": "gt-fail", "version": "1.0.0",
  "scripts": { "test": "echo FAIL_LINE_1 && echo FAIL_LINE_2 && exit 1" } }
EOF
            ;;
        no-test)
            cat > "$dir/package.json" <<'EOF'
{ "name": "gt-no-test", "version": "1.0.0",
  "scripts": { "build": "echo nope" } }
EOF
            ;;
        no-package)
            : # empty dir
            ;;
        slow)
            cat > "$dir/package.json" <<'EOF'
{ "name": "gt-slow", "version": "1.0.0",
  "scripts": { "test": "sleep 30 && exit 0" } }
EOF
            ;;
    esac
    echo "$dir"
}

# ---- Tests ----

test_script_exists() {
    if [ -x "$GT" ]; then
        pass "ground-truth.sh exists and is executable"
    else
        fail "ground-truth.sh not found or not executable: $GT"
    fi
}
test_script_exists

if [ ! -x "$GT" ]; then
    echo ""
    echo "=== Results ==="
    echo "Passed: $PASSED, Failed: $FAILED"
    exit 1
fi

test_passing_fixture_emits_pass() {
    local dir
    dir=$(make_fixture pass)
    local out
    out=$("$GT" "$dir" 2>&1)
    rm -rf "$dir"
    if echo "$out" | jq -e '.tests_run == true and .tests_pass == true' >/dev/null 2>&1; then
        pass "passing fixture → tests_run=true, tests_pass=true"
    else
        fail "passing fixture wrong output: $out"
    fi
}
test_passing_fixture_emits_pass

test_failing_fixture_emits_fail() {
    local dir
    dir=$(make_fixture fail)
    local out
    out=$("$GT" "$dir" 2>&1)
    rm -rf "$dir"
    if echo "$out" | jq -e '.tests_run == true and .tests_pass == false' >/dev/null 2>&1; then
        pass "failing fixture → tests_run=true, tests_pass=false"
    else
        fail "failing fixture wrong output: $out"
    fi
}
test_failing_fixture_emits_fail

test_failing_fixture_captures_tail() {
    local dir
    dir=$(make_fixture fail)
    local out
    out=$("$GT" "$dir" 2>&1)
    rm -rf "$dir"
    local tail
    tail=$(echo "$out" | jq -r '.tests_tail // ""')
    if echo "$tail" | grep -q "FAIL_LINE_2"; then
        pass "failing fixture captures stdout tail (FAIL_LINE_2 visible)"
    else
        fail "failing fixture missing tail content. Got: $tail"
    fi
}
test_failing_fixture_captures_tail

test_no_test_script_skips_gracefully() {
    local dir
    dir=$(make_fixture no-test)
    local out
    out=$("$GT" "$dir" 2>&1)
    rm -rf "$dir"
    if echo "$out" | jq -e '.tests_run == false' >/dev/null 2>&1; then
        pass "fixture without test script → tests_run=false"
    else
        fail "no-test fixture wrong output: $out"
    fi
}
test_no_test_script_skips_gracefully

test_no_package_json_skips_gracefully() {
    local dir
    dir=$(make_fixture no-package)
    local out
    out=$("$GT" "$dir" 2>&1)
    rm -rf "$dir"
    if echo "$out" | jq -e '.tests_run == false' >/dev/null 2>&1; then
        pass "fixture without package.json → tests_run=false"
    else
        fail "no-package fixture wrong output: $out"
    fi
}
test_no_package_json_skips_gracefully

test_missing_dir_errors() {
    local out rc
    set +e
    out=$("$GT" /tmp/nonexistent-gt-dir-$$ 2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE "not found|does not exist"; then
        pass "missing fixture dir → error exit + clear message"
    else
        fail "missing dir should error. rc=$rc out=$out"
    fi
}
test_missing_dir_errors

test_no_args_errors() {
    local out rc
    set +e
    out=$("$GT" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE "usage|argument"; then
        pass "no args → error + usage"
    else
        fail "no args should show usage. rc=$rc out=$out"
    fi
}
test_no_args_errors

test_help_flag_works() {
    local out
    out=$("$GT" --help 2>&1 || true)
    if echo "$out" | grep -qiE "usage|fixture"; then
        pass "--help shows usage"
    else
        fail "--help did not show usage. Got: $out"
    fi
}
test_help_flag_works

test_emits_valid_json() {
    local dir
    dir=$(make_fixture pass)
    local out
    out=$("$GT" "$dir" 2>&1)
    rm -rf "$dir"
    if echo "$out" | jq empty >/dev/null 2>&1; then
        pass "output is valid JSON"
    else
        fail "output is not valid JSON: $out"
    fi
}
test_emits_valid_json

test_timeout_long_running() {
    local dir
    dir=$(make_fixture slow)
    local start end elapsed
    start=$(date +%s)
    set +e
    GROUND_TRUTH_TIMEOUT=2 "$GT" "$dir" >/dev/null 2>&1
    set -e
    end=$(date +%s)
    elapsed=$((end - start))
    rm -rf "$dir"
    if [ "$elapsed" -lt 10 ]; then
        pass "GROUND_TRUTH_TIMEOUT honored (elapsed=${elapsed}s, sleep was 30s)"
    else
        fail "timeout not enforced — elapsed=${elapsed}s for a 2s timeout on a 30s sleep"
    fi
}
test_timeout_long_running

# ---- Results ----

echo ""
echo "=== Results ==="
echo "Passed: $PASSED, Failed: $FAILED"
if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
echo "All ground-truth tests passed."
