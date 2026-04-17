#!/bin/bash
# SessionStart hook — nudges user when effort level is below recommended
# and tells Claude the recommended model so it can compare against its own
# CC does NOT expose the model to hooks, so model nudge relies on Claude
# seeing this output and comparing against its system prompt
# Non-blocking: always exits 0

RECOMMENDED_MODEL="opus[1m]"
RECOMMENDED_EFFORT="xhigh"

# Drain stdin (SessionStart sends JSON but model field isn't in it)
cat > /dev/null

if ! command -v jq > /dev/null 2>&1; then
    exit 0
fi

effort=""
project_dir="${CLAUDE_PROJECT_DIR:-.}"
for f in "$project_dir/.claude/settings.local.json" "$project_dir/.claude/settings.json" "$HOME/.claude/settings.json"; do
    if [ -f "$f" ]; then
        val=$(jq -r '.effortLevel // empty' "$f" 2>/dev/null)
        if [ -n "$val" ]; then
            effort="$val"
            break
        fi
    fi
done

nudge=""

if [ -n "$effort" ] && [ "$effort" != "$RECOMMENDED_EFFORT" ]; then
    nudge="effort: $effort → $RECOMMENDED_EFFORT (run: /effort $RECOMMENDED_EFFORT)"
fi

if [ -n "$nudge" ]; then
    echo "Upgrade available:"
    echo "  $nudge"
    echo "  recommended model: $RECOMMENDED_MODEL (run: /model $RECOMMENDED_MODEL)"
    echo "  (Claude: compare recommended model against your current model — nudge user if different)"
fi

exit 0
