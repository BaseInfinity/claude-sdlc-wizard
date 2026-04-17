#!/bin/bash
# Persist the last-checked API date back to the repo.
#
# Extracted from .github/workflows/weekly-api-update.yml so it's testable
# in isolation. The non-blocking `git push` is load-bearing: branch
# protection on main rejects direct pushes, but the tracking issue we
# opened upstream is idempotent (single issue per label, edited in place),
# so a rejected push is safe to retry next cron tick.
#
# Usage:
#   persist-api-state.sh <state-file> <iso-date>
#
# Exits 0 on success AND when `git push` is rejected (by design).
# Exits non-zero only on invalid input or unexpected git failures.

set -euo pipefail

STATE_FILE="${1:-}"
LATEST_DATE="${2:-}"

if [ -z "$STATE_FILE" ] || [ -z "$LATEST_DATE" ]; then
    echo "usage: $0 <state-file> <iso-date>" >&2
    exit 2
fi

if ! [[ "$LATEST_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "invalid iso-date: $LATEST_DATE (expected YYYY-MM-DD)" >&2
    exit 2
fi

echo "$LATEST_DATE" > "$STATE_FILE"

if git diff --quiet "$STATE_FILE"; then
    echo "state file unchanged"
    exit 0
fi

git config user.name 'github-actions[bot]'
git config user.email 'github-actions[bot]@users.noreply.github.com'
git add "$STATE_FILE"
git commit -m "chore: bump last-checked API date to $LATEST_DATE"

# Non-blocking: branch protection may reject direct push to main.
# Issue-level idempotency keeps the workflow safe to retry.
git push || echo "::warning::state push rejected (branch protection?); issue-level idempotency keeps workflow safe to retry"
