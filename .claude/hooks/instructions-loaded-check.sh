#!/bin/bash
# InstructionsLoaded hook - validates SDLC files exist at session start
# Fires when Claude loads instructions (session start/resume)
# Available since Claude Code v2.1.69

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MISSING=""

if [ ! -f "$PROJECT_DIR/SDLC.md" ]; then
    MISSING="${MISSING}SDLC.md "
fi

if [ ! -f "$PROJECT_DIR/TESTING.md" ]; then
    MISSING="${MISSING}TESTING.md "
fi

if [ -n "$MISSING" ]; then
    echo "WARNING: Missing SDLC wizard files: ${MISSING}"
    echo "Run the wizard setup to generate them."
fi
