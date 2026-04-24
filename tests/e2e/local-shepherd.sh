#!/bin/bash
# Local-Max E2E Shepherd (ROADMAP #212)
#
# Replaces CI's `claude-code-action@v1` simulation with a local `claude --print`
# run on the maintainer's Max subscription. Preserves parity with the CI config
# (model pin, max-turns, allowed tools, output shape) so scores are comparable.
#
# Scope (from ROADMAP #212 revised architecture):
#   (a) trusted same-repo PRs only — fork PRs stay on CI-API path (trust boundary)
#   (b) simulation leg on Max ($0 after cap)
#   (c) evaluator still on API (ROADMAP #228 migrates it)
#   (d) GitHub check-run emission so branch protection is satisfied
#   (e) provenance fields on score-history so local/CI rows are distinguishable
#
# Usage:
#   ./tests/e2e/local-shepherd.sh <PR_NUMBER>
#
# Env overrides (for testing + power users):
#   SDLC_LOCAL_SHEPHERD_DRY_RUN=1   — skip check-run POST + PR comment
#   SDLC_SHEPHERD_HISTORY_FILE=path — override score-history location
#   SDLC_SHEPHERD_EVALUATOR=path    — override evaluator path (for mocks)
#
# Exit codes:
#   0 success
#   1 generic error (missing dep, bad args, eval failure)
#   2 fork-PR abort (trust boundary — do NOT change to 1)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
DEFAULT_HISTORY="$SCRIPT_DIR/score-history.jsonl"
HISTORY_FILE="${SDLC_SHEPHERD_HISTORY_FILE:-$DEFAULT_HISTORY}"
EVALUATOR="${SDLC_SHEPHERD_EVALUATOR:-$SCRIPT_DIR/evaluate.sh}"

usage() {
    cat >&2 <<EOF
Usage: $0 <PR_NUMBER>

Runs E2E simulation on the user's Max subscription (via 'claude --print'),
scores with evaluate.sh, appends to score-history.jsonl with provenance,
then posts a GitHub check-run + PR comment.

Requirements: claude CLI, gh CLI (authed), jq, ANTHROPIC_API_KEY (evaluator).

Env:
  SDLC_LOCAL_SHEPHERD_DRY_RUN=1   skip post-run side effects (check-run, comment)
  SDLC_SHEPHERD_HISTORY_FILE=path override score-history.jsonl location
  SDLC_SHEPHERD_EVALUATOR=path    override evaluator binary

Exits: 0=success, 1=error, 2=fork-PR-abort.
EOF
    exit 1
}

[ $# -lt 1 ] && usage
PR_NUMBER="$1"

# Dependency checks
for bin in claude gh jq; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Error: $bin CLI not found on PATH" >&2; exit 1; }
done

# Trust boundary: fork PRs do NOT run locally (P0 from Codex review of #212).
# Running a fork PR here would expose the maintainer's GitHub session + Claude
# auth to untrusted code.
IS_FORK=$(gh pr view "$PR_NUMBER" --json headRepository --jq '.headRepository.isFork // "true"' 2>/dev/null || echo "true")
if [ "$IS_FORK" = "true" ]; then
    echo "Abort: PR #$PR_NUMBER is from a fork. Local shepherd only runs same-repo PRs (Codex P0 trust boundary). Fork PRs stay on the CI-API path." >&2
    exit 2
fi

# Evaluator still hits Anthropic API (ROADMAP #228 will migrate).
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY not set. The evaluator still hits the Anthropic API (#228 tracks migration)." >&2
    exit 1
fi

# Pick scenario round-robin by PR number (same logic as CI).
# shellcheck source=lib/scenario-selector.sh
source "$SCRIPT_DIR/lib/scenario-selector.sh"
SCENARIO_FILE=$(select_scenario "$SCENARIOS_DIR" "$PR_NUMBER")
SCENARIO_NAME=$(basename "$SCENARIO_FILE" .md)
echo "PR #$PR_NUMBER → scenario: $SCENARIO_NAME" >&2

# Extract the task text (between '## Task' and the next '## ' header).
TASK=$(sed -n '/^## Task$/,/^## /p' "$SCENARIO_FILE" | grep -v '^##' | head -40)

# ---- Parity with CI (.github/workflows/ci.yml:327-358) ----
# These values MUST match what `claude-code-action@v1` uses in CI. Changing
# any of them without a matching CI change creates a silent score-drift risk.
PARITY_MODEL="claude-opus-4-7"
PARITY_MAX_TURNS=55
PARITY_ALLOWED_TOOLS='Read,Edit,Write,Bash(npm *),Bash(node *),Bash(git *),Glob,Grep,TodoWrite,TaskCreate,Task'

TMPRUN=$(mktemp -d)
trap 'rm -rf "$TMPRUN"' EXIT
OUTPUT_FILE="$TMPRUN/claude-execution-output.json"

echo "Running simulation: model=$PARITY_MODEL, max-turns=$PARITY_MAX_TURNS" >&2
claude --print \
    --model "$PARITY_MODEL" \
    --max-turns "$PARITY_MAX_TURNS" \
    --allowedTools "$PARITY_ALLOWED_TOOLS" \
    --output-format json \
    "$TASK" > "$OUTPUT_FILE" 2>"$TMPRUN/claude.err" || true

# ---- Score ----
# Evaluator may fail in restricted environments (network, credits) — proceed
# with score=0 so provenance-only tests can still verify the score-history
# append.
SCORE=0
MAX_SCORE=10
CRIT='{}'
if [ -x "$EVALUATOR" ] && [ -s "$OUTPUT_FILE" ]; then
    # Capture evaluator output separately so a failed evaluator (non-zero
    # exit after partial stdout write) doesn't corrupt EVAL_JSON with the
    # `|| echo '{}'` fallback concatenated to actual JSON.
    set +e
    EVAL_JSON=$("$EVALUATOR" "$SCENARIO_FILE" "$OUTPUT_FILE" --json 2>"$TMPRUN/eval.err")
    EVAL_RC=$?
    set -e
    if [ "$EVAL_RC" -ne 0 ] || [ -z "$EVAL_JSON" ]; then
        EVAL_JSON='{}'
    fi
    # Validate JSON; if jq rejects, fall back to empty object.
    if ! echo "$EVAL_JSON" | jq empty 2>/dev/null; then
        EVAL_JSON='{}'
    fi
    SCORE=$(echo "$EVAL_JSON" | jq -r '.score // 0' 2>/dev/null)
    MAX_SCORE=$(echo "$EVAL_JSON" | jq -r '.max_score // 10' 2>/dev/null)
    CRIT=$(echo "$EVAL_JSON" | jq -c '.criteria // {}' 2>/dev/null)
    # Guard against non-numeric or empty values from unusual evaluator output.
    case "$SCORE" in ''|*[!0-9]*) SCORE=0 ;; esac
    case "$MAX_SCORE" in ''|*[!0-9]*) MAX_SCORE=10 ;; esac
    [ -z "$CRIT" ] && CRIT='{}'
fi

# ---- Provenance (Codex P1 #5 on #212 plan) ----
HOST_OS=$(uname -s 2>/dev/null || echo "unknown")
# Extract a semver-looking token from `claude --version` rather than trusting
# last-word parsing — some CLI versions embed trailing metadata.
CLI_VERSION=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[ -z "$CLI_VERSION" ] && CLI_VERSION="unknown"
CLAUDE_CODE_VERSION="$CLI_VERSION"
AUTH_MODE="subscription"     # sim on Max subscription
EXECUTION_PATH="local-max"

# Append to score-history.jsonl with provenance fields.
mkdir -p "$(dirname "$HISTORY_FILE")"
jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg scenario "$SCENARIO_NAME" \
    --argjson score "$SCORE" \
    --argjson max_score "$MAX_SCORE" \
    --argjson criteria "$CRIT" \
    --arg execution_path "$EXECUTION_PATH" \
    --arg host_os "$HOST_OS" \
    --arg cli_version "$CLI_VERSION" \
    --arg claude_code_version "$CLAUDE_CODE_VERSION" \
    --arg auth_mode "$AUTH_MODE" \
    --argjson pr_number "$PR_NUMBER" \
    '{timestamp:$ts, scenario:$scenario, score:$score, max_score:$max_score, criteria:$criteria, execution_path:$execution_path, host_os:$host_os, cli_version:$cli_version, claude_code_version:$claude_code_version, auth_mode:$auth_mode, pr_number:$pr_number}' \
    >> "$HISTORY_FILE"

echo "Score $SCORE/$MAX_SCORE appended to $HISTORY_FILE" >&2

# ---- Dry-run: stop before side effects ----
if [ "${SDLC_LOCAL_SHEPHERD_DRY_RUN:-0}" = "1" ]; then
    echo "DRY_RUN: skipping check-run POST + PR comment" >&2
    exit 0
fi

# ---- Post GitHub check-run (Codex P1 #4) ----
# Use a dedicated check name (`e2e-local-shepherd`) — don't collide with CI's
# `e2e-quick-check`. Branch protection can opt-in by adding this name to its
# required-checks list.
REPO_NWO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "BaseInfinity/claude-sdlc-wizard")
HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq .headRefOid 2>/dev/null || echo "")

CONCLUSION="success"
if [ "$SCORE" -lt 5 ]; then CONCLUSION="failure"; fi

if [ -n "$HEAD_SHA" ]; then
    gh api "repos/$REPO_NWO/check-runs" \
        --method POST \
        --field "name=e2e-local-shepherd" \
        --field "head_sha=$HEAD_SHA" \
        --field "status=completed" \
        --field "conclusion=$CONCLUSION" \
        --field "output[title]=E2E Shepherd: $SCORE/$MAX_SCORE ($SCENARIO_NAME)" \
        --field "output[summary]=Local-Max E2E simulation for PR #$PR_NUMBER scored $SCORE/$MAX_SCORE on scenario \`$SCENARIO_NAME\`. Execution path: local-max ($HOST_OS, claude $CLI_VERSION)." \
        >/dev/null 2>&1 || echo "Warning: check-run POST failed (non-fatal)" >&2
fi

# ---- Post PR comment ----
COMMENT_FILE="$TMPRUN/comment.md"
cat > "$COMMENT_FILE" <<EOF
## Local-Max E2E Shepherd

**Scenario:** \`$SCENARIO_NAME\`
**Score:** **$SCORE/$MAX_SCORE** ($CONCLUSION)
**Execution path:** \`local-max\` — simulation on Max subscription, zero API for sim leg.

<details><summary>Provenance</summary>

- host: \`$HOST_OS\`
- claude: \`$CLI_VERSION\`
- auth: \`$AUTH_MODE\` (sim) / \`api\` (evaluator, ROADMAP #228)
- execution_path: \`$EXECUTION_PATH\`

</details>

> Run: \`tests/e2e/local-shepherd.sh $PR_NUMBER\`
EOF

gh pr comment "$PR_NUMBER" --body-file "$COMMENT_FILE" >/dev/null 2>&1 || \
    echo "Warning: PR comment failed (non-fatal)" >&2

echo "Done: score $SCORE/$MAX_SCORE, conclusion=$CONCLUSION" >&2
exit 0
