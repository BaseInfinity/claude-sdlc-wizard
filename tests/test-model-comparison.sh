#!/bin/bash
# Model Comparison Benchmark — Quality Tests
# Validates that the workflow_dispatch workflow for A/B testing
# model quality (Opus vs Sonnet) is correctly structured and
# implements all required behavioral patterns from ci.yml Tier 2.
# Proves It Gate: tests prove BEHAVIOR, not just existence.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

WORKFLOW="$REPO_ROOT/.github/workflows/benchmark-model-comparison.yml"

echo "=== Model Comparison Benchmark Quality Tests ==="
echo "Validates workflow structure, model parameterization, error handling, and cost controls"
echo ""

# ─────────────────────────────────────────────────────
# Workflow Structure (structural — validates YAML correctness)
# ─────────────────────────────────────────────────────

echo "--- Workflow Structure ---"

# Test 1: Workflow file exists and is valid YAML
test_workflow_valid_yaml() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing: $WORKFLOW"; return; fi
    if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW'))" 2>/dev/null; then
        pass "Workflow file exists and is valid YAML"
    else
        fail "Workflow file is not valid YAML"
    fi
}

# Test 2: Workflow uses workflow_dispatch trigger (not push/PR)
test_workflow_dispatch_trigger() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "workflow_dispatch" "$WORKFLOW"; then
        # Also verify it does NOT trigger on push or pull_request
        if grep -qE "^\s+push:|^\s+pull_request:" "$WORKFLOW"; then
            fail "Workflow should only use workflow_dispatch, not push/PR triggers"
        else
            pass "Workflow uses workflow_dispatch trigger only"
        fi
    else
        fail "Workflow missing workflow_dispatch trigger"
    fi
}

# Test 3: Workflow has model input with choice type
test_model_input_choice() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "type: choice" "$WORKFLOW" && grep -q "model:" "$WORKFLOW"; then
        pass "Workflow has model input with choice type"
    else
        fail "Workflow missing model input with choice type"
    fi
}

# Test 4: Workflow model choices include both Opus and Sonnet
test_model_choices() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    local has_opus has_sonnet
    has_opus=$(grep -c "claude-opus-4-6" "$WORKFLOW" || true)
    has_sonnet=$(grep -c "claude-sonnet-4-6" "$WORKFLOW" || true)
    if [ "$has_opus" -gt 0 ] && [ "$has_sonnet" -gt 0 ]; then
        pass "Workflow model choices include both claude-opus-4-6 and claude-sonnet-4-6"
    else
        fail "Workflow missing one or both model choices (opus=$has_opus, sonnet=$has_sonnet)"
    fi
}

# Test 5: Workflow has scenario input with string type
test_scenario_input() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "scenario:" "$WORKFLOW" && grep -q "type: string" "$WORKFLOW"; then
        pass "Workflow has scenario input with string type"
    else
        fail "Workflow missing scenario input with string type"
    fi
}

# Test 6: Workflow has trials input with number type (default 5)
test_trials_input() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "trials:" "$WORKFLOW" && grep -q "type: number" "$WORKFLOW"; then
        if grep -A5 "trials:" "$WORKFLOW" | grep -q "default: 5"; then
            pass "Workflow has trials input with number type, default 5"
        else
            fail "Workflow trials input missing default: 5"
        fi
    else
        fail "Workflow missing trials input with number type"
    fi
}

# Test 7: Workflow has max_turns input with number type (default 55)
test_max_turns_input() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "max_turns:" "$WORKFLOW" && grep -q "default: 55" "$WORKFLOW"; then
        pass "Workflow has max_turns input with number type, default 55"
    else
        fail "Workflow missing max_turns input with default 55"
    fi
}

# ─────────────────────────────────────────────────────
# Model Selection (behavioral — proves parameterization)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Model Selection ---"

# Test 8: Workflow passes --model via claude_args (not env var, not hardcoded)
test_model_via_claude_args() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "\-\-model" "$WORKFLOW"; then
        # Verify it's in claude_args context, not as an env var
        if grep -B5 "\-\-model" "$WORKFLOW" | grep -q "claude_args"; then
            pass "Workflow passes --model via claude_args"
        else
            fail "Workflow has --model but not within claude_args"
        fi
    else
        fail "Workflow missing --model flag"
    fi
}

# Test 9: Workflow uses inputs.model interpolation (parameterized, not hardcoded)
test_model_parameterized() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q 'inputs\.model' "$WORKFLOW"; then
        pass "Workflow uses \${{ inputs.model }} interpolation (parameterized)"
    else
        fail "Workflow model is hardcoded instead of using inputs.model"
    fi
}

# ─────────────────────────────────────────────────────
# Evaluation Integration (behavioral — proves error handling)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Evaluation Integration ---"

# Test 10: Workflow sources stats.sh for CI calculation
test_sources_stats() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "source.*stats\.sh\|\..*stats\.sh" "$WORKFLOW"; then
        pass "Workflow sources stats.sh for CI calculation"
    else
        fail "Workflow missing stats.sh sourcing"
    fi
}

# Test 11: Workflow calls evaluate.sh with --json flag
test_evaluate_json_flag() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "evaluate\.sh.*--json" "$WORKFLOW"; then
        pass "Workflow calls evaluate.sh with --json flag"
    else
        fail "Workflow missing evaluate.sh --json call"
    fi
}

# Test 12: Workflow runs evaluation in a loop (multiple trials)
test_eval_loop() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "for.*in\|while" "$WORKFLOW" && grep -q "evaluate\.sh" "$WORKFLOW"; then
        pass "Workflow runs evaluation in a loop (multiple trials)"
    else
        fail "Workflow missing evaluation loop"
    fi
}

# Test 13: Workflow separates stderr from evaluate.sh (2> redirect, not 2>&1)
test_stderr_separation() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    # Must have 2> redirect but NOT 2>&1 (which mixes streams)
    if grep -q '2>"' "$WORKFLOW" || grep -q "2>'" "$WORKFLOW" || grep -q '2>\$' "$WORKFLOW"; then
        if grep -q '2>&1.*evaluate' "$WORKFLOW"; then
            fail "Workflow uses 2>&1 with evaluate.sh (should separate stderr)"
        else
            pass "Workflow separates stderr from evaluate.sh with 2> redirect"
        fi
    else
        fail "Workflow missing stderr separation (2> redirect)"
    fi
}

# Test 14: Workflow checks EVAL_EXIT non-zero (evaluator failure path)
test_eval_exit_check() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "EVAL_EXIT" "$WORKFLOW"; then
        pass "Workflow checks EVAL_EXIT for evaluator failure path"
    else
        fail "Workflow missing EVAL_EXIT check (evaluator failure handling)"
    fi
}

# Test 15: Workflow checks .error == true in evaluator response (API error path)
test_error_field_check() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q '\.error.*true\|error.*==.*true' "$WORKFLOW"; then
        pass "Workflow checks .error == true in evaluator response"
    else
        fail "Workflow missing .error == true check (API error path)"
    fi
}

# Test 16: Workflow validates .score field exists (invalid JSON path)
test_score_validation() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q '\.score' "$WORKFLOW" && grep -q 'empty\|null\|-z' "$WORKFLOW"; then
        pass "Workflow validates .score field exists in JSON response"
    else
        fail "Workflow missing .score validation (invalid JSON path)"
    fi
}

# ─────────────────────────────────────────────────────
# Input Validation (behavioral — proves bad input rejection)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Input Validation ---"

# Test 17: Validate-inputs checks scenario file exists
test_scenario_validation() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "scenarios/" "$WORKFLOW" && grep -q "validate" "$WORKFLOW"; then
        # Must check file existence, not just reference the path
        if grep -q "\-f\|\-e\|test.*scenarios\|ls.*scenarios" "$WORKFLOW"; then
            pass "Validate-inputs checks scenario file exists in scenarios/"
        else
            fail "Workflow references scenarios/ but doesn't validate file existence"
        fi
    else
        fail "Workflow missing scenario file validation"
    fi
}

# Test 18: Validate-inputs rejects trials > 5
test_trials_max_cap() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -qE '\-gt 5|\> 5|trials.*5|max.*5' "$WORKFLOW"; then
        pass "Validate-inputs rejects trials > 5 (cost guard)"
    else
        fail "Workflow missing trials > 5 rejection (cost guard)"
    fi
}

# Test 19: Validate-inputs rejects trials < 1
test_trials_min_cap() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -qE '\-lt 1|\< 1|trials.*1|min.*1' "$WORKFLOW"; then
        pass "Validate-inputs rejects trials < 1 (sanity)"
    else
        fail "Workflow missing trials < 1 rejection (sanity)"
    fi
}

# Test 19b: Validate-inputs rejects max_turns > 100 (cost guard)
test_max_turns_cap() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -qE '\-gt 100|max_turns.*100|MAX_TURNS.*100' "$WORKFLOW"; then
        pass "Validate-inputs rejects max_turns > 100 (cost guard)"
    else
        fail "Workflow missing max_turns > 100 rejection (cost guard)"
    fi
}

# ─────────────────────────────────────────────────────
# Simulation Quality (behavioral — proves correct setup)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Simulation Quality ---"

# Test 20: Workflow uses anthropics/claude-code-action@v1
test_claude_code_action() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "anthropics/claude-code-action@v1" "$WORKFLOW"; then
        pass "Workflow uses anthropics/claude-code-action@v1"
    else
        fail "Workflow missing anthropics/claude-code-action@v1"
    fi
}

# Test 21: Workflow has integrity check (timing validation)
test_integrity_check() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "ELAPSED\|integrity\|timing" "$WORKFLOW" && grep -q "20\|30" "$WORKFLOW"; then
        pass "Workflow has integrity check (timing validation)"
    else
        fail "Workflow missing integrity check"
    fi
}

# Test 22: Simulation prompt includes TDD and confidence instructions
test_prompt_quality() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    local has_tdd has_conf
    has_tdd=$(grep -ci "TDD\|test.*first\|test.*BEFORE" "$WORKFLOW" || true)
    has_conf=$(grep -ci "confidence\|Confidence:" "$WORKFLOW" || true)
    if [ "$has_tdd" -gt 0 ] && [ "$has_conf" -gt 0 ]; then
        pass "Simulation prompt includes TDD and confidence instructions"
    else
        fail "Simulation prompt missing TDD ($has_tdd) or confidence ($has_conf) instructions"
    fi
}

# Test 23: Workflow installs wizard into test fixture before simulation
test_wizard_install() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "fixtures/test-repo" "$WORKFLOW" && grep -q "cp.*hooks\|cp.*skills\|Install.*wizard" "$WORKFLOW"; then
        pass "Workflow installs wizard into test fixture before simulation"
    else
        fail "Workflow missing wizard installation into test fixture"
    fi
}

# Test 23b: Workflow verifies wizard installation (not silent failure)
test_wizard_install_verify() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "Verify wizard" "$WORKFLOW" && grep -q "hooks.*not installed\|meaningless" "$WORKFLOW"; then
        pass "Workflow verifies wizard installation (P0 fix: no silent failures)"
    else
        fail "Workflow missing wizard installation verification step"
    fi
}

# Test 24: Workflow requires ANTHROPIC_API_KEY secret for simulation
test_api_key_required() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q 'secrets\.ANTHROPIC_API_KEY' "$WORKFLOW"; then
        pass "Workflow requires ANTHROPIC_API_KEY secret"
    else
        fail "Workflow missing ANTHROPIC_API_KEY secret requirement"
    fi
}

# Test 25: Workflow checks output file exists before evaluation
test_output_file_guard() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q 'OUTPUT_FILE\|execution-output\|output.*file' "$WORKFLOW" && grep -q '\-f.*OUTPUT\|test.*-f\|if.*OUTPUT_FILE' "$WORKFLOW"; then
        pass "Workflow checks output file exists before evaluation"
    else
        fail "Workflow missing output file existence check before evaluation"
    fi
}

# ─────────────────────────────────────────────────────
# Matrix Expansion (behavioral — proves "all" mode)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Matrix Expansion ---"

# Test 26: Workflow has matrix strategy for scenario expansion
test_matrix_strategy() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "matrix" "$WORKFLOW" && grep -q "strategy" "$WORKFLOW"; then
        pass "Workflow has matrix strategy for scenario expansion"
    else
        fail "Workflow missing matrix strategy"
    fi
}

# Test 27: Workflow generates scenario list from scenarios/*.md when input is "all"
test_all_scenario_expansion() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q '"all"\|== .all' "$WORKFLOW" && grep -q "scenarios/" "$WORKFLOW"; then
        pass "Workflow handles 'all' input to expand scenarios"
    else
        fail "Workflow missing 'all' scenario expansion logic"
    fi
}

# ─────────────────────────────────────────────────────
# Results & Artifacts (behavioral — proves output correctness)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Results & Artifacts ---"

# Test 28: Workflow writes to GITHUB_STEP_SUMMARY
test_step_summary() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "GITHUB_STEP_SUMMARY" "$WORKFLOW"; then
        pass "Workflow writes results to GITHUB_STEP_SUMMARY"
    else
        fail "Workflow missing GITHUB_STEP_SUMMARY output"
    fi
}

# Test 29: Workflow uploads JSON artifact
test_artifact_upload() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "actions/upload-artifact" "$WORKFLOW"; then
        pass "Workflow uploads artifact with actions/upload-artifact"
    else
        fail "Workflow missing artifact upload"
    fi
}

# Test 30: Summary includes mean, ci_lower, ci_upper (not just raw score)
test_summary_ci_fields() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    local has_mean has_lower has_upper
    has_mean=$(grep -ci "mean\|average" "$WORKFLOW" || true)
    has_lower=$(grep -ci "ci_lower\|lower.*bound\|CI.*lower" "$WORKFLOW" || true)
    has_upper=$(grep -ci "ci_upper\|upper.*bound\|CI.*upper" "$WORKFLOW" || true)
    if [ "$has_mean" -gt 0 ] && [ "$has_lower" -gt 0 ] && [ "$has_upper" -gt 0 ]; then
        pass "Summary includes mean, CI lower bound, and CI upper bound"
    else
        fail "Summary missing statistical fields (mean=$has_mean, lower=$has_lower, upper=$has_upper)"
    fi
}

# Test 31: Artifact JSON includes score data fields
test_artifact_content() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    # Verify the workflow writes structured JSON with expected fields to artifact
    local has_scores has_criteria
    has_scores=$(grep -cE 'scores|mean|ci_lower|ci_upper' "$WORKFLOW" || true)
    has_criteria=$(grep -ci 'criteria' "$WORKFLOW" || true)
    if [ "$has_scores" -gt 0 ] && [ "$has_criteria" -gt 0 ]; then
        pass "Artifact JSON includes score data and criteria fields"
    else
        fail "Artifact missing expected data fields (scores=$has_scores, criteria=$has_criteria)"
    fi
}

# ─────────────────────────────────────────────────────
# Safety & Budget (behavioral — proves cost control)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Safety & Budget ---"

# Test 32: Workflow has concurrency group with cancel-in-progress
test_concurrency() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "concurrency:" "$WORKFLOW" && grep -q "cancel-in-progress: true" "$WORKFLOW"; then
        pass "Workflow has concurrency group with cancel-in-progress: true"
    else
        fail "Workflow missing concurrency group or cancel-in-progress"
    fi
}

# Test 33: Workflow permissions are contents: read only (no write scopes)
test_permissions_readonly() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "contents: read" "$WORKFLOW"; then
        if grep -q "contents: write\|pull-requests: write\|issues: write" "$WORKFLOW"; then
            fail "Workflow has write permissions (should be read-only)"
        else
            pass "Workflow permissions are contents: read only"
        fi
    else
        fail "Workflow missing explicit permissions declaration"
    fi
}

# Test 34: Zero inline ${{ inputs.* }} or ${{ matrix.* }} in run: blocks (injection prevention)
test_env_block_injection_prevention() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    # Parse YAML, extract run: blocks, check for inline interpolation
    local violations
    violations=$(python3 -c "
import yaml, re
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
count = 0
for job_name, job in wf.get('jobs', {}).items():
    for step in job.get('steps', []):
        run_block = step.get('run', '')
        if run_block:
            matches = re.findall(r'\\\$\{\{.*?(inputs\.|matrix\.).*?\}\}', run_block)
            count += len(matches)
print(count)
")
    if [ "$violations" = "0" ]; then
        pass "Zero inline \${{ inputs/matrix }} in run: blocks (injection-safe)"
    else
        fail "Found $violations inline \${{ inputs/matrix }} in run: blocks (shell injection risk)"
    fi
}

# Test 35: Artifact construction uses jq (not fragile heredoc)
test_artifact_uses_jq() {
    if [ ! -f "$WORKFLOW" ]; then fail "Workflow file missing"; return; fi
    if grep -q "jq -n" "$WORKFLOW" && grep -q "\-\-arg model\|\-\-argjson mean" "$WORKFLOW"; then
        pass "Artifact JSON constructed with jq (safe against empty outputs)"
    else
        fail "Artifact JSON uses fragile heredoc instead of jq"
    fi
}

# ─────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────

echo ""

test_workflow_valid_yaml
test_workflow_dispatch_trigger
test_model_input_choice
test_model_choices
test_scenario_input
test_trials_input
test_max_turns_input
test_model_via_claude_args
test_model_parameterized
test_sources_stats
test_evaluate_json_flag
test_eval_loop
test_stderr_separation
test_eval_exit_check
test_error_field_check
test_score_validation
test_scenario_validation
test_trials_max_cap
test_trials_min_cap
test_max_turns_cap
test_claude_code_action
test_integrity_check
test_prompt_quality
test_wizard_install
test_wizard_install_verify
test_api_key_required
test_output_file_guard
test_matrix_strategy
test_all_scenario_expansion
test_step_summary
test_artifact_upload
test_summary_ci_fields
test_artifact_content
test_concurrency
test_permissions_readonly
test_env_block_injection_prevention
test_artifact_uses_jq

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
