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
HANDOFF="$ROOT/.reviews/handoff.json"
if [ -f "$HANDOFF" ]; then
    STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$HANDOFF" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    case "$STATUS" in
        PENDING_REVIEW|PENDING_RECHECK)
            HOLD_REASONS="${HOLD_REASONS}  - Codex review is ${STATUS}. Round-1 evidence lives in this context — compacting now loses what round-2 needs to re-verify.
    Resolve: wait for CERTIFIED (or escalate) before /compact."$'\n'
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

exit 0
