#!/bin/bash
# Light SDLC hook - baseline reminder every prompt (~100 tokens)
# Full guidance in skill: .claude/skills/sdlc/

# Walk up from CWD to find nearest SDLC.md + TESTING.md (#171: monorepo support)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_find-sdlc-root.sh"

# Token-bloat fix: when both project + plugin register this hook, plugin yields.
# Prevents 2× SDLC BASELINE print per UserPromptSubmit (~300 tokens doubled).
# Pass real script path explicitly (not $0) so the dedupe heuristic recognizes
# plugin paths even when the script is sourced or invoked via aliases.
dedupe_plugin_or_project "${BASH_SOURCE[0]}" || exit 0

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

# Effort auto-bump (ROADMAP #195). Watches this UserPromptSubmit payload for
# LOW-confidence / FAILED-repeatedly / CONFUSED phrases, logs a timestamped
# signal, and emits a loud '/effort xhigh' nudge when ≥2 signals land inside
# a 30-minute window. Enforces the SDLC confidence table mid-session so
# Claude stops burning budget at 'high' after confidence drops.
EFFORT_CACHE_DIR="${SDLC_WIZARD_CACHE_DIR:-$HOME/.cache/sdlc-wizard}"
EFFORT_SIGNALS="$EFFORT_CACHE_DIR/effort-signals.log"
PROMPT_TEXT=""
if [ ! -t 0 ] && command -v jq > /dev/null 2>&1; then
    STDIN_JSON=$(cat)
    if [ -n "$STDIN_JSON" ]; then
        PROMPT_TEXT=$(printf '%s' "$STDIN_JSON" | jq -r '.prompt // empty' 2>/dev/null) || PROMPT_TEXT=""
    fi
fi
if [ -n "$PROMPT_TEXT" ]; then
    LOWER=$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')
    SIGNAL_REASON=""
    # Every trigger requires first-person ownership or a structured-label
    # form, so educational/quoted mentions ("How do I name a low confidence
    # badge?", "What does 'failed again' mean?") don't fire.
    case "$LOWER" in
        *"i'm stuck"*|*"i am stuck"*|*"im stuck"*|\
        *"i'm confused"*|*"i am confused"*|*"im confused"*|\
        *"i tried twice"*|*"i've tried twice"*|*"ive tried twice"*|\
        *"i can't figure"*|*"i cant figure"*|\
        *"i'm not sure why"*|*"i am not sure why"*|*"im not sure why"*|\
        *"my confidence is low"*|*"my confidence: low"*|*"confidence: low"*|\
        *"it's still failing"*|*"its still failing"*|\
        *"it keeps failing"*|*"this keeps failing"*|\
        *"it failed again"*|*"this failed again"*|\
        *"failed twice"*|*"failed 2x"*)
            SIGNAL_REASON="low"
            ;;
    esac
    if [ -n "$SIGNAL_REASON" ]; then
        # Group the write so redirection errors (e.g., unwritable HOME,
        # cache-dir-is-a-file) land on /dev/null instead of leaking to stderr.
        {
            if mkdir -p "$EFFORT_CACHE_DIR" && [ -d "$EFFORT_CACHE_DIR" ]; then
                # Prune entries older than 1h on every write to cap log size.
                if [ -f "$EFFORT_SIGNALS" ]; then
                    PRUNE_THRESH=$(( $(date +%s) - 3600 ))
                    awk -v t="$PRUNE_THRESH" '$1+0 >= t' "$EFFORT_SIGNALS" > "${EFFORT_SIGNALS}.tmp" \
                        && mv "${EFFORT_SIGNALS}.tmp" "$EFFORT_SIGNALS"
                fi
                printf '%s\t%s\n' "$(date +%s)" "$SIGNAL_REASON" >> "$EFFORT_SIGNALS"
            fi
        } 2>/dev/null || true
    fi
fi
if [ -f "$EFFORT_SIGNALS" ]; then
    NOW=$(date +%s)
    THRESH=$(( NOW - 1800 ))
    RECENT=$(awk -v t="$THRESH" '$1+0 >= t' "$EFFORT_SIGNALS" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${RECENT:-0}" -ge 2 ]; then
        echo ""
        echo "!! EFFORT BUMP REQUIRED: ${RECENT} low-confidence signals in last 30 min !!"
        echo "   Run /effort xhigh NOW — spinning at 'high' after confidence drops wastes budget."
        echo "   (Auto-enforcement of the SDLC confidence table. ROADMAP #195.)"
        echo ""
    fi
fi

if [ ! -s "$PROJECT_DIR/SDLC.md" ] || [ ! -s "$PROJECT_DIR/TESTING.md" ]; then
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

AUTO-INVOKE SKILL (Claude MUST do this FIRST):
- implement/fix/refactor/feature/bug/build/test/TDD/release/publish/deploy → Invoke: Skill tool, skill="sdlc"
- DON'T invoke for: questions, explanations, reading/exploring code, simple queries
- DON'T wait for user to type /sdlc - AUTO-INVOKE based on task type

Workflow phases:
1. Plan Mode (research) → Present approach + confidence
2. Transition (update docs) → Request /compact
3. Implementation (TDD after compact)
4. SELF-REVIEW (/code-review) → BEFORE presenting to user

Quick refs: SDLC.md | TESTING.md | *_PLAN.md for feature
EOF
