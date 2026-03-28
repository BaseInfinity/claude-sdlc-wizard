#!/bin/bash
# Test check-compliance.sh logic
# Tests: missing complexity, unknown values, pattern matching, exit codes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLIANCE_SCRIPT="$SCRIPT_DIR/e2e/check-compliance.sh"
PASSED=0
FAILED=0

# Color output
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

echo "=== Compliance Checker Tests ==="
echo ""

# Setup temp dir for test fixtures
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Helper: create a test scenario file
create_scenario() {
    local complexity="$1"
    local file="$TEMP_DIR/scenario-${complexity}.md"
    cat > "$file" << EOF
# Test Scenario

## Complexity
${complexity}

## Task
Do something for testing purposes.
EOF
    echo "$file"
}

# Helper: create a test repo with claude output
create_test_dir() {
    local content="$1"
    local dir="$TEMP_DIR/test-repo-$$-$RANDOM"
    mkdir -p "$dir"
    echo "$content" > "$dir/claude_output.txt"
    echo "$dir"
}

# Test 1: Script exists and is executable
test_script_exists() {
    if [ -x "$COMPLIANCE_SCRIPT" ]; then
        pass "check-compliance.sh exists and is executable"
    else
        fail "check-compliance.sh not found or not executable"
    fi
}

# Test 2: Simple scenario with all patterns matching runs to completion
test_simple_all_match() {
    local scenario
    scenario=$(create_scenario "Simple")
    # Include patterns for ALL checks: read, task/plan, fix, review
    local test_dir
    test_dir=$(create_test_dir "Let me read the file first. My plan is to fix the typo. I will update the change and review it.")

    local output
    output=$("$COMPLIANCE_SCRIPT" "$test_dir" "$scenario" 2>&1) || true
    if echo "$output" | grep -q "compliance check passed"; then
        pass "Simple scenario with all patterns passes"
    else
        fail "Simple scenario with all patterns should pass, got: $output"
    fi
}

# Test 3: Medium scenario with all patterns runs to completion
test_medium_all_match() {
    local scenario
    scenario=$(create_scenario "Medium")
    # Include ALL patterns: read, task/plan, test/failing, confidence/HIGH, task/todo, review
    local test_dir
    test_dir=$(create_test_dir "I will read the file and plan my approach. Using TDD with a failing test first. My confidence is HIGH. Creating a TodoWrite for task tracking. Let me review my changes.")

    local output
    output=$("$COMPLIANCE_SCRIPT" "$test_dir" "$scenario" 2>&1) || true
    if echo "$output" | grep -q "compliance check passed"; then
        pass "Medium scenario with all patterns passes"
    else
        fail "Medium scenario with all patterns should pass, got: $output"
    fi
}

# Test 4: Hard scenario with all patterns runs to completion
test_hard_all_match() {
    local scenario
    scenario=$(create_scenario "Hard")
    # Include ALL patterns: read, task/plan, planning/EnterPlanMode, todo/TodoWrite, confidence/HIGH, test/TDD, review
    local test_dir
    test_dir=$(create_test_dir "I need to read the code first. My plan is clear. Using EnterPlanMode for planning phase. Creating TodoWrite task list. My confidence is HIGH. Following TDD approach with test. Let me review everything.")

    local output
    output=$("$COMPLIANCE_SCRIPT" "$test_dir" "$scenario" 2>&1) || true
    if echo "$output" | grep -q "compliance check passed"; then
        pass "Hard scenario with all patterns passes"
    else
        fail "Hard scenario with all patterns should pass, got: $output"
    fi
}

# Test 5: Warning-only checks (required=false) do not abort the script
test_warnings_dont_abort() {
    local scenario
    scenario=$(create_scenario "Simple")
    # Intentionally omit all matching keywords — all checks are required=false (warnings)
    local test_dir
    test_dir=$(create_test_dir "Something without any matching keywords xyz.")

    local exit_code=0
    local output
    output=$("$COMPLIANCE_SCRIPT" "$test_dir" "$scenario" 2>&1) || exit_code=$?
    # Script should run to completion with exit 0 and show warnings
    if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "Compliance Results"; then
        pass "Warning-only checks run to completion without aborting (exit 0)"
    else
        fail "Script should complete with exit 0 and warnings, got exit=$exit_code"
    fi
}

# Test 6: Missing claude_output.txt completes with warnings and exit 0
test_missing_output_file() {
    local scenario
    scenario=$(create_scenario "Simple")
    local empty_dir="$TEMP_DIR/empty-repo-$$"
    mkdir -p "$empty_dir"

    local exit_code=0
    local output
    output=$("$COMPLIANCE_SCRIPT" "$empty_dir" "$scenario" 2>&1) || exit_code=$?
    # All checks are required=false (warnings), so script completes with exit 0
    if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "passed with warnings\|Warnings:"; then
        pass "Missing output file completes with warnings (exit 0)"
    else
        fail "Missing output file should complete with exit 0 and warnings, got exit=$exit_code"
    fi
}

# Test 7: Complexity extraction from scenario file
test_complexity_extraction() {
    local scenario
    scenario=$(create_scenario "Hard")
    local test_dir
    test_dir=$(create_test_dir "reading the file. plan approach. planning with EnterPlanMode. todo list. confidence HIGH. test TDD. review done.")

    local output
    output=$("$COMPLIANCE_SCRIPT" "$test_dir" "$scenario" 2>&1) || true
    if echo "$output" | grep -q "Complexity: hard"; then
        pass "Complexity correctly extracted from scenario file"
    else
        fail "Should extract complexity, got: $output"
    fi
}

# Test 8: Case-insensitive pattern matching (grep -qi)
test_case_insensitive() {
    local scenario
    scenario=$(create_scenario "Simple")
    # Use lowercase versions of keywords
    local test_dir
    test_dir=$(create_test_dir "reading the file. task planning. fixing the bug. review complete.")

    local output
    output=$("$COMPLIANCE_SCRIPT" "$test_dir" "$scenario" 2>&1) || true
    if echo "$output" | grep -q "compliance check passed"; then
        pass "Case-insensitive matching works"
    else
        fail "Case-insensitive matching should work, got: $output"
    fi
}

# Test 9: Pass/Warn counts shown in output on success
test_results_section() {
    local scenario
    scenario=$(create_scenario "Simple")
    local test_dir
    test_dir=$(create_test_dir "reading the file. task approach. fixing it. review done.")

    local output
    output=$("$COMPLIANCE_SCRIPT" "$test_dir" "$scenario" 2>&1) || true
    if echo "$output" | grep -q "Passed:"; then
        pass "Results section shows pass counts"
    else
        fail "Should show pass counts in results"
    fi
}

# Test 10: Wizard idempotence claim uses qualified language
test_wizard_idempotence_qualified() {
    local WIZARD_MD="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"
    if [ ! -f "$WIZARD_MD" ]; then
        fail "CLAUDE_CODE_SDLC_WIZARD.md not found"
        return
    fi

    # The wizard should NOT make unqualified safety guarantees about idempotence
    # It should use language like "designed to be" or "intended" rather than absolute claims
    if grep -q 'designed to be idempotent\|intended to be idempotent' "$WIZARD_MD"; then
        pass "Wizard idempotence claim uses qualified language"
    else
        fail "Wizard should use qualified idempotence language (designed/intended) rather than absolute claims"
    fi
}

# Run all tests
test_script_exists
test_simple_all_match
test_medium_all_match
test_hard_all_match
test_warnings_dont_abort
test_missing_output_file
test_complexity_extraction
test_case_insensitive
test_results_section
test_wizard_idempotence_qualified

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All compliance tests passed!"
