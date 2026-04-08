#!/bin/bash
# Catch Analytics — reads catches.jsonl and outputs effectiveness metrics
#
# Usage:
#   ./catch-analytics.sh                              # console output
#   ./catch-analytics.sh --report                     # markdown for docs
#   ./catch-analytics.sh --history path/to/file.jsonl  # custom history file
#
# Reads catches.jsonl (JSON-lines) with format:
#   { id, timestamp, layer, severity, pr, description }
#
# Metrics:
#   - DDE (Defect Detection Effectiveness) per layer: catches / total
#   - Escape rate: catches at layer N imply layers 1..N-1 missed it
#   - Severity breakdown per layer
#
# Layer pipeline order (for escape analysis):
#   hook → self-review → cross-model-review → ci-review
# A catch at ci-review means 3 prior layers escaped it.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HISTORY_FILE="$SCRIPT_DIR/../../.metrics/catches.jsonl"
REPORT_MODE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --history)
            HISTORY_FILE="$2"
            shift 2
            ;;
        --report)
            REPORT_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# Handle empty or missing file
if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
    if [ "$REPORT_MODE" = true ]; then
        echo "# Effectiveness Scoreboard"
        echo ""
        echo "No catches recorded yet."
    else
        echo "No catches recorded."
    fi
    exit 0
fi

# Count total
TOTAL=$(wc -l < "$HISTORY_FILE" | tr -d ' ')

if [ "$TOTAL" -eq 0 ]; then
    echo "No catches recorded."
    exit 0
fi

# Layer ordering for escape analysis
# Index: hook=0, self-review=1, cross-model-review=2, ci-review=3
layer_index() {
    case "$1" in
        hook) echo 0 ;;
        self-review) echo 1 ;;
        cross-model-review) echo 2 ;;
        ci-review) echo 3 ;;
        *) echo -1 ;;
    esac
}

# Count per layer (use -c for compact single-line output)
COUNT_HOOK=$(jq -c 'select(.layer=="hook")' "$HISTORY_FILE" | wc -l | tr -d ' ')
COUNT_SELF=$(jq -c 'select(.layer=="self-review")' "$HISTORY_FILE" | wc -l | tr -d ' ')
COUNT_CROSS=$(jq -c 'select(.layer=="cross-model-review")' "$HISTORY_FILE" | wc -l | tr -d ' ')
COUNT_CI=$(jq -c 'select(.layer=="ci-review")' "$HISTORY_FILE" | wc -l | tr -d ' ')

# Count per severity
COUNT_P0=$(jq -c 'select(.severity=="P0")' "$HISTORY_FILE" | wc -l | tr -d ' ')
COUNT_P1=$(jq -c 'select(.severity=="P1")' "$HISTORY_FILE" | wc -l | tr -d ' ')
COUNT_P2=$(jq -c 'select(.severity=="P2")' "$HISTORY_FILE" | wc -l | tr -d ' ')

# DDE percentage (integer)
dde() {
    local count="$1"
    if [ "$TOTAL" -eq 0 ]; then
        echo 0
    else
        echo $(( (count * 100) / TOTAL ))
    fi
}

DDE_HOOK=$(dde "$COUNT_HOOK")
DDE_SELF=$(dde "$COUNT_SELF")
DDE_CROSS=$(dde "$COUNT_CROSS")
DDE_CI=$(dde "$COUNT_CI")

# Escape analysis: catches at layer N mean N-1 upstream layers escaped
# Total escapes = sum of (layer_index * count_at_layer) for each catch
ESCAPE_SELF=0  # times self-review missed (catches at cross-model or ci)
ESCAPE_CROSS=0 # times cross-model missed (catches at ci)

ESCAPE_SELF=$((COUNT_CROSS + COUNT_CI))
ESCAPE_CROSS=$COUNT_CI

# Severity per layer (for detailed breakdown)
sev_per_layer() {
    local layer="$1"
    local sev="$2"
    jq -c "select(.layer==\"$layer\" and .severity==\"$sev\")" "$HISTORY_FILE" | wc -l | tr -d ' '
}

if [ "$REPORT_MODE" = true ]; then
    echo "# Effectiveness Scoreboard"
    echo ""
    echo "## Defect Detection Effectiveness (DDE)"
    echo ""
    echo "| Layer | Catches | DDE % | Pipeline Position |"
    echo "|-------|---------|-------|-------------------|"
    echo "| hook | $COUNT_HOOK | ${DDE_HOOK}% | 1st (earliest) |"
    echo "| self-review | $COUNT_SELF | ${DDE_SELF}% | 2nd |"
    echo "| cross-model-review | $COUNT_CROSS | ${DDE_CROSS}% | 3rd |"
    echo "| ci-review | $COUNT_CI | ${DDE_CI}% | 4th (latest) |"
    echo "| **Total** | **$TOTAL** | **100%** | |"
    echo ""
    echo "## Escape Rate"
    echo ""
    echo "| Layer | Escapes (bugs it missed) | Escape Rate |"
    echo "|-------|-------------------------|-------------|"
    if [ "$TOTAL" -gt 0 ]; then
        echo "| self-review | $ESCAPE_SELF | $(( (ESCAPE_SELF * 100) / TOTAL ))% |"
        echo "| cross-model-review | $ESCAPE_CROSS | $(( (ESCAPE_CROSS * 100) / TOTAL ))% |"
    fi
    echo ""
    echo "## Severity Breakdown"
    echo ""
    echo "| Layer | P0 | P1 | P2 |"
    echo "|-------|----|----|----|"
    echo "| hook | $(sev_per_layer hook P0) | $(sev_per_layer hook P1) | $(sev_per_layer hook P2) |"
    echo "| self-review | $(sev_per_layer self-review P0) | $(sev_per_layer self-review P1) | $(sev_per_layer self-review P2) |"
    echo "| cross-model-review | $(sev_per_layer cross-model-review P0) | $(sev_per_layer cross-model-review P1) | $(sev_per_layer cross-model-review P2) |"
    echo "| ci-review | $(sev_per_layer ci-review P0) | $(sev_per_layer ci-review P1) | $(sev_per_layer ci-review P2) |"
    echo ""
    echo "_Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) | Total catches: $TOTAL_"
else
    echo "=== Effectiveness Scoreboard ==="
    echo ""
    echo "Defect Detection Effectiveness (DDE):"
    echo "  hook:                ${DDE_HOOK}%  ($COUNT_HOOK catches)"
    echo "  self-review:         ${DDE_SELF}%  ($COUNT_SELF catches)"
    echo "  cross-model-review:  ${DDE_CROSS}%  ($COUNT_CROSS catches)"
    echo "  ci-review:           ${DDE_CI}%  ($COUNT_CI catches)"
    echo "  total:               $TOTAL catches"
    echo ""
    echo "Escape Rate:"
    echo "  self-review missed:         $ESCAPE_SELF bugs (caught later by cross-model or CI)"
    echo "  cross-model-review missed:  $ESCAPE_CROSS bugs (caught later by CI)"
    echo ""
    echo "Severity:"
    echo "  P0 (critical): $COUNT_P0"
    echo "  P1 (major):    $COUNT_P1"
    echo "  P2 (minor):    $COUNT_P2"
fi
