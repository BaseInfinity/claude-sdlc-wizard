#!/bin/bash
# Autocompact Benchmark Results Analyzer
# Reads benchmark JSONL results and produces statistical comparison tables
# with 95% confidence intervals per threshold.
#
# Usage:
#   ./analyze-results.sh results/benchmark-20260405-120000.jsonl
#   ./analyze-results.sh results/  # Analyze all files in directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source stats library for confidence interval calculations
source "$REPO_ROOT/tests/e2e/lib/stats.sh"

if [ -z "$1" ]; then
    echo "Usage: $0 <results.jsonl | results_dir/>"
    exit 1
fi

# Collect all JSONL files
if [ -d "$1" ]; then
    RESULTS_FILES=("$1"/*.jsonl)
else
    RESULTS_FILES=("$1")
fi

# Merge all results
ALL_RESULTS=$(cat "${RESULTS_FILES[@]}")

echo "=== Autocompact Benchmark Analysis ==="
echo "Files: ${#RESULTS_FILES[@]}"
echo "Total trials: $(echo "$ALL_RESULTS" | wc -l | tr -d ' ')"
echo ""

# Get unique thresholds
THRESHOLDS=$(echo "$ALL_RESULTS" | jq -r '.threshold' | sort -un)

# ─────────────────────────────────────────────────────
# Task Score Comparison Table
# ─────────────────────────────────────────────────────

echo "--- Task Completion Score (0-10) ---"
printf "%-12s %-8s %-30s\n" "Threshold" "Mean" "95% CI"
printf "%-12s %-8s %-30s\n" "---------" "----" "------"

for threshold in $THRESHOLDS; do
    SCORES=$(echo "$ALL_RESULTS" | jq -r "select(.threshold == $threshold) | .task_score" | tr '\n' ' ')
    if [ -n "$SCORES" ]; then
        CI_RESULT=$(calculate_confidence_interval "$SCORES")
        MEAN=$(get_mean "$SCORES" 2>/dev/null || echo "$CI_RESULT" | awk '{print $1}')
        printf "%-12s %-8s %-30s\n" "${threshold}%" "$MEAN" "$CI_RESULT"
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# Context Preservation Comparison Table
# ─────────────────────────────────────────────────────

echo "--- Context Preservation Rate (Canary Recall %) ---"
printf "%-12s %-8s %-30s\n" "Threshold" "Mean" "95% CI"
printf "%-12s %-8s %-30s\n" "---------" "----" "------"

for threshold in $THRESHOLDS; do
    RATES=$(echo "$ALL_RESULTS" | jq -r "select(.threshold == $threshold) | .preservation_rate" | tr '\n' ' ')
    if [ -n "$RATES" ]; then
        CI_RESULT=$(calculate_confidence_interval "$RATES")
        MEAN=$(get_mean "$RATES" 2>/dev/null || echo "$CI_RESULT" | awk '{print $1}')
        printf "%-12s %-8s %-30s\n" "${threshold}%" "$MEAN" "$CI_RESULT"
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# Duration Comparison Table
# ─────────────────────────────────────────────────────

echo "--- Duration (seconds) ---"
printf "%-12s %-8s %-30s\n" "Threshold" "Mean" "95% CI"
printf "%-12s %-8s %-30s\n" "---------" "----" "------"

for threshold in $THRESHOLDS; do
    DURATIONS=$(echo "$ALL_RESULTS" | jq -r "select(.threshold == $threshold) | .duration_seconds" | tr '\n' ' ')
    if [ -n "$DURATIONS" ]; then
        CI_RESULT=$(calculate_confidence_interval "$DURATIONS")
        MEAN=$(get_mean "$DURATIONS" 2>/dev/null || echo "$CI_RESULT" | awk '{print $1}')
        printf "%-12s %-8s %-30s\n" "${threshold}%" "$MEAN" "$CI_RESULT"
    fi
done

echo ""

# ─────────────────────────────────────────────────────
# Pairwise Comparison (adjacent thresholds)
# ─────────────────────────────────────────────────────

echo "--- Pairwise CI Overlap (Task Score) ---"
THRESHOLD_ARRAY=($THRESHOLDS)
for ((i=0; i<${#THRESHOLD_ARRAY[@]}-1; i++)); do
    T1="${THRESHOLD_ARRAY[$i]}"
    T2="${THRESHOLD_ARRAY[$((i+1))]}"
    SCORES1=$(echo "$ALL_RESULTS" | jq -r "select(.threshold == $T1) | .task_score" | tr '\n' ' ')
    SCORES2=$(echo "$ALL_RESULTS" | jq -r "select(.threshold == $T2) | .task_score" | tr '\n' ' ')
    if [ -n "$SCORES1" ] && [ -n "$SCORES2" ]; then
        COMPARISON=$(compare_ci "$SCORES1" "$SCORES2" 2>/dev/null || echo "insufficient data")
        echo "  ${T1}% vs ${T2}%: $COMPARISON"
    fi
done

echo ""
echo "Analysis complete."
