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

exit 0
