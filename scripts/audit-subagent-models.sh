#!/bin/bash
# Audit subagent model compliance from Claude Code transcripts
# Usage: ./scripts/audit-subagent-models.sh [session-subagents-dir]
#
# If no dir given, finds the most recent session for sdlc-wizard project.
# Reports which model each agent type actually used.

set -e

PROJECT_DIR="$HOME/.claude/projects/-Users-$(whoami)-sdlc-wizard"

if [ -n "$1" ]; then
    SESSION_DIR="$1"
else
    # Find most recent session with subagents
    SESSION_DIR=$(find "$PROJECT_DIR" -maxdepth 2 -name "subagents" -type d 2>/dev/null | while read -r dir; do
        parent=$(dirname "$dir")
        stat -f "%m %N" "$parent" 2>/dev/null || stat -c "%Y %n" "$parent" 2>/dev/null
    done | sort -rn | head -1 | awk '{print $2}')

    if [ -z "$SESSION_DIR" ]; then
        echo "No sessions with subagents found"
        exit 1
    fi
    SESSION_DIR="$SESSION_DIR/subagents"
fi

if [ ! -d "$SESSION_DIR" ]; then
    echo "Directory not found: $SESSION_DIR"
    exit 1
fi

echo "=== Subagent Model Compliance Audit ==="
echo "Session: $SESSION_DIR"
echo ""

EXPECTED_MODEL="${CLAUDE_CODE_SUBAGENT_MODEL:-claude-opus-4-7}"
echo "Expected model: $EXPECTED_MODEL"
echo ""

# Write raw data to temp file
RAW_FILE="${TMPDIR:-/tmp}/audit-raw-$$.txt"
RESULTS_FILE="${TMPDIR:-/tmp}/audit-results-$$.txt"
trap 'rm -f "$RAW_FILE" "$RESULTS_FILE"' EXIT

for meta in "$SESSION_DIR"/agent-*.meta.json; do
    [ -f "$meta" ] || continue

    agent_type=$(python3 -c "import json; d=json.load(open('$meta')); print(d.get('agentType','unknown'))" 2>/dev/null)
    jsonl="${meta%.meta.json}.jsonl"
    [ -f "$jsonl" ] || continue

    model=$(head -2 "$jsonl" | tail -1 | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('message',{}).get('model','unknown'))" 2>/dev/null)

    echo "$agent_type|$model"
done > "$RAW_FILE"

# Summarize
echo "--- Breakdown by Agent Type + Model ---"
sort "$RAW_FILE" | uniq -c | sort -rn | tee "$RESULTS_FILE"
echo ""

# Calculate compliance
TOTAL=$(wc -l < "$RAW_FILE" | tr -d ' ')
COMPLIANT=$(grep -c "|${EXPECTED_MODEL}$" "$RAW_FILE" || true)

if [ "$TOTAL" -gt 0 ]; then
    PCT=$((COMPLIANT * 100 / TOTAL))
    echo "--- Compliance ---"
    echo "Total subagents: $TOTAL"
    echo "Using $EXPECTED_MODEL: $COMPLIANT"
    echo "Non-compliant: $((TOTAL - COMPLIANT))"
    echo "Compliance: ${PCT}%"
    echo ""

    if [ "$PCT" -ge 95 ]; then
        echo "PASS: Model compliance >= 95%"
    elif [ "$PCT" -ge 80 ]; then
        echo "WARN: Model compliance ${PCT}% (target: 95%)"
    else
        echo "FAIL: Model compliance ${PCT}% — env var override not working reliably"
    fi
else
    echo "No subagent transcripts found"
fi
