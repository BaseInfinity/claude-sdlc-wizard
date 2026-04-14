#!/bin/bash
# Test simulation prompt requirements in ci.yml
#
# Verifies that the CI simulation prompts instruct Claude to use
# scoreable SDLC practices, and that supporting infrastructure
# (output limits, fixture size) is adequate.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"
EVALUATE_FILE="$SCRIPT_DIR/evaluate.sh"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/test-repo"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

echo "=== Simulation Prompt Requirements Tests ==="
echo ""

# -----------------------------------------------
# Prompt content tests (check ci.yml prompts)
# -----------------------------------------------

echo "--- Prompt instructs scoreable SDLC criteria ---"

test_prompt_mentions_task_tracking() {
    if grep -A 30 'prompt: |' "$CI_FILE" | grep -qi 'TodoWrite\|TaskCreate'; then
        pass "Prompt mentions TodoWrite or TaskCreate"
    else
        fail "Prompt should mention TodoWrite or TaskCreate for task tracking scoring"
    fi
}

test_prompt_mentions_confidence() {
    if grep -A 30 'prompt: |' "$CI_FILE" | grep -qi 'confidence.*HIGH\|confidence.*MEDIUM\|confidence.*LOW\|Confidence: HIGH/MEDIUM/LOW'; then
        pass "Prompt mentions confidence levels (HIGH/MEDIUM/LOW)"
    else
        fail "Prompt should mention confidence levels for scoring"
    fi
}

test_prompt_mentions_tdd() {
    if grep -A 30 'prompt: |' "$CI_FILE" | grep -qi 'TDD\|test.*first\|test-first\|tests FIRST'; then
        pass "Prompt mentions TDD or test-first"
    else
        fail "Prompt should mention TDD or test-first approach"
    fi
}

test_prompt_mentions_plan_mode() {
    if grep -A 30 'prompt: |' "$CI_FILE" | grep -qi 'plan.*before coding\|plan mode\|EnterPlanMode'; then
        pass "Prompt mentions planning before coding"
    else
        fail "Prompt should mention planning for complex tasks"
    fi
}

test_prompt_mentions_self_review() {
    if grep -A 30 'prompt: |' "$CI_FILE" | grep -qi 'self.review\|review.*changes\|review your'; then
        pass "Prompt mentions self-review"
    else
        fail "Prompt should mention self-review"
    fi
}

test_prompt_self_review_explains_how() {
    # Self-review was 0% across all E2E evaluations because the prompt just said
    # "self-review your changes" without explaining HOW (Read/Grep/diff on modified files).
    # The evaluator requires tool-based evidence, not just text statements.
    if grep -A 30 'prompt: |' "$CI_FILE" | grep -qiE 'Read.*modified|Read.*files.*changed|Read.*back|review.*Read|Grep.*diff|git diff'; then
        pass "Prompt explains self-review means using Read/Grep/diff on modified files"
    else
        fail "Prompt must explain self-review = use Read/Grep/diff on modified files (scored criterion)"
    fi
}

test_prompt_self_review_marked_scored() {
    # Self-review must be in the IMPORTANT/scored section, not just step list.
    # Other scored criteria (task_tracking, confidence, tdd_red) all have MUST + scored warnings.
    if grep -A 40 'IMPORTANT:' "$CI_FILE" | grep -qiE 'self.review.*scored|review.*scored|self.review.*MUST'; then
        pass "Prompt marks self-review as scored in IMPORTANT section"
    else
        fail "Prompt must mark self-review as scored in IMPORTANT section (like task_tracking, confidence, tdd_red)"
    fi
}

test_all_structured_simulation_prompts_have_self_review() {
    # Every individual prompt block in workflows with structured prompts must have
    # self-review in both STEPS and IMPORTANT. Counts occurrences to ensure each
    # prompt block is individually covered (ci.yml has 4 blocks, benchmark has 1).
    local missing=""
    for wf in "$REPO_ROOT"/.github/workflows/*.yml; do
        [ ! -f "$wf" ] && continue
        grep -q 'STEPS:' "$wf" || continue
        grep -q 'IMPORTANT:' "$wf" || continue
        local basename
        basename=$(basename "$wf")
        # Count prompt blocks (each "STEPS:" starts a new prompt)
        local prompt_count step_review_count important_review_count
        prompt_count=$(grep -c 'STEPS:' "$wf")
        # Count self-review in step 7 (Read back files)
        step_review_count=$(grep -ciE 'Self-review:.*Read.*back.*files|Read.*back.*files.*modified|Read.*files.*modified' "$wf")
        # Count self-review in IMPORTANT (MUST + scored)
        important_review_count=$(grep -ciE 'MUST self.review.*scored|self.review.*MUST.*scored' "$wf")
        if [ "$step_review_count" -lt "$prompt_count" ]; then
            missing="$missing $basename(STEPS:$step_review_count/$prompt_count)"
        fi
        if [ "$important_review_count" -lt "$prompt_count" ]; then
            missing="$missing $basename(IMPORTANT:$important_review_count/$prompt_count)"
        fi
    done
    if [ -z "$missing" ]; then
        pass "All structured simulation prompts have self-review in STEPS + IMPORTANT"
    else
        fail "Missing self-review in structured simulation prompts:$missing"
    fi
}

# -----------------------------------------------
# Infrastructure tests
# -----------------------------------------------

echo ""
echo "--- Infrastructure adequacy ---"

test_output_limit_adequate() {
    # evaluate.sh should not truncate at 50KB - need at least 100KB
    local limit
    limit=$(grep -o 'head -c [0-9]*' "$EVALUATE_FILE" | head -1 | grep -o '[0-9]*')
    if [ -n "$limit" ] && [ "$limit" -ge 100000 ]; then
        pass "Output limit is >= 100KB (${limit} bytes)"
    else
        fail "Output limit should be >= 100KB, got ${limit:-unknown} bytes"
    fi
}

test_fixture_app_size() {
    local app_file="$FIXTURE_DIR/src/app.js"
    if [ ! -f "$app_file" ]; then
        fail "Fixture app.js not found at $app_file"
        return
    fi
    local line_count
    line_count=$(wc -l < "$app_file" | tr -d ' ')
    if [ "$line_count" -ge 40 ]; then
        pass "Fixture app.js has >= 40 lines ($line_count lines)"
    else
        fail "Fixture app.js should have >= 40 lines, has $line_count"
    fi
}

test_fixture_has_multiple_source_files() {
    local src_count
    src_count=$(find "$FIXTURE_DIR/src" -name "*.js" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$src_count" -ge 2 ]; then
        pass "Fixture has >= 2 source files ($src_count files)"
    else
        fail "Fixture should have >= 2 source files, has $src_count"
    fi
}

test_evaluate_uses_file_based_curl() {
    # evaluate.sh must use curl -d @file (file-based) not inline -d '{...}'
    # to avoid "Argument list too long" with large outputs (200KB+)
    if grep -q '\-d @' "$EVALUATE_FILE"; then
        pass "evaluate.sh uses file-based curl (-d @file)"
    else
        fail "evaluate.sh should use file-based curl (-d @file) to avoid argument length limits"
    fi
}

# Run all tests
test_prompt_mentions_task_tracking
test_prompt_mentions_confidence
test_prompt_mentions_tdd
test_prompt_mentions_plan_mode
test_prompt_mentions_self_review
test_prompt_self_review_explains_how
test_prompt_self_review_marked_scored
test_all_structured_simulation_prompts_have_self_review
test_output_limit_adequate
test_fixture_app_size
test_fixture_has_multiple_source_files
test_evaluate_uses_file_based_curl

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All simulation prompt tests passed!"
