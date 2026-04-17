#!/bin/bash
# SessionStart hook — nudges user when a better model or effort level is available
# Reads model from JSON stdin (SessionStart payload), effort from settings.json
# Non-blocking: always exits 0

# Recommended model and effort — update these when new models ship
RECOMMENDED_MODEL="claude-opus-4-7"
RECOMMENDED_EFFORT="xhigh"

input=$(cat)

if ! command -v jq > /dev/null 2>&1; then
    exit 0
fi

model=$(echo "$input" | jq -r '.model // empty' 2>/dev/null)
if [ -z "$model" ]; then
    exit 0
fi

effort=""
for f in ".claude/settings.local.json" ".claude/settings.json" "$HOME/.claude/settings.json"; do
    if [ -f "$f" ]; then
        val=$(jq -r '.effortLevel // empty' "$f" 2>/dev/null)
        if [ -n "$val" ]; then
            effort="$val"
            break
        fi
    fi
done

nudge_model=""
nudge_effort=""

if [ "$model" != "$RECOMMENDED_MODEL" ]; then
    nudge_model="model: $model → $RECOMMENDED_MODEL (run: /model $RECOMMENDED_MODEL)"
fi

if [ -n "$effort" ] && [ "$effort" != "$RECOMMENDED_EFFORT" ]; then
    nudge_effort="effort: $effort → $RECOMMENDED_EFFORT (run: /effort $RECOMMENDED_EFFORT)"
fi

if [ -n "$nudge_model" ] || [ -n "$nudge_effort" ]; then
    echo "Upgrade available:"
    [ -n "$nudge_model" ] && echo "  $nudge_model"
    [ -n "$nudge_effort" ] && echo "  $nudge_effort"
fi

exit 0
