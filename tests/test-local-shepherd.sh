#!/bin/bash
# Tests for ROADMAP #212: tests/e2e/local-shepherd.sh
#
# The local shepherd runs an E2E simulation on the user's Max subscription
# (via `claude --print`) instead of paying Anthropic API. Produces the same
# scoring output CI would produce, plus provenance fields so local and CI
# rows in score-history.jsonl are distinguishable.
#
# Tests are fully mocked: no real `claude`, `gh`, or `curl` calls.
#
# NOTE: deliberately no `set -e`. Each test's capture pattern uses `|| rc=$?`
# or `|| true` so a failing shepherd invocation doesn't abort the suite.

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
#   pr view N --json headRefOid --jq .headRefOid → prints ${MOCK_PR_HEAD_SHA:-abcd1234}
#   api repos/.../check-runs → prints mock response + logs invocation
#   pr comment N --body-file X → prints mock response + logs invocation
_mock_gh() {
    local bindir="$1" is_fork="$2" log_file="${3:-/dev/null}" head_sha="${4:-abcd1234}"
    mkdir -p "$bindir"
    cat > "$bindir/gh" <<EOF
#!/bin/bash
echo "gh \$*" >> "$log_file"
case "\$1 \$2" in
    "pr view")
        case "\$*" in
            *isFork*) echo "$is_fork" ;;
            *headRefOid*) echo "$head_sha" ;;
            *login*) echo "stefanayala" ;;
            *title*) echo "Test PR title" ;;
            *headRefName*) echo "test-branch" ;;
            *) echo "{}" ;;
        esac
        ;;
    "api repos"*|"api /repos"*)
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

# Writes a mock `git` that emits a controllable HEAD SHA for `rev-parse HEAD`.
_mock_git() {
    local bindir="$1" head_sha="${2:-abcd1234}"
    mkdir -p "$bindir"
    cat > "$bindir/git" <<EOF
#!/bin/bash
case "\$1 \$2" in
    "rev-parse HEAD") echo "$head_sha" ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$bindir/git"
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
    _mock_git "$bindir"
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
    _mock_git "$bindir"
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
    _mock_git "$bindir"
    _mock_claude "$bindir" "$claude_log"
    _mock_curl "$bindir"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    local invocation
    invocation=$(cat "$claude_log" 2>/dev/null)
    rm -rf "$tmpdir"
    # Must have ALL parity flags. NOTE: no --model — CI doesn't pin it either
    # (relies on action default), so shepherd doesn't pin it. Both shift
    # together if Anthropic changes the default.
    if echo "$invocation" | grep -q -- '--max-turns 55' && \
       echo "$invocation" | grep -q -- '--allowedTools' && \
       echo "$invocation" | grep -q -- '--add-dir' && \
       echo "$invocation" | grep -q -- '--output-format json'; then
        pass "shepherd invokes claude with parity flags (--max-turns 55, --allowedTools, --add-dir, --output-format json)"
    else
        fail "claude invocation missing parity flags. Got: '$invocation'"
    fi
}

test_shepherd_appends_score_history_with_provenance() {
    # Codex P1 #5 (review of #212 plan): local and CI rows must be
    # distinguishable in score-history.jsonl so mixed data doesn't poison
    # CUSUM/trend analytics. Provenance fields: execution_path, host_os,
    # cli_version, claude_code_version, auth_mode, pr_number.
    local tmpdir bindir history_file evaluator
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    history_file="$tmpdir/score-history.jsonl"
    evaluator="$tmpdir/mock-evaluator.sh"
    touch "$history_file"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    # Mock evaluator that emits a valid score JSON — needed because the
    # shepherd now hard-fails on evaluator errors (Codex LS-002).
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":8,"max_score":10,"criteria":{"tdd_red":{"points":2}}}'
EOF
    chmod +x "$evaluator"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
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
    local tmpdir bindir gh_log evaluator
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    gh_log="$tmpdir/gh.log"
    evaluator="$tmpdir/mock-evaluator.sh"
    _mock_gh "$bindir" "false" "$gh_log"
    _mock_git "$bindir"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":8,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$evaluator"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
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
    _mock_git "$bindir"
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

# ---- Codex review fixes (PR #229 round 2) ----

test_shepherd_aborts_on_sha_mismatch() {
    # LS-001 P0: if local HEAD doesn't match PR's headRefOid, the shepherd
    # would certify arbitrary local state as if it were the PR's code. Must
    # abort with clear error unless SDLC_SHEPHERD_SKIP_SHA_CHECK=1.
    local tmpdir bindir
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    # gh returns head_sha=aaaa1111; git mocks HEAD=bbbb2222 → mismatch.
    _mock_gh "$bindir" "false" "$tmpdir/gh.log" "aaaa1111"
    _mock_git "$bindir" "bbbb2222"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    local rc=0 out
    out=$(PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 2>&1) || rc=$?
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "does not match"; then
        pass "shepherd aborts on local HEAD / PR head_sha mismatch (rc=$rc)"
    else
        fail "shepherd must refuse to run on the wrong commit (rc=$rc, out='$out')"
    fi
}

test_shepherd_exits_1_on_claude_failure() {
    # LS-002 P0: a failed sim (claude exit != 0) must propagate rc=1, not
    # silently continue with score=0/10. Distinguish from fork-abort rc=2.
    local tmpdir bindir
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir"
    mkdir -p "$bindir"
    cat > "$bindir/claude" <<'EOF'
#!/bin/bash
if [ "$1" = "--version" ]; then echo "2.1.118"; exit 0; fi
echo "simulated claude crash" >&2
exit 42
EOF
    chmod +x "$bindir/claude"
    _mock_curl "$bindir"
    local rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || rc=$?
    local history_has_entry
    history_has_entry=$([ -s "$tmpdir/score-history.jsonl" ] && echo yes || echo no)
    rm -rf "$tmpdir"
    if [ "$rc" -eq 1 ] && [ "$history_has_entry" = "no" ]; then
        pass "shepherd exits 1 and skips history append on claude failure"
    else
        fail "claude crash must fail hard (rc=$rc, history=$history_has_entry)"
    fi
}

test_shepherd_exits_1_on_evaluator_failure() {
    # LS-002 P0: evaluator failure must propagate rc=1, not downgrade to {}
    # and then score=0/10 (indistinguishable from real failing simulation).
    local tmpdir bindir
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$tmpdir/crash-evaluator.sh" <<'EOF'
#!/bin/bash
echo "evaluator blew up" >&2
exit 5
EOF
    chmod +x "$tmpdir/crash-evaluator.sh"
    local rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$tmpdir/crash-evaluator.sh" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || rc=$?
    local history_has_entry
    history_has_entry=$([ -s "$tmpdir/score-history.jsonl" ] && echo yes || echo no)
    rm -rf "$tmpdir"
    if [ "$rc" -eq 1 ] && [ "$history_has_entry" = "no" ]; then
        pass "shepherd exits 1 and skips history append on evaluator failure"
    else
        fail "evaluator crash must fail hard (rc=$rc, history=$history_has_entry)"
    fi
}

test_shepherd_exits_1_on_checkrun_failure() {
    # LS-002 P0 round 3: check-run POST failure used to be a non-fatal warning
    # that left rc=0. Codex correctly flagged this — branch protection waiting
    # on e2e-local-shepherd would never be satisfied, and the user wouldn't
    # know. Must hard-fail rc=1 on check-run error.
    local tmpdir bindir evaluator
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    evaluator="$tmpdir/mock-evaluator.sh"
    # Mock gh that fails on `api` (check-run POST) but succeeds on `pr view`.
    mkdir -p "$bindir"
    cat > "$bindir/gh" <<'EOF'
#!/bin/bash
case "$1 $2" in
    "pr view")
        case "$*" in
            *isFork*) echo "false" ;;
            *headRefOid*) echo "abcd1234" ;;
            *) echo "{}" ;;
        esac
        ;;
    "api repos"*|"api /repos"*)
        echo "HTTP 403 — mock check-run POST failure" >&2
        exit 1
        ;;
    *) echo "{}" ;;
esac
EOF
    chmod +x "$bindir/gh"
    _mock_git "$bindir"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":8,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$evaluator"
    local rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || rc=$?
    rm -rf "$tmpdir"
    if [ "$rc" -eq 1 ]; then
        pass "shepherd exits 1 on check-run POST failure (gate not satisfied)"
    else
        fail "check-run POST failure must be hard-fail (rc=$rc)"
    fi
}

test_shepherd_prompt_matches_ci_yml() {
    # LS-003 P1: shepherd's embedded prompt must be byte-compatible with CI's
    # inline prompt at .github/workflows/ci.yml:338-361. If either drifts,
    # parity is broken and scores diverge.
    local ci_file="$REPO_ROOT/.github/workflows/ci.yml"
    local miss=""
    for sig in \
        "You are running an E2E SDLC simulation" \
        "Use TodoWrite or TaskCreate to track your work" \
        "Follow TDD: write/update tests FIRST" \
        "Do NOT use EnterPlanMode or ExitPlanMode"; do
        if ! grep -qF "$sig" "$SHEPHERD"; then
            miss="$miss|missing-in-shepherd: $sig"
        fi
        if ! grep -qF "$sig" "$ci_file"; then
            miss="$miss|missing-in-ci.yml: $sig"
        fi
    done
    if ! grep -qF -- "--add-dir" "$SHEPHERD"; then miss="$miss|shepherd missing --add-dir"; fi
    if ! grep -qF -- "--add-dir pr-branch/tests/e2e" "$ci_file"; then miss="$miss|ci.yml missing --add-dir"; fi
    if [ -z "$miss" ]; then
        pass "shepherd prompt + flags match ci.yml signature lines"
    else
        fail "prompt/flag parity drift:$miss"
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
test_shepherd_aborts_on_sha_mismatch
test_shepherd_exits_1_on_claude_failure
test_shepherd_exits_1_on_evaluator_failure
test_shepherd_exits_1_on_checkrun_failure
test_shepherd_prompt_matches_ci_yml

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

[ "$FAILED" -gt 0 ] && exit 1
exit 0
