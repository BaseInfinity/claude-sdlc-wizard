#!/bin/bash
# Tests for ROADMAP #212: tests/e2e/local-shepherd.sh
#
# The local shepherd runs an E2E simulation on the user's Max subscription
# (via `claude --print`) instead of paying Anthropic API. Produces the same
# scoring output CI would produce, plus provenance fields so local and CI
# rows in score-history.jsonl are distinguishable.
#
# Tests are fully mocked: no real `claude`, `gh`, or `curl` calls.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHEPHERD="$REPO_ROOT/tests/e2e/local-shepherd.sh"

PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

echo "=== local-shepherd.sh Tests (ROADMAP #212) ==="
echo ""

# ---- Mocks ----
# Writes a mock `gh` to $1/gh. Subcommands:
#   pr view N --json headRepository.isFork --jq .isFork → prints $2 (true|false)
#   pr view N --json author --jq .author.login → prints "stefanayala"
#   api repos/.../check-runs → prints mock response + logs invocation
#   pr comment N --body-file X → prints mock response + logs invocation
_mock_gh() {
    local bindir="$1" is_fork="$2" log_file="${3:-/dev/null}"
    mkdir -p "$bindir"
    cat > "$bindir/gh" <<EOF
#!/bin/bash
echo "gh \$*" >> "$log_file"
case "\$1 \$2" in
    "pr view")
        # Parse --json/--jq to decide what to emit
        case "\$*" in
            *isFork*) echo "$is_fork" ;;
            *login*) echo "stefanayala" ;;
            *title*) echo "Test PR title" ;;
            *headRefName*) echo "test-branch" ;;
            *) echo "{}" ;;
        esac
        ;;
    "api repos"*|"api /repos"*)
        # Check-run POST
        echo '{"id": 12345, "status": "completed"}'
        ;;
    "pr comment")
        echo "Comment posted"
        ;;
    *)
        echo "{}"
        ;;
esac
EOF
    chmod +x "$bindir/gh"
}

# Writes a mock `claude` that records its args + writes a fake JSON transcript
_mock_claude() {
    local bindir="$1" log_file="${2:-/dev/null}"
    mkdir -p "$bindir"
    cat > "$bindir/claude" <<EOF
#!/bin/bash
echo "claude \$*" >> "$log_file"
# Emit a minimal-but-valid JSON envelope matching claude --output-format json shape.
# Contains keywords that evaluate.sh's deterministic grep looks for: TodoWrite,
# HIGH, tests/foo.test.js — so scoring can run end-to-end without a real sim.
cat <<JSON
{
  "type": "result",
  "session_id": "mock-session-id",
  "result": "TodoWrite: planned. Confidence: HIGH. Wrote tests/app.test.js first (TDD RED), then src/app.js (GREEN). All tests pass.",
  "total_cost_usd": 0,
  "num_turns": 3
}
JSON
EOF
    chmod +x "$bindir/claude"
}

# Writes a mock `curl` that returns a fake evaluator response
_mock_curl() {
    local bindir="$1"
    mkdir -p "$bindir"
    cat > "$bindir/curl" <<'EOF'
#!/bin/bash
# Mock Anthropic API evaluator — always says criterion met.
echo '{"content":[{"text":"{\"met\":true,\"evidence\":\"mock evidence\"}"}]}'
EOF
    chmod +x "$bindir/curl"
}

# ---- Tests ----

test_shepherd_script_exists() {
    if [ -x "$SHEPHERD" ]; then
        pass "local-shepherd.sh exists and is executable"
    else
        fail "local-shepherd.sh missing or not executable at $SHEPHERD"
    fi
}

test_shepherd_usage_on_no_args() {
    local rc=0 out
    out=$("$SHEPHERD" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE 'usage|pr.*number|argument'; then
        pass "shepherd prints usage and exits non-zero without args"
    else
        fail "shepherd should usage-error on no args (rc=$rc, out='$out')"
    fi
}

test_shepherd_aborts_on_fork_pr() {
    local tmpdir bindir log_file
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    log_file="$tmpdir/gh.log"
    _mock_gh "$bindir" "true" "$log_file"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    local rc=0 out
    out=$(PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 999 2>&1) || rc=$?
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "fork"; then
        pass "shepherd aborts on fork PR (rc=$rc, mentions 'fork')"
    else
        fail "shepherd must abort on fork PR (rc=$rc, out='$out')"
    fi
}

test_shepherd_aborts_on_missing_api_key() {
    local tmpdir bindir
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    # Evaluator needs API key; shepherd should refuse without it.
    local rc=0 out
    out=$(PATH="$bindir:$PATH" ANTHROPIC_API_KEY="" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 2>&1) || rc=$?
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE 'api.*key|anthropic_api_key'; then
        pass "shepherd aborts without ANTHROPIC_API_KEY (evaluator dep)"
    else
        fail "shepherd must require api key for evaluator (rc=$rc, out='$out')"
    fi
}

test_shepherd_calls_claude_with_parity_flags() {
    # The reason #212 exists: swap the API runner for a local one that produces
    # parity output. Verify the local runner invokes `claude` with flags that
    # match CI's claude-code-action@v1 config: model pin, max-turns 55, allowed
    # tools, JSON output format. Anything missing = silent score drift risk.
    local tmpdir bindir claude_log
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    claude_log="$tmpdir/claude.log"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_claude "$bindir" "$claude_log"
    _mock_curl "$bindir"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    local invocation
    invocation=$(cat "$claude_log" 2>/dev/null)
    rm -rf "$tmpdir"
    # Must have ALL parity flags:
    if echo "$invocation" | grep -q -- '--max-turns 55' && \
       echo "$invocation" | grep -q -- '--allowedTools' && \
       echo "$invocation" | grep -q -- '--model claude-opus-4-7' && \
       echo "$invocation" | grep -q -- '--output-format json'; then
        pass "shepherd invokes claude with parity flags (--max-turns 55, --allowedTools, --model, --output-format json)"
    else
        fail "claude invocation missing parity flags. Got: '$invocation'"
    fi
}

test_shepherd_appends_score_history_with_provenance() {
    # Codex P1 #5 (review of #212 plan): local and CI rows must be
    # distinguishable in score-history.jsonl so mixed data doesn't poison
    # CUSUM/trend analytics. Provenance fields: execution_path, host_os,
    # cli_version, claude_code_version, auth_mode, pr_number.
    local tmpdir bindir history_file
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    history_file="$tmpdir/score-history.jsonl"
    touch "$history_file"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_HISTORY_FILE="$history_file" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    local new_line missing
    new_line=$(tail -1 "$history_file" 2>/dev/null)
    missing=""
    for field in execution_path host_os claude_code_version auth_mode pr_number; do
        if ! echo "$new_line" | grep -q "\"$field\""; then
            missing="$missing $field"
        fi
    done
    rm -rf "$tmpdir"
    if [ -z "$missing" ] && echo "$new_line" | grep -q '"execution_path":"local-max"'; then
        pass "shepherd appends score-history with all provenance fields + execution_path=local-max"
    else
        fail "score-history entry missing provenance fields:$missing. Line: '$new_line'"
    fi
}

test_shepherd_posts_check_run() {
    # Shepherd posts a GitHub check-run via `gh api` so the result is visible
    # on the PR alongside the CI's check-runs. Codex P1 #4: sticky comments
    # are insufficient; branch protection only satisfies on real check-runs.
    local tmpdir bindir gh_log
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    gh_log="$tmpdir/gh.log"
    _mock_gh "$bindir" "false" "$gh_log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    # grep -c exits 1 on no-match AND prints 0; use pipe-to-wc for single clean integer.
    local posted
    posted=$(grep 'api.*check-runs' "$gh_log" 2>/dev/null | wc -l | tr -d ' ')
    rm -rf "$tmpdir"
    if [ "${posted:-0}" -ge 1 ]; then
        pass "shepherd posts a check-run via gh api"
    else
        fail "shepherd must POST to /repos/OWNER/REPO/check-runs (gh.log grep count: $posted)"
    fi
}

test_shepherd_dry_run_skips_side_effects() {
    # SDLC_LOCAL_SHEPHERD_DRY_RUN=1 lets users inspect the invocation and
    # final score WITHOUT posting check-runs or PR comments. Useful for the
    # first few manual runs to trust the shepherd before wiring into workflow.
    local tmpdir bindir gh_log
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    gh_log="$tmpdir/gh.log"
    _mock_gh "$bindir" "false" "$gh_log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    # In dry-run: no check-run POST, no pr comment (allowed: pr view for fork check)
    local posted_checkrun commented
    posted_checkrun=$(grep 'api.*check-runs' "$gh_log" 2>/dev/null | wc -l | tr -d ' ')
    commented=$(grep '^gh pr comment' "$gh_log" 2>/dev/null | wc -l | tr -d ' ')
    rm -rf "$tmpdir"
    if [ "${posted_checkrun:-0}" -eq 0 ] && [ "${commented:-0}" -eq 0 ]; then
        pass "shepherd dry-run skips check-run POST and PR comment"
    else
        fail "dry-run should skip side effects (check-runs:$posted_checkrun, comments:$commented)"
    fi
}

# ---- Test run ----
test_shepherd_script_exists
test_shepherd_usage_on_no_args
test_shepherd_aborts_on_fork_pr
test_shepherd_aborts_on_missing_api_key
test_shepherd_calls_claude_with_parity_flags
test_shepherd_appends_score_history_with_provenance
test_shepherd_posts_check_run
test_shepherd_dry_run_skips_side_effects

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

[ "$FAILED" -gt 0 ] && exit 1
exit 0
