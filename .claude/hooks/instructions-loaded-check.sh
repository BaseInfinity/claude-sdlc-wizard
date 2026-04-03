#!/bin/bash
# InstructionsLoaded hook - validates SDLC files exist at session start
# Fires when Claude loads instructions (session start/resume)
# Available since Claude Code v2.1.69
# Note: no set -e — this hook must always exit 0 to not block session start

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
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
