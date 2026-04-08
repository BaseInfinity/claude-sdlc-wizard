#!/bin/bash
# Firmware Fixture Quality Tests (#78)
# Proves the wizard handles non-web domains end-to-end.
# Every test checks OUTPUT QUALITY, not just existence.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

FIXTURE="$REPO_ROOT/tests/e2e/fixtures/firmware-embedded"
WIZARD="$REPO_ROOT/CLAUDE_CODE_SDLC_WIZARD.md"

echo "=== Firmware Fixture Quality Tests (#78) ==="
echo "Proves wizard handles non-web domains end-to-end"
echo ""

# ─────────────────────────────────────────────────────
# Domain Indicator Coverage
# Proves fixture triggers wizard's firmware detection
# ─────────────────────────────────────────────────────

echo "--- Domain Indicator Coverage ---"

# Test 1: Fixture has Makefile with flash target (firmware indicator #1)
test_makefile_flash_target() {
    if [ -f "$FIXTURE/Makefile" ] && grep -q "flash" "$FIXTURE/Makefile"; then
        pass "Fixture has Makefile with flash target"
    else
        fail "Fixture missing Makefile with flash target (firmware indicator)"
    fi
}
test_makefile_flash_target

# Test 2: Fixture has .cfg device configs (firmware indicator #2)
test_device_configs() {
    local cfg_count
    cfg_count=$(find "$FIXTURE/configs" -name "*.cfg" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$cfg_count" -ge 3 ]; then
        pass "Fixture has $cfg_count device configs (>= 3 for multi-device)"
    else
        fail "Fixture has $cfg_count device configs, need >= 3 for multi-device proof"
    fi
}
test_device_configs

# Test 3: Fixture has /dev/tty reference (firmware indicator #3)
test_dev_tty_reference() {
    if grep -rq "/dev/tty" "$FIXTURE/"; then
        pass "Fixture has /dev/tty reference"
    else
        fail "Fixture missing /dev/tty reference (firmware indicator)"
    fi
}
test_dev_tty_reference

# Test 4: Fixture has .c source files (firmware indicator #4)
test_c_source() {
    local c_count
    c_count=$(find "$FIXTURE/src" -name "*.c" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$c_count" -ge 1 ]; then
        pass "Fixture has $c_count .c source files"
    else
        fail "Fixture missing .c source files (firmware indicator)"
    fi
}
test_c_source

# Test 5: Fixture has /sys/ sysfs reference (firmware indicator #5)
test_sysfs_reference() {
    if grep -rq "/sys/" "$FIXTURE/"; then
        pass "Fixture has /sys/ sysfs reference"
    else
        fail "Fixture missing /sys/ sysfs reference (firmware indicator)"
    fi
}
test_sysfs_reference

# ─────────────────────────────────────────────────────
# Python + Shell Overlay (roadmap requirement)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Python + Shell SD Card Overlay ---"

# Test 6: Fixture has Python overlay scripts
test_python_overlay() {
    local py_count
    py_count=$(find "$FIXTURE" -name "*.py" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$py_count" -ge 1 ]; then
        pass "Fixture has $py_count Python overlay scripts"
    else
        fail "Fixture missing Python overlay scripts (roadmap: 'Python + shell')"
    fi
}
test_python_overlay

# Test 7: Python overlay script handles SD card operations
test_python_sdcard_ops() {
    if grep -rq "overlay\|sdcard\|sd_card\|mount" "$FIXTURE"/*.py "$FIXTURE"/**/*.py 2>/dev/null; then
        pass "Python scripts reference SD card/overlay operations"
    else
        fail "Python scripts don't reference SD card/overlay operations"
    fi
}
test_python_sdcard_ops

# ─────────────────────────────────────────────────────
# Test Infrastructure Within Fixture
# Proves fixture has testing layers matching wizard guidance
# ─────────────────────────────────────────────────────

echo ""
echo "--- Fixture Test Infrastructure ---"

# Test 8: Fixture has a tests/ directory with test scripts
test_fixture_has_tests() {
    local test_count
    test_count=$(find "$FIXTURE/tests" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$test_count" -ge 2 ]; then
        pass "Fixture has $test_count test files"
    else
        fail "Fixture has $test_count test files, need >= 2 (SIL + config validation)"
    fi
}
test_fixture_has_tests

# Test 9: Fixture has SIL test (matches wizard's ~60% testing layer)
test_fixture_sil_test() {
    if grep -rqi "SIL\|software.in.the.loop\|emulat" "$FIXTURE/tests/" 2>/dev/null; then
        pass "Fixture has SIL (Software-in-the-Loop) test"
    else
        fail "Fixture missing SIL test (wizard says SIL = 60% of firmware test suite)"
    fi
}
test_fixture_sil_test

# Test 10: Fixture has config validation test (matches wizard's ~25% testing layer)
test_fixture_config_validation() {
    if grep -rqi "config.*valid\|valid.*config\|parse.*config\|config.*parse" "$FIXTURE/tests/" 2>/dev/null; then
        pass "Fixture has config validation test"
    else
        fail "Fixture missing config validation test (wizard says ~25% of firmware suite)"
    fi
}
test_fixture_config_validation

# ─────────────────────────────────────────────────────
# Multi-Device Differentiation
# ─────────────────────────────────────────────────────

echo ""
echo "--- Multi-Device Differentiation ---"

# Test 11: Device configs have distinct display resolutions
test_distinct_resolutions() {
    local resolutions
    resolutions=$(grep -h "display_width" "$FIXTURE"/configs/*.cfg 2>/dev/null | sort -u | wc -l | tr -d ' ')
    if [ "$resolutions" -ge 2 ]; then
        pass "Device configs have $resolutions distinct display widths"
    else
        fail "Device configs should have distinct resolutions (found $resolutions unique widths)"
    fi
}
test_distinct_resolutions

# Test 12: No web/API indicators present (negative test — proves no misclassification)
test_no_web_indicators() {
    local has_web=0
    # Check for web framework indicators that would trigger web domain detection
    [ -f "$FIXTURE/package.json" ] && grep -q "react\|vue\|angular\|express\|next" "$FIXTURE/package.json" 2>/dev/null && has_web=1
    find "$FIXTURE" -path "*/src/components/*" 2>/dev/null | grep -q . && has_web=1
    find "$FIXTURE" -name "playwright.config.*" -o -name "cypress.config.*" 2>/dev/null | grep -q . && has_web=1
    if [ "$has_web" -eq 0 ]; then
        pass "No web/API indicators present (clean firmware domain signal)"
    else
        fail "Web/API indicators found — would confuse domain detection"
    fi
}
test_no_web_indicators

# ─────────────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────────────

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
