#!/bin/bash
# Run Tier 2 (5-trial) statistical evaluation
#
# Usage:
#   ./run-tier2-evaluation.sh <scenario> <output_file> [trials]
#
# Arguments:
#   scenario     Scenario file path (required)
#   output_file  Claude execution output file (required)
#   trials       Number of evaluation trials (default: 5)
#
# Output (to stdout):
#   scores=<space-separated scores>
#   score=<mean>
#   ci=<confidence interval string>
#
# Example:
#   ./run-tier2-evaluation.sh tests/e2e/scenarios/version-upgrade.md /tmp/claude-output.json
#   # Output:
#   # scores= 5.1 5.3 5.0 5.2 5.4
#   # score=5.2
#   # ci=5.2 ± 0.2 (95% CI: [5.0, 5.4])

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCENARIO="${1:?Error: scenario file path required}"
OUTPUT_FILE="${2:?Error: output file path required}"
TRIALS="${3:-5}"

# Verify scenario exists
if [ ! -f "$SCENARIO" ]; then
    echo "Error: Scenario not found: $SCENARIO" >&2
    exit 1
fi

# Verify output file exists
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Output file not found: $OUTPUT_FILE" >&2
    exit 1
fi

# Run evaluations
SCORES=""
for i in $(seq 1 "$TRIALS"); do
    echo "Trial $i/$TRIALS..." >&2
    EVAL_STDERR="${TMPDIR:-/tmp}/eval-stderr-t2-$i.log"
    EVAL_EXIT=0
    RESULT=$("$SCRIPT_DIR/evaluate.sh" "$SCENARIO" "$OUTPUT_FILE" --json 2>"$EVAL_STDERR") || EVAL_EXIT=$?

    # evaluate.sh exit semantics are overloaded: exit 1 covers both
    # "genuine infra error" (LLM outage, bad input) AND "evaluation
    # completed with PASS=false" (critical miss, score < baseline). For
    # 5-trial statistical evaluation, only the former should abort — a
    # critical-miss trial is still a valid data point. Distinguish via
    # the JSON .error field, matching ci.yml's single-trial pattern.
    INFRA_ERROR=false
    if echo "$RESULT" | jq -e '.error == true' > /dev/null 2>&1; then
        INFRA_ERROR=true
    fi

    if [ "$INFRA_ERROR" = "true" ]; then
        echo "Error: evaluate.sh returned .error=true on trial $i: $(echo "$RESULT" | jq -r '.summary')" >&2
        echo "Stderr: $(cat "$EVAL_STDERR")" >&2
        exit 1
    fi

    SCORE=$(echo "$RESULT" | jq -r '.score // empty')
    if [ -z "$SCORE" ]; then
        # Non-zero exit AND no valid JSON/score = treat as infra error.
        # Non-zero exit WITH valid score = low-score run, record it.
        echo "Error: evaluate.sh returned no score on trial $i (exit=$EVAL_EXIT)" >&2
        echo "Stderr: $(cat "$EVAL_STDERR")" >&2
        echo "Result: ${RESULT:0:500}" >&2
        exit 1
    fi

    # If evaluate.sh exited non-zero but we got a valid score here, log a
    # warning so weekly-update triage still surfaces the low score.
    if [ "$EVAL_EXIT" -ne 0 ]; then
        echo "Warning: trial $i scored $SCORE but evaluate.sh exited $EVAL_EXIT (critical miss or below baseline — recording data point)" >&2
    fi
    SCORES="$SCORES $SCORE"
    echo "  Trial $i score: $SCORE" >&2
done

# Calculate statistics
source "$SCRIPT_DIR/lib/stats.sh"
CI_RESULT=$(calculate_confidence_interval "$SCORES")
MEAN=$(get_mean "$SCORES")

# Output in key=value format for easy parsing
echo "scores=$SCORES"
echo "score=$MEAN"
echo "ci=$CI_RESULT"
