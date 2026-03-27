#!/bin/bash
# Test workflow trigger configurations and state file handling

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

echo "=== Workflow Trigger Tests ==="
echo ""

# Test 1: Weekly-update workflow has workflow_dispatch trigger
test_weekly_update_dispatch() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml file not found"
        return
    fi

    if grep -q "workflow_dispatch:" "$WORKFLOW"; then
        pass "weekly-update.yml has workflow_dispatch trigger"
    else
        fail "weekly-update.yml missing workflow_dispatch trigger"
    fi
}

# Test 2: daily-update.yml must NOT exist (consolidated into weekly-update.yml)
test_daily_update_deleted() {
    WORKFLOW="$REPO_ROOT/.github/workflows/daily-update.yml"

    if [ -f "$WORKFLOW" ]; then
        fail "daily-update.yml still exists (should be deleted — consolidated into weekly-update.yml)"
    else
        pass "daily-update.yml does not exist (consolidated into weekly-update.yml)"
    fi
}

# Test 3: Monthly workflow has workflow_dispatch trigger
test_monthly_dispatch() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "Monthly workflow file not found"
        return
    fi

    if grep -q "workflow_dispatch:" "$WORKFLOW"; then
        pass "Monthly workflow has workflow_dispatch trigger"
    else
        fail "Monthly workflow missing workflow_dispatch trigger"
    fi
}

# Test 4: Weekly-update workflow has active schedule trigger
test_weekly_update_has_schedule() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "schedule:" "$WORKFLOW" && grep -q "cron:" "$WORKFLOW"; then
        pass "weekly-update.yml has active schedule with cron trigger"
    else
        fail "weekly-update.yml missing schedule trigger"
    fi
}

# Test 35: weekly-community.yml must NOT exist (consolidated into weekly-update.yml)
test_weekly_community_deleted() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-community.yml"

    if [ -f "$WORKFLOW" ]; then
        fail "weekly-community.yml still exists (should be deleted — consolidated into weekly-update.yml)"
    else
        pass "weekly-community.yml does not exist (consolidated into weekly-update.yml)"
    fi
}

# Test 36: Monthly workflow has active schedule trigger (Item 23 Phase 3)
test_monthly_has_schedule() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if grep -q "schedule:" "$WORKFLOW" && grep -q "cron:" "$WORKFLOW"; then
        pass "Monthly workflow has active schedule with cron trigger"
    else
        fail "Monthly workflow missing schedule trigger (should have cron for Item 23)"
    fi
}

# Test 5: State file path is valid in weekly-update workflow
test_state_file_path() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "last-checked-version.txt" "$WORKFLOW"; then
        pass "weekly-update.yml references state file correctly"
    else
        fail "weekly-update.yml missing state file reference"
    fi
}

# Test 6: State file round-trip (write then read)
test_state_file_roundtrip() {
    TEMP_DIR=$(mktemp -d)
    STATE_FILE="$TEMP_DIR/last-checked-version.txt"
    TEST_VERSION="v2.1.20"

    # Write
    echo "$TEST_VERSION" > "$STATE_FILE"

    # Read back (same logic as workflow)
    if [ -f "$STATE_FILE" ]; then
        READ_VERSION=$(cat "$STATE_FILE" | tr -d '\n')
    else
        READ_VERSION="v0.0.0"
    fi

    rm -rf "$TEMP_DIR"

    if [ "$READ_VERSION" = "$TEST_VERSION" ]; then
        pass "State file round-trip works correctly"
    else
        fail "State file round-trip failed: wrote '$TEST_VERSION', read '$READ_VERSION'"
    fi
}

# Test 7: Workflow has proper permissions
test_workflow_permissions() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "permissions:" "$WORKFLOW"; then
        pass "weekly-update.yml declares permissions"
    else
        fail "weekly-update.yml missing permissions declaration"
    fi
}

# Test 8: Workflow uses checkout action
test_workflow_checkout() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "actions/checkout" "$WORKFLOW"; then
        pass "weekly-update.yml uses checkout action"
    else
        fail "weekly-update.yml missing checkout action"
    fi
}

# Test 9: Error handling - jq fallback for missing release
test_error_handling_pattern() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    # Check for error handling pattern (|| echo for fallback)
    if grep -q '|| echo' "$WORKFLOW" || grep -q '2>/dev/null' "$WORKFLOW"; then
        pass "weekly-update.yml has error handling patterns"
    else
        fail "weekly-update.yml missing error handling"
    fi
}

# Test 10: All workflows are valid YAML (basic check)
test_yaml_validity() {
    WORKFLOWS="$REPO_ROOT/.github/workflows"
    ALL_VALID=true

    for workflow in "$WORKFLOWS"/*.yml; do
        # Basic check: file starts with valid YAML (name: or on:)
        FIRST_LINE=$(head -n 1 "$workflow")
        if [[ ! "$FIRST_LINE" =~ ^(name:|on:|\#) ]]; then
            fail "Workflow $(basename "$workflow") may have invalid YAML"
            ALL_VALID=false
        fi
    done

    if [ "$ALL_VALID" = true ]; then
        pass "All workflow files have valid YAML structure"
    fi
}

# ============================================
# E2E Bootstrapping Detection Regression Tests
# ============================================
# These tests ensure the bootstrapping logic in ci.yml
# is not accidentally removed or broken.

# Test 11: CI has bootstrapping detection step
test_e2e_bootstrapping_detection() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    if grep -q "check-baseline" "$WORKFLOW" && \
       grep -q "has_baseline" "$WORKFLOW"; then
        pass "CI has bootstrapping detection step"
    else
        fail "CI missing bootstrapping detection (check-baseline + has_baseline)"
    fi
}

# Test 12: Baseline steps are conditional on has_baseline
test_e2e_conditional_baseline() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if grep -q "if:.*has_baseline.*true" "$WORKFLOW"; then
        pass "Baseline steps are conditional on has_baseline"
    else
        fail "Baseline steps not properly conditional on has_baseline"
    fi
}

# Test 13: Bootstrapping is handled in compare step
test_e2e_bootstrapping_handling() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if grep -q "is_bootstrapping" "$WORKFLOW"; then
        pass "Compare step handles bootstrapping case"
    else
        fail "Compare step missing bootstrapping handling (is_bootstrapping)"
    fi
}

# ============================================
# CI Label Trigger Tests
# ============================================
# These tests ensure the CI workflow properly handles
# the `labeled` event for merge-ready label triggering.

# Test 14: CI pull_request trigger includes 'labeled' type
test_ci_labeled_trigger() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    if grep -q "labeled" "$WORKFLOW"; then
        pass "CI pull_request trigger includes 'labeled' type"
    else
        fail "CI pull_request trigger missing 'labeled' type"
    fi
}

# Test 15: e2e-quick-check is guarded from labeled events
test_quick_check_labeled_guard() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    # The e2e-quick-check job should skip on labeled events
    # Look for the guard condition near the e2e-quick-check job
    if sed -n '/e2e-quick-check:/,/steps:/p' "$WORKFLOW" | grep -q "labeled"; then
        pass "e2e-quick-check is guarded from labeled events"
    else
        fail "e2e-quick-check missing guard for labeled events"
    fi
}

# Test 16: cleanup-old-comments is guarded from labeled events
test_cleanup_labeled_guard() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    # The cleanup-old-comments job should skip on labeled events
    if sed -n '/cleanup-old-comments:/,/steps:/p' "$WORKFLOW" | grep -q "labeled"; then
        pass "cleanup-old-comments is guarded from labeled events"
    else
        fail "cleanup-old-comments missing guard for labeled events"
    fi
}

# Test 17: Weekly-update workflow checks for existing PR before creating
test_weekly_existing_pr_check() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "existing-pr" "$WORKFLOW" && grep -q "skip" "$WORKFLOW"; then
        pass "weekly-update.yml checks for existing PR before creating"
    else
        fail "weekly-update.yml missing existing PR check"
    fi
}

# ============================================
# PR Review Re-trigger Tests
# ============================================
# These tests ensure the PR review workflow re-runs
# on each push (synchronize event), not just on open.

# Test 18: PR review triggers on synchronize (re-review on push)
test_pr_review_synchronize_trigger() {
    WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "PR review workflow file not found"
        return
    fi

    # Check the types: line specifically includes synchronize
    if grep "types:" "$WORKFLOW" | grep -q "synchronize"; then
        pass "PR review workflow triggers on synchronize"
    else
        fail "PR review workflow missing synchronize trigger (reviews only run once per PR)"
    fi
}

# Test 19: PR review if-condition allows synchronize events through
test_pr_review_synchronize_condition() {
    WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "PR review workflow file not found"
        return
    fi

    # The job-level if condition must include synchronize
    if grep -A 5 "if:" "$WORKFLOW" | grep -q "synchronize"; then
        pass "PR review if-condition handles synchronize events"
    else
        fail "PR review if-condition does not handle synchronize events (reviews won't run on push)"
    fi
}

# ============================================
# E2E AllowedTools Coverage Tests
# ============================================
# These tests ensure Claude simulations have access
# to the tools that scenarios actually need.

# Test 20: CI allowedTools excludes plan mode tools (they loop in headless CI)
test_ci_allowed_tools_no_plan_mode() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    if grep "allowedTools" "$WORKFLOW" | grep -q "EnterPlanMode\|ExitPlanMode"; then
        fail "CI allowedTools should NOT include EnterPlanMode/ExitPlanMode (loops in headless CI)"
    else
        pass "CI allowedTools excludes plan mode tools (headless-safe)"
    fi
}

# Test 21: CI allowedTools includes task tracking tools (needed for scoring)
test_ci_allowed_tools_task_tracking() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    if grep "allowedTools" "$WORKFLOW" | grep -q "TaskCreate"; then
        pass "CI allowedTools includes TaskCreate"
    else
        fail "CI allowedTools missing TaskCreate (8/10 scenarios score on task tracking)"
    fi
}

# ============================================
# CI Auto-Fix Workflow Tests
# ============================================
# These tests ensure the ci-self-heal.yml workflow
# is properly configured for the automated fix loop.

# Test 22: ci-self-heal.yml file exists
test_ci_autofix_exists() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ -f "$WORKFLOW" ]; then
        pass "ci-self-heal.yml file exists"
    else
        fail "ci-self-heal.yml file not found"
    fi
}

# Test 23: ci-autofix triggers on workflow_run
test_ci_autofix_workflow_run_trigger() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for trigger test)"
        return
    fi

    if grep -q "workflow_run:" "$WORKFLOW"; then
        pass "ci-autofix triggers on workflow_run"
    else
        fail "ci-autofix missing workflow_run trigger"
    fi
}

# Test 24: ci-autofix watches both CI and PR Code Review workflows
test_ci_autofix_watches_both_workflows() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for workflows test)"
        return
    fi

    if grep -q '"CI"' "$WORKFLOW" && grep -q '"PR Code Review"' "$WORKFLOW"; then
        pass "ci-autofix watches both CI and PR Code Review workflows"
    else
        fail "ci-autofix not watching both CI and PR Code Review workflows"
    fi
}

# Test 25: ci-autofix has MAX_AUTOFIX_RETRIES config
test_ci_autofix_max_retries() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for retries test)"
        return
    fi

    if grep -q "MAX_AUTOFIX_RETRIES" "$WORKFLOW"; then
        pass "ci-autofix has MAX_AUTOFIX_RETRIES config"
    else
        fail "ci-autofix missing MAX_AUTOFIX_RETRIES config"
    fi
}

# Test 26: ci-autofix excludes main branch
test_ci_autofix_excludes_main() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for branch exclusion test)"
        return
    fi

    if grep -q "main" "$WORKFLOW" && grep -q "head_branch" "$WORKFLOW"; then
        pass "ci-autofix excludes main branch"
    else
        fail "ci-autofix missing main branch exclusion"
    fi
}

# Test 27: ci-autofix uses claude-code-action
test_ci_autofix_uses_claude() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for claude action test)"
        return
    fi

    if grep -q "claude-code-action" "$WORKFLOW"; then
        pass "ci-autofix uses claude-code-action"
    else
        fail "ci-autofix missing claude-code-action"
    fi
}

# Test 28: ci-autofix uses [autofix] commit tag pattern
test_ci_autofix_commit_tag() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for commit tag test)"
        return
    fi

    if grep -q '\[autofix' "$WORKFLOW"; then
        pass "ci-autofix uses [autofix] commit tag pattern"
    else
        fail "ci-autofix missing [autofix] commit tag pattern"
    fi
}

# Test 29: ci-autofix posts sticky PR comment
test_ci_autofix_sticky_comment() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for sticky comment test)"
        return
    fi

    if grep -q "sticky-pull-request-comment" "$WORKFLOW" && grep -q "ci-autofix" "$WORKFLOW"; then
        pass "ci-autofix posts sticky PR comment"
    else
        fail "ci-autofix missing sticky PR comment"
    fi
}

# Test 30: ci.yml has workflow_dispatch trigger
test_ci_workflow_dispatch() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found (needed for dispatch test)"
        return
    fi

    if grep -q "workflow_dispatch:" "$WORKFLOW"; then
        pass "ci.yml has workflow_dispatch trigger"
    else
        fail "ci.yml missing workflow_dispatch trigger"
    fi
}

# Test 31: ci-autofix reads review comment for findings
test_ci_autofix_reads_review() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for review reading test)"
        return
    fi

    if grep -q "claude-review" "$WORKFLOW"; then
        pass "ci-autofix reads review comment (claude-review header)"
    else
        fail "ci-autofix missing review comment reading (claude-review)"
    fi
}

# ============================================
# CI Autofix Prompt & E2E Turns Tests
# ============================================
# These tests ensure the ci-autofix prompt passes
# context via file paths (not broken step outputs)
# and that simulations have enough turns.

# Test 32: ci-autofix prompt references /tmp/ci-failure-context.txt
test_ci_autofix_prompt_failure_file() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for prompt file test)"
        return
    fi

    if grep -q "/tmp/ci-failure-context.txt" "$WORKFLOW"; then
        pass "ci-autofix prompt references /tmp/ci-failure-context.txt"
    else
        fail "ci-autofix prompt missing /tmp/ci-failure-context.txt reference (Claude gets empty context)"
    fi
}

# Test 33: ci-autofix prompt references /tmp/review-findings.md
test_ci_autofix_prompt_review_file() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for prompt file test)"
        return
    fi

    if grep -q "/tmp/review-findings.md" "$WORKFLOW"; then
        pass "ci-autofix prompt references /tmp/review-findings.md"
    else
        fail "ci-autofix prompt missing /tmp/review-findings.md reference (Claude gets empty context)"
    fi
}

# Test 34: ci.yml max-turns is >= 35 for all simulations
test_ci_max_turns_sufficient() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found (needed for max-turns test)"
        return
    fi

    # Extract all --max-turns values and check they're all >= 35
    ALL_SUFFICIENT=true
    while IFS= read -r line; do
        TURNS=$(echo "$line" | grep -oE '[0-9]+')
        if [ "$TURNS" -lt 35 ]; then
            fail "ci.yml has --max-turns $TURNS (need >= 35 to avoid error_max_turns flakiness)"
            ALL_SUFFICIENT=false
            break
        fi
    done < <(grep -- "--max-turns" "$WORKFLOW")

    if [ "$ALL_SUFFICIENT" = true ]; then
        pass "ci.yml max-turns is >= 35 for all simulations"
    fi
}

# Run all tests
test_weekly_update_dispatch
test_daily_update_deleted
test_monthly_dispatch
test_weekly_update_has_schedule
test_weekly_community_deleted
test_monthly_has_schedule
test_state_file_path
test_state_file_roundtrip
test_workflow_permissions
test_workflow_checkout
test_error_handling_pattern
test_yaml_validity
test_e2e_bootstrapping_detection
test_e2e_conditional_baseline
test_e2e_bootstrapping_handling
test_ci_labeled_trigger
test_quick_check_labeled_guard
test_cleanup_labeled_guard
test_weekly_existing_pr_check
test_pr_review_synchronize_trigger
test_pr_review_synchronize_condition
test_ci_allowed_tools_no_plan_mode
test_ci_allowed_tools_task_tracking
test_ci_autofix_exists
test_ci_autofix_workflow_run_trigger
test_ci_autofix_watches_both_workflows
test_ci_autofix_max_retries
test_ci_autofix_excludes_main
test_ci_autofix_uses_claude
test_ci_autofix_commit_tag
test_ci_autofix_sticky_comment
test_ci_workflow_dispatch
test_ci_autofix_reads_review
test_ci_autofix_prompt_failure_file
test_ci_autofix_prompt_review_file
test_ci_max_turns_sufficient

# ============================================
# CI Autofix Suggestion Handling Tests
# ============================================
# These tests ensure ci-autofix addresses ALL review
# findings (both criticals and suggestions), not just criticals.

# Test 37: ci-autofix checks for suggestions (not just criticals)
test_ci_autofix_checks_suggestions() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for suggestions test)"
        return
    fi

    if grep -q "Suggestions (nice to have)" "$WORKFLOW"; then
        pass "ci-autofix checks for suggestions (not just criticals)"
    else
        fail "ci-autofix only checks for criticals, ignores suggestions"
    fi
}

# Test 38: ci-autofix prompt addresses all findings
test_ci_autofix_prompt_all_findings() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for prompt test)"
        return
    fi

    if grep -q "suggestions" "$WORKFLOW" && grep -q "critical" "$WORKFLOW"; then
        pass "ci-autofix prompt addresses both criticals and suggestions"
    else
        fail "ci-autofix prompt only addresses criticals"
    fi
}

# Test 39: ci-autofix prompt tells Claude to use Read tool (not Bash) for context files
test_ci_autofix_prompt_read_tool() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for Read tool test)"
        return
    fi

    if grep -q "Use the Read tool" "$WORKFLOW" && grep -q "NOT Bash" "$WORKFLOW"; then
        pass "ci-autofix prompt steers Claude to Read tool (prevents wasted Bash denials)"
    else
        fail "ci-autofix prompt missing Read tool guidance (Claude will waste turns on denied Bash calls)"
    fi
}

test_ci_autofix_checks_suggestions
test_ci_autofix_prompt_all_findings
test_ci_autofix_prompt_read_tool

# ============================================
# CI Autofix Max-Turns & Prompt Hygiene Tests
# ============================================

# Test 40: ci-autofix --max-turns >= 30
test_ci_autofix_max_turns() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for max-turns test)"
        return
    fi

    # Extract --max-turns value from ci-self-heal.yml
    TURNS=$(grep -oE '\-\-max-turns [0-9]+' "$WORKFLOW" | grep -oE '[0-9]+')

    if [ -z "$TURNS" ]; then
        fail "ci-self-heal.yml missing --max-turns flag"
        return
    fi

    if [ "$TURNS" -ge 30 ]; then
        pass "ci-autofix --max-turns is >= 30 ($TURNS)"
    else
        fail "ci-autofix --max-turns is $TURNS (need >= 30 for complex fixes)"
    fi
}

# Test 41: ci-autofix prompt has no literal \n ternary pattern
test_ci_autofix_no_ternary_newlines() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml file not found (needed for ternary test)"
        return
    fi

    # Check for the problematic pattern: ${{ expr && 'text\n' || '' }}
    if grep -q "&&.*\\\\n.*||" "$WORKFLOW"; then
        fail "ci-autofix prompt uses ternary with literal \\n (renders as literal backslash-n, not newline)"
    else
        pass "ci-autofix prompt has no ternary \\n pattern"
    fi
}

test_ci_autofix_max_turns
test_ci_autofix_no_ternary_newlines

# ============================================
# CI Cosmetic Step Resilience Tests
# ============================================
# These tests ensure cosmetic CI steps (PR comments)
# don't fail the build, while the real quality gate does.

# Test 42: "Build quick check comment message" has continue-on-error
test_quick_check_comment_continue_on_error() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found (needed for continue-on-error test)"
        return
    fi

    # Check that the "Build quick check comment message" step has continue-on-error: true
    if grep -A 5 "Build quick check comment message" "$WORKFLOW" | grep -q "continue-on-error: true"; then
        pass "Build quick check comment message has continue-on-error: true"
    else
        fail "Build quick check comment message missing continue-on-error: true (cosmetic step can fail the build)"
    fi
}

# Test 43: "Comment quick check results on PR" has continue-on-error
test_quick_check_post_comment_continue_on_error() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found (needed for continue-on-error test)"
        return
    fi

    # Check that the "Comment quick check results on PR" step has continue-on-error: true
    if grep -A 2 "Comment quick check results on PR" "$WORKFLOW" | grep -q "continue-on-error: true"; then
        pass "Comment quick check results on PR has continue-on-error: true"
    else
        fail "Comment quick check results on PR missing continue-on-error: true (cosmetic step can fail the build)"
    fi
}

# Test 44: "Fail on regression" does NOT have continue-on-error
test_fail_on_regression_no_continue_on_error() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found (needed for quality gate test)"
        return
    fi

    # The quality gate must NOT have continue-on-error
    if grep -A 2 "Fail on regression" "$WORKFLOW" | grep -q "continue-on-error"; then
        fail "Fail on regression has continue-on-error (quality gate would be bypassed!)"
    else
        pass "Fail on regression does NOT have continue-on-error (quality gate intact)"
    fi
}

# ============================================
# CI Comment Safety Tests
# ============================================
# These tests ensure untrusted LLM output (criteria evidence)
# is NOT assigned via ${{ }} inline in bash (backtick injection).

# Test 45: CRITERIA is passed via env block, not inline ${{ }} in bash
test_criteria_not_inline_expanded() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found (needed for criteria safety test)"
        return
    fi

    # Check that CRITERIA is NOT set via inline ${{ }} in a bash variable assignment
    # Bad:  CRITERIA="${{ steps.eval-candidate.outputs.criteria }}"
    # Good: env: CRITERIA: ${{ steps.eval-candidate.outputs.criteria }}
    if grep -E 'CRITERIA="\$\{\{' "$WORKFLOW"; then
        fail "CRITERIA uses inline \${{ }} expansion (backticks in LLM evidence text execute as commands)"
    else
        pass "CRITERIA is not inline-expanded in bash (safe from backtick injection)"
    fi
}

# Test 46: Comment-building steps use env block for untrusted outputs
test_comment_steps_use_env_block() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found (needed for env block test)"
        return
    fi

    # Both "Build quick check comment message" and "Build full evaluation comment message"
    # should have an env: block that includes CRITERIA
    QUICK_HAS_ENV=false
    FULL_HAS_ENV=false

    # Use python for reliable multi-line YAML parsing
    python3 -c "
import yaml, sys
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        name = step.get('name', '')
        env = step.get('env', {})
        if 'Build quick check comment message' in name:
            if 'CRITERIA' in env:
                print('QUICK_ENV_OK')
        if 'Build full evaluation comment message' in name:
            if 'CRITERIA' in env:
                print('FULL_ENV_OK')
" > /tmp/env_check_result.txt 2>&1

    if grep -q "QUICK_ENV_OK" /tmp/env_check_result.txt; then
        QUICK_HAS_ENV=true
    fi
    if grep -q "FULL_ENV_OK" /tmp/env_check_result.txt; then
        FULL_HAS_ENV=true
    fi

    if [ "$QUICK_HAS_ENV" = true ] && [ "$FULL_HAS_ENV" = true ]; then
        pass "Both comment-building steps pass CRITERIA via env block (safe)"
    else
        if [ "$QUICK_HAS_ENV" = false ]; then
            fail "Quick check comment step missing CRITERIA in env block"
        fi
        if [ "$FULL_HAS_ENV" = false ]; then
            fail "Full evaluation comment step missing CRITERIA in env block"
        fi
    fi
}

test_criteria_not_inline_expanded
test_comment_steps_use_env_block

test_quick_check_comment_continue_on_error
test_quick_check_post_comment_continue_on_error
test_fail_on_regression_no_continue_on_error

# ============================================
# Full E2E Dependency Compatibility Tests
# ============================================
# These tests ensure the e2e-full-evaluation job can actually run
# when triggered by the 'labeled' event (merge-ready label).

# Test 47: e2e-full-evaluation must not depend on jobs that skip on 'labeled' events
test_full_eval_deps_run_on_labeled() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # Parse the workflow to check that every job in e2e-full-evaluation's 'needs'
    # does NOT have a condition that excludes 'labeled' events
    python3 -c "
import yaml, sys
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
jobs = wf.get('jobs', {})
full_eval = jobs.get('e2e-full-evaluation', {})
needs = full_eval.get('needs', [])
if isinstance(needs, str):
    needs = [needs]

blocked = []
for dep in needs:
    dep_job = jobs.get(dep, {})
    condition = str(dep_job.get('if', ''))
    # If the dependency skips on 'labeled' events, full-eval can never run
    if \"event.action != 'labeled'\" in condition:
        blocked.append(dep)

if blocked:
    print('BLOCKED_BY:' + ','.join(blocked))
else:
    print('DEPS_OK')
" > /tmp/full_eval_deps.txt 2>&1

    if grep -q "DEPS_OK" /tmp/full_eval_deps.txt; then
        pass "e2e-full-evaluation dependencies all run on 'labeled' events"
    else
        BLOCKERS=$(grep "BLOCKED_BY:" /tmp/full_eval_deps.txt | sed 's/BLOCKED_BY://')
        fail "e2e-full-evaluation depends on jobs that skip on 'labeled': $BLOCKERS (full eval can never run)"
    fi
}

test_full_eval_deps_run_on_labeled

# ============================================
# PR Review Prompt Hygiene Tests
# ============================================
# Ensure the review prompt doesn't contain shell
# constructs that won't expand in YAML strings.

# Test 48: pr-review prompt must not use $(cat ...) in YAML prompt field
test_review_prompt_no_shell_subst() {
    WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "pr-review.yml file not found"
        return
    fi

    # $(cat ...) in a YAML 'prompt: |' field is dead code —
    # YAML strings don't execute shell commands.
    # claude-code-action provides comments through its own mechanism.
    if grep -E '\$\(cat ' "$WORKFLOW"; then
        fail "pr-review.yml prompt contains \$(cat ...) — won't expand in YAML string (dead code)"
    else
        pass "pr-review.yml prompt has no shell command substitution in YAML strings"
    fi
}

test_review_prompt_no_shell_subst

# Test 91: pr-review prompt references CODE_REVIEW_EXCEPTIONS.md
test_review_prompt_has_exceptions_ref() {
    WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "pr-review.yml file not found"
        return
    fi

    if grep -q "CODE_REVIEW_EXCEPTIONS.md" "$WORKFLOW"; then
        pass "pr-review.yml prompt references CODE_REVIEW_EXCEPTIONS.md"
    else
        fail "pr-review.yml prompt does not reference CODE_REVIEW_EXCEPTIONS.md"
    fi
}

# Test 92: CODE_REVIEW_EXCEPTIONS.md exists
test_review_exceptions_file_exists() {
    if [ -f "$REPO_ROOT/CODE_REVIEW_EXCEPTIONS.md" ]; then
        pass "CODE_REVIEW_EXCEPTIONS.md exists"
    else
        fail "CODE_REVIEW_EXCEPTIONS.md not found in repo root"
    fi
}

test_review_prompt_has_exceptions_ref
test_review_exceptions_file_exists

# Test 93: ci.yml has concurrency group (cancel stale runs)
test_ci_has_concurrency() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci.yml file not found"
        return
    fi

    if grep -q "cancel-in-progress: true" "$WORKFLOW"; then
        pass "ci.yml has concurrency cancel-in-progress"
    else
        fail "ci.yml missing concurrency cancel-in-progress"
    fi
}

# Test 94: pr-review.yml has concurrency group (cancel stale runs)
test_pr_review_has_concurrency() {
    WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "pr-review.yml file not found"
        return
    fi

    if grep -q "cancel-in-progress: true" "$WORKFLOW"; then
        pass "pr-review.yml has concurrency cancel-in-progress"
    else
        fail "pr-review.yml missing concurrency cancel-in-progress"
    fi
}

test_ci_has_concurrency
test_pr_review_has_concurrency

# ============================================
# Weekly-Update Workflow Input Validation Tests
# ============================================
# Ensure claude-code-action steps use valid inputs only.
# (Consolidates former daily-update + weekly-community tests)

# Test 49: weekly-update must NOT use 'prompt_file' (not a valid action input)
test_weekly_update_no_prompt_file_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    # claude-code-action@v1 does not accept 'prompt_file' — use 'prompt' instead
    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        with_block = step.get('with', {})
        if 'prompt_file' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/prompt_file_check.txt 2>&1

    if grep -q "FOUND:" /tmp/prompt_file_check.txt; then
        STEP=$(grep "FOUND:" /tmp/prompt_file_check.txt | head -1 | sed 's/FOUND://')
        fail "weekly-update uses 'prompt_file' input in step '$STEP' — not a valid claude-code-action input"
    else
        pass "weekly-update does not use invalid 'prompt_file' input"
    fi
}

# Test 50: weekly-update must NOT use 'direct_prompt' (not a valid action input)
test_weekly_update_no_direct_prompt_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        with_block = step.get('with', {})
        if 'direct_prompt' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/direct_prompt_check.txt 2>&1

    if grep -q "FOUND:" /tmp/direct_prompt_check.txt; then
        STEP=$(grep "FOUND:" /tmp/direct_prompt_check.txt | head -1 | sed 's/FOUND://')
        fail "weekly-update uses 'direct_prompt' input in step '$STEP' — not a valid claude-code-action input"
    else
        pass "weekly-update does not use invalid 'direct_prompt' input"
    fi
}

# Test 51: weekly-update must NOT use 'model' as a top-level action input
test_weekly_update_no_model_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        uses = step.get('uses', '')
        with_block = step.get('with', {})
        if 'claude-code-action' in uses and 'model' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/model_input_check.txt 2>&1

    if grep -q "FOUND:" /tmp/model_input_check.txt; then
        STEP=$(grep "FOUND:" /tmp/model_input_check.txt | head -1 | sed 's/FOUND://')
        fail "weekly-update uses 'model' as action input in step '$STEP' — use claude_args --model instead"
    else
        pass "weekly-update does not use invalid 'model' action input"
    fi
}

# Test 52: weekly-update evaluate.sh calls must NOT use 2>&1 (stderr corruption)
test_weekly_update_no_stderr_mixing_in_eval() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    # evaluate.sh calls with 2>&1 corrupt JSON output with stderr messages.
    python3 -c "
import yaml, re
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        run = step.get('run', '')
        if 'evaluate.sh' in run and '2>&1' in run:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/stderr_mix_check.txt 2>&1

    if grep -q "FOUND:" /tmp/stderr_mix_check.txt; then
        STEP=$(grep "FOUND:" /tmp/stderr_mix_check.txt | head -1 | sed 's/FOUND://')
        fail "weekly-update step '$STEP' pipes evaluate.sh stderr to stdout (2>&1) — causes jq parse failures"
    else
        pass "weekly-update.yml does not mix stderr into evaluate.sh output"
    fi
}

test_weekly_update_no_prompt_file_input
test_weekly_update_no_direct_prompt_input
test_weekly_update_no_model_input
test_weekly_update_no_stderr_mixing_in_eval

# Test 53: weekly-update must NOT reference outputs.response (doesn't exist in claude-code-action@v1)
test_weekly_update_no_outputs_response() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    content = f.read()
if 'outputs.response' in content:
    print('FOUND')
" > /tmp/outputs_response_check.txt 2>&1

    if grep -q "FOUND" /tmp/outputs_response_check.txt; then
        fail "weekly-update references 'outputs.response' — claude-code-action@v1 has no response output"
    else
        pass "weekly-update does not reference non-existent 'outputs.response'"
    fi
}

# Test 54: weekly-update must extract analysis from execution output file
test_weekly_update_extracts_from_output_file() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        run = step.get('run', '')
        if 'claude-execution-output.json' in run and 'analysis' in step.get('name', '').lower():
            print('READS_OUTPUT_FILE')
" > /tmp/output_file_check.txt 2>&1

    if grep -q "READS_OUTPUT_FILE" /tmp/output_file_check.txt; then
        pass "weekly-update extracts analysis from execution output file"
    else
        fail "weekly-update does not read claude-execution-output.json for analysis (result will be empty)"
    fi
}

test_weekly_update_no_outputs_response
test_weekly_update_extracts_from_output_file

# ============================================
# Weekly-Update Workflow Input Validation Tests (continued)
# ============================================
# Tests 55-60: These previously tested weekly-community.yml separately.
# Now consolidated — they also check weekly-update.yml (same file as 49-54).

# Test 55: weekly-update must NOT use 'allowed_tools' as action input (use claude_args)
test_weekly_update_no_allowed_tools_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        with_block = step.get('with', {})
        if 'allowed_tools' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/weekly_allowed_tools_check.txt 2>&1

    if grep -q "FOUND:" /tmp/weekly_allowed_tools_check.txt; then
        STEP=$(grep "FOUND:" /tmp/weekly_allowed_tools_check.txt | head -1 | sed 's/FOUND://')
        fail "weekly-update uses 'allowed_tools' input in step '$STEP' — use claude_args --allowedTools instead"
    else
        pass "weekly-update does not use invalid 'allowed_tools' input"
    fi
}

# Test 56: weekly-update must extract community scan result from execution output file
test_weekly_update_extracts_scan_from_output_file() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        run = step.get('run', '')
        name = step.get('name', '').lower()
        if 'claude-execution-output.json' in run and ('scan' in name or 'extract' in name or 'save' in name):
            print('READS_OUTPUT_FILE')
" > /tmp/weekly_output_file_check.txt 2>&1

    if grep -q "READS_OUTPUT_FILE" /tmp/weekly_output_file_check.txt; then
        pass "weekly-update extracts community scan result from execution output file"
    else
        fail "weekly-update does not read claude-execution-output.json for community scan result"
    fi
}

# Test 57: weekly-update community scan references last-community-scan.txt state file
test_weekly_update_community_state_file() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "last-community-scan.txt" "$WORKFLOW"; then
        pass "weekly-update references community scan state file"
    else
        fail "weekly-update missing last-community-scan.txt reference"
    fi
}

# Test 58: weekly-update creates GitHub issues for community digest
test_weekly_update_creates_issues() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "gh issue create\|issues:" "$WORKFLOW"; then
        pass "weekly-update has issue creation capability"
    else
        fail "weekly-update missing issue creation for community digest"
    fi
}

# Test 59: weekly-update uses peter-evans/create-pull-request for version update PRs
test_weekly_update_uses_create_pr() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "peter-evans/create-pull-request" "$WORKFLOW"; then
        pass "weekly-update uses peter-evans/create-pull-request"
    else
        fail "weekly-update missing peter-evans/create-pull-request"
    fi
}

test_weekly_update_no_allowed_tools_input
test_weekly_update_extracts_scan_from_output_file
test_weekly_update_community_state_file
test_weekly_update_creates_issues
test_weekly_update_uses_create_pr

# ============================================
# Monthly-Research Workflow Input Validation Tests
# ============================================
# Same class of bugs as daily-update and weekly-community.

# Test 61: monthly-research must NOT use 'prompt_file' (not a valid action input)
test_monthly_no_prompt_file_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        with_block = step.get('with', {})
        if 'prompt_file' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/monthly_prompt_file_check.txt 2>&1

    if grep -q "FOUND:" /tmp/monthly_prompt_file_check.txt; then
        STEP=$(grep "FOUND:" /tmp/monthly_prompt_file_check.txt | head -1 | sed 's/FOUND://')
        fail "monthly-research uses 'prompt_file' input in step '$STEP' — not a valid claude-code-action input"
    else
        pass "monthly-research does not use invalid 'prompt_file' input"
    fi
}

# Test 62: monthly-research must NOT use 'direct_prompt' (not a valid action input)
test_monthly_no_direct_prompt_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        with_block = step.get('with', {})
        if 'direct_prompt' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/monthly_direct_prompt_check.txt 2>&1

    if grep -q "FOUND:" /tmp/monthly_direct_prompt_check.txt; then
        STEP=$(grep "FOUND:" /tmp/monthly_direct_prompt_check.txt | head -1 | sed 's/FOUND://')
        fail "monthly-research uses 'direct_prompt' input in step '$STEP' — not a valid claude-code-action input"
    else
        pass "monthly-research does not use invalid 'direct_prompt' input"
    fi
}

# Test 63: monthly-research must NOT use 'model' as a top-level action input
test_monthly_no_model_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        uses = step.get('uses', '')
        with_block = step.get('with', {})
        if 'claude-code-action' in uses and 'model' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/monthly_model_check.txt 2>&1

    if grep -q "FOUND:" /tmp/monthly_model_check.txt; then
        STEP=$(grep "FOUND:" /tmp/monthly_model_check.txt | head -1 | sed 's/FOUND://')
        fail "monthly-research uses 'model' as action input in step '$STEP' — not a valid claude-code-action input"
    else
        pass "monthly-research does not use invalid 'model' action input"
    fi
}

# Test 64: monthly-research must NOT use 'allowed_tools' as action input (use claude_args)
test_monthly_no_allowed_tools_input() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        with_block = step.get('with', {})
        if 'allowed_tools' in with_block:
            print('FOUND:' + step.get('name', 'unnamed'))
" > /tmp/monthly_allowed_tools_check.txt 2>&1

    if grep -q "FOUND:" /tmp/monthly_allowed_tools_check.txt; then
        STEP=$(grep "FOUND:" /tmp/monthly_allowed_tools_check.txt | head -1 | sed 's/FOUND://')
        fail "monthly-research uses 'allowed_tools' input in step '$STEP' — use claude_args --allowedTools instead"
    else
        pass "monthly-research does not use invalid 'allowed_tools' input"
    fi
}

# Test 65: monthly-research must NOT reference outputs.response
test_monthly_no_outputs_response() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    content = f.read()
if 'outputs.response' in content:
    print('FOUND')
" > /tmp/monthly_outputs_response_check.txt 2>&1

    if grep -q "FOUND" /tmp/monthly_outputs_response_check.txt; then
        fail "monthly-research references 'outputs.response' — claude-code-action@v1 has no response output"
    else
        pass "monthly-research does not reference non-existent 'outputs.response'"
    fi
}

# Test 66: monthly-research must extract research result from execution output file
test_monthly_extracts_from_output_file() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        run = step.get('run', '')
        name = step.get('name', '').lower()
        if 'claude-execution-output.json' in run and ('research' in name or 'extract' in name or 'save' in name):
            print('READS_OUTPUT_FILE')
" > /tmp/monthly_output_file_check.txt 2>&1

    if grep -q "READS_OUTPUT_FILE" /tmp/monthly_output_file_check.txt; then
        pass "monthly-research extracts research result from execution output file"
    else
        fail "monthly-research does not read claude-execution-output.json for research result"
    fi
}

test_monthly_no_prompt_file_input
test_monthly_no_direct_prompt_input
test_monthly_no_model_input
test_monthly_no_allowed_tools_input
test_monthly_no_outputs_response
test_monthly_extracts_from_output_file

# ============================================
# Silent Workflow Failure Regression Tests
# ============================================
# These tests ensure previously-identified silent failures
# remain fixed after the post-audit cleanup.

# Test 67: ci.yml has no dead token extraction showing N/A
test_ci_no_dead_token_extraction() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # The execution output file from claude-code-action@v1 does NOT contain
    # .usage.input_tokens, .token_usage, .total_tokens, etc.
    # Any jq paths extracting these are dead code producing N/A values.
    if grep -q '\.usage\.input_tokens\|\.token_usage\|\.total_tokens' "$WORKFLOW"; then
        fail "ci.yml still has dead token extraction code (all values show N/A)"
    else
        pass "ci.yml has no dead token extraction code"
    fi
}

# Test 68: ci.yml has score history git commit step
test_ci_score_history_committed() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # score-history.jsonl must be committed back to the repo
    # so it persists across CI runs (ephemeral runners lose it otherwise)
    if grep -A 5 'score-history.jsonl' "$WORKFLOW" | grep -q 'git commit'; then
        pass "ci.yml commits score-history.jsonl back to repo"
    else
        fail "ci.yml does not commit score-history.jsonl (history lost on ephemeral runner)"
    fi
}

# Test 69: ci-autofix has no show_full_output input
test_ci_autofix_no_show_full_output() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml not found"
        return
    fi

    if grep -q 'show_full_output' "$WORKFLOW"; then
        fail "ci-self-heal.yml still has invalid 'show_full_output' input"
    else
        pass "ci-self-heal.yml has no invalid 'show_full_output' input"
    fi
}

# Test 70: weekly-update community-e2e-test triggers on findings (not just actions)
test_weekly_e2e_triggers_on_findings() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    # has_suggestions should be based on findings_count (not actions_count)
    # because Claude may structure output without .recommended_actions key
    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
jobs = wf.get('jobs', {})
scan_job = jobs.get('scan-community', {})
outputs = scan_job.get('outputs', {})
has_suggestions = str(outputs.get('has_suggestions', ''))
# Should reference findings_count, not actions_count
if 'findings_count' in has_suggestions:
    print('USES_FINDINGS')
elif 'actions_count' in has_suggestions:
    print('USES_ACTIONS')
else:
    print('UNKNOWN')
" > /tmp/weekly_trigger_check.txt 2>&1

    if grep -q "USES_FINDINGS" /tmp/weekly_trigger_check.txt; then
        pass "weekly-update community-e2e-test triggers on findings_count (robust)"
    else
        fail "weekly-update community-e2e-test triggers on actions_count (fragile — depends on exact JSON key name)"
    fi
}

# Test 71: monthly-research e2e-test triggers on notable research
test_monthly_e2e_triggers_on_notable() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    # has_updates should NOT depend solely on .recommended_wizard_updates
    # because Claude may structure output without that exact key
    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
jobs = wf.get('jobs', {})
research_job = jobs.get('deep-research', {})
outputs = research_job.get('outputs', {})
has_updates = str(outputs.get('has_updates', ''))
# Should NOT reference updates_count alone (fragile)
# Should use nothing_notable or a broader condition
if 'nothing_notable' in has_updates:
    print('USES_NOTHING_NOTABLE')
elif 'updates_count' in has_updates:
    print('USES_UPDATES_COUNT')
else:
    print('UNKNOWN')
" > /tmp/monthly_trigger_check.txt 2>&1

    if grep -q "USES_NOTHING_NOTABLE" /tmp/monthly_trigger_check.txt; then
        pass "monthly-research e2e-test triggers on notable research (robust)"
    else
        fail "monthly-research e2e-test triggers on updates_count (fragile — depends on exact JSON key name)"
    fi
}

# Test 72: ci.yml score history push uses explicit branch ref (not bare git push)
test_ci_score_history_push_explicit_ref() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # On pull_request events, actions/checkout checks out refs/pull/N/merge (detached HEAD).
    # Bare `git push` on detached HEAD fails silently with continue-on-error.
    # Must use explicit ref: git push origin HEAD:refs/heads/<branch>
    if grep -A 15 'Commit score history' "$WORKFLOW" | grep -q 'git push origin.*refs/heads/\|git push origin.*\$PR_BRANCH'; then
        pass "ci.yml score history push uses explicit branch ref (detached HEAD safe)"
    else
        fail "ci.yml score history push uses bare 'git push' (fails silently on detached HEAD)"
    fi
}

# Test 73: ci-self-heal.yml must NOT have 'workflows: write' permission (invalid scope, breaks GitHub parser)
test_ci_autofix_no_workflows_permission() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-autofix workflow file not found"
        return
    fi

    # 'workflows' is NOT a valid YAML permission scope (actionlint confirms).
    # Having it causes GitHub's parser to silently fail, registering the workflow
    # as 'on: push' instead of 'on: workflow_run'. This killed the self-healing loop.
    # Pushing workflow files requires a PAT with 'workflow' scope or a GitHub App, not YAML permissions.
    if grep -q 'workflows: write' "$WORKFLOW"; then
        fail "ci-self-heal.yml has invalid 'workflows: write' permission (breaks GitHub's YAML parser)"
    else
        pass "ci-self-heal.yml does not have invalid 'workflows' permission scope"
    fi
}

# Test 74: ci.yml initializes git in workspace root before claude-code-action
test_ci_workspace_git_init() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # actions/checkout with path: creates subdirectories, leaving workspace root as non-git.
    # claude-code-action@v1 configureGitAuth runs git config in workspace root and crashes.
    # Fix: git init in workspace root before the first simulation step.
    if grep -q 'git init' "$WORKFLOW"; then
        pass "ci.yml initializes git in workspace root (prevents configureGitAuth crash)"
    else
        fail "ci.yml missing git init for workspace root (configureGitAuth will crash)"
    fi
}

# Test 75: ci.yml max-turns is sufficient for hard scenarios (>= 50)
test_ci_max_turns_sufficient() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # Hard scenarios (refactor) need more than 45 turns.
    # error_max_turns causes action failure even with is_error: false.
    MAX_TURNS=$(grep 'max-turns' "$WORKFLOW" | head -1 | sed 's/.*max-turns //' | sed 's/[^0-9].*//')
    if [ -z "$MAX_TURNS" ]; then
        fail "Could not find max-turns in ci.yml"
        return
    fi

    if [ "$MAX_TURNS" -ge 50 ]; then
        pass "ci.yml max-turns ($MAX_TURNS) is sufficient for hard scenarios"
    else
        fail "ci.yml max-turns ($MAX_TURNS) is too low for hard scenarios (need >= 50)"
    fi
}

# Test 76: Tier 1 regression threshold must be >= 1.5 (absorbs ±1 LLM noise)
test_tier1_regression_threshold() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # Tier 1 uses single-trial comparison. LLM judge + simulation has ±1 point
    # stochastic variance. A threshold < 1.5 causes false REGRESSION failures.
    # Extract the threshold from the "Compare scores" step's bc comparison.
    # Pattern: DELTA < -X.X where X.X is the threshold
    THRESHOLD=$(grep -oE 'DELTA < -[0-9]+\.?[0-9]*' "$WORKFLOW" | head -1 | grep -oE '[0-9]+\.?[0-9]*')

    if [ -z "$THRESHOLD" ]; then
        fail "Could not find Tier 1 regression threshold in ci.yml"
        return
    fi

    # Compare using bc: threshold must be >= 1.5
    if [ "$(echo "$THRESHOLD >= 1.5" | bc -l)" -eq 1 ]; then
        pass "Tier 1 regression threshold is $THRESHOLD (absorbs LLM noise)"
    else
        fail "Tier 1 regression threshold is $THRESHOLD (too tight — causes false regressions from ±1 LLM noise, need >= 1.5)"
    fi
}

# ============================================
# Monthly-Research Permission Tests
# ============================================
# Ensure monthly-research has the permissions its
# e2e-test job needs (creates PRs via peter-evans/create-pull-request).

# Test 77: monthly-research has pull-requests: write permission
test_monthly_has_pr_write_permission() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    if grep -q 'pull-requests: write' "$WORKFLOW"; then
        pass "monthly-research has pull-requests: write permission"
    else
        fail "monthly-research missing pull-requests: write permission (e2e-test creates PRs)"
    fi
}

# Test 78: ci-self-heal.yml has name: field (required for workflow_run registry)
test_ci_autofix_has_name_field() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml not found"
        return
    fi

    # GitHub's workflow registry uses the name: field to match workflow_run triggers.
    # If the name: field is missing or doesn't match what other workflows reference,
    # workflow_run events silently stop firing.
    YAML_NAME=$(python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
print(wf.get('name', ''))
")

    if [ "$YAML_NAME" = "CI Auto-Fix" ]; then
        pass "ci-self-heal.yml has correct name: field ('CI Auto-Fix')"
    elif [ -n "$YAML_NAME" ]; then
        fail "ci-self-heal.yml name: field is '$YAML_NAME' (expected 'CI Auto-Fix')"
    else
        fail "ci-self-heal.yml missing name: field (workflow_run registry will use file path instead)"
    fi
}

# Test 79: ci-self-heal.yml has actions: write permission (needed for gh workflow run dispatch)
test_ci_autofix_has_actions_write() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml not found"
        return
    fi

    # GITHUB_TOKEN pushes don't trigger workflow events (anti-loop protection).
    # The workaround is `gh workflow run ci.yml` to re-trigger CI after fixing.
    # This requires `actions: write` permission, otherwise: HTTP 403.
    if grep -q 'actions: write' "$WORKFLOW"; then
        pass "ci-self-heal.yml has actions: write permission (needed for CI re-trigger)"
    else
        fail "ci-self-heal.yml missing actions: write permission (gh workflow run returns 403)"
    fi
}

# Test 80: ci-self-heal.yml comment includes collapsible <details> section
test_ci_autofix_comment_has_details() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "ci-self-heal.yml not found (needed for comment format test)"
        return
    fi

    if grep -q '<details>' "$WORKFLOW" && grep -q '</details>' "$WORKFLOW"; then
        pass "ci-self-heal.yml comment includes collapsible <details> section"
    else
        fail "ci-self-heal.yml comment missing <details> section (flat format is not scannable)"
    fi
}

test_ci_autofix_comment_has_details
test_ci_autofix_has_name_field
test_monthly_has_pr_write_permission
test_ci_autofix_has_actions_write
test_tier1_regression_threshold
test_ci_no_dead_token_extraction
test_ci_score_history_committed
test_ci_autofix_no_show_full_output
test_weekly_e2e_triggers_on_findings
test_monthly_e2e_triggers_on_notable
test_ci_score_history_push_explicit_ref
test_ci_autofix_no_workflows_permission
test_ci_workspace_git_init
test_ci_max_turns_sufficient

# Test 81: ci.yml workspace git init adds origin remote (trusted file restore needs it)
test_ci_workspace_git_init_has_origin() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # claude-code-action@v1 configureGitAuth does `git remote set-url origin <url>`
    # and trusted file restore does `git fetch origin main --depth=1`.
    # Both require origin to exist. Bare `git init .` is not enough.
    if grep -q 'git remote add origin' "$WORKFLOW"; then
        pass "ci.yml workspace init adds origin remote (prevents trusted file restore crash)"
    else
        fail "ci.yml workspace init missing 'git remote add origin' (claude-code-action trusted file restore will crash)"
    fi
}

# Test 82: ci.yml shellcheck step name accurately describes what it does
test_ci_shellcheck_step_name_accurate() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # The step previously said "Shellcheck scripts in workflows" but only runs a grep.
    # Step name must not claim to run shellcheck when it doesn't.
    if grep -q 'name: Shellcheck' "$WORKFLOW"; then
        fail "ci.yml has step named 'Shellcheck' but doesn't actually run shellcheck (misleading)"
    else
        pass "ci.yml shell validation step name is accurate (no false shellcheck claim)"
    fi
}

test_ci_workspace_git_init_has_origin
test_ci_shellcheck_step_name_accurate

# Test 83: weekly-update schedule is weekly (Monday only)
test_weekly_update_monday_schedule() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"
    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi
    # Cron should end with day-of-week = 1 (Monday), not * (daily)
    # Format: minute hour day-of-month month day-of-week
    if grep -E '^\s+- cron:.*\* 1' "$WORKFLOW" > /dev/null; then
        pass "weekly-update runs weekly on Mondays (cost-efficient)"
    else
        fail "weekly-update should run weekly on Monday (cron day-of-week = 1)"
    fi
}

# Test 84: All auto-update schedules are uncommented (active)
test_all_schedules_active() {
    local all_active=true
    for wf in weekly-update.yml monthly-research.yml; do
        WORKFLOW="$REPO_ROOT/.github/workflows/$wf"
        if [ ! -f "$WORKFLOW" ]; then
            fail "$wf not found"
            all_active=false
            continue
        fi
        # Check for uncommented schedule: line (no # before it)
        if grep -E '^\s+schedule:' "$WORKFLOW" | grep -qv '#'; then
            : # active
        else
            all_active=false
            fail "$wf schedule is commented out (should be active)"
        fi
    done
    if [ "$all_active" = true ]; then
        pass "All auto-update workflow schedules are active (weekly-update + monthly-research)"
    fi
}

# Test 85: ci.yml score history checkouts PR branch before push
test_ci_score_history_checkouts_pr_branch() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi
    # The score history step must checkout the actual PR branch (not push from detached HEAD)
    if grep -A 15 'Commit score history' "$WORKFLOW" | grep -q 'git checkout'; then
        pass "ci.yml score history checks out PR branch before push"
    else
        fail "ci.yml score history pushes from detached HEAD (will fail silently)"
    fi
}

test_weekly_update_monday_schedule
test_all_schedules_active
test_ci_score_history_checkouts_pr_branch

# ============================================
# Weekly-Update Consolidation Structure Tests
# ============================================
# These tests verify the consolidated weekly-update.yml
# has all 4 jobs with correct dependency chains.

# Test 86: weekly-update.yml has all 4 jobs (check-updates, version-test, scan-community, community-e2e-test)
test_weekly_update_has_four_jobs() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
jobs = list(wf.get('jobs', {}).keys())
expected = ['check-updates', 'version-test', 'scan-community', 'community-e2e-test']
missing = [j for j in expected if j not in jobs]
if not missing:
    print('ALL_PRESENT')
else:
    print('MISSING:' + ','.join(missing))
" > /tmp/weekly_jobs_check.txt 2>&1

    if grep -q "ALL_PRESENT" /tmp/weekly_jobs_check.txt; then
        pass "weekly-update.yml has all 4 required jobs"
    else
        MISSING=$(grep "MISSING:" /tmp/weekly_jobs_check.txt | sed 's/MISSING://')
        fail "weekly-update.yml missing jobs: $MISSING"
    fi
}

# Test 87: weekly-update.yml version-test depends on check-updates
test_weekly_update_version_test_needs_check_updates() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
jobs = wf.get('jobs', {})
version_test = jobs.get('version-test', {})
needs = version_test.get('needs', [])
if isinstance(needs, str):
    needs = [needs]
if 'check-updates' in needs:
    print('DEP_OK')
else:
    print('DEP_MISSING')
" > /tmp/weekly_dep_check1.txt 2>&1

    if grep -q "DEP_OK" /tmp/weekly_dep_check1.txt; then
        pass "weekly-update.yml version-test depends on check-updates"
    else
        fail "weekly-update.yml version-test missing 'needs: check-updates' dependency"
    fi
}

# Test 88: weekly-update.yml community-e2e-test depends on scan-community
test_weekly_update_community_e2e_needs_scan() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    python3 -c "
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
jobs = wf.get('jobs', {})
community_e2e = jobs.get('community-e2e-test', {})
needs = community_e2e.get('needs', [])
if isinstance(needs, str):
    needs = [needs]
if 'scan-community' in needs:
    print('DEP_OK')
else:
    print('DEP_MISSING')
" > /tmp/weekly_dep_check2.txt 2>&1

    if grep -q "DEP_OK" /tmp/weekly_dep_check2.txt; then
        pass "weekly-update.yml community-e2e-test depends on scan-community"
    else
        fail "weekly-update.yml community-e2e-test missing 'needs: scan-community' dependency"
    fi
}

# Test 89: weekly-update.yml has issues: write permission (needed for community digest)
test_weekly_update_has_issues_permission() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    if grep -q "issues: write" "$WORKFLOW"; then
        pass "weekly-update.yml has issues: write permission"
    else
        fail "weekly-update.yml missing issues: write permission (community digest creates issues)"
    fi
}

# Test 90: weekly-update.yml has exactly one cron schedule entry
test_weekly_update_single_cron() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    CRON_COUNT=$(grep -cE '^\s+- cron:' "$WORKFLOW" 2>/dev/null || echo "0")
    if [ "$CRON_COUNT" = "1" ]; then
        pass "weekly-update.yml has exactly 1 cron schedule (single Monday run)"
    else
        fail "weekly-update.yml has $CRON_COUNT cron entries (expected exactly 1)"
    fi
}

# Test 91: CI Tier 2 comment matches actual trial count (5x, not 3x)
test_tier2_comment_matches_trial_count() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # The Tier 2 job header comment must say 5x (matching the actual loop count)
    if grep -q "5x evaluations each" "$WORKFLOW"; then
        pass "Tier 2 comment correctly says 5x evaluations"
    else
        fail "Tier 2 comment does not say '5x evaluations each' (stale comment?)"
    fi
}

# Test 92: CI Tier 2 cleans stale output between baseline and candidate sims
test_tier2_cleans_stale_output() {
    WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "CI workflow file not found"
        return
    fi

    # The "Reset test fixture for CANDIDATE" step must remove stale output
    if grep -A 10 "Reset test fixture for CANDIDATE" "$WORKFLOW" | grep -q "rm.*claude-execution-output"; then
        pass "Tier 2 cleans stale output file between baseline and candidate"
    else
        fail "Tier 2 does NOT clean stale output file between baseline and candidate sims"
    fi
}

test_weekly_update_has_four_jobs
test_weekly_update_version_test_needs_check_updates
test_weekly_update_community_e2e_needs_scan
test_weekly_update_has_issues_permission
test_weekly_update_single_cron
test_tier2_comment_matches_trial_count
test_tier2_cleans_stale_output

# ============================================
# Full System Audit (#25) — Apply Step Bug Tests
# ============================================
# The "apply" step in auto-update workflows modifies repo root files,
# but candidate simulations run in the test fixture. Without copying
# applied changes into the fixture, baseline == candidate (useless).

# Test 93: weekly-update.yml copies modified wizard into fixture after Phase B apply step
test_weekly_update_copies_wizard_after_apply() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    # After "Apply changelog suggestions" step, there must be a step that
    # copies .claude/ files into the test fixture before candidate simulation
    if grep -A 50 "Apply changelog suggestions" "$WORKFLOW" | grep -q "cp.*\.claude.*fixtures/test-repo"; then
        pass "weekly-update.yml copies wizard into fixture after apply step"
    else
        fail "weekly-update.yml does NOT copy applied changes into test fixture (baseline == candidate, comparison useless)"
    fi
}

# Test 94: monthly-research.yml copies modified wizard into fixture after apply step
test_monthly_copies_wizard_after_apply() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    # After "Apply research recommendations" step, there must be a step that
    # copies .claude/ files into the test fixture before candidate simulation
    if grep -A 40 "Apply research recommendations" "$WORKFLOW" | grep -q "cp.*\.claude.*fixtures/test-repo"; then
        pass "monthly-research.yml copies wizard into fixture after apply step"
    else
        fail "monthly-research.yml does NOT copy applied changes into test fixture (baseline == candidate, comparison useless)"
    fi
}

# Test 95: weekly-update.yml cleans stale output before Phase B simulation
test_weekly_update_cleans_output_before_phase_b() {
    WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "weekly-update.yml not found"
        return
    fi

    # Between Phase A eval and Phase B sim, stale output file must be removed
    # Otherwise candidate eval reads baseline data on silent sim failure
    if grep -B 20 "Run scenario simulation for Phase B" "$WORKFLOW" | grep -q "rm.*claude-execution-output"; then
        pass "weekly-update.yml cleans stale output before Phase B sim"
    else
        fail "weekly-update.yml does NOT clean stale output before Phase B sim (candidate eval reads baseline data on failure)"
    fi
}

# Test 96: monthly-research.yml cleans stale output before candidate simulation
test_monthly_cleans_output_before_candidate() {
    WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if [ ! -f "$WORKFLOW" ]; then
        fail "monthly-research.yml not found"
        return
    fi

    # Between baseline eval and candidate sim, stale output file must be removed
    if grep -B 20 "Run candidate simulation" "$WORKFLOW" | grep -q "rm.*claude-execution-output"; then
        pass "monthly-research.yml cleans stale output before candidate sim"
    else
        fail "monthly-research.yml does NOT clean stale output before candidate sim (candidate eval reads baseline data on failure)"
    fi
}

# Test 97: README workflow count matches actual count (5 workflows)
test_readme_workflow_count_accurate() {
    README="$REPO_ROOT/README.md"

    if [ ! -f "$README" ]; then
        fail "README.md not found"
        return
    fi

    # Count actual workflow files
    ACTUAL_COUNT=$(ls "$REPO_ROOT"/.github/workflows/*.yml 2>/dev/null | wc -l | tr -d ' ')

    if grep -q "All $ACTUAL_COUNT workflows" "$README"; then
        pass "README workflow count ($ACTUAL_COUNT) matches actual workflow files"
    else
        fail "README workflow count does not match actual count ($ACTUAL_COUNT workflows)"
    fi
}

test_weekly_update_copies_wizard_after_apply
test_monthly_copies_wizard_after_apply
test_weekly_update_cleans_output_before_phase_b
test_monthly_cleans_output_before_candidate
test_readme_workflow_count_accurate

# Test 98: e2e-quick-check must not skip on workflow_dispatch
# Bug: PR #75 blocked because gh workflow run (dispatch) caused e2e-quick-check to be skipped.
# Branch protection requires e2e-quick-check. Skipped result overwrites previous pass → PR blocked.
test_quick_check_accepts_workflow_dispatch() {
    CI="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$CI" ]; then
        fail "ci.yml not found"
        return
    fi

    # Extract the e2e-quick-check job's if: condition
    # It must include workflow_dispatch, not just pull_request
    local condition
    condition=$(awk '/^ *e2e-quick-check:/{found=1} found && /^ *if:/{print; exit}' "$CI")

    if echo "$condition" | grep -q "workflow_dispatch"; then
        pass "e2e-quick-check condition allows workflow_dispatch"
    else
        fail "e2e-quick-check condition must allow workflow_dispatch (prevents PR #75 bug where dispatch overwrites check with 'skipped')"
    fi
}

# Test 99: cleanup-old-comments must not skip on workflow_dispatch
# Same bug pattern as e2e-quick-check — both are PR-conditional and required (or in needs chain).
test_cleanup_accepts_workflow_dispatch() {
    CI="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$CI" ]; then
        fail "ci.yml not found"
        return
    fi

    local condition
    condition=$(awk '/^ *cleanup-old-comments:/{found=1} found && /^ *if:/{print; exit}' "$CI")

    if echo "$condition" | grep -q "workflow_dispatch"; then
        pass "cleanup-old-comments condition allows workflow_dispatch"
    else
        fail "cleanup-old-comments condition must allow workflow_dispatch (same bug as e2e-quick-check)"
    fi
}

# Test 100: All jobs required by branch protection must run on workflow_dispatch
# Branch protection requires: validate, e2e-quick-check
# validate has no condition (always runs). e2e-quick-check needs dispatch support.
# This test ensures no required job has a pull_request-only condition.
test_required_checks_run_on_dispatch() {
    CI="$REPO_ROOT/.github/workflows/ci.yml"

    if [ ! -f "$CI" ]; then
        fail "ci.yml not found"
        return
    fi

    local all_pass=true

    # Required checks: validate and e2e-quick-check
    for job in validate e2e-quick-check; do
        # Extract the if: line for this job (between job name and its steps/needs)
        local condition
        condition=$(sed -n "/^  ${job}:/,/^  [a-z]/{ /if:/p; }" "$CI" | head -1)

        # No condition means always runs (good)
        if [ -z "$condition" ]; then
            continue
        fi

        # Has a condition — must not be pull_request-only (must include workflow_dispatch)
        if echo "$condition" | grep -q "workflow_dispatch"; then
            continue
        fi

        # If it only checks for pull_request, it will skip on dispatch
        if echo "$condition" | grep -q "pull_request"; then
            all_pass=false
        fi
    done

    if [ "$all_pass" = true ]; then
        pass "All branch-protection-required jobs (validate, e2e-quick-check) run on workflow_dispatch"
    else
        fail "Some required jobs skip on workflow_dispatch — will block auto-merge after self-heal re-trigger"
    fi
}

test_quick_check_accepts_workflow_dispatch
test_cleanup_accepts_workflow_dispatch
test_required_checks_run_on_dispatch

# Test 101: weekly-update fetches release list (not just /releases/latest)
test_weekly_update_multi_release_fetch() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if grep -q 'releases?per_page=' "$WORKFLOW"; then
        pass "weekly-update.yml fetches release list (not just /releases/latest)"
    else
        fail "weekly-update.yml should use releases?per_page= instead of releases/latest"
    fi
}

# Test 102: analyze-release.md handles multiple releases
test_analyze_release_handles_multi() {
    local PROMPT="$REPO_ROOT/.github/prompts/analyze-release.md"

    if grep -qi "one or more.*release\|multiple release\|releases are provided" "$PROMPT"; then
        pass "analyze-release.md handles multiple releases"
    else
        fail "analyze-release.md should mention handling multiple releases"
    fi
}

test_weekly_update_multi_release_fetch
test_analyze_release_handles_multi

# Test 103: ci-self-heal adds needs-regression-test label after autofix
test_ci_autofix_regression_label() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if grep -q 'needs-regression-test' "$WORKFLOW"; then
        pass "ci-self-heal.yml adds needs-regression-test label after autofix"
    else
        fail "ci-self-heal.yml should add needs-regression-test label when autofix commits"
    fi
}

# Test 104: ci-self-heal has issues: write permission (needed for label management)
test_ci_autofix_has_issues_permission() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if grep -q 'issues: write' "$WORKFLOW"; then
        pass "ci-self-heal.yml has issues: write permission"
    else
        fail "ci-self-heal.yml needs issues: write permission for label management"
    fi
}

# Test 105: ci-self-heal sticky comment mentions regression test when fix is committed
test_ci_autofix_comment_regression_note() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if grep -qi 'regression.*test\|regression-test' "$WORKFLOW"; then
        pass "ci-self-heal.yml mentions regression test in autofix flow"
    else
        fail "ci-self-heal.yml should mention regression test needed after autofix"
    fi
}

# Test 106: ci-self-heal ensures label exists before adding it (gh label create --force)
test_ci_autofix_ensures_label_exists() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if grep -q 'gh label create.*needs-regression-test.*--force' "$WORKFLOW"; then
        pass "ci-self-heal.yml ensures needs-regression-test label exists before adding"
    else
        fail "ci-self-heal.yml should use 'gh label create --force' to ensure label exists"
    fi
}

test_ci_autofix_regression_label
test_ci_autofix_has_issues_permission
test_ci_autofix_comment_regression_note
test_ci_autofix_ensures_label_exists

# --- --bare flag tests (non-E2E steps should use --bare, E2E simulations should NOT) ---

# Test 107: pr-review.yml uses --bare in claude_args
test_bare_pr_review() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if grep -A2 'claude_args:' "$WORKFLOW" | grep -q '\-\-bare'; then
        pass "pr-review.yml uses --bare in claude_args"
    else
        fail "pr-review.yml should use --bare (non-E2E analysis step)"
    fi
}

# Test 108: ci-self-heal.yml uses --bare in claude_args
test_bare_ci_self_heal() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/ci-self-heal.yml"

    if grep -A3 'claude_args:' "$WORKFLOW" | grep -q '\-\-bare'; then
        pass "ci-self-heal.yml uses --bare in claude_args"
    else
        fail "ci-self-heal.yml should use --bare (non-E2E fix step)"
    fi
}

# Test 109: weekly-update.yml analysis step uses --bare
test_bare_weekly_update_analysis() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    # The "Analyze release with Claude" step should have --bare
    # Check that the step's claude-code-action invocation includes --bare
    if sed -n '/name: Analyze release with Claude/,/name:/p' "$WORKFLOW" | grep -q '\-\-bare'; then
        pass "weekly-update.yml analysis step uses --bare"
    else
        fail "weekly-update.yml 'Analyze release with Claude' should use --bare"
    fi
}

# Test 110: monthly-research.yml deep research step uses --bare
test_bare_monthly_research() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if sed -n '/name: Run deep research with Claude/,/name:/p' "$WORKFLOW" | grep -q '\-\-bare'; then
        pass "monthly-research.yml deep research step uses --bare"
    else
        fail "monthly-research.yml 'Run deep research with Claude' should use --bare"
    fi
}

# Test 111: ci.yml E2E simulation steps do NOT use --bare (negative test)
test_no_bare_ci_simulations() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

    # ci.yml has ONLY E2E simulation steps — none should have --bare
    if grep -A3 'claude_args:' "$WORKFLOW" | grep -q '\-\-bare'; then
        fail "ci.yml should NOT use --bare (all steps are E2E simulations)"
    else
        pass "ci.yml correctly does NOT use --bare in any step"
    fi
}

# Test 112: weekly-update.yml simulation steps do NOT use --bare (negative test)
test_no_bare_weekly_simulations() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    # Simulation steps have claude_args with --allowedTools but should NOT have --bare
    # Check that simulation step names don't have --bare in their claude_args blocks
    local bare_in_sim=false
    for sim_name in "Run scenario simulation with Claude" "Run baseline simulation with Claude" "Run candidate simulation with Claude"; do
        if sed -n "/name: ${sim_name}/,/name:/p" "$WORKFLOW" | grep -q '\-\-bare'; then
            bare_in_sim=true
            break
        fi
    done

    if [ "$bare_in_sim" = "false" ]; then
        pass "weekly-update.yml simulation steps correctly do NOT use --bare"
    else
        fail "weekly-update.yml simulation steps should NOT use --bare"
    fi
}

# Test 122: pr-review.yml uses --effort high for deep reasoning on reviews
test_pr_review_effort_high() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if grep -A4 'claude_args:' "$WORKFLOW" | grep -q '\-\-effort high'; then
        pass "pr-review.yml uses --effort high in claude_args"
    else
        fail "pr-review.yml should use --effort high for deeper review reasoning"
    fi
}

# Test 123: pr-review.yml uses claude-opus-4-6 model
test_pr_review_opus_model() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"

    if grep -A4 'claude_args:' "$WORKFLOW" | grep -q 'claude-opus-4-6'; then
        pass "pr-review.yml uses claude-opus-4-6 model"
    else
        fail "pr-review.yml should use claude-opus-4-6 for maximum review quality"
    fi
}

test_bare_pr_review
test_bare_ci_self_heal
test_bare_weekly_update_analysis
test_bare_monthly_research
test_no_bare_ci_simulations
test_no_bare_weekly_simulations
test_pr_review_effort_high
test_pr_review_opus_model

# --- Bug fix tests (weekly-update/monthly-research workflow issues) ---

# Test 113: scan-community push to main is non-blocking (|| true)
test_scan_community_push_nonblocking() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if grep -q 'git push.*|| true' "$WORKFLOW"; then
        pass "scan-community git push is non-blocking (|| true)"
    else
        fail "scan-community git push should be non-blocking (protected branch blocks direct push)"
    fi
}

# Test 114: No working_directory input in weekly-update (not a valid claude-code-action input)
test_no_working_directory_weekly() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if grep -q 'working_directory:' "$WORKFLOW"; then
        fail "weekly-update.yml should not use working_directory (invalid claude-code-action input)"
    else
        pass "weekly-update.yml has no invalid working_directory input"
    fi
}

# Test 115: No working_directory input in monthly-research
test_no_working_directory_monthly() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"

    if grep -q 'working_directory:' "$WORKFLOW"; then
        fail "monthly-research.yml should not use working_directory (invalid claude-code-action input)"
    else
        pass "monthly-research.yml has no invalid working_directory input"
    fi
}

# Test 116: Simulation max-turns >= 35 in weekly-update (was 30, ci.yml uses 55)
test_weekly_sim_max_turns() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"
    local min_turns=35
    local all_ok=true

    while IFS= read -r line; do
        local turns
        turns=$(echo "$line" | grep -oE '[0-9]+')
        if [ -n "$turns" ] && [ "$turns" -lt "$min_turns" ]; then
            all_ok=false
            break
        fi
    done < <(grep 'max-turns' "$WORKFLOW")

    if [ "$all_ok" = "true" ]; then
        pass "weekly-update.yml simulation --max-turns >= $min_turns"
    else
        fail "weekly-update.yml has --max-turns < $min_turns (too low, causes error_max_turns)"
    fi
}

# Test 117: Simulation max-turns >= 35 in monthly-research
test_monthly_sim_max_turns() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/monthly-research.yml"
    local min_turns=35
    local all_ok=true

    while IFS= read -r line; do
        local turns
        turns=$(echo "$line" | grep -oE '[0-9]+')
        if [ -n "$turns" ] && [ "$turns" -lt "$min_turns" ]; then
            all_ok=false
            break
        fi
    done < <(grep 'max-turns' "$WORKFLOW")

    if [ "$all_ok" = "true" ]; then
        pass "monthly-research.yml simulation --max-turns >= $min_turns"
    else
        fail "monthly-research.yml has --max-turns < $min_turns (too low, causes error_max_turns)"
    fi
}

test_scan_community_push_nonblocking
test_no_working_directory_weekly
test_no_working_directory_monthly
test_weekly_sim_max_turns
test_monthly_sim_max_turns

# ============================================
# .gitignore Tests
# ============================================
# Workflows create node_modules and cache artifacts.
# Without .gitignore, peter-evans/create-pull-request commits them.

# Test 118: .gitignore exists at repo root
test_gitignore_exists() {
    if [ -f "$REPO_ROOT/.gitignore" ]; then
        pass ".gitignore exists at repo root"
    else
        fail ".gitignore missing — workflow PRs will commit node_modules and cache artifacts"
    fi
}

# Test 119: .gitignore ignores node_modules
test_gitignore_node_modules() {
    if [ ! -f "$REPO_ROOT/.gitignore" ]; then
        fail ".gitignore missing (can't check node_modules pattern)"
        return
    fi

    if grep -q 'node_modules' "$REPO_ROOT/.gitignore"; then
        pass ".gitignore ignores node_modules"
    else
        fail ".gitignore missing node_modules pattern"
    fi
}

# Test 120: .gitignore ignores e2e cache
test_gitignore_e2e_cache() {
    if [ ! -f "$REPO_ROOT/.gitignore" ]; then
        fail ".gitignore missing (can't check e2e cache pattern)"
        return
    fi

    if grep -q '.cache' "$REPO_ROOT/.gitignore"; then
        pass ".gitignore ignores e2e cache files"
    else
        fail ".gitignore missing e2e cache pattern"
    fi
}

test_gitignore_exists
test_gitignore_node_modules
test_gitignore_e2e_cache

# ============================================
# CI Coverage Tests
# ============================================
# Every test-*.sh script should be wired into ci.yml validate job.
# Catches orphaned test scripts that run locally but not in CI.

# Test 121: All test-*.sh scripts are referenced in ci.yml validate job
test_no_orphaned_test_scripts() {
    local CI="$REPO_ROOT/.github/workflows/ci.yml"
    if [ ! -f "$CI" ]; then
        fail "ci.yml not found"
        return
    fi

    local orphans=""
    # Check tests/ (top-level test scripts)
    for script in "$REPO_ROOT"/tests/test-*.sh; do
        local name
        name=$(basename "$script")
        if ! grep -q "tests/$name" "$CI"; then
            orphans="$orphans $name"
        fi
    done
    # Check tests/e2e/ (e2e test scripts)
    for script in "$REPO_ROOT"/tests/e2e/test-*.sh; do
        local name
        name=$(basename "$script")
        if ! grep -q "tests/e2e/$name" "$CI"; then
            orphans="$orphans $name"
        fi
    done

    if [ -z "$orphans" ]; then
        pass "All test-*.sh scripts are wired into ci.yml"
    else
        fail "Orphaned test scripts not in ci.yml:$orphans"
    fi
}

test_no_orphaned_test_scripts

# ============================================
# Codex Cross-Model Review Findings (Tests 124-130)
# Validates fixes for issues found by independent Codex audit
# ============================================

# Test 124: pr-review.yml checkout specifies explicit ref for PR head
# Without explicit ref, pull_request_target checks out main instead of PR code
test_pr_review_checkout_explicit_ref() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"
    if [ ! -f "$WORKFLOW" ]; then
        fail "pr-review.yml not found"
        return
    fi

    if grep -A 5 'actions/checkout@v4' "$WORKFLOW" | grep -q 'ref:'; then
        pass "pr-review.yml checkout specifies explicit ref (pull_request_target safe)"
    else
        fail "pr-review.yml checkout missing explicit ref (pull_request_target checks out base branch)"
    fi
}

# Test 125: pr-review.yml concurrency group uses PR number, not github.ref
# github.ref on pull_request_target = refs/heads/main for ALL PRs (collision)
test_pr_review_concurrency_uses_pr_number() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"
    if [ ! -f "$WORKFLOW" ]; then
        fail "pr-review.yml not found"
        return
    fi

    if grep -A 4 'concurrency:' "$WORKFLOW" | grep -q 'pull_request.number'; then
        pass "pr-review.yml concurrency group uses PR number (no cross-PR collision)"
    else
        fail "pr-review.yml concurrency group doesn't use PR number (pull_request_target collision risk)"
    fi
}

# Test 126: ci.yml does not use head.ref directly in run: blocks (injection risk)
# head.ref should be passed via env: block, not interpolated inline in shell
test_ci_head_ref_not_in_run_blocks() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
    if [ ! -f "$WORKFLOW" ]; then
        fail "ci.yml not found"
        return
    fi

    # Use YAML parser to check run: block content for direct head.ref interpolation
    local result
    result=$(python3 -c "
import yaml, sys
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
found = False
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        run = step.get('run', '')
        if 'pull_request.head.ref' in run:
            found = True
print('CLEAN' if not found else 'FOUND')
" 2>/dev/null) || true
    if [ "$result" = "CLEAN" ]; then
        pass "ci.yml: head.ref passed via env: blocks, not inline in run: blocks"
    else
        fail "ci.yml: head.ref used directly in run: blocks (injection risk — use env: block)"
    fi
}

# Test 127: pr-review.yml trivial detection excludes execution-critical paths
# .github/workflows/*.yml and tests/** should never be "trivial" in this meta-repo
test_trivial_pr_excludes_critical_paths() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"
    if [ ! -f "$WORKFLOW" ]; then
        fail "pr-review.yml not found"
        return
    fi

    if grep -A 40 'Check if trivial PR' "$WORKFLOW" | grep -q 'github\|\.github'; then
        pass "pr-review.yml trivial detection excludes .github/ paths"
    else
        fail "pr-review.yml trivial detection doesn't exclude .github/ paths (workflow changes skip review)"
    fi
}

# Test 128: pr-review.yml CI wait checks e2e-quick-check, not just validate
test_ci_wait_includes_e2e() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/pr-review.yml"
    if [ ! -f "$WORKFLOW" ]; then
        fail "pr-review.yml not found"
        return
    fi

    if grep -A 40 'Wait for CI to complete' "$WORKFLOW" | grep -q 'e2e-quick-check'; then
        pass "pr-review.yml waits for e2e-quick-check (not just validate)"
    else
        fail "pr-review.yml only waits for validate, misses e2e-quick-check signal"
    fi
}

# Test 129: CONTRIBUTING.md lists all test scripts that CI validate runs
test_contributing_matches_ci_scripts() {
    local CI="$REPO_ROOT/.github/workflows/ci.yml"
    local CONTRIB="$REPO_ROOT/CONTRIBUTING.md"
    if [ ! -f "$CI" ] || [ ! -f "$CONTRIB" ]; then
        fail "ci.yml or CONTRIBUTING.md not found"
        return
    fi

    # Extract test runner scripts (test-*.sh and run-simulation.sh) from both files
    # Exclude helper scripts like evaluate.sh, score-analytics.sh (not test runners)
    local result
    result=$(python3 -c "
import re
with open('$CONTRIB') as f:
    contrib_scripts = set(re.findall(r'\./tests/(?:e2e/)?(?:test-[^\s\\\\]+\.sh|run-simulation\.sh)', f.read()))
with open('$CI') as f:
    ci_scripts = set(re.findall(r'\./tests/(?:e2e/)?(?:test-[^\s\\\\]+\.sh|run-simulation\.sh)', f.read()))
missing = ci_scripts - contrib_scripts
if missing:
    print('MISSING:' + ','.join(sorted(missing)))
else:
    print('OK')
" 2>/dev/null) || true
    if [ "$result" = "OK" ]; then
        pass "CONTRIBUTING.md lists all test scripts from CI"
    else
        fail "CONTRIBUTING.md missing test scripts that CI validate runs"
    fi
}

# Test 130: testing SKILL.md does not recommend `act` for workflow testing
# TESTING.md says workflows can't be tested locally with act
test_skill_no_act_for_workflows() {
    local SKILL="$REPO_ROOT/.claude/skills/testing/SKILL.md"
    if [ ! -f "$SKILL" ]; then
        fail "testing SKILL.md not found"
        return
    fi

    # Should NOT recommend using act to test workflows (TESTING.md says it doesn't work)
    # Match the specific recommendation pattern, not negations like "can't run with act"
    if grep -qi 'Use.*act.*to test\|Use `act`' "$SKILL"; then
        fail "testing SKILL.md still recommends 'act' for workflows (contradicts TESTING.md)"
    else
        pass "testing SKILL.md does not recommend 'act' for workflow testing"
    fi
}

test_pr_review_checkout_explicit_ref
test_pr_review_concurrency_uses_pr_number
test_ci_head_ref_not_in_run_blocks
test_trivial_pr_excludes_critical_paths
test_ci_wait_includes_e2e
test_contributing_matches_ci_scripts
test_skill_no_act_for_workflows

# --- Round 2: Codex cross-model review findings (2026-03-27) ---

# Test 131: README raw install URL matches actual GitHub remote
test_readme_raw_url_matches_remote() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then
        fail "README.md not found"
        return
    fi

    # The raw URL must use the correct repo name (agentic-ai-sdlc-wizard)
    if grep -q 'raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/' "$README"; then
        pass "README raw URL uses correct repo name"
    else
        fail "README raw URL does not match remote (expected agentic-ai-sdlc-wizard)"
    fi
}

# Test 132: No stale "daily" cadence references in key docs
# Weekly + monthly exist, daily was removed. Check broadly — not just specific phrases.
test_no_stale_daily_cadence() {
    local ERRORS=0

    # README.md should not describe daily cadence anywhere (table, summary, etc.)
    # Exclude changelog/historical lines by checking current-tense descriptions
    if grep -qiE 'Daily[/ ].*workflow|Daily.*Claude Code|Daily/weekly/monthly' "$REPO_ROOT/README.md" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
    fi

    # CLAUDE.md should not say "Daily workflow"
    if grep -qi 'Daily workflow checks Claude Code' "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
    fi

    # CLAUDE_CODE_SDLC_WIZARD.md should not say "Daily workflow"
    if grep -qi 'Daily workflow tests new Claude Code' "$REPO_ROOT/CLAUDE_CODE_SDLC_WIZARD.md" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
    fi

    if [ "$ERRORS" -eq 0 ]; then
        pass "No stale 'daily' cadence references in key docs"
    else
        fail "Found $ERRORS stale 'daily' cadence reference(s) — only weekly/monthly exist"
    fi
}

# Test 133: Wizard explicitly distinguishes template defaults vs repo config
test_wizard_autofix_template_distinction() {
    local WIZARD="$REPO_ROOT/CLAUDE_CODE_SDLC_WIZARD.md"
    if [ ! -f "$WIZARD" ]; then
        fail "CLAUDE_CODE_SDLC_WIZARD.md not found"
        return
    fi

    # Must have a callout explaining template vs this repo's config
    if grep -qi 'template.*vs.*this repo\|template.*repo.*distinction\|template.*safe default' "$WIZARD"; then
        pass "Wizard distinguishes template defaults vs repo config"
    else
        fail "Wizard does not explain template vs repo distinction for autofix"
    fi
}

# Test 134: Wizard does not recommend `act` for workflow testing
# TESTING.md and CI_CD.md say act doesn't work with claude-code-action@v1
test_wizard_no_act_recommendation() {
    local WIZARD="$REPO_ROOT/CLAUDE_CODE_SDLC_WIZARD.md"
    if [ ! -f "$WIZARD" ]; then
        fail "CLAUDE_CODE_SDLC_WIZARD.md not found"
        return
    fi

    # Should NOT have act install instructions or recommend act for testing
    if grep -qi 'brew install act\|Use `act` locally\|Local testing with `act`' "$WIZARD"; then
        fail "Wizard still recommends 'act' for workflow testing (contradicts TESTING.md)"
    else
        pass "Wizard does not recommend 'act' for workflow testing"
    fi
}

# Test 135: COMPETITIVE_AUDIT.md has current test counts (23 scripts)
test_competitive_audit_current_counts() {
    local AUDIT="$REPO_ROOT/COMPETITIVE_AUDIT.md"
    if [ ! -f "$AUDIT" ]; then
        fail "COMPETITIVE_AUDIT.md not found"
        return
    fi

    if grep -q '23 scripts' "$AUDIT"; then
        pass "COMPETITIVE_AUDIT.md has current test script count (23)"
    else
        fail "COMPETITIVE_AUDIT.md has stale test script count (expected 23)"
    fi
}

# Test 136: AUTO_SELF_UPDATE.md "Who Gets What" section uses current cadence
# The roadmap history items mention "daily" in past tense (DONE items) — that's fine.
# The active "Who Gets What" section should say "weekly/monthly", not "daily/weekly/monthly".
test_auto_self_update_no_daily() {
    local PLAN="$REPO_ROOT/plans/AUTO_SELF_UPDATE.md"
    if [ ! -f "$PLAN" ]; then
        fail "plans/AUTO_SELF_UPDATE.md not found"
        return
    fi

    # Check the "Who Gets What" / "Our auto-workflows" line specifically
    if grep -q 'auto-workflows.*(weekly/monthly)' "$PLAN"; then
        pass "AUTO_SELF_UPDATE.md 'Who Gets What' uses current cadence (weekly/monthly)"
    else
        fail "AUTO_SELF_UPDATE.md 'Who Gets What' has stale cadence (expected weekly/monthly)"
    fi
}

test_readme_raw_url_matches_remote
test_no_stale_daily_cadence
test_wizard_autofix_template_distinction
test_wizard_no_act_recommendation
test_competitive_audit_current_counts
test_auto_self_update_no_daily

# --- Round 3: Codex main-branch audit findings (2026-03-27) ---

# Test 137: PR review extraction uses robust array detection
test_pr_review_extraction_uses_array_detection() {
    local WF="$REPO_ROOT/.github/workflows/pr-review.yml"
    if [ ! -f "$WF" ]; then fail "pr-review.yml not found"; return; fi

    if grep -q 'type == "array"' "$WF"; then
        pass "pr-review.yml uses robust array/object extraction pattern"
    else
        fail "pr-review.yml missing array detection — still using fragile .result // .output only"
    fi
}

# Test 138: No hook recommends act for workflow testing
test_no_hook_recommends_act() {
    local HOOKS_DIR="$REPO_ROOT/.claude/hooks"
    if [ ! -d "$HOOKS_DIR" ]; then fail ".claude/hooks/ directory not found"; return; fi

    if grep -rq 'act workflow_dispatch' "$HOOKS_DIR"/ 2>/dev/null; then
        fail "Hook(s) still recommend 'act' for workflow testing — contradicts repo policy"
    else
        pass "No hooks recommend 'act' for workflow testing"
    fi
}

# Test 139: No workflow declares unused id-token: write
test_no_unused_id_token_permission() {
    local WF_DIR="$REPO_ROOT/.github/workflows"
    local ERRORS=0

    for wf in "$WF_DIR"/*.yml; do
        if grep -q 'id-token: write' "$wf" 2>/dev/null; then
            ERRORS=$((ERRORS + 1))
        fi
    done

    if [ "$ERRORS" -eq 0 ]; then
        pass "No workflow declares unused id-token: write permission"
    else
        fail "$ERRORS workflow(s) still declare id-token: write (no OIDC consumers exist)"
    fi
}

# Test 140: Third-party action tag pinning tradeoff is documented
test_action_pinning_tradeoff_documented() {
    local EXCEPTIONS="$REPO_ROOT/CODE_REVIEW_EXCEPTIONS.md"
    if [ ! -f "$EXCEPTIONS" ]; then fail "CODE_REVIEW_EXCEPTIONS.md not found"; return; fi

    if grep -qi 'pinned to major tags\|tag.pinning' "$EXCEPTIONS" 2>/dev/null; then
        pass "Third-party action tag-pinning tradeoff documented in CODE_REVIEW_EXCEPTIONS.md"
    else
        fail "CODE_REVIEW_EXCEPTIONS.md does not document the action tag-pinning tradeoff"
    fi
}

# Test 141: ci-self-heal dispatch gates on committed
test_self_heal_dispatch_gates_on_committed() {
    local WF="$REPO_ROOT/.github/workflows/ci-self-heal.yml"
    if [ ! -f "$WF" ]; then fail "ci-self-heal.yml not found"; return; fi

    # The "Re-trigger CI" step's if condition must include a committed check
    if grep -A 5 'Re-trigger CI via workflow dispatch' "$WF" | grep -q 'committed'; then
        pass "ci-self-heal.yml dispatch gates on committed output"
    else
        fail "ci-self-heal.yml dispatch does not check committed — wastes CI runs on no-op"
    fi
}

# Test 142: README does not contain brittle exact test counts
test_readme_no_brittle_test_count() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then fail "README.md not found"; return; fi

    # Should not contain "354+" or any specific "NNN+ automated tests" pattern
    if grep -qE '[0-9]{3}\+[[:space:]]+automated tests' "$README" 2>/dev/null; then
        fail "README.md still contains brittle exact test count"
    else
        pass "README.md uses resilient test count wording"
    fi
}

test_pr_review_extraction_uses_array_detection
test_no_hook_recommends_act
test_no_unused_id_token_permission
test_action_pinning_tradeoff_documented
test_self_heal_dispatch_gates_on_committed
test_readme_no_brittle_test_count

# --- Round 4: Codex pass-2 audit findings (2026-03-27) ---

# Test 143: ci.yml generates SCORE_TRENDS.md before committing score history (Tier 1)
test_score_trends_generated_before_commit() {
    local CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"
    if [ ! -f "$CI_FILE" ]; then fail "ci.yml not found"; return; fi

    # Find line numbers of generate and commit steps in Tier 1 (e2e-quick-check job)
    local gen_line commit_line
    gen_line=$(grep -n 'Generate score trends report' "$CI_FILE" | head -1 | cut -d: -f1)
    commit_line=$(grep -n 'Commit score history' "$CI_FILE" | head -1 | cut -d: -f1)

    if [ -z "$gen_line" ] || [ -z "$commit_line" ]; then
        fail "Could not find score trends generate or commit steps in ci.yml"
        return
    fi

    if [ "$gen_line" -lt "$commit_line" ]; then
        pass "ci.yml generates SCORE_TRENDS.md before committing score history"
    else
        fail "ci.yml generates SCORE_TRENDS.md AFTER commit step (line $gen_line > $commit_line)"
    fi
}

# Test 144: ci.yml git add includes SCORE_TRENDS.md
test_score_trends_included_in_commit() {
    local CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"
    if [ ! -f "$CI_FILE" ]; then fail "ci.yml not found"; return; fi

    if grep -q 'git add.*SCORE_TRENDS.md' "$CI_FILE" 2>/dev/null; then
        pass "ci.yml includes SCORE_TRENDS.md in git add"
    else
        fail "ci.yml does not include SCORE_TRENDS.md in git add"
    fi
}

# Test 145: SCORE_TRENDS.md does not falsely claim auto-update
test_score_trends_honest_footer() {
    local TRENDS="$REPO_ROOT/SCORE_TRENDS.md"
    if [ ! -f "$TRENDS" ]; then fail "SCORE_TRENDS.md not found"; return; fi

    if grep -q 'Updated after each CI E2E run' "$TRENDS" 2>/dev/null; then
        fail "SCORE_TRENDS.md still falsely claims 'Updated after each CI E2E run'"
    else
        pass "SCORE_TRENDS.md has honest update mechanism description"
    fi
}

# Test 146: README scoring table shows TDD GREEN as AI-judge
test_readme_tdd_green_is_ai_judge() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then fail "README.md not found"; return; fi

    if grep -E 'TDD GREEN.*AI-judge' "$README" >/dev/null 2>&1; then
        pass "README correctly shows TDD GREEN as AI-judge"
    else
        fail "README does not show TDD GREEN as AI-judge"
    fi
}

# Test 147: README scoring split says 40% deterministic (not 60%)
test_readme_scoring_split_accurate() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then fail "README.md not found"; return; fi

    if grep -q '40% deterministic' "$README" 2>/dev/null; then
        pass "README correctly says 40% deterministic"
    else
        fail "README does not say 40% deterministic (actual: 4/10 criteria are deterministic)"
    fi
}

# Test 148: CONTRIBUTING.md shows tdd_red at 2 points
test_contributing_tdd_red_points() {
    local CONTRIB="$REPO_ROOT/CONTRIBUTING.md"
    if [ ! -f "$CONTRIB" ]; then fail "CONTRIBUTING.md not found"; return; fi

    if grep -E 'tdd_red.*\| 2 \|' "$CONTRIB" >/dev/null 2>&1; then
        pass "CONTRIBUTING.md correctly shows tdd_red at 2 points"
    else
        fail "CONTRIBUTING.md does not show tdd_red at 2 points (actual max is 2 per deterministic-checks.sh)"
    fi
}

# Test 149: CONTRIBUTING.md task_tracking mentions TodoWrite
test_contributing_task_tracking_mentions_todowrite() {
    local CONTRIB="$REPO_ROOT/CONTRIBUTING.md"
    if [ ! -f "$CONTRIB" ]; then fail "CONTRIBUTING.md not found"; return; fi

    if grep -E 'task_tracking.*TodoWrite' "$CONTRIB" >/dev/null 2>&1; then
        pass "CONTRIBUTING.md task_tracking mentions TodoWrite"
    else
        fail "CONTRIBUTING.md task_tracking does not mention TodoWrite (evaluator checks TodoWrite|TaskCreate)"
    fi
}

# Test 150: ci.yml workflow-level permissions are read-only
test_ci_validate_read_only_permissions() {
    local CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"
    if [ ! -f "$CI_FILE" ]; then fail "ci.yml not found"; return; fi

    # Check that workflow-level permissions use 'read' not 'write'
    # Extract the permissions block (between 'permissions:' and 'jobs:')
    local perms_section
    perms_section=$(sed -n '/^permissions:/,/^jobs:/p' "$CI_FILE" | head -10)

    if echo "$perms_section" | grep -q 'write' 2>/dev/null; then
        fail "ci.yml workflow-level permissions still grant write access"
    else
        pass "ci.yml workflow-level permissions are read-only"
    fi
}

# Test 151: CI_CD.md Tier 1 description doesn't mention "token metrics"
test_cicd_no_token_metrics_in_tier1() {
    local CICD="$REPO_ROOT/CI_CD.md"
    if [ ! -f "$CICD" ]; then fail "CI_CD.md not found"; return; fi

    # Check first 40 lines (Tier 1 flow summary area) for "token metrics"
    if head -40 "$CICD" | grep -qi 'token metrics' 2>/dev/null; then
        fail "CI_CD.md still mentions 'token metrics' in Tier 1 flow description"
    else
        pass "CI_CD.md Tier 1 flow does not mention token metrics"
    fi
}

# Test 152: CI_CD.md overview table accurately describes push-to-main
test_cicd_push_main_validation_only() {
    local CICD="$REPO_ROOT/CI_CD.md"
    if [ ! -f "$CICD" ]; then fail "CI_CD.md not found"; return; fi

    # The overview table should not lump "PR, push to main" in one row with "E2E evaluation"
    # Either split into separate rows or not claim push-to-main does E2E
    if head -15 "$CICD" | grep -i 'ci.yml' | grep -qi 'PR.*push to main.*E2E' 2>/dev/null; then
        fail "CI_CD.md overview table lumps PR and push-to-main together with E2E"
    else
        pass "CI_CD.md overview table accurately distinguishes PR vs push-to-main"
    fi
}

# Test 153: CI_CD.md permissions section doesn't mention id-token:write
test_cicd_permissions_no_id_token() {
    local CICD="$REPO_ROOT/CI_CD.md"
    if [ ! -f "$CICD" ]; then fail "CI_CD.md not found"; return; fi

    if grep -q 'id-token.*write' "$CICD" 2>/dev/null; then
        fail "CI_CD.md permissions section still mentions id-token: write"
    else
        pass "CI_CD.md permissions section does not mention id-token: write"
    fi
}

# Test 154: ci-self-heal.yml creates a friction-signal GitHub issue
test_selfheal_creates_friction_issue() {
    local WF="$REPO_ROOT/.github/workflows/ci-self-heal.yml"
    if [ ! -f "$WF" ]; then fail "ci-self-heal.yml not found"; return; fi

    if grep -q 'gh issue create' "$WF" && grep -q 'friction-signal' "$WF"; then
        pass "ci-self-heal.yml creates friction-signal issue"
    else
        fail "ci-self-heal.yml missing friction-signal issue creation"
    fi
}

# Test 155: Friction issue step uses --body-file (not inline body)
test_selfheal_friction_uses_bodyfile() {
    local WF="$REPO_ROOT/.github/workflows/ci-self-heal.yml"
    if [ ! -f "$WF" ]; then fail "ci-self-heal.yml not found"; return; fi

    if grep -q '\-\-body-file' "$WF"; then
        pass "Friction issue step uses --body-file"
    else
        fail "Friction issue step missing --body-file"
    fi
}

# Test 156: Friction issue step is gated on skip != true
test_selfheal_friction_gated_on_skip() {
    local WF="$REPO_ROOT/.github/workflows/ci-self-heal.yml"
    if [ ! -f "$WF" ]; then fail "ci-self-heal.yml not found"; return; fi

    # The friction step's if condition must check skip
    if grep -A5 'friction' "$WF" | grep -q "skip != 'true'"; then
        pass "Friction issue step gated on skip"
    else
        fail "Friction issue step not gated on skip"
    fi
}

# Test 157: README setup claim references roadmap for cross-stack
test_readme_setup_mentions_roadmap() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then fail "README.md not found"; return; fi

    if grep -i 'auto-detect' "$README" | grep -qi 'roadmap'; then
        pass "README setup claim references roadmap"
    else
        fail "README setup claim does not reference roadmap"
    fi
}

# Test 158: README friction row mentions self-heal or CI friction
test_readme_friction_mentions_selfheal() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then fail "README.md not found"; return; fi

    if grep -i 'self-evolving' "$README" | grep -qiE 'self-heal|ci friction|friction signal'; then
        pass "README friction row mentions self-heal/CI friction"
    else
        fail "README friction row does not mention self-heal or CI friction signals"
    fi
}

# Test 159: CI_CD.md ci-self-heal section documents friction-signal
test_cicd_documents_friction_signal() {
    local CICD="$REPO_ROOT/CI_CD.md"
    if [ ! -f "$CICD" ]; then fail "CI_CD.md not found"; return; fi

    if grep -qi 'friction.signal' "$CICD"; then
        pass "CI_CD.md documents friction-signal"
    else
        fail "CI_CD.md does not document friction-signal"
    fi
}

# Test 160: ROADMAP.md has setup-path E2E item
test_roadmap_has_setup_path_e2e() {
    local ROADMAP="$REPO_ROOT/ROADMAP.md"
    if [ ! -f "$ROADMAP" ]; then fail "ROADMAP.md not found"; return; fi

    if grep -qi 'setup.path.*e2e\|setup.*e2e.*proof' "$ROADMAP"; then
        pass "ROADMAP.md has setup-path E2E item"
    else
        fail "ROADMAP.md missing setup-path E2E item"
    fi
}

# Test 161: Friction issue step gates on has_findings for review-findings mode
test_selfheal_friction_gated_on_has_findings() {
    local WF="$REPO_ROOT/.github/workflows/ci-self-heal.yml"
    if [ ! -f "$WF" ]; then fail "ci-self-heal.yml not found"; return; fi

    # The friction step's if condition must check has_findings == 'true' for review-findings mode
    if grep -A10 'Create friction-signal issue' "$WF" | grep -q "has_findings == 'true'"; then
        pass "Friction issue step gated on has_findings for review-findings mode"
    else
        fail "Friction issue step not gated on has_findings"
    fi
}

test_score_trends_generated_before_commit
test_score_trends_included_in_commit
test_score_trends_honest_footer
test_readme_tdd_green_is_ai_judge
test_readme_scoring_split_accurate
test_contributing_tdd_red_points
test_contributing_task_tracking_mentions_todowrite
test_ci_validate_read_only_permissions
test_cicd_no_token_metrics_in_tier1
test_cicd_push_main_validation_only
test_cicd_permissions_no_id_token
test_selfheal_creates_friction_issue
test_selfheal_friction_uses_bodyfile
test_selfheal_friction_gated_on_skip
test_readme_setup_mentions_roadmap
test_readme_friction_mentions_selfheal
test_cicd_documents_friction_signal
test_roadmap_has_setup_path_e2e
test_selfheal_friction_gated_on_has_findings

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All workflow trigger tests passed!"
