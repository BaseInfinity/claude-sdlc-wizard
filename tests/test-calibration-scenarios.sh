#!/bin/bash
# ROADMAP #96 Phase 3 PR 2 — calibration scenarios validation.
#
# Validates the structure of `calibration-*` scenarios so the harness can rely
# on consistent fields. These scenarios are designed to reward self-review and
# punish rushed implementations — the score delta between SDLC-compliant and
# naive agents on these scenarios is the load-bearing calibration signal.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="$SCRIPT_DIR/e2e/scenarios"
PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

echo "=== Calibration Scenario Tests (ROADMAP #96 Phase 3 PR 2) ==="
echo ""

# At least one calibration-* scenario must exist.
test_calibration_exists() {
    local count
    count=$(find "$SCENARIOS_DIR" -maxdepth 1 -name 'calibration-*.md' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -ge 1 ]; then
        pass "calibration-*.md scenario exists ($count file(s))"
    else
        fail "no calibration-*.md scenarios in $SCENARIOS_DIR"
    fi
}
test_calibration_exists

# Every calibration scenario must satisfy the harness format.
for scenario in "$SCENARIOS_DIR"/calibration-*.md; do
    [ -e "$scenario" ] || continue
    name=$(basename "$scenario")

    if grep -qE '^# Scenario:' "$scenario"; then
        pass "$name has a Scenario header"
    else
        fail "$name missing '# Scenario:' header"
    fi

    if grep -qE '^## Task' "$scenario"; then
        pass "$name has a Task section"
    else
        fail "$name missing '## Task' section"
    fi

    if grep -qE '^## Fixture:' "$scenario"; then
        pass "$name declares its Fixture"
    else
        fail "$name missing '## Fixture:' declaration"
    fi

    if grep -qE '^## Success Criteria' "$scenario"; then
        pass "$name has Success Criteria section"
    else
        fail "$name missing '## Success Criteria' section (Codex CAL-001 — validator hardened to enforce standard scenario sections)"
    fi

    if grep -qE 'Calibration Signal' "$scenario"; then
        pass "$name documents the calibration signal explicitly"
    else
        fail "$name should document Calibration Signal (expected score-delta hypothesis)"
    fi

    # Codex round 1 CAL-001: validator was loose enough that a thin scenario
    # with only header/fixture/task passed. Calibration scenarios must match
    # the full harness format so they're directly comparable to non-calibration
    # scenarios in scoring + reporting.
    if grep -qE '^## Complexity' "$scenario"; then
        pass "$name has Complexity section"
    else
        fail "$name missing '## Complexity' (CAL-001 — required for harness parity)"
    fi

    if grep -qE '^## Expected SDLC Compliance' "$scenario"; then
        pass "$name has Expected SDLC Compliance section"
    else
        fail "$name missing '## Expected SDLC Compliance' (CAL-001)"
    fi

    if grep -qE '^## Verification Criteria' "$scenario"; then
        pass "$name has Verification Criteria section"
    else
        fail "$name missing '## Verification Criteria' (CAL-001)"
    fi

    # Score table: must include a row mentioning 'Total possible: 10 points'
    # so calibration scenarios are scored on the same 10-point rubric as the
    # rest of the harness (Codex round 1 CAL-002 — the original /8 table
    # didn't match the evaluator's actual scoring). 8 was reserved as a typo
    # detector — anything else is fine.
    if grep -qE 'Total possible:[[:space:]]*10[[:space:]]*points' "$scenario"; then
        pass "$name uses standard 10-point rubric (CAL-002 parity with evaluate.sh)"
    else
        fail "$name should declare 'Total possible: 10 points' (Codex CAL-002 — must match evaluator)"
    fi

    # Calibration scenarios must list >=2 distinct edge-case requirements;
    # that's the whole point of the careful-read calibration. Heuristic: count
    # numbered list items in the Task section's body.
    requirement_count=$(awk '/^## Task/{flag=1;next}/^## /{flag=0}flag' "$scenario" \
        | grep -cE '^[0-9]+\.[[:space:]]' || true)
    if [ "$requirement_count" -ge 2 ]; then
        pass "$name lists >=2 numbered requirements ($requirement_count) — careful-read signal"
    else
        fail "$name should list >=2 numbered requirements (found $requirement_count) — calibration needs multiple paths to test self-review"
    fi
done

echo ""
echo "=== Results ==="
echo "Passed: $PASSED, Failed: $FAILED"
if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
echo "All calibration-scenario tests passed."
