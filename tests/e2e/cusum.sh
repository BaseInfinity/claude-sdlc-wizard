#!/bin/bash
# CUSUM (Cumulative Sum) Drift Detection
#
# Detects gradual score drift that before/after comparisons might miss.
# Based on statistical process control methodology.
#
# Usage:
#   ./cusum.sh [--check] [--add <score>] [--reset]
#
# Options:
#   --check       Check current CUSUM status and alert if drift detected
#   --add <score> Add a new score and recalculate CUSUM
#   --reset       Reset the score history (start fresh)
#   --status      Show current drift status
#
# Exit codes:
#   0 - Normal operation / no drift
#   1 - Drift detected (CUSUM crossed threshold)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HISTORY_FILE="$SCRIPT_DIR/score-history.txt"

# Configuration
TARGET_SCORE=7.0         # Where we want to be
DRIFT_THRESHOLD=3.0      # CUSUM threshold for alerting
WARNING_THRESHOLD=2.0    # CUSUM threshold for warning

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 [--check] [--add <score>] [--reset] [--status]"
    echo ""
    echo "Options:"
    echo "  --check       Check current CUSUM status (default)"
    echo "  --add <score> Add a new score and recalculate"
    echo "  --reset       Reset score history"
    echo "  --status      Show detailed status"
    exit 0
}

# Ensure history file exists
ensure_history() {
    if [ ! -f "$HISTORY_FILE" ]; then
        touch "$HISTORY_FILE"
    fi
}

# Calculate CUSUM from history
calculate_cusum() {
    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo "0.0"
        return
    fi

    awk -v target="$TARGET_SCORE" '
    BEGIN { cusum = 0 }
    {
        deviation = $1 - target
        cusum += deviation
    }
    END {
        printf "%.2f", cusum
    }
    ' "$HISTORY_FILE"
}

# Get score count
get_score_count() {
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "0"
        return
    fi
    wc -l < "$HISTORY_FILE" | tr -d ' '
}

# Get mean score
get_mean_score() {
    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo "N/A"
        return
    fi

    awk '
    BEGIN { sum = 0; count = 0 }
    { sum += $1; count++ }
    END {
        if (count > 0) printf "%.1f", sum/count
        else print "N/A"
    }
    ' "$HISTORY_FILE"
}

# Get latest score
get_latest_score() {
    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo "N/A"
        return
    fi
    tail -1 "$HISTORY_FILE"
}

# Check drift status
check_drift() {
    local cusum
    cusum=$(calculate_cusum)
    local abs_cusum
    abs_cusum=$(echo "$cusum" | awk '{printf "%.2f", ($1 < 0) ? -$1 : $1}')

    # Determine status
    if echo "$abs_cusum $DRIFT_THRESHOLD" | awk '{exit !($1 >= $2)}'; then
        echo "ALERT"
    elif echo "$abs_cusum $WARNING_THRESHOLD" | awk '{exit !($1 >= $2)}'; then
        echo "WARNING"
    else
        echo "NORMAL"
    fi
}

# Show status
show_status() {
    ensure_history

    local cusum score_count mean_score latest_score status
    cusum=$(calculate_cusum)
    score_count=$(get_score_count)
    mean_score=$(get_mean_score)
    latest_score=$(get_latest_score)
    status=$(check_drift)

    echo ""
    echo "=========================================="
    echo "  CUSUM Drift Detection Status"
    echo "=========================================="
    echo ""
    echo "Configuration:"
    echo "  Target Score:      $TARGET_SCORE"
    echo "  Warning Threshold: ±$WARNING_THRESHOLD"
    echo "  Alert Threshold:   ±$DRIFT_THRESHOLD"
    echo ""
    echo "Current State:"
    echo "  Score Count:       $score_count"
    echo "  Mean Score:        $mean_score"
    echo "  Latest Score:      $latest_score"
    echo -e "  CUSUM Value:       ${BLUE}$cusum${NC}"
    echo ""

    case "$status" in
        NORMAL)
            echo -e "  Status: ${GREEN}NORMAL${NC} - Scores stable around target"
            ;;
        WARNING)
            if echo "$cusum" | awk '{exit !($1 < 0)}'; then
                echo -e "  Status: ${YELLOW}WARNING${NC} - Scores trending below target"
            else
                echo -e "  Status: ${YELLOW}WARNING${NC} - Scores trending above target (good!)"
            fi
            ;;
        ALERT)
            if echo "$cusum" | awk '{exit !($1 < 0)}'; then
                echo -e "  Status: ${RED}ALERT${NC} - Significant drift BELOW target"
                echo ""
                echo "  Action: Review recent changes for regression causes."
            else
                echo -e "  Status: ${GREEN}ALERT${NC} - Significant drift ABOVE target"
                echo ""
                echo "  Action: Consider raising baseline - scores consistently exceeding target!"
            fi
            ;;
    esac
    echo ""
}

# Add a score
add_score() {
    local score="$1"
    ensure_history

    # Validate score is a number between 0 and 10
    if ! echo "$score" | grep -qE '^[0-9]+\.?[0-9]*$'; then
        echo "Error: Score must be a number" >&2
        exit 1
    fi

    if echo "$score" | awk '{exit !($1 < 0 || $1 > 10)}'; then
        echo "Error: Score must be between 0 and 10" >&2
        exit 1
    fi

    # Add score to history
    echo "$score" >> "$HISTORY_FILE"

    # Show updated status
    echo -e "${GREEN}Added score: $score${NC}"
    echo ""

    local cusum status
    cusum=$(calculate_cusum)
    status=$(check_drift)

    echo "CUSUM: $cusum (Status: $status)"

    # Return appropriate exit code
    if [ "$status" = "ALERT" ]; then
        if echo "$cusum" | awk '{exit !($1 < 0)}'; then
            exit 1  # Negative drift is bad
        fi
    fi
}

# Reset history
reset_history() {
    if [ -f "$HISTORY_FILE" ]; then
        rm "$HISTORY_FILE"
    fi
    touch "$HISTORY_FILE"
    echo -e "${GREEN}Score history reset.${NC}"
}

# Check and return status
check_and_report() {
    ensure_history

    local status
    status=$(check_drift)
    local cusum
    cusum=$(calculate_cusum)

    case "$status" in
        NORMAL)
            echo "CUSUM=$cusum STATUS=NORMAL"
            exit 0
            ;;
        WARNING)
            echo "CUSUM=$cusum STATUS=WARNING"
            exit 0
            ;;
        ALERT)
            echo "CUSUM=$cusum STATUS=ALERT"
            if echo "$cusum" | awk '{exit !($1 < 0)}'; then
                exit 1  # Negative drift alert
            else
                exit 0  # Positive drift is good
            fi
            ;;
    esac
}

# Main
main() {
    case "${1:-}" in
        --help|-h)
            usage
            ;;
        --check)
            check_and_report
            ;;
        --add)
            if [ -z "${2:-}" ]; then
                echo "Error: --add requires a score" >&2
                exit 1
            fi
            add_score "$2"
            ;;
        --reset)
            reset_history
            ;;
        --status|"")
            show_status
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
}

main "$@"
