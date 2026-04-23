#!/bin/bash
# PreCompact hook - block manual /compact at non-seam boundaries
# Fires on manual /compact only (auto-compact is threshold-driven; blocking
# it could push past 100% context and lose everything). Matcher: "manual"
# in .claude/settings.json.
#
# Requires Claude Code v2.1.105+ (PreCompact event introduced April 13, 2026).
#
# Seam policy: compacting mid-cycle loses evidence the next round needs.
# Block when:
#   (1) .reviews/handoff.json status is PENDING_REVIEW or PENDING_RECHECK
#       → mid-Codex-round, compact after CERTIFIED
#   (2) git rebase/merge/cherry-pick in progress
#       → finish in-progress git operation first
# Allow otherwise.

[ ! -t 0 ] && INPUT=$(cat) || INPUT=""

# Determine project root: prefer $CLAUDE_PROJECT_DIR, fall back to cwd
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

HOLD_REASONS=""

# Check 1: Codex review mid-cycle
# Self-heal paths (ordered by preference):
#   (a) #209: handoff has pr_number + gh reports PR MERGED → implicit CERTIFIED (silent)
#   (b) #229: handoff has no pr_number but mtime > SDLC_HANDOFF_STALE_DAYS days
#       → implicit CERTIFIED with WARN (the handoff predates #209 or was never
#       PR-linked; blocking forever over a forgotten artifact is worse UX than
#       the bug we're preventing). Default threshold: 14 days.
HANDOFF="$ROOT/.reviews/handoff.json"
STALE_DAYS="${SDLC_HANDOFF_STALE_DAYS:-14}"
STALE_WARN=""
if [ -f "$HANDOFF" ]; then
    STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$HANDOFF" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    case "$STATUS" in
        PENDING_REVIEW|PENDING_RECHECK)
            PR_NUMBER=$(grep -o '"pr_number"[[:space:]]*:[[:space:]]*[0-9][0-9]*' "$HANDOFF" 2>/dev/null | head -1 | grep -o '[0-9][0-9]*$')
            HEALED=0
            if [ -n "$PR_NUMBER" ]; then
                # Path (a): PR-linked self-heal (#209). Applies regardless of mtime —
                # an OPEN PR with old mtime is still a live review.
                if command -v gh >/dev/null 2>&1; then
                    PR_STATE=$(gh pr view "$PR_NUMBER" --json state --jq .state 2>/dev/null)
                    [ "$PR_STATE" = "MERGED" ] && HEALED=1
                fi
            else
                # Path (b): stale-handoff auto-expire (#229). Only when no pr_number
                # — we must not short-circuit PR-linked reviews.
                MTIME=$(stat -f %m "$HANDOFF" 2>/dev/null || stat -c %Y "$HANDOFF" 2>/dev/null)
                if [ -n "$MTIME" ]; then
                    NOW=$(date +%s)
                    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
                    if [ "$AGE_DAYS" -ge "$STALE_DAYS" ]; then
                        HEALED=1
                        STALE_WARN="WARN: handoff.json is ${STATUS} and ${AGE_DAYS}d old with no pr_number — treating as stale CERTIFIED (override: set SDLC_HANDOFF_STALE_DAYS or close out the review)."
                    fi
                fi
            fi
            if [ "$HEALED" -ne 1 ]; then
                HOLD_REASONS="${HOLD_REASONS}  - Codex review is ${STATUS}. Round-1 evidence lives in this context — compacting now loses what round-2 needs to re-verify.
    Resolve: wait for CERTIFIED (or escalate) before /compact."$'\n'
            fi
            ;;
    esac
fi

# Check 2: in-progress git operation
GITDIR="$ROOT/.git"
if [ -d "$GITDIR" ]; then
    if [ -e "$GITDIR/REBASE_HEAD" ] || [ -d "$GITDIR/rebase-merge" ] || [ -d "$GITDIR/rebase-apply" ]; then
        HOLD_REASONS="${HOLD_REASONS}  - Git rebase in progress. Compacting mid-rebase loses the operation's context.
    Resolve: finish or abort the rebase before /compact."$'\n'
    fi
    if [ -e "$GITDIR/MERGE_HEAD" ]; then
        HOLD_REASONS="${HOLD_REASONS}  - Git merge in progress. Compacting mid-merge loses the operation's context.
    Resolve: finish or abort the merge before /compact."$'\n'
    fi
    if [ -e "$GITDIR/CHERRY_PICK_HEAD" ]; then
        HOLD_REASONS="${HOLD_REASONS}  - Git cherry-pick in progress. Compacting mid-cherry-pick loses the operation's context.
    Resolve: finish or abort the cherry-pick before /compact."$'\n'
    fi
fi

if [ -n "$HOLD_REASONS" ]; then
    {
        echo "HOLD: manual /compact at a non-seam. Compacting mid-cycle loses evidence the next round needs."
        echo ""
        echo "$HOLD_REASONS"
        echo "Natural seams: commit boundary, Codex CERTIFIED, PR merge, ROADMAP item DONE."
        echo "Override: resolve the blocker above, or temporarily disable this hook in .claude/settings.json."
    } >&2
    exit 2
fi

# Stale-handoff unblock: emit a one-line WARN so the user knows the hook
# self-healed over an abandoned PENDING artifact (but still allow /compact).
[ -n "$STALE_WARN" ] && echo "$STALE_WARN" >&2
exit 0
