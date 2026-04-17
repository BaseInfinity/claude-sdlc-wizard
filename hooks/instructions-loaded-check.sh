#!/bin/bash
# InstructionsLoaded hook - validates SDLC files exist at session start
# Fires when Claude loads instructions (session start/resume)
# Available since Claude Code v2.1.69
# Note: no set -e — this hook must always exit 0 to not block session start

# Walk up from CWD to find nearest SDLC.md + TESTING.md (#171: monorepo support)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_find-sdlc-root.sh"

# CWD walk-up finds nearest SDLC project (#173: silent exit for non-SDLC dirs)
if find_sdlc_root; then
    PROJECT_DIR="$SDLC_ROOT"
elif find_partial_sdlc_root; then
    # Partial setup — one file exists but not both. Warn about missing files
    PROJECT_DIR="$SDLC_ROOT"
else
    # Not an SDLC project at all — exit silently
    exit 0
fi

MISSING=""

if [ ! -f "$PROJECT_DIR/SDLC.md" ]; then
    MISSING="${MISSING:+${MISSING}, }SDLC.md"
fi

if [ ! -f "$PROJECT_DIR/TESTING.md" ]; then
    MISSING="${MISSING:+${MISSING}, }TESTING.md"
fi

if [ -n "$MISSING" ]; then
    echo "WARNING: Missing SDLC wizard files: ${MISSING}"
    echo "Invoke Skill tool, skill=\"setup-wizard\" to generate them."
fi

# Version update check (non-blocking, best-effort)
SDLC_MD="$PROJECT_DIR/SDLC.md"
if [ -f "$SDLC_MD" ]; then
    INSTALLED_VERSION=$(grep -o 'SDLC Wizard Version: [0-9.]*' "$SDLC_MD" | head -1 | sed 's/SDLC Wizard Version: //')
    if [ -n "$INSTALLED_VERSION" ] && command -v npm > /dev/null 2>&1; then
        LATEST_VERSION=$(npm view agentic-sdlc-wizard version 2>/dev/null) || true
        if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$INSTALLED_VERSION" ]; then
            echo "SDLC Wizard update available: ${INSTALLED_VERSION} → ${LATEST_VERSION} (run /update-wizard)"
        fi
    fi
fi

# Cross-model review staleness check (non-blocking, best-effort)
if command -v codex > /dev/null 2>&1 && [ -d "$PROJECT_DIR/.reviews" ]; then
    REVIEW_FILE="$PROJECT_DIR/.reviews/latest-review.md"
    if [ -f "$REVIEW_FILE" ]; then
        # Get file modification time (macOS stat -f %m, Linux stat -c %Y)
        if stat -f %m "$REVIEW_FILE" > /dev/null 2>&1; then
            REVIEW_MTIME=$(stat -f %m "$REVIEW_FILE")
        else
            REVIEW_MTIME=$(stat -c %Y "$REVIEW_FILE" 2>/dev/null || echo "0")
        fi
        NOW=$(date +%s)
        REVIEW_AGE=$(( (NOW - REVIEW_MTIME) / 86400 ))
        # Count commits since last review
        COMMITS_SINCE=$(git -C "$PROJECT_DIR" log --oneline --after="@${REVIEW_MTIME}" 2>/dev/null | wc -l | tr -d ' ') || true
        if [ "$REVIEW_AGE" -gt 3 ] && [ "${COMMITS_SINCE:-0}" -gt 5 ]; then
            echo "WARNING: ${COMMITS_SINCE} commits over ${REVIEW_AGE}d since last cross-model review — reviews may not be running. Verify: codex exec \"echo test\""
        fi
    fi
fi

# Model/effort upgrade check (non-blocking, best-effort)
RECOMMENDED_MODEL="opus[1m]"
RECOMMENDED_EFFORT="xhigh"
if command -v jq > /dev/null 2>&1; then
    EFFORT=""
    PROJ="${CLAUDE_PROJECT_DIR:-$PROJECT_DIR}"
    for f in "$PROJ/.claude/settings.local.json" "$PROJ/.claude/settings.json" "$HOME/.claude/settings.json"; do
        if [ -f "$f" ]; then
            val=$(jq -r '.effortLevel // empty' "$f" 2>/dev/null)
            if [ -n "$val" ]; then EFFORT="$val"; break; fi
        fi
    done
    if [ -n "$EFFORT" ] && [ "$EFFORT" != "$RECOMMENDED_EFFORT" ]; then
        echo "Upgrade available: effort $EFFORT → $RECOMMENDED_EFFORT (run: /effort $RECOMMENDED_EFFORT)"
        echo "Recommended model: $RECOMMENDED_MODEL (run: /model $RECOMMENDED_MODEL)"
    fi
fi

# Dual-channel install check (#181) — nudge when CLI skills + Claude plugin both present
if [ -d "$PROJECT_DIR/.claude/skills/update" ]; then
    for plugin_path in "$HOME/.claude/plugins-local/sdlc-wizard-wrap" "$HOME/.claude/plugins/cache/sdlc-wizard-local"; do
        if [ -d "$plugin_path" ]; then
            echo "WARNING: dual-install detected — CLI skills in .claude/skills/ AND Claude plugin at:"
            echo "  $plugin_path"
            echo "  Duplicate /update-wizard commands come from running both channels. Pick one:"
            echo "    - Keep plugin: remove .claude/skills/ from this project"
            echo "    - Keep CLI:    /plugin uninstall sdlc-wizard (or remove plugin dir)"
            break
        fi
    done
fi

# Claude Code version check (non-blocking, best-effort)
if command -v claude > /dev/null 2>&1 && command -v npm > /dev/null 2>&1; then
    CC_LOCAL=$(claude --version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -1) || true
    if [ -n "$CC_LOCAL" ]; then
        CC_LATEST=$(npm view @anthropic-ai/claude-code version 2>/dev/null) || true
        if [ -n "$CC_LATEST" ] && [ "$CC_LATEST" != "$CC_LOCAL" ]; then
            echo "Claude Code update available: ${CC_LOCAL} → ${CC_LATEST} (run: npm install -g @anthropic-ai/claude-code)"
        fi
    fi
fi

exit 0
