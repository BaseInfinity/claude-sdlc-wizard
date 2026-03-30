#!/bin/bash
# Light SDLC hook - baseline reminder every prompt (~100 tokens)
# Full guidance in skills: .claude/skills/sdlc/ and .claude/skills/testing/

# Check if setup has been completed
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
if [ ! -f "$PROJECT_DIR/SDLC.md" ] || [ ! -f "$PROJECT_DIR/TESTING.md" ]; then
    cat << 'SETUP'
SETUP NOT COMPLETE: SDLC.md and/or TESTING.md are missing.

MANDATORY FIRST ACTION: Invoke Skill tool, skill="setup-wizard"
Do NOT proceed with any other task until setup is complete.
Tell the user: "I need to run the SDLC setup wizard first to configure your project."
SETUP
    exit 0
fi

cat << 'EOF'
SDLC BASELINE:
1. TodoWrite FIRST (plan tasks before coding)
2. STATE CONFIDENCE: HIGH/MEDIUM/LOW
3. LOW confidence? ASK USER before proceeding
4. FAILED 2x? STOP and ASK USER
5. ALL TESTS MUST PASS BEFORE COMMIT - NO EXCEPTIONS

AUTO-INVOKE SKILLS (Claude MUST do this FIRST):
- implement/fix/refactor/feature/bug/build → Invoke: Skill tool, skill="sdlc"
- test/TDD/write test (standalone) → Invoke: Skill tool, skill="testing"
- If BOTH match (e.g., "fix the test") → sdlc takes precedence (includes TDD)
- DON'T invoke for: questions, explanations, reading/exploring code, simple queries
- DON'T wait for user to type /sdlc - AUTO-INVOKE based on task type

Workflow phases:
1. Plan Mode (research) → Present approach + confidence
2. Transition (update docs) → Request /compact
3. Implementation (TDD after compact)
4. SELF-REVIEW (/code-review) → BEFORE presenting to user

Quick refs: SDLC.md | TESTING.md | *_PLAN.md for feature
EOF
