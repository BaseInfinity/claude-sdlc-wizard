#!/bin/bash
# Test degradation detection: score persistence + wizard hardening
# TDD RED: All tests written before implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
WIZARD_DOC="$REPO_ROOT/CLAUDE_CODE_SDLC_WIZARD.md"
SETTINGS_JSON="$REPO_ROOT/cli/templates/settings.json"
CUSUM_SCRIPT="$REPO_ROOT/tests/e2e/cusum.sh"

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

echo "=== Degradation Detection Tests ==="
echo ""

# ────────────────────────────────────────────
# Score Persistence Tests (7)
# ────────────────────────────────────────────

echo "--- Score Persistence ---"

# Tests 1-4 REWORKED for ROADMAP #212 Option 1: ci.yml's e2e-quick-check and
# e2e-full-evaluation jobs were removed. Score persistence now happens locally
# via tests/e2e/local-shepherd.sh. The CUSUM/JSONL/schema tests below still
# run against the JSONL file + the shared persist-score-history.sh script.
# Stubbing Tests 1-4 — the ci.yml-job-structure checks are no longer meaningful.

test_tier1_persist_step() { pass "tier1-persist-step test n/a (ci.yml e2e jobs removed per #212 Option 1; shepherd handles persistence)"; }
test_tier2_persist_step() { pass "tier2-persist-step test n/a (ci.yml e2e jobs removed per #212 Option 1)"; }
test_fork_guard() { pass "fork-guard test n/a (ci.yml e2e jobs removed; shepherd has its own fork-abort at local-shepherd.sh:78)"; }
test_continue_on_error_removed() { pass "continue-on-error-removed test n/a (ci.yml persist steps removed per #212 Option 1)"; }

# Keep the old function defs as no-ops so they don't shadow the stubs above.
_unused_old_test_tier1_persist_step() {
    # The persist step must appear AFTER score recording (~line 648) and
    # BEFORE the upload artifact step. We verify by checking that the step
    # name exists in the e2e-quick-check job section (lines 225-960ish)
    local tier1_section
    tier1_section=$(python3 -c "
import yaml, json
with open('$CI_YML') as f:
    wf = yaml.safe_load(f)
steps = wf['jobs']['e2e-quick-check']['steps']
names = [s.get('name', '') for s in steps]
print(json.dumps(names))
")
    if echo "$tier1_section" | grep -q "Persist scores to PR branch"; then
        # Also verify it comes after score recording
        local record_idx persist_idx
        record_idx=$(echo "$tier1_section" | python3 -c "
import json, sys
names = json.load(sys.stdin)
for i, n in enumerate(names):
    if 'Record' in n and 'score' in n.lower():
        print(i); break
else:
    print(-1)
")
        persist_idx=$(echo "$tier1_section" | python3 -c "
import json, sys
names = json.load(sys.stdin)
for i, n in enumerate(names):
    if 'Persist scores' in n:
        print(i); break
else:
    print(-1)
")
        if [ "$persist_idx" -gt "$record_idx" ] && [ "$record_idx" -ge 0 ]; then
            pass "Tier 1 has persist step after score recording"
        else
            fail "Tier 1 persist step must come after score recording (record=$record_idx, persist=$persist_idx)"
        fi
    else
        fail "Tier 1 missing 'Persist scores to PR branch' step"
    fi
}

_unused_old_test_tier2_persist_step() {
    local tier2_section
    tier2_section=$(python3 -c "
import yaml, json
with open('$CI_YML') as f:
    wf = yaml.safe_load(f)
steps = wf['jobs']['e2e-full-evaluation']['steps']
names = [s.get('name', '') for s in steps]
print(json.dumps(names))
")
    if echo "$tier2_section" | grep -q "Persist scores to PR branch"; then
        local record_idx persist_idx
        record_idx=$(echo "$tier2_section" | python3 -c "
import json, sys
names = json.load(sys.stdin)
for i, n in enumerate(names):
    if 'Record' in n and 'score' in n.lower():
        print(i); break
else:
    print(-1)
")
        persist_idx=$(echo "$tier2_section" | python3 -c "
import json, sys
names = json.load(sys.stdin)
for i, n in enumerate(names):
    if 'Persist scores' in n:
        print(i); break
else:
    print(-1)
")
        if [ "$persist_idx" -gt "$record_idx" ] && [ "$record_idx" -ge 0 ]; then
            pass "Tier 2 has persist step after score recording"
        else
            fail "Tier 2 persist step must come after score recording (record=$record_idx, persist=$persist_idx)"
        fi
    else
        fail "Tier 2 missing 'Persist scores to PR branch' step"
    fi
}

_unused_old_test_fork_guard() {
    # Both persist steps must guard against fork PRs with:
    # github.event.pull_request.head.repo.full_name == github.repository
    local persist_steps
    persist_steps=$(python3 -c "
import yaml
with open('$CI_YML') as f:
    wf = yaml.safe_load(f)
count = 0
for job_name in ['e2e-quick-check', 'e2e-full-evaluation']:
    for step in wf['jobs'][job_name]['steps']:
        if 'Persist scores' in step.get('name', ''):
            cond = step.get('if', '')
            if 'head.repo.full_name' in cond and 'github.repository' in cond:
                count += 1
print(count)
")
    if [ "$persist_steps" = "2" ]; then
        pass "Both persist steps have same-repo fork guard"
    else
        fail "Expected 2 persist steps with fork guard, found $persist_steps"
    fi
}

# Test 4: Persist steps MUST NOT swallow push failures
# (PR #196: silent continue-on-error was the root cause of the 19-day
# score-history stall — the shared script now handles transient races
# internally, so genuine push failures must surface, not be hidden.)
_unused_old_test_continue_on_error_removed() {
    local coe_count
    coe_count=$(python3 -c "
import yaml
with open('$CI_YML') as f:
    wf = yaml.safe_load(f)
count = 0
for job_name in ['e2e-quick-check', 'e2e-full-evaluation']:
    for step in wf['jobs'][job_name]['steps']:
        if 'Persist scores' in step.get('name', ''):
            if step.get('continue-on-error') is True:
                count += 1
print(count)
")
    if [ "$coe_count" = "0" ]; then
        pass "Both persist steps have continue-on-error removed (silent failures surface)"
    else
        fail "Expected 0 persist steps with continue-on-error: true (silent failure regression), found $coe_count"
    fi
}

# Test 5: [skip ci] marker lives in the shared persist script, not inline
test_skip_ci_in_script() {
    local persist_script="$REPO_ROOT/scripts/persist-score-history.sh"
    if [ ! -f "$persist_script" ]; then
        fail "scripts/persist-score-history.sh not found"
        return
    fi
    if grep -q "\[skip ci\]" "$persist_script"; then
        pass "persist script commit message contains [skip ci]"
    else
        fail "scripts/persist-score-history.sh missing [skip ci] marker in commit message"
    fi
}

# Test 6: JSONL written by CI has required fields cusum.sh consumes
test_jsonl_schema() {
    # Extract the jq -nc template from ci.yml and verify it produces
    # JSON with all fields cusum.sh needs: score (required by --add-json),
    # plus timestamp, scenario, max_score, criteria, sdp for analytics
    local sample_json
    sample_json=$(jq -nc \
        --arg ts "2026-01-01T00:00:00Z" \
        --arg scenario "test-scenario" \
        --argjson score 8 \
        --argjson max_score 10 \
        --argjson criteria '{"tdd_red":1,"self_review":1}' \
        --argjson sdp '{"adjusted":8,"external_benchmark":75,"robustness":1.0}' \
        '{timestamp: $ts, scenario: $scenario, score: $score, max_score: $max_score, criteria: $criteria, sdp: $sdp}')

    # Verify all required fields exist
    local has_score has_ts has_scenario has_max has_criteria has_sdp
    has_score=$(echo "$sample_json" | jq 'has("score")')
    has_ts=$(echo "$sample_json" | jq 'has("timestamp")')
    has_scenario=$(echo "$sample_json" | jq 'has("scenario")')
    has_max=$(echo "$sample_json" | jq 'has("max_score")')
    has_criteria=$(echo "$sample_json" | jq 'has("criteria")')
    has_sdp=$(echo "$sample_json" | jq 'has("sdp")')

    # Verify score is numeric (cusum.sh validates this)
    local score_is_num
    score_is_num=$(echo "$sample_json" | jq '.score | type == "number"')

    if [ "$has_score" = "true" ] && [ "$has_ts" = "true" ] && \
       [ "$has_scenario" = "true" ] && [ "$has_max" = "true" ] && \
       [ "$has_criteria" = "true" ] && [ "$has_sdp" = "true" ] && \
       [ "$score_is_num" = "true" ]; then
        pass "CI JSONL schema has all required fields with correct types"
    else
        fail "CI JSONL schema missing fields (score=$has_score/$score_is_num ts=$has_ts scenario=$has_scenario max=$has_max criteria=$has_criteria sdp=$has_sdp)"
    fi
}

# Test 7: cusum.sh --add-json can parse a sample JSONL entry matching CI output format
test_cusum_integration() {
    local sample_json
    sample_json=$(jq -nc \
        --arg ts "2026-01-01T00:00:00Z" \
        --arg scenario "test-scenario" \
        --argjson score 8 \
        --argjson max_score 10 \
        --argjson criteria '{"tdd_red":1,"self_review":1}' \
        --argjson sdp '{"adjusted":8,"external_benchmark":75,"robustness":1.0}' \
        '{timestamp: $ts, scenario: $scenario, score: $score, max_score: $max_score, criteria: $criteria, sdp: $sdp}')

    # Back up existing history, use temp
    local orig_jsonl="$SCRIPT_DIR/e2e/score-history.jsonl"
    local backup=""
    if [ -f "$orig_jsonl" ] && [ -s "$orig_jsonl" ]; then
        backup=$(cat "$orig_jsonl")
    fi

    # Run cusum --add-json with CI-format entry
    local output exit_code=0
    output=$("$CUSUM_SCRIPT" --add-json "$sample_json" 2>&1) || exit_code=$?

    # Restore original
    if [ -n "$backup" ]; then
        echo "$backup" > "$orig_jsonl"
    else
        > "$orig_jsonl"
    fi

    # cusum.sh should accept this without error (exit 0 = no drift, exit 1 = drift detected, both OK)
    if echo "$output" | grep -q "Added.*score"; then
        pass "cusum.sh --add-json accepts CI-format JSONL entry"
    else
        fail "cusum.sh --add-json rejected CI-format entry (exit=$exit_code): $output"
    fi
}

# ────────────────────────────────────────────
# Wizard Hardening Tests (5)
# ────────────────────────────────────────────

echo ""
echo "--- Wizard Hardening ---"

# Test 8: Wizard doc effort section references "adaptive thinking" as root cause
test_adaptive_thinking_reference() {
    # The effort section must explain WHY effort matters — not just how to set it.
    # Must reference "adaptive thinking" as the mechanism behind CC degradation.
    local effort_section
    effort_section=$(sed -n '/## Recommended Effort Level/,/^## /p' "$WIZARD_DOC")

    if echo "$effort_section" | grep -iq "adaptive thinking"; then
        pass "Wizard effort section references adaptive thinking as root cause"
    else
        fail "Wizard effort section must reference 'adaptive thinking' as degradation root cause"
    fi
}

# Test 9: Wizard doc scopes medium default to Pro/Max (not blanket claim)
test_pro_max_scope() {
    # Must NOT say "medium is the default" without qualification.
    # Must scope to Pro/Max plans specifically (API/Team/Enterprise default to high).
    local effort_section
    effort_section=$(sed -n '/## Recommended Effort Level/,/^## /p' "$WIZARD_DOC")

    if echo "$effort_section" | grep -iE "Pro.*Max|Max.*Pro|Pro/Max|Pro and Max"; then
        # Also verify it doesn't make a blanket "medium is default" claim
        if echo "$effort_section" | grep -iE "medium.*(default|defaults)" | grep -iqE "Pro|Max|plan"; then
            pass "Medium default scoped to Pro/Max plans"
        elif ! echo "$effort_section" | grep -iqE "medium.*(default|defaults)"; then
            # No "medium default" claim at all — also acceptable
            pass "Medium default scoped to Pro/Max plans (no blanket claim)"
        else
            fail "Medium default claim exists but not scoped to Pro/Max"
        fi
    else
        fail "Wizard effort section must reference Pro/Max plans for medium default scope"
    fi
}

# Test 10: Wizard doc cites code.claude.com docs (live URL)
test_live_docs_citation() {
    local effort_section
    effort_section=$(sed -n '/## Recommended Effort Level/,/^## /p' "$WIZARD_DOC")

    if echo "$effort_section" | grep -q "code.claude.com"; then
        pass "Wizard effort section cites code.claude.com docs"
    else
        fail "Wizard effort section must cite code.claude.com docs (not memory files or vague references)"
    fi
}

# Test 11: Wizard doc documents CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING as opt-in
test_env_var_documented() {
    # The env var must be documented in the wizard doc as an opt-in hardening option,
    # NOT shipped as a default in settings.json (it's a "nuclear option").
    local effort_section
    effort_section=$(sed -n '/## Recommended Effort Level/,/^## /p' "$WIZARD_DOC")

    if echo "$effort_section" | grep -q "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING"; then
        # Also verify it's NOT in the default settings.json template
        if jq -e '.env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING' "$SETTINGS_JSON" > /dev/null 2>&1; then
            fail "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING should be opt-in, not in default settings.json"
        else
            pass "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING documented as opt-in (not in default template)"
        fi
    else
        fail "Wizard doc must document CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING env var"
    fi
}

# Test 12: Wizard doc has anti-laziness guidance referencing specific mechanisms
test_anti_laziness_mechanisms() {
    # Anti-laziness guidance must reference SPECIFIC mechanisms, not vague "be thorough".
    # Must mention at least 2 of: adaptive thinking, effort levels, thinking budget, reasoning allocation
    local wizard_content
    wizard_content=$(cat "$WIZARD_DOC")

    local mechanism_count=0
    echo "$wizard_content" | grep -iq "adaptive thinking" && mechanism_count=$((mechanism_count + 1))
    echo "$wizard_content" | grep -iq "effort.level\|effort:.*high\|effort.*level" && mechanism_count=$((mechanism_count + 1))
    echo "$wizard_content" | grep -iq "thinking budget\|reasoning.*budget\|reasoning.*allocat" && mechanism_count=$((mechanism_count + 1))
    echo "$wizard_content" | grep -iq "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING" && mechanism_count=$((mechanism_count + 1))

    if [ "$mechanism_count" -ge 2 ]; then
        pass "Wizard doc anti-laziness guidance references $mechanism_count specific mechanisms"
    else
        fail "Anti-laziness guidance must reference specific mechanisms (adaptive thinking, effort levels, etc.), found $mechanism_count"
    fi
}

# ────────────────────────────────────────────
# Integration Tests (2)
# ────────────────────────────────────────────

echo ""
echo "--- Integration ---"

# Test 13: Weekly-update workflow calls cusum.sh
test_weekly_update_cusum() {
    if grep -q "cusum.sh" "$REPO_ROOT/.github/workflows/weekly-update.yml"; then
        pass "Weekly-update workflow calls cusum.sh"
    else
        fail "Weekly-update workflow must call cusum.sh for drift detection"
    fi
}

# Test 14: cusum.sh --add-json accepts score field (matches CI schema)
test_cusum_score_field() {
    # Verify cusum.sh validates .score field exists (not .total or .value)
    # This confirms CI's jq output (.score) matches cusum's expected input
    local bad_json='{"total": 8, "timestamp": "2026-01-01"}'
    local output exit_code=0
    output=$("$CUSUM_SCRIPT" --add-json "$bad_json" 2>&1) || exit_code=$?

    if [ "$exit_code" -ne 0 ] && echo "$output" | grep -qi "score"; then
        pass "cusum.sh rejects JSON without .score field (validates CI schema contract)"
    else
        fail "cusum.sh should reject JSON without .score field (exit=$exit_code)"
    fi
}

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────

echo ""
echo "--- Running Tests ---"
echo ""

test_tier1_persist_step
test_tier2_persist_step
test_fork_guard
test_continue_on_error_removed
test_skip_ci_in_script
test_jsonl_schema
test_cusum_integration
test_adaptive_thinking_reference
test_pro_max_scope
test_live_docs_citation
test_env_var_documented
test_anti_laziness_mechanisms
test_weekly_update_cusum
test_cusum_score_field

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
