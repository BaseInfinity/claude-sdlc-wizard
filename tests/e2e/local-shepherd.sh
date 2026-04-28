#!/bin/bash
# Local-Max E2E Shepherd (ROADMAP #212, #230)
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
# ROADMAP #230 — `--compare-baseline` flag:
#   Runs the same scenario on main (via git worktree) AND the current branch,
#   computes the score delta, posts a comparison check-run + PR comment.
#   Unblocks #231 Phase 2 (weekly-update migration). Uses the same scenario
#   for both runs (delta is meaningful only with apples-to-apples comparison).
#
# Usage:
#   ./tests/e2e/local-shepherd.sh <PR_NUMBER>
#   ./tests/e2e/local-shepherd.sh <PR_NUMBER> --compare-baseline
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
Usage: $0 <PR_NUMBER> [--compare-baseline]

Runs E2E simulation on the user's Max subscription (via 'claude --print'),
scores with evaluate.sh, appends to score-history.jsonl with provenance,
then posts a GitHub check-run + PR comment.

Flags:
  --compare-baseline    Also run on main (via git worktree) and post the
                        score delta. Same scenario for both runs.

Requirements: claude CLI, gh CLI (authed), jq, ANTHROPIC_API_KEY (evaluator).

Env:
  SDLC_LOCAL_SHEPHERD_DRY_RUN=1   skip post-run side effects (check-run, comment)
  SDLC_SHEPHERD_HISTORY_FILE=path override score-history.jsonl location
  SDLC_SHEPHERD_EVALUATOR=path    override evaluator binary

Exits: 0=success, 1=error, 2=fork-PR-abort.
EOF
    exit 1
}

# Parse args: positional PR_NUMBER + optional --compare-baseline flag.
PR_NUMBER=""
COMPARE_BASELINE=0
for arg in "$@"; do
    case "$arg" in
        --compare-baseline) COMPARE_BASELINE=1 ;;
        --help|-h) usage ;;
        *)
            if [ -z "$PR_NUMBER" ]; then
                PR_NUMBER="$arg"
            fi
            ;;
    esac
done
[ -z "$PR_NUMBER" ] && usage

# Dependency checks
for bin in claude gh jq git; do
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

# HEAD-SHA verification (Codex LS-001 P0): the shepherd scores + posts a
# check-run against the PR's head SHA from GitHub. If the local worktree is
# on a different commit, we would certify the wrong code as passing. Require
# the user to check out the PR branch first (`gh pr checkout $PR`).
PR_HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq .headRefOid 2>/dev/null)
LOCAL_HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
if [ -z "$PR_HEAD_SHA" ] || [ -z "$LOCAL_HEAD_SHA" ]; then
    echo "Error: could not resolve HEAD SHAs (pr=$PR_HEAD_SHA local=$LOCAL_HEAD_SHA)" >&2
    exit 1
fi
if [ "${SDLC_SHEPHERD_SKIP_SHA_CHECK:-0}" != "1" ] && [ "$PR_HEAD_SHA" != "$LOCAL_HEAD_SHA" ]; then
    echo "Error: local HEAD ($LOCAL_HEAD_SHA) does not match PR #$PR_NUMBER head ($PR_HEAD_SHA)." >&2
    echo "       Check out the PR branch first:  gh pr checkout $PR_NUMBER" >&2
    echo "       Or set SDLC_SHEPHERD_SKIP_SHA_CHECK=1 (not recommended)." >&2
    exit 1
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

# ---- Parity with CI (.github/workflows/ci.yml:327-361) ----
# These values MUST match what `claude-code-action@v1` uses in CI. Changing
# any of them without a matching CI change creates a silent score-drift risk.
# The parity-audit test (tests/test-local-shepherd.sh) diffs these against
# the CI block to catch drift.
# Model is NOT pinned explicitly — CI relies on action default (Opus 4.7),
# so shepherd does too. If Anthropic changes the default, both paths shift
# together.
PARITY_MAX_TURNS=55
PARITY_ALLOWED_TOOLS='Read,Edit,Write,Bash(npm *),Bash(node *),Bash(git *),Glob,Grep,TodoWrite,TaskCreate,Task'

TMPRUN=$(mktemp -d)
trap 'rm -rf "$TMPRUN"' EXIT
OUTPUT_FILE="$TMPRUN/claude-execution-output.json"

# Relative scenario path, fixtures working dir — match CI prompt structure
# (pr-branch is CI artifact path; locally we use repo-root relative).
REL_SCENARIO="tests/e2e/scenarios/$SCENARIO_NAME.md"
FIXTURES_REL="tests/e2e/fixtures/test-repo"

# Full prompt — byte-equivalent to .github/workflows/ci.yml:338-361 modulo
# the pr-branch/ prefix that only exists in CI's checked-out-artifact layout.
# bash 3.2 on macOS has a heredoc-in-$() parsing bug when the body contains
# backticks (even inside a 'PROMPT'-quoted delimiter), so we write the prompt
# to a temp file line-by-line and read it back. Ugly but bash-3.2 safe.
PROMPT_FILE="$TMPRUN/parity-prompt.txt"
{
    printf '%s\n' "You are running an E2E SDLC simulation. Your goal is to complete a coding task"
    printf '%s\n' "while demonstrating proper SDLC practices."
    printf '%s\n' ""
    printf '%s\n' "Working directory: $FIXTURES_REL"
    printf '%s\n' "Scenario file: $REL_SCENARIO"
    printf '%s\n' ""
    printf '%s\n' "STEPS:"
    printf '%s\n' "1. Read the scenario file to understand the task and complexity"
    printf '%s\n' "2. Use TodoWrite or TaskCreate to track your work"
    printf '%s\n' '3. State your confidence level explicitly: "Confidence: HIGH", "Confidence: MEDIUM", or "Confidence: LOW"'
    printf '%s\n' "4. For medium/hard tasks, plan your approach before coding (outline steps in a message)"
    printf '%s\n' "5. Follow TDD: write/update tests FIRST, verify they fail, then implement"
    printf '6. Run %cnpm test%c to verify all tests pass\n' 96 96
    printf '%s\n' "7. Self-review: use Read to read back the files you modified, check for issues"
    printf '%s\n' ""
    printf '%s\n' "IMPORTANT:"
    printf '%s\n' "- You MUST use TodoWrite or TaskCreate (scored by automated checks)"
    printf '%s\n' '- You MUST state confidence as exactly "Confidence: HIGH/MEDIUM/LOW" (scored by automated checks)'
    printf '%s\n' "- Write or edit test files BEFORE implementation files (TDD RED phase is scored)"
    printf '%s\n' "- You MUST self-review by using Read on files you modified before finishing (scored by automated checks)"
    printf '%s\n' "- All files you need are in the working directory — do not search elsewhere"
    printf '%s\n' "- Be efficient with your turns — execute, don't just plan"
    printf '%s\n' "- Do NOT use EnterPlanMode or ExitPlanMode — plan inline in your messages instead"
} > "$PROMPT_FILE"
PARITY_PROMPT=$(cat "$PROMPT_FILE")

# ---- Provenance fields (computed once, reused for baseline + candidate rows) ----
HOST_OS=$(uname -s 2>/dev/null || echo "unknown")
CLI_VERSION=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[ -z "$CLI_VERSION" ] && CLI_VERSION="unknown"
CLAUDE_CODE_VERSION="$CLI_VERSION"
AUTH_MODE="subscription"
EXECUTION_PATH="local-max"

# ---- ROADMAP #230: --compare-baseline — run baseline FIRST in a main worktree ----
BASELINE_SCORE=""
BASELINE_MAX=""
if [ "$COMPARE_BASELINE" = "1" ]; then
    BASELINE_DIR=$(mktemp -d -t sdlc-baseline.XXXXXX)
    # `git worktree add` requires the path NOT to exist, so remove the empty
    # mktemp dir first. Race-window: a concurrent shepherd run could collide,
    # but that's a pathological case (two compare-baseline runs in the same
    # second) — accept the tiny window over `--force` which silently overwrites.
    rmdir "$BASELINE_DIR" 2>/dev/null || rm -rf "$BASELINE_DIR"
    # Detach so we don't lock main as a branch; --force handles a stale lock
    # left behind by a previous failed run.
    if ! git worktree add --detach --force "$BASELINE_DIR" main 2>"$TMPRUN/worktree.err"; then
        # Fallback to origin/main if the local main ref is missing.
        if ! git worktree add --detach --force "$BASELINE_DIR" origin/main 2>>"$TMPRUN/worktree.err"; then
            echo "Error: could not create main worktree (tried 'main' and 'origin/main')" >&2
            sed -n '1,5p' "$TMPRUN/worktree.err" >&2
            exit 1
        fi
    fi
    # Cleanup: prune the worktree on exit. `git worktree remove` may fail if
    # the dir was deleted out-of-band; fall back to rm + prune so subsequent
    # runs don't trip on a stale worktree entry.
    cleanup_baseline_worktree() {
        if [ -n "${BASELINE_DIR:-}" ] && [ -d "$BASELINE_DIR" ]; then
            git worktree remove --force "$BASELINE_DIR" 2>/dev/null \
                || { rm -rf "$BASELINE_DIR"; git worktree prune 2>/dev/null || true; }
        fi
    }
    # Replace the existing TMPRUN-only trap with a combined one.
    trap 'cleanup_baseline_worktree; rm -rf "$TMPRUN"' EXIT

    # Codex P1 #2: nest BASELINE_TMPRUN under TMPRUN so the existing trap
    # (which now also runs cleanup_baseline_worktree) covers it. Previously
    # mktemp -d created a sibling dir that leaked on early failures.
    BASELINE_TMPRUN="$TMPRUN/baseline"
    mkdir -p "$BASELINE_TMPRUN"
    BASELINE_OUTPUT="$BASELINE_TMPRUN/claude-execution-output.json"
    echo "Running baseline simulation in $BASELINE_DIR (main): max-turns=$PARITY_MAX_TURNS" >&2
    set +e
    ( cd "$BASELINE_DIR" && claude --print \
        --max-turns "$PARITY_MAX_TURNS" \
        --allowedTools "$PARITY_ALLOWED_TOOLS" \
        --add-dir "tests/e2e" \
        --output-format json \
        "$PARITY_PROMPT" > "$BASELINE_OUTPUT" 2>"$BASELINE_TMPRUN/claude.err" )
    BASELINE_CLAUDE_RC=$?
    set -e
    if [ "$BASELINE_CLAUDE_RC" -ne 0 ]; then
        echo "Error: baseline simulation failed (rc=$BASELINE_CLAUDE_RC)" >&2
        [ -s "$BASELINE_TMPRUN/claude.err" ] && sed -n '1,5p' "$BASELINE_TMPRUN/claude.err" >&2
        exit 1
    fi
    if [ ! -s "$BASELINE_OUTPUT" ]; then
        echo "Error: baseline simulation output empty" >&2
        exit 1
    fi
    set +e
    BASELINE_EVAL=$("$EVALUATOR" "$SCENARIO_FILE" "$BASELINE_OUTPUT" --json 2>"$BASELINE_TMPRUN/eval.err")
    BASELINE_EVAL_RC=$?
    set -e
    if [ "$BASELINE_EVAL_RC" -ne 0 ] || ! echo "$BASELINE_EVAL" | jq empty 2>/dev/null; then
        echo "Error: baseline evaluator failed (rc=$BASELINE_EVAL_RC)" >&2
        [ -s "$BASELINE_TMPRUN/eval.err" ] && sed -n '1,5p' "$BASELINE_TMPRUN/eval.err" >&2
        exit 1
    fi
    BASELINE_SCORE=$(echo "$BASELINE_EVAL" | jq -r '.score // 0')
    BASELINE_MAX=$(echo "$BASELINE_EVAL" | jq -r '.max_score // 10')
    BASELINE_CRIT=$(echo "$BASELINE_EVAL" | jq -c '.criteria // {}')
    case "$BASELINE_SCORE" in ''|*[!0-9]*) BASELINE_SCORE=0 ;; esac
    case "$BASELINE_MAX" in ''|*[!0-9]*) BASELINE_MAX=10 ;; esac
    [ -z "$BASELINE_CRIT" ] && BASELINE_CRIT='{}'

    # Codex P1 #1: do NOT append the baseline row here. Defer to after the
    # candidate sim+eval succeeds — otherwise a candidate failure leaves an
    # orphan baseline row in history with no comparison partner. Both rows
    # are written together at the end, or neither is.
    echo "Baseline score: $BASELINE_SCORE/$BASELINE_MAX (main)" >&2
fi

echo "Running simulation: max-turns=$PARITY_MAX_TURNS" >&2
# LS-002: hard-fail on claude error. Previously `|| true` swallowed failures,
# so a crashed sim still produced score=0 as if it had completed. Now a
# non-zero claude exit propagates to the shepherd's exit.
set +e
claude --print \
    --max-turns "$PARITY_MAX_TURNS" \
    --allowedTools "$PARITY_ALLOWED_TOOLS" \
    --add-dir "tests/e2e" \
    --output-format json \
    "$PARITY_PROMPT" > "$OUTPUT_FILE" 2>"$TMPRUN/claude.err"
CLAUDE_RC=$?
set -e
if [ "$CLAUDE_RC" -ne 0 ]; then
    echo "Error: claude simulation failed (rc=$CLAUDE_RC)" >&2
    [ -s "$TMPRUN/claude.err" ] && sed -n '1,5p' "$TMPRUN/claude.err" >&2
    exit 1
fi

# ---- Score (LS-002: hard-fail on evaluator error) ----
# Previously the evaluator's non-zero exit silently became score=0/10 + an
# empty criteria object, indistinguishable from a real failing simulation.
# Now evaluator failures propagate: the shepherd exits 1 and nothing is
# appended to score-history. Set SDLC_SHEPHERD_SOFT_FAIL=1 to restore the
# old permissive behavior (useful for smoke testing, not for CI).
if [ ! -x "$EVALUATOR" ]; then
    echo "Error: evaluator not executable at $EVALUATOR" >&2
    exit 1
fi
if [ ! -s "$OUTPUT_FILE" ]; then
    echo "Error: simulation output is empty — cannot evaluate" >&2
    exit 1
fi

set +e
EVAL_JSON=$("$EVALUATOR" "$SCENARIO_FILE" "$OUTPUT_FILE" --json 2>"$TMPRUN/eval.err")
EVAL_RC=$?
set -e
if [ "$EVAL_RC" -ne 0 ]; then
    if [ "${SDLC_SHEPHERD_SOFT_FAIL:-0}" = "1" ]; then
        echo "Warning: evaluator rc=$EVAL_RC — continuing in soft-fail mode" >&2
        EVAL_JSON='{}'
    else
        echo "Error: evaluator failed (rc=$EVAL_RC)" >&2
        [ -s "$TMPRUN/eval.err" ] && sed -n '1,5p' "$TMPRUN/eval.err" >&2
        exit 1
    fi
fi
# Validate JSON; if jq rejects (e.g., stdout mixed with stderr), hard-fail
# unless soft-fail is on.
if ! echo "$EVAL_JSON" | jq empty 2>/dev/null; then
    if [ "${SDLC_SHEPHERD_SOFT_FAIL:-0}" = "1" ]; then
        EVAL_JSON='{}'
    else
        echo "Error: evaluator emitted non-JSON output" >&2
        exit 1
    fi
fi
SCORE=$(echo "$EVAL_JSON" | jq -r '.score // 0' 2>/dev/null)
MAX_SCORE=$(echo "$EVAL_JSON" | jq -r '.max_score // 10' 2>/dev/null)
CRIT=$(echo "$EVAL_JSON" | jq -c '.criteria // {}' 2>/dev/null)
case "$SCORE" in ''|*[!0-9]*) SCORE=0 ;; esac
case "$MAX_SCORE" in ''|*[!0-9]*) MAX_SCORE=10 ;; esac
[ -z "$CRIT" ] && CRIT='{}'

# Provenance fields were computed once before the baseline run (see above).
# Append history rows. When --compare-baseline is set, both baseline AND
# candidate rows are written here (deferred from the baseline block per
# Codex P1 #1 — atomic so a candidate failure can't leave an orphan row).
# Single-run mode omits comparison_role for backward compat.
mkdir -p "$(dirname "$HISTORY_FILE")"
if [ "$COMPARE_BASELINE" = "1" ]; then
    # Baseline row first (deferred from baseline block).
    jq -nc \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg scenario "$SCENARIO_NAME" \
        --argjson score "$BASELINE_SCORE" \
        --argjson max_score "$BASELINE_MAX" \
        --argjson criteria "$BASELINE_CRIT" \
        --arg execution_path "$EXECUTION_PATH" \
        --arg host_os "$HOST_OS" \
        --arg cli_version "$CLI_VERSION" \
        --arg claude_code_version "$CLAUDE_CODE_VERSION" \
        --arg auth_mode "$AUTH_MODE" \
        --arg comparison_role "baseline" \
        --argjson pr_number "$PR_NUMBER" \
        '{timestamp:$ts, scenario:$scenario, score:$score, max_score:$max_score, criteria:$criteria, execution_path:$execution_path, host_os:$host_os, cli_version:$cli_version, claude_code_version:$claude_code_version, auth_mode:$auth_mode, comparison_role:$comparison_role, pr_number:$pr_number}' \
        >> "$HISTORY_FILE"
    # Candidate row second.
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
        --arg comparison_role "candidate" \
        --argjson pr_number "$PR_NUMBER" \
        '{timestamp:$ts, scenario:$scenario, score:$score, max_score:$max_score, criteria:$criteria, execution_path:$execution_path, host_os:$host_os, cli_version:$cli_version, claude_code_version:$claude_code_version, auth_mode:$auth_mode, comparison_role:$comparison_role, pr_number:$pr_number}' \
        >> "$HISTORY_FILE"
else
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
fi

echo "Score $SCORE/$MAX_SCORE appended to $HISTORY_FILE" >&2

# ---- ROADMAP #230: comparison summary (compare-baseline mode) ----
if [ "$COMPARE_BASELINE" = "1" ]; then
    DELTA=$((SCORE - BASELINE_SCORE))
    DELTA_SIGN="+"
    [ "$DELTA" -lt 0 ] && DELTA_SIGN=""
    echo "Comparison: baseline=$BASELINE_SCORE/$BASELINE_MAX, candidate=$SCORE/$MAX_SCORE, delta=${DELTA_SIGN}${DELTA}" >&2
fi

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

if [ -z "$HEAD_SHA" ]; then
    echo "Error: could not resolve PR head SHA for check-run POST" >&2
    exit 1
fi

# Build check-run + PR-comment fields. In comparison mode, both surfaces show
# baseline vs candidate vs delta — single-run mode is unchanged.
if [ "$COMPARE_BASELINE" = "1" ]; then
    CHECKRUN_TITLE="E2E Shepherd: ${SCORE}/${MAX_SCORE} vs baseline ${BASELINE_SCORE}/${BASELINE_MAX} (${DELTA_SIGN}${DELTA})"
    CHECKRUN_SUMMARY="Local-Max E2E comparison for PR #$PR_NUMBER on scenario \`$SCENARIO_NAME\`. Baseline (main): ${BASELINE_SCORE}/${BASELINE_MAX}. Candidate (PR): ${SCORE}/${MAX_SCORE}. Delta: ${DELTA_SIGN}${DELTA}. Execution path: local-max ($HOST_OS, claude $CLI_VERSION)."
else
    CHECKRUN_TITLE="E2E Shepherd: $SCORE/$MAX_SCORE ($SCENARIO_NAME)"
    CHECKRUN_SUMMARY="Local-Max E2E simulation for PR #$PR_NUMBER scored $SCORE/$MAX_SCORE on scenario \`$SCENARIO_NAME\`. Execution path: local-max ($HOST_OS, claude $CLI_VERSION)."
fi

# LS-002: check-run POST failure is hard-fail. If branch protection is
# waiting on e2e-local-shepherd, a silent warning isn't enough — we must
# surface that the gate was never satisfied. Set SDLC_SHEPHERD_SOFT_FAIL=1
# to downgrade to a warning (for debugging).
set +e
gh api "repos/$REPO_NWO/check-runs" \
    --method POST \
    --field "name=e2e-local-shepherd" \
    --field "head_sha=$HEAD_SHA" \
    --field "status=completed" \
    --field "conclusion=$CONCLUSION" \
    --field "output[title]=$CHECKRUN_TITLE" \
    --field "output[summary]=$CHECKRUN_SUMMARY" \
    >"$TMPRUN/checkrun.out" 2>"$TMPRUN/checkrun.err"
CHECKRUN_RC=$?
set -e
if [ "$CHECKRUN_RC" -ne 0 ]; then
    if [ "${SDLC_SHEPHERD_SOFT_FAIL:-0}" = "1" ]; then
        echo "Warning: check-run POST failed (rc=$CHECKRUN_RC) — continuing in soft-fail mode" >&2
    else
        echo "Error: check-run POST failed (rc=$CHECKRUN_RC)" >&2
        [ -s "$TMPRUN/checkrun.err" ] && sed -n '1,5p' "$TMPRUN/checkrun.err" >&2
        exit 1
    fi
fi

# ---- Post PR comment ----
COMMENT_FILE="$TMPRUN/comment.md"
if [ "$COMPARE_BASELINE" = "1" ]; then
    cat > "$COMMENT_FILE" <<EOF
## Local-Max E2E Shepherd — Baseline vs Candidate

**Scenario:** \`$SCENARIO_NAME\` (same scenario for both runs)
**Baseline (main):** ${BASELINE_SCORE}/${BASELINE_MAX}
**Candidate (PR):** ${SCORE}/${MAX_SCORE}
**Delta:** **${DELTA_SIGN}${DELTA}**

<details><summary>Provenance</summary>

- host: \`$HOST_OS\`
- claude: \`$CLI_VERSION\`
- auth: \`$AUTH_MODE\` (sim) / \`api\` (evaluator, ROADMAP #228)
- execution_path: \`$EXECUTION_PATH\`
- comparison_role: \`baseline\` + \`candidate\` (rows tagged in score-history.jsonl)

</details>

> One-run-per-side delta — useful as advisory signal, not statistical evidence.
> For variance-aware comparison, see ROADMAP #212 (i) Prove-It Gate (paired N=15 runs).
> Run: \`tests/e2e/local-shepherd.sh $PR_NUMBER --compare-baseline\`
EOF
else
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
fi

gh pr comment "$PR_NUMBER" --body-file "$COMMENT_FILE" >/dev/null 2>&1 || \
    echo "Warning: PR comment failed (non-fatal)" >&2

if [ "$COMPARE_BASELINE" = "1" ]; then
    echo "Done: candidate $SCORE/$MAX_SCORE, baseline $BASELINE_SCORE/$BASELINE_MAX, delta ${DELTA_SIGN}${DELTA}" >&2
else
    echo "Done: score $SCORE/$MAX_SCORE, conclusion=$CONCLUSION" >&2
fi
exit 0
