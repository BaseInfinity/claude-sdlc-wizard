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

# Roadmap #224: opt-in fires-once instrumentation. CC 2.1.118 shipped a fix for
# prompt hooks double-firing when a verifier subagent itself made tool calls.
# When SDLC_HOOK_FIRE_LOG is set, append one tab-separated record per real
# invocation (post-dedupe). Maintainer can compare line count against prompt
# count to verify the CC fix in real sessions. See CLAUDE_CODE_SDLC_WIZARD.md →
# "Verifying Prompt-Hook-Fires-Once" for the procedure.
if [ -n "${SDLC_HOOK_FIRE_LOG:-}" ]; then
    {
        printf '%s\t%s\tsdlc-prompt-check\n' "$(date +%s)" "$$" >> "$SDLC_HOOK_FIRE_LOG"
    } 2>/dev/null || true
fi

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
SESSION_ID=""
# Read stdin once regardless of jq availability — session_id extraction
# is jq-independent (Codex round 1 P1: BASELINE gate failed when jq was
# missing or broken). Prompt extraction still needs jq because prompt
# content can contain arbitrary multi-line text + escapes.
if [ ! -t 0 ]; then
    STDIN_JSON=$(cat)
    if [ -n "$STDIN_JSON" ]; then
        # session_id is a UUID-shaped string with no escapable content
        # in CC's stdin contract — regex extraction is sufficient.
        # `tr -cd` later strips anything filename-unsafe, so a malformed
        # input cannot escape the cache dir.
        SESSION_ID=$(printf '%s' "$STDIN_JSON" \
            | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' \
            | head -1 \
            | sed 's/.*"\([^"]*\)"$/\1/')
        if command -v jq > /dev/null 2>&1; then
            PROMPT_TEXT=$(printf '%s' "$STDIN_JSON" | jq -r '.prompt // empty' 2>/dev/null) || PROMPT_TEXT=""
        fi
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

# Token-bloat fix: BASELINE block fires once per CC session (~250 tok × 50
# prompts = ~12K wasted tokens before this gate). Once Claude has the SDLC
# skill auto-invoked (covers TodoWrite/confidence/workflow), this static
# block is duplicate context. Sentinel is per-session_id so a fresh CC
# session re-emits the cold-start nudge. Without session_id (legacy CC, or
# direct shell tests with no JSON stdin), behavior is unchanged — emits
# every fire. SETUP-not-complete + EFFORT-bump branches above are NOT
# gated; they're dynamic state warnings that must fire every prompt.
#
# Concurrency: claim is atomic via `set -C` (noclobber) — the redirect
# `: > "$path"` create-or-fails. Across N parallel fires with the same
# session_id, exactly one wins the claim and emits BASELINE; the rest
# see file-exists and suppress. (Codex round 1 P1: previous "check then
# write after emit" pattern allowed N parallel fires to all emit.)
SHOULD_EMIT_BASELINE=1
BASELINE_SENTINEL=""
if [ -n "$SESSION_ID" ]; then
    BASELINE_CACHE_DIR="${SDLC_WIZARD_CACHE_DIR:-$HOME/.cache/sdlc-wizard}"
    # Strip path-traversal chars from session_id before using in filename
    # (defense-in-depth — CC session_ids are UUIDs, but never trust stdin).
    SAFE_SID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9._-')
    if [ -n "$SAFE_SID" ]; then
        BASELINE_SENTINEL="$BASELINE_CACHE_DIR/baseline-shown-${SAFE_SID}"
        mkdir -p "$BASELINE_CACHE_DIR" 2>/dev/null || true
        # Atomic create-or-fail: subshell sets noclobber so `: > "$path"`
        # fails (rc≠0) if the file already exists. The full conditional
        # tree:
        #   - claim succeeds → emit (we won the race)
        #   - claim fails AND file exists → suppress (someone else won)
        #   - claim fails AND file doesn't exist → cache unwritable;
        #     fall back to emit so user never loses cold-start nudge.
        if (set -C; : > "$BASELINE_SENTINEL") 2>/dev/null; then
            SHOULD_EMIT_BASELINE=1
        elif [ -f "$BASELINE_SENTINEL" ]; then
            SHOULD_EMIT_BASELINE=0
        else
            SHOULD_EMIT_BASELINE=1
        fi
    fi
fi

if [ "$SHOULD_EMIT_BASELINE" -eq 1 ]; then
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
    # Prune sentinels older than 7d so cache doesn't grow forever.
    # Best-effort: errors silently swallowed.
    if [ -n "$BASELINE_SENTINEL" ]; then
        find "$BASELINE_CACHE_DIR" -name 'baseline-shown-*' -type f -mtime +7 -delete 2>/dev/null || true
    fi
fi
