#!/bin/bash
# Persist E2E score-history append to the PR branch.
#
# Extracted from .github/workflows/ci.yml ("Persist scores to PR branch"
# steps) so it's testable in isolation and so the fetch-rebase-retry
# logic lives in one place.
#
# Root cause this guards against (observed 2026-04-18 on PR #194):
#   actions/checkout@v4 on pull_request events checks out
#   refs/pull/N/merge (a detached HEAD). The step then tries to
#   `git push origin HEAD:refs/heads/<branch>`. When the remote branch
#   has advanced during CI (concurrent score push, rebase, etc.), this
#   push is rejected as non-fast-forward and the score append is lost.
#   `continue-on-error: true` on the step masks the failure entirely.
#
# This script fetches the remote branch, rebases the local score commit
# onto it, and retries. If the rebase is impossible (true conflict on
# score-history.jsonl — both sides appended different data), it falls
# back to taking the remote then re-appending, since score-history.jsonl
# is append-only and any two appends are independent data points.
#
# Usage:
#   persist-score-history.sh <pr-head-ref> <history-file>
#
# Exits 0 on success or legitimate no-op. Exits non-zero only on
# invalid input or unexpected git failures after all recovery attempts.

set -uo pipefail

PR_HEAD_REF="${1:-}"
HISTORY_FILE="${2:-}"
REMOTE="${PERSIST_REMOTE:-origin}"
MAX_RETRIES="${PERSIST_MAX_RETRIES:-3}"

if [ -z "$PR_HEAD_REF" ] || [ -z "$HISTORY_FILE" ]; then
    echo "usage: $0 <pr-head-ref> <history-file>" >&2
    exit 2
fi

if [ ! -f "$HISTORY_FILE" ]; then
    echo "history file not found: $HISTORY_FILE" >&2
    exit 2
fi

git config user.name 'github-actions[bot]'
git config user.email 'github-actions[bot]@users.noreply.github.com'

git add "$HISTORY_FILE"

if git diff --staged --quiet; then
    echo "score-history unchanged; nothing to persist"
    exit 0
fi

# Stash the new append so we can rebase on top of a fresh fetch.
NEW_ENTRIES=$(git diff --staged "$HISTORY_FILE" | grep -E '^\+[^+]' | sed 's/^+//')
if [ -z "$NEW_ENTRIES" ]; then
    echo "no new score entries in staged diff; treating as no-op"
    git reset -q HEAD "$HISTORY_FILE"
    exit 0
fi

git commit -q -m "chore: record E2E score [skip ci]"

PUSH_ERR=$(mktemp -t persist-push-err.XXXXXX)
trap 'rm -f "$PUSH_ERR"' EXIT

attempt=1
while [ "$attempt" -le "$MAX_RETRIES" ]; do
    if git push "$REMOTE" HEAD:refs/heads/"$PR_HEAD_REF" 2>"$PUSH_ERR"; then
        echo "score persisted to $PR_HEAD_REF on attempt $attempt"
        exit 0
    fi

    # Match only non-fast-forward markers. Bare "rejected" also covers
    # pre-receive / branch-protection rejections which are NOT recoverable
    # by rebase and must NOT be retried.
    if ! grep -qE '\(fetch first\)|\(non-fast-forward\)' "$PUSH_ERR"; then
        echo "push failed with non-race error (not a non-fast-forward):" >&2
        cat "$PUSH_ERR" >&2
        exit 1
    fi

    echo "push rejected (non-fast-forward) on attempt $attempt; rebasing onto remote $PR_HEAD_REF"
    git fetch -q "$REMOTE" "$PR_HEAD_REF"

    # Try a plain rebase first. score-history.jsonl is append-only so
    # in nearly all cases this is a clean fast-forward of the local
    # commit on top of the remote head.
    if git rebase -q FETCH_HEAD; then
        attempt=$((attempt + 1))
        # Small jitter to reduce thundering-herd with concurrent CI runs.
        if [ "$attempt" -le "$MAX_RETRIES" ]; then sleep $((RANDOM % 2 + 1)); fi
        continue
    fi

    # Rebase conflicted — both sides appended different lines. Resolve
    # by concatenating: remote content first, our new entries last.
    git rebase --abort > /dev/null 2>&1 || true
    git reset --hard FETCH_HEAD > /dev/null
    printf '%s\n' "$NEW_ENTRIES" >> "$HISTORY_FILE"
    git add "$HISTORY_FILE"
    git commit -q -m "chore: record E2E score [skip ci]"
    attempt=$((attempt + 1))
    if [ "$attempt" -le "$MAX_RETRIES" ]; then sleep $((RANDOM % 2 + 1)); fi
done

echo "persist failed after $MAX_RETRIES attempts" >&2
cat "$PUSH_ERR" >&2 2>/dev/null || true
exit 1
