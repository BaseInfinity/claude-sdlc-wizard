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
    local bindir="$1" head_sha="${2:-abcd1234}" log_file="${3:-/dev/null}"
    mkdir -p "$bindir"
    cat > "$bindir/git" <<EOF
#!/bin/bash
echo "git \$*" >> "$log_file"
case "\$1 \$2" in
    "rev-parse HEAD") echo "$head_sha" ;;
    "worktree add")
        # Mock worktree creation: the shepherd may pushd into the path,
        # so the dir must actually exist. git worktree add format:
        #   git worktree add [<options>] <path> [<commit-ish>]
        # Path is the first non-flag positional arg AFTER 'worktree add'.
        # Walk past 'worktree' and 'add', then past flags (--detach, --force,
        # -b, --reason, etc.), then the next non-flag is <path>.
        path=""
        shift 2  # consume 'worktree' 'add'
        skip_next=0
        while [ \$# -gt 0 ]; do
            if [ "\$skip_next" = "1" ]; then skip_next=0; shift; continue; fi
            case "\$1" in
                -b|-B|--reason) skip_next=1; shift ;;
                --) shift; break ;;
                -*) shift ;;  # boolean flag
                *) path="\$1"; break ;;
            esac
        done
        if [ -n "\$path" ]; then
            mkdir -p "\$path"
            # Populate with the minimum the shepherd needs: scenarios + fixtures.
            if [ -d "$REPO_ROOT/tests/e2e/scenarios" ]; then
                mkdir -p "\$path/tests/e2e"
                cp -R "$REPO_ROOT/tests/e2e/scenarios" "\$path/tests/e2e/" 2>/dev/null
                [ -d "$REPO_ROOT/tests/e2e/fixtures" ] && cp -R "$REPO_ROOT/tests/e2e/fixtures" "\$path/tests/e2e/" 2>/dev/null
            fi
        fi
        ;;
    "worktree remove")
        # Path is first non-flag arg after 'worktree remove'.
        path=""
        shift 2
        while [ \$# -gt 0 ]; do
            case "\$1" in
                -*) shift ;;
                *) path="\$1"; break ;;
            esac
        done
        [ -n "\$path" ] && [ -d "\$path" ] && rm -rf "\$path"
        ;;
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

test_shepherd_prompt_has_required_signatures() {
    # Originally LS-003 P1 (parity with ci.yml). After ROADMAP #212 Option 1
    # removed the e2e jobs from ci.yml, parity with a deleted block is moot.
    # ROADMAP #96 Phase 1 (de-coaching): the old prompt told the agent
    # exactly what was scored ("MUST use TodoWrite (scored by automated
    # checks)" etc.) which saturated the benchmark at 10/10. The new
    # prompt is neutral task framing — the agent must practice SDLC
    # organically. Test asserts the new neutral signatures so a future
    # regression that re-introduces the cheat sheet shows up here.
    local miss=""
    for sig in \
        "You are completing a coding task" \
        "Working directory:" \
        "Scenario file:" \
        "Do NOT use EnterPlanMode or ExitPlanMode"; do
        if ! grep -qF "$sig" "$SHEPHERD"; then
            miss="$miss|missing-in-shepherd: $sig"
        fi
    done
    # Negative assertion: cheat-sheet phrases must NOT resurrect.
    for forbidden in \
        "scored by automated checks" \
        "MUST use TodoWrite" \
        "TDD RED phase is scored"; do
        if grep -qF "$forbidden" "$SHEPHERD"; then
            miss="$miss|cheat-sheet phrase resurrected: $forbidden"
        fi
    done
    if ! grep -qF -- "--add-dir" "$SHEPHERD"; then miss="$miss|shepherd missing --add-dir"; fi
    if ! grep -qF -- "--max-turns" "$SHEPHERD"; then miss="$miss|shepherd missing --max-turns"; fi
    if ! grep -qF -- "--allowedTools" "$SHEPHERD"; then miss="$miss|shepherd missing --allowedTools"; fi
    if [ -z "$miss" ]; then
        pass "shepherd has neutral task prompt + parity flags (no answer-key coaching)"
    else
        fail "shepherd prompt drift:$miss"
    fi
}

# ---- ROADMAP #230: --compare-baseline mode ----
# Single-scenario delta between candidate (current branch) and baseline (main).
# Unblocks #231 Phase 2 weekly-update migration. Stub-friendly via mocks; no
# real claude/gh/git calls.

# Helper: shared compare-baseline harness — sets up mocks, runs shepherd with
# --compare-baseline, returns paths. Caller asserts on the captured artifacts.
_compare_baseline_run() {
    local tmpdir="$1"
    local bindir="$tmpdir/bin"
    local evaluator="$tmpdir/eval.sh"
    mkdir -p "$bindir"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    # Fresh git mock with worktree support; both commands log into git.log.
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    # Mock claude: log every invocation + emit minimal valid JSON.
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    # State file path explicit, NOT via $TMPDIR (which can be unset on Linux
    # GHA runners — caused both calls to fall through to the "not-first"
    # branch, masking the delta and breaking the summary test on CI).
    local state_file="$tmpdir/_compare_eval_state"
    cat > "$evaluator" <<EOF
#!/bin/bash
# Mock evaluator returning different scores per call to make delta visible.
# First call (baseline): 7. Second call (candidate): 9.
state="$state_file"
[ ! -f "\$state" ] && echo 0 > "\$state"
n=\$(cat "\$state")
echo \$((n + 1)) > "\$state"
if [ "\$n" = "0" ]; then
    echo '{"score":7,"max_score":10,"criteria":{"tdd_red":{"points":2}}}'
else
    echo '{"score":9,"max_score":10,"criteria":{"tdd_red":{"points":2}}}'
fi
EOF
    chmod +x "$evaluator"
    rm -f "$state_file"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 --compare-baseline \
        > "$tmpdir/stdout.log" 2> "$tmpdir/stderr.log" || true
}

test_compare_baseline_creates_main_worktree() {
    # The whole point: run baseline against a clean main checkout, not the
    # current branch's working tree. git worktree add main <path> is the spec.
    local tmpdir
    tmpdir=$(mktemp -d)
    _compare_baseline_run "$tmpdir"
    local git_log="$tmpdir/git.log"
    if grep -qE "worktree add.*main|worktree add.*--detach|worktree add" "$git_log" 2>/dev/null \
       && grep -q "worktree add" "$git_log" 2>/dev/null \
       && grep -qE "main|origin/main" "$git_log" 2>/dev/null; then
        pass "compare-baseline creates a main worktree (git worktree add main)"
    else
        fail "compare-baseline must call 'git worktree add ... main' (git.log: $(cat $git_log 2>/dev/null | head -5))"
    fi
    rm -rf "$tmpdir"
}

test_compare_baseline_runs_sim_twice() {
    # Two simulations: baseline + candidate. claude gets called twice with the
    # same parity flags but in different working dirs.
    local tmpdir
    tmpdir=$(mktemp -d)
    _compare_baseline_run "$tmpdir"
    local claude_log="$tmpdir/claude.log"
    # Each invocation logs a line beginning "claude". Count non-version calls.
    local sim_calls
    sim_calls=$(grep -c "^claude.*--print" "$claude_log" 2>/dev/null || true)
    rm -rf "$tmpdir"
    if [ "${sim_calls:-0}" -ge 2 ]; then
        pass "compare-baseline runs claude --print twice (baseline + candidate)"
    else
        fail "compare-baseline must run claude twice (got: $sim_calls calls)"
    fi
}

test_compare_baseline_appends_two_history_rows_with_roles() {
    # score-history must distinguish baseline vs candidate rows. New field
    # comparison_role: "baseline" | "candidate". Without it, mixed comparison
    # rows poison CUSUM/trend analytics same way local-vs-CI mixing does.
    local tmpdir history_file baseline_row candidate_row
    tmpdir=$(mktemp -d)
    _compare_baseline_run "$tmpdir"
    history_file="$tmpdir/score-history.jsonl"
    baseline_row=$(grep '"comparison_role":"baseline"' "$history_file" 2>/dev/null || true)
    candidate_row=$(grep '"comparison_role":"candidate"' "$history_file" 2>/dev/null || true)
    rm -rf "$tmpdir"
    if [ -n "$baseline_row" ] && [ -n "$candidate_row" ]; then
        pass "compare-baseline appends two rows with comparison_role=baseline AND =candidate"
    else
        fail "score-history must have role-tagged rows. baseline='$baseline_row' candidate='$candidate_row'"
    fi
}

test_compare_baseline_posts_delta_summary() {
    # In non-dry-run mode, posts ONE check-run + ONE PR comment showing both
    # scores + delta. Dry-run mode (used in this harness) writes the comment
    # body to a known location for inspection but skips the gh side effects.
    # Spec: stderr/stdout summary mentions both scores + delta — visible to
    # the user even in dry-run.
    local tmpdir
    tmpdir=$(mktemp -d)
    _compare_baseline_run "$tmpdir"
    local stderr_log="$tmpdir/stderr.log" stdout_log="$tmpdir/stdout.log"
    local combined
    combined="$(cat "$stderr_log" "$stdout_log" 2>/dev/null)"
    rm -rf "$tmpdir"
    # Mock evaluator returns 7 then 9, delta = +2. Look for both scores + a
    # delta indicator (Δ, "delta", or signed integer like "+2").
    if echo "$combined" | grep -qE 'baseline.*7' \
       && echo "$combined" | grep -qE 'candidate.*9' \
       && echo "$combined" | grep -qE 'delta|Δ|\+2|change'; then
        pass "compare-baseline summarizes baseline=7, candidate=9, delta=+2"
    else
        fail "compare-baseline summary missing scores+delta. Output: '$combined'"
    fi
}

test_compare_baseline_cleans_up_worktree_on_exit() {
    # Worktree must be removed (or at least pruned) on shepherd exit. Otherwise
    # repeated runs accumulate stale worktrees and confuse the next git op.
    local tmpdir
    tmpdir=$(mktemp -d)
    _compare_baseline_run "$tmpdir"
    local git_log="$tmpdir/git.log"
    if grep -qE "worktree (remove|prune)" "$git_log" 2>/dev/null; then
        pass "compare-baseline runs 'git worktree remove' (or prune) on exit"
    else
        fail "compare-baseline must clean up worktree (git.log: $(cat $git_log 2>/dev/null | head -5))"
    fi
    rm -rf "$tmpdir"
}

test_compare_baseline_uses_same_scenario_for_both_runs() {
    # Comparing apples to apples: baseline + candidate must run the SAME
    # scenario. Otherwise the delta is meaningless. Scenario is selected once
    # (round-robin by PR number) and reused.
    local tmpdir history_file baseline_scenario candidate_scenario
    tmpdir=$(mktemp -d)
    _compare_baseline_run "$tmpdir"
    history_file="$tmpdir/score-history.jsonl"
    baseline_scenario=$(grep '"comparison_role":"baseline"' "$history_file" 2>/dev/null \
        | head -1 | jq -r '.scenario // empty' 2>/dev/null || true)
    candidate_scenario=$(grep '"comparison_role":"candidate"' "$history_file" 2>/dev/null \
        | head -1 | jq -r '.scenario // empty' 2>/dev/null || true)
    rm -rf "$tmpdir"
    if [ -n "$baseline_scenario" ] && [ "$baseline_scenario" = "$candidate_scenario" ]; then
        pass "compare-baseline reuses one scenario for both runs ($baseline_scenario)"
    else
        fail "scenarios diverged: baseline='$baseline_scenario' candidate='$candidate_scenario'"
    fi
}

test_compare_baseline_no_orphan_row_on_candidate_failure() {
    # Codex P1 #1 round-1 finding: baseline row was appended BEFORE candidate
    # ran, so a candidate crash left an orphan baseline-only row in history
    # — poisoning trend analytics with half-comparisons. Fix: defer both
    # appends until candidate sim+eval succeed (atomic write of both rows).
    # This test crashes the candidate (second claude call) and asserts zero
    # rows were appended for that comparison.
    local tmpdir bindir evaluator
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    # Mock claude that succeeds on baseline (call 1) but fails on candidate (call 2).
    mkdir -p "$bindir"
    local state_file="$tmpdir/claude-state"
    echo 0 > "$state_file"
    cat > "$bindir/claude" <<EOF
#!/bin/bash
if [ "\$1" = "--version" ]; then echo "2.1.118"; exit 0; fi
n=\$(cat "$state_file")
echo \$((n + 1)) > "$state_file"
if [ "\$n" = "0" ]; then
    cat <<JSON
{"type":"result","session_id":"mock","result":"TodoWrite. Confidence: HIGH. tests/x.test.js","total_cost_usd":0,"num_turns":3}
JSON
    exit 0
else
    echo "candidate crash" >&2
    exit 42
fi
EOF
    chmod +x "$bindir/claude"
    _mock_curl "$bindir"
    cat > "$tmpdir/eval.sh" <<'EOF'
#!/bin/bash
echo '{"score":7,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$tmpdir/eval.sh"
    local rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$tmpdir/eval.sh" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 --compare-baseline \
        >/dev/null 2>&1 || rc=$?
    # File may not exist if shepherd aborts before mkdir — treat as zero rows.
    local row_count
    if [ -f "$tmpdir/score-history.jsonl" ]; then
        row_count=$(wc -l < "$tmpdir/score-history.jsonl" 2>/dev/null | tr -d ' ')
    else
        row_count=0
    fi
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] && [ "${row_count:-0}" -eq 0 ]; then
        pass "candidate failure leaves zero comparison rows (no orphan baseline)"
    else
        fail "candidate crash must NOT write orphan baseline row (rc=$rc, history_rows=$row_count)"
    fi
}

test_compare_baseline_no_baseline_tmprun_leak() {
    # Codex P1 #2 round-1 finding: BASELINE_TMPRUN was created via mktemp -d
    # outside the trap-managed cleanup. If anything failed before the manual
    # rm -rf, the dir leaked. Fix: nest under TMPRUN so the existing trap
    # covers it. This test verifies no /tmp/sdlc-baseline.* dirs survive a
    # successful run (mock claude + eval succeed; we just check housekeeping).
    local tmpdir bindir evaluator before_count after_count
    before_count=$(find "${TMPDIR:-/tmp}" -maxdepth 2 -type d -name 'sdlc-baseline*' 2>/dev/null | wc -l | tr -d ' ')
    tmpdir=$(mktemp -d)
    _compare_baseline_run "$tmpdir"
    after_count=$(find "${TMPDIR:-/tmp}" -maxdepth 2 -type d -name 'sdlc-baseline*' 2>/dev/null | wc -l | tr -d ' ')
    rm -rf "$tmpdir"
    # Allow zero growth (or even shrinkage from the cleanup of pre-existing
    # dirs). Fail only if we LEAK new ones.
    if [ "${after_count:-0}" -le "${before_count:-0}" ]; then
        pass "compare-baseline does not leak BASELINE_TMPRUN dirs (before=$before_count after=$after_count)"
    else
        fail "BASELINE_TMPRUN leaked (before=$before_count after=$after_count)"
    fi
}

test_compare_baseline_aborts_when_baseline_sim_fails() {
    # If baseline fails, candidate must NOT run, exit code is 1, and we don't
    # post a partial comparison comment.
    local tmpdir bindir evaluator
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    # Crash claude on every call — baseline run will be the first to crash,
    # so candidate should never be attempted.
    mkdir -p "$bindir"
    cat > "$bindir/claude" <<'EOF'
#!/bin/bash
if [ "$1" = "--version" ]; then echo "2.1.118"; exit 0; fi
echo "simulated claude crash" >&2
exit 42
EOF
    chmod +x "$bindir/claude"
    _mock_curl "$bindir"
    cat > "$tmpdir/eval.sh" <<'EOF'
#!/bin/bash
echo '{"score":8,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$tmpdir/eval.sh"
    local rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$tmpdir/eval.sh" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 --compare-baseline \
        >/dev/null 2>&1 || rc=$?
    local has_candidate
    has_candidate=$(grep -c '"comparison_role":"candidate"' "$tmpdir/score-history.jsonl" 2>/dev/null || echo 0)
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] && [ "${has_candidate:-0}" -eq 0 ]; then
        pass "compare-baseline aborts on baseline sim failure (rc=$rc, no candidate row written)"
    else
        fail "baseline failure must abort (rc=$rc, candidate_rows=$has_candidate)"
    fi
}

# ---- ROADMAP #231 Phase 2: --strip-paths (prove-it pattern, same-commit) ----
# Helper: standard --compare-baseline --strip-paths run with mock evaluator
# returning 9 for baseline (intact fixture) and 5 for candidate (stripped),
# making the prove-it delta visible (KEEP-CUSTOM verdict).
_strip_paths_run() {
    local tmpdir="$1" strip_arg="${2:-[\".claude/hooks/sdlc-prompt-check.sh\"]}"
    local bindir="$tmpdir/bin"
    local evaluator="$tmpdir/eval.sh"
    mkdir -p "$bindir"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    local state_file="$tmpdir/_strip_eval_state"
    cat > "$evaluator" <<EOF
#!/bin/bash
state="$state_file"
[ ! -f "\$state" ] && echo 0 > "\$state"
n=\$(cat "\$state")
echo \$((n + 1)) > "\$state"
if [ "\$n" = "0" ]; then
    echo '{"score":9,"max_score":10,"criteria":{"tdd_red":{"points":2}}}'
else
    echo '{"score":5,"max_score":10,"criteria":{"tdd_red":{"points":0}}}'
fi
EOF
    chmod +x "$evaluator"
    rm -f "$state_file"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 231 \
        --compare-baseline --strip-paths "$strip_arg" \
        > "$tmpdir/stdout.log" 2> "$tmpdir/stderr.log" || true
}

test_strip_paths_requires_compare_baseline() {
    # Lone --strip-paths is meaningless — must error fast with a clear message.
    # Otherwise users get silent fall-through to single-run (no comparison).
    local tmpdir bindir
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$tmpdir/eval.sh" <<'EOF'
#!/bin/bash
echo '{"score":7,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$tmpdir/eval.sh"
    local rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$tmpdir/eval.sh" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 231 \
        --strip-paths '[".claude/hooks/sdlc-prompt-check.sh"]' \
        > "$tmpdir/stdout.log" 2> "$tmpdir/stderr.log" || rc=$?
    local stderr_content
    stderr_content=$(cat "$tmpdir/stderr.log" 2>/dev/null)
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] && echo "$stderr_content" | grep -qE 'compare-baseline|--compare-baseline'; then
        pass "--strip-paths without --compare-baseline exits non-zero with clear error"
    else
        fail "--strip-paths alone must error (rc=$rc, stderr='$stderr_content')"
    fi
}

test_strip_paths_rejects_non_allowlisted_path() {
    # Security: prevents LLM hallucination from deleting arbitrary files. The
    # prove-it allowlist (tests/e2e/lib/prove-it.sh) is the source of truth.
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    _strip_paths_run "$tmpdir" '["/etc/passwd"]'
    # _strip_paths_run swallows rc — re-derive from absence of comparison rows.
    # Better: capture rc by re-running standalone here.
    local bindir="$tmpdir/bin"
    rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$tmpdir/eval.sh" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl.2" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 231 \
        --compare-baseline --strip-paths '["/etc/passwd"]' \
        >/dev/null 2>"$tmpdir/stderr.2" || rc=$?
    local stderr_content
    stderr_content=$(cat "$tmpdir/stderr.2" 2>/dev/null)
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] && echo "$stderr_content" | grep -qiE 'allowlist|allowed|/etc/passwd|no valid'; then
        pass "--strip-paths rejects non-allowlisted paths (security: no arbitrary deletions)"
    else
        fail "--strip-paths must reject /etc/passwd (rc=$rc, stderr='$stderr_content')"
    fi
}

test_strip_paths_skips_main_worktree() {
    # Same-commit prove-it semantics: NO main worktree creation. Both runs
    # use the current branch. Cross-commit comparison is the no-strip mode.
    local tmpdir
    tmpdir=$(mktemp -d)
    _strip_paths_run "$tmpdir"
    local git_log="$tmpdir/git.log"
    # Should NOT contain `worktree add main` or `worktree add origin/main`.
    if ! grep -qE "worktree add.*\b(main|origin/main)\b" "$git_log" 2>/dev/null; then
        pass "--strip-paths does not create a main worktree (same-commit mode)"
    else
        fail "--strip-paths must skip main worktree (git.log: $(cat $git_log 2>/dev/null | head -5))"
    fi
    rm -rf "$tmpdir"
}

test_strip_paths_runs_sim_twice() {
    # Both baseline (intact fixture) and candidate (stripped fixture) run.
    local tmpdir
    tmpdir=$(mktemp -d)
    _strip_paths_run "$tmpdir"
    local sim_calls
    sim_calls=$(grep -c "^claude.*--print" "$tmpdir/claude.log" 2>/dev/null || true)
    rm -rf "$tmpdir"
    if [ "${sim_calls:-0}" -ge 2 ]; then
        pass "--strip-paths runs claude --print twice (baseline + candidate)"
    else
        fail "--strip-paths must run claude twice (got: $sim_calls calls)"
    fi
}

test_strip_paths_appends_two_history_rows_with_roles() {
    # Atomic append: both rows or neither. Same contract as plain compare-baseline.
    local tmpdir history_file baseline_row candidate_row
    tmpdir=$(mktemp -d)
    _strip_paths_run "$tmpdir"
    history_file="$tmpdir/score-history.jsonl"
    baseline_row=$(grep '"comparison_role":"baseline"' "$history_file" 2>/dev/null || true)
    candidate_row=$(grep '"comparison_role":"candidate"' "$history_file" 2>/dev/null || true)
    rm -rf "$tmpdir"
    if [ -n "$baseline_row" ] && [ -n "$candidate_row" ]; then
        pass "--strip-paths appends baseline + candidate rows with comparison_role"
    else
        fail "history must have both rows. baseline='$baseline_row' candidate='$candidate_row'"
    fi
}

test_strip_paths_emits_strip_signal_in_stderr() {
    # Operator visibility: shepherd's stderr must mention what was stripped.
    # Otherwise a silent --strip-paths run is indistinguishable from a regular
    # compare-baseline (same delta column in the PR comment, different cause).
    local tmpdir
    tmpdir=$(mktemp -d)
    _strip_paths_run "$tmpdir"
    local stderr_log="$tmpdir/stderr.log"
    local combined
    combined=$(cat "$stderr_log" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$combined" | grep -qiE 'strip|stripped|prove.it|sdlc-prompt-check'; then
        pass "--strip-paths emits operator-visible signal mentioning strip action"
    else
        fail "--strip-paths must surface what was stripped. stderr: '$combined'"
    fi
}

test_strip_paths_no_dir_leak_on_success() {
    # Both BASELINE_DIR and CANDIDATE_DIR (if same-commit mode creates them as
    # tmpdirs) must clean up on exit. Otherwise repeated runs accumulate.
    local before_count after_count tmpdir
    before_count=$(find "${TMPDIR:-/tmp}" -maxdepth 2 -type d \( -name 'sdlc-baseline-strip*' -o -name 'sdlc-candidate-strip*' \) 2>/dev/null | wc -l | tr -d ' ')
    tmpdir=$(mktemp -d)
    _strip_paths_run "$tmpdir"
    after_count=$(find "${TMPDIR:-/tmp}" -maxdepth 2 -type d \( -name 'sdlc-baseline-strip*' -o -name 'sdlc-candidate-strip*' \) 2>/dev/null | wc -l | tr -d ' ')
    rm -rf "$tmpdir"
    if [ "${after_count:-0}" -le "${before_count:-0}" ]; then
        pass "--strip-paths does not leak strip tmpdirs (before=$before_count after=$after_count)"
    else
        fail "--strip-paths leaked tmpdirs (before=$before_count after=$after_count)"
    fi
}

test_strip_paths_validates_via_prove_it_lib() {
    # The shepherd MUST source tests/e2e/lib/prove-it.sh and use its
    # validate_removable_paths function. This pins us to the single source of
    # truth for the allowlist (no parallel allowlists drifting apart).
    if grep -qE 'tests/e2e/lib/prove-it\.sh|lib/prove-it\.sh' "$SHEPHERD" 2>/dev/null \
       && grep -qE 'validate_removable_paths|create_stripped_fixture' "$SHEPHERD" 2>/dev/null; then
        pass "shepherd sources prove-it.sh lib (single source of truth for allowlist)"
    else
        fail "shepherd must source tests/e2e/lib/prove-it.sh and use its functions"
    fi
}

test_strip_paths_equals_form_rejects_empty() {
    # Codex P1 #2 round 1: the `--strip-paths=` form silently set STRIP_PATHS=""
    # and fell through to single-run mode (the -n check below skipped the
    # require-compare-baseline error). Must reject empty equals form same as
    # bare flag with no value.
    local tmpdir bindir
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$tmpdir/eval.sh" <<'EOF'
#!/bin/bash
echo '{"score":7,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$tmpdir/eval.sh"
    local rc=0
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$tmpdir/eval.sh" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 231 \
        --compare-baseline --strip-paths= \
        > "$tmpdir/stdout.log" 2> "$tmpdir/stderr.log" || rc=$?
    local stderr_content row_count
    stderr_content=$(cat "$tmpdir/stderr.log" 2>/dev/null)
    if [ -f "$tmpdir/score-history.jsonl" ]; then
        row_count=$(wc -l < "$tmpdir/score-history.jsonl" 2>/dev/null | tr -d ' ')
    else
        row_count=0
    fi
    rm -rf "$tmpdir"
    # Must error AND not append any history rows.
    if [ "$rc" -ne 0 ] && [ "${row_count:-0}" -eq 0 ] && echo "$stderr_content" | grep -qE 'strip-paths.*requires|JSON array'; then
        pass "--strip-paths= empty form rejected with error (no silent fall-through)"
    else
        fail "--strip-paths= must error (rc=$rc, rows=$row_count, stderr='$stderr_content')"
    fi
}

test_strip_paths_no_leak_on_setup_failure() {
    # Codex P1 #1 round 1: install cleanup trap BEFORE creating tmpdirs so
    # an early failure (e.g., a cp / fixture-build crash) doesn't leak. We
    # simulate by pre-counting tmpdirs, running with a forced /etc/passwd
    # path (which exits BEFORE any tmpdir creation), and confirming no leak.
    # The harder case (failure DURING setup) is hard to reproduce
    # deterministically without monkey-patching cp; we rely on the trap-set
    # ordering check below to cover it.
    local before_count after_count tmpdir bindir
    before_count=$(find "${TMPDIR:-/tmp}" -maxdepth 2 -type d \( -name 'sdlc-baseline-strip*' -o -name 'sdlc-candidate-strip*' -o -name 'sdlc-cand-stage*' \) 2>/dev/null | wc -l | tr -d ' ')
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$tmpdir/eval.sh" <<'EOF'
#!/bin/bash
echo '{"score":7,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$tmpdir/eval.sh"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$tmpdir/eval.sh" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 231 \
        --compare-baseline --strip-paths '["/etc/passwd"]' \
        >/dev/null 2>&1 || true
    after_count=$(find "${TMPDIR:-/tmp}" -maxdepth 2 -type d \( -name 'sdlc-baseline-strip*' -o -name 'sdlc-candidate-strip*' -o -name 'sdlc-cand-stage*' \) 2>/dev/null | wc -l | tr -d ' ')
    rm -rf "$tmpdir"
    if [ "${after_count:-0}" -le "${before_count:-0}" ]; then
        pass "early validation failure does not leak strip tmpdirs (before=$before_count after=$after_count)"
    else
        fail "early-failure path leaked tmpdirs (before=$before_count after=$after_count)"
    fi
}

test_strip_paths_trap_set_before_tmpdir() {
    # Static check: cleanup_strip_dirs and its trap MUST appear in the source
    # BEFORE the first `mktemp -d -t sdlc-baseline-strip`. Otherwise a crash
    # between mktemp and trap leaks. Codex P1 #1 round 1 fix.
    local cleanup_line trap_line first_mktemp_line
    cleanup_line=$(grep -nE 'cleanup_strip_dirs\(\) \{' "$SHEPHERD" | head -1 | cut -d: -f1)
    trap_line=$(grep -nE "trap.*cleanup_strip_dirs.*EXIT" "$SHEPHERD" | head -1 | cut -d: -f1)
    first_mktemp_line=$(grep -n 'mktemp -d -t sdlc-baseline-strip' "$SHEPHERD" | head -1 | cut -d: -f1)
    if [ -n "$cleanup_line" ] && [ -n "$trap_line" ] && [ -n "$first_mktemp_line" ] \
       && [ "$cleanup_line" -lt "$first_mktemp_line" ] \
       && [ "$trap_line" -lt "$first_mktemp_line" ]; then
        pass "cleanup_strip_dirs trap is installed BEFORE first strip tmpdir creation (line $trap_line < $first_mktemp_line)"
    else
        fail "trap-before-tmpdir invariant broken: cleanup=$cleanup_line, trap=$trap_line, first_mktemp=$first_mktemp_line"
    fi
}

test_strip_paths_pr_comment_uses_intact_stripped_labels() {
    # Codex P1 #3 round 1: in strip mode, the check-run + PR comment must
    # NOT mislabel as "Baseline (main)" / "Candidate (PR)" because both are
    # the SAME COMMIT. They must say "intact" / "stripped" with the stripped
    # paths surfaced.
    local tmpdir
    tmpdir=$(mktemp -d)
    _strip_paths_run "$tmpdir"
    local stderr_log="$tmpdir/stderr.log"
    local combined
    combined=$(cat "$stderr_log" 2>/dev/null)
    rm -rf "$tmpdir"
    # Stderr summary line is the visible signal in dry-run. Verify intact +
    # stripped wording is present and the misleading "main" label is NOT.
    if echo "$combined" | grep -qE 'intact-fixture|intact fixture' \
       && echo "$combined" | grep -qE 'stripped-fixture|stripped fixture' \
       && ! echo "$combined" | grep -qE 'baseline=.*\bmain\b'; then
        pass "strip mode summary uses intact/stripped labels (not main/PR)"
    else
        fail "strip mode mislabels comparison. stderr: '$combined'"
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
test_shepherd_prompt_has_required_signatures
test_compare_baseline_creates_main_worktree
test_compare_baseline_runs_sim_twice
test_compare_baseline_appends_two_history_rows_with_roles
test_compare_baseline_posts_delta_summary
test_compare_baseline_cleans_up_worktree_on_exit
test_compare_baseline_uses_same_scenario_for_both_runs
test_compare_baseline_aborts_when_baseline_sim_fails
test_compare_baseline_no_orphan_row_on_candidate_failure
test_compare_baseline_no_baseline_tmprun_leak
test_strip_paths_requires_compare_baseline
test_strip_paths_rejects_non_allowlisted_path
test_strip_paths_skips_main_worktree
test_strip_paths_runs_sim_twice
test_strip_paths_appends_two_history_rows_with_roles
test_strip_paths_emits_strip_signal_in_stderr
test_strip_paths_no_dir_leak_on_success
test_strip_paths_validates_via_prove_it_lib
test_strip_paths_equals_form_rejects_empty
test_strip_paths_no_leak_on_setup_failure
test_strip_paths_trap_set_before_tmpdir
test_strip_paths_pr_comment_uses_intact_stripped_labels

# ---- ROADMAP #96 Phase 2: ground-truth gate integration tests ----
# The shepherd runs ground-truth.sh post-simulation. If `npm test` fails,
# the score gets capped at GROUND_TRUTH_FAIL_CAP (default 5). Score-
# history rows record tests_run/tests_pass/ground_truth_gated/
# original_judge_score so trend analytics can distinguish judge-noise
# from real regression.
test_ground_truth_gate_caps_score_when_tests_fail() {
    local tmpdir bindir history_file evaluator gt
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    history_file="$tmpdir/score-history.jsonl"
    evaluator="$tmpdir/mock-evaluator.sh"
    gt="$tmpdir/mock-ground-truth.sh"
    touch "$history_file"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    # Judge gives 9/10
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":9,"max_score":10,"criteria":{}}'
EOF
    # But ground-truth says tests fail
    cat > "$gt" <<'EOF'
#!/bin/bash
echo '{"tests_run":true,"tests_pass":false,"tests_rc":1,"tests_tail":"AssertionError"}'
EOF
    chmod +x "$evaluator" "$gt"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_GROUND_TRUTH="$gt" \
        SDLC_SHEPHERD_HISTORY_FILE="$history_file" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    local row
    row=$(tail -1 "$history_file" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$row" | jq -e '.score == 5 and .original_judge_score == 9 and .ground_truth_gated == true and .tests_pass == false' >/dev/null 2>&1; then
        pass "ground-truth gate caps judge=9 to score=5 when tests fail"
    else
        fail "ground-truth gate did not apply. row=$row"
    fi
}
test_ground_truth_gate_caps_score_when_tests_fail

test_ground_truth_gate_passes_through_when_tests_pass() {
    local tmpdir bindir history_file evaluator gt
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    history_file="$tmpdir/score-history.jsonl"
    evaluator="$tmpdir/mock-evaluator.sh"
    gt="$tmpdir/mock-ground-truth.sh"
    touch "$history_file"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":8,"max_score":10,"criteria":{}}'
EOF
    cat > "$gt" <<'EOF'
#!/bin/bash
echo '{"tests_run":true,"tests_pass":true,"tests_rc":0,"tests_tail":"OK"}'
EOF
    chmod +x "$evaluator" "$gt"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_GROUND_TRUTH="$gt" \
        SDLC_SHEPHERD_HISTORY_FILE="$history_file" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    local row
    row=$(tail -1 "$history_file" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$row" | jq -e '.score == 8 and .ground_truth_gated == false and .tests_pass == true' >/dev/null 2>&1; then
        pass "ground-truth gate leaves judge score alone when tests pass"
    else
        fail "ground-truth gate misfired. row=$row"
    fi
}
test_ground_truth_gate_passes_through_when_tests_pass

test_ground_truth_skipped_when_no_tests_configured() {
    # Fixture without test script → tests_run=false → no gate applied,
    # judge score stands alone.
    local tmpdir bindir history_file evaluator gt
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    history_file="$tmpdir/score-history.jsonl"
    evaluator="$tmpdir/mock-evaluator.sh"
    gt="$tmpdir/mock-ground-truth.sh"
    touch "$history_file"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":7,"max_score":10,"criteria":{}}'
EOF
    cat > "$gt" <<'EOF'
#!/bin/bash
echo '{"tests_run":false,"reason":"no_test_script"}'
EOF
    chmod +x "$evaluator" "$gt"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_GROUND_TRUTH="$gt" \
        SDLC_SHEPHERD_HISTORY_FILE="$history_file" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    local row
    row=$(tail -1 "$history_file" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$row" | jq -e '.score == 7 and .ground_truth_gated == false and .tests_run == false' >/dev/null 2>&1; then
        pass "no-tests fixture → judge score stands alone (no gate)"
    else
        fail "no-tests path misfired. row=$row"
    fi
}
test_ground_truth_skipped_when_no_tests_configured

test_ground_truth_skip_env_var() {
    # SDLC_SHEPHERD_SKIP_GROUND_TRUTH=1 disables gate entirely (escape
    # hatch for users who don't have a fixture or want raw judge scores).
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
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":9,"max_score":10,"criteria":{}}'
EOF
    chmod +x "$evaluator"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_SKIP_GROUND_TRUTH=1 \
        SDLC_SHEPHERD_HISTORY_FILE="$history_file" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 >/dev/null 2>&1 || true
    local row
    row=$(tail -1 "$history_file" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$row" | jq -e '.score == 9 and .tests_run == false and .ground_truth_gated == false' >/dev/null 2>&1; then
        pass "SDLC_SHEPHERD_SKIP_GROUND_TRUTH disables gate entirely"
    else
        fail "skip env var did not disable gate. row=$row"
    fi
}
test_ground_truth_skip_env_var

# ---- ROADMAP #96 Phase 2 (Codex F-01/F-02): compare-baseline gate ----
# The gate must apply per-row in compare-baseline mode AND test the
# CANDIDATE_DIR fixture, not the repo-root fixture. Round 1 missed
# both gaps; round 2 wires baseline/candidate gates separately.
test_compare_baseline_gate_caps_candidate_when_tests_fail() {
    local tmpdir bindir evaluator gt
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    evaluator="$tmpdir/eval.sh"
    gt="$tmpdir/ground-truth.sh"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    # Both legs return judge=9 (above cap)
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":9,"max_score":10,"criteria":{}}'
EOF
    # Both legs: tests fail
    cat > "$gt" <<'EOF'
#!/bin/bash
echo '{"tests_run":true,"tests_pass":false,"tests_rc":1,"tests_tail":"failed"}'
EOF
    chmod +x "$evaluator" "$gt"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_GROUND_TRUTH="$gt" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 --compare-baseline \
        >/dev/null 2>&1 || true
    local baseline_row candidate_row
    baseline_row=$(grep '"comparison_role":"baseline"' "$tmpdir/score-history.jsonl" 2>/dev/null)
    candidate_row=$(grep '"comparison_role":"candidate"' "$tmpdir/score-history.jsonl" 2>/dev/null)
    rm -rf "$tmpdir"
    local ok_baseline ok_candidate
    ok_baseline=$(echo "$baseline_row" | jq -e '.score == 5 and .original_judge_score == 9 and .ground_truth_gated == true and .tests_pass == false' >/dev/null 2>&1 && echo yes || echo no)
    ok_candidate=$(echo "$candidate_row" | jq -e '.score == 5 and .original_judge_score == 9 and .ground_truth_gated == true and .tests_pass == false' >/dev/null 2>&1 && echo yes || echo no)
    if [ "$ok_baseline" = "yes" ] && [ "$ok_candidate" = "yes" ]; then
        pass "compare-baseline gate caps BOTH baseline + candidate when tests fail"
    else
        fail "compare-baseline gate misfired. baseline=$ok_baseline ($baseline_row) candidate=$ok_candidate ($candidate_row)"
    fi
}
test_compare_baseline_gate_caps_candidate_when_tests_fail

test_compare_baseline_gate_no_cap_when_judge_below_cap() {
    # Edge case: judge=4 already below cap. Tests fail. Score stays 4.
    # ground_truth_gated must be false (cap didn't apply).
    local tmpdir bindir evaluator gt
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    evaluator="$tmpdir/eval.sh"
    gt="$tmpdir/ground-truth.sh"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":4,"max_score":10,"criteria":{}}'
EOF
    cat > "$gt" <<'EOF'
#!/bin/bash
echo '{"tests_run":true,"tests_pass":false,"tests_rc":1,"tests_tail":"failed"}'
EOF
    chmod +x "$evaluator" "$gt"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_GROUND_TRUTH="$gt" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 --compare-baseline \
        >/dev/null 2>&1 || true
    local candidate_row
    candidate_row=$(grep '"comparison_role":"candidate"' "$tmpdir/score-history.jsonl" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$candidate_row" | jq -e '.score == 4 and .original_judge_score == 4 and .ground_truth_gated == false and .tests_pass == false' >/dev/null 2>&1; then
        pass "compare-baseline: judge=4 + tests-fail leaves score=4, gated=false"
    else
        fail "compare-baseline cap-boundary semantics wrong. row=$candidate_row"
    fi
}
test_compare_baseline_gate_no_cap_when_judge_below_cap

test_compare_baseline_gate_baseline_uses_baseline_dir() {
    # F-01 regression (default compare-baseline mode): the BASELINE leg
    # of the gate must invoke ground-truth with $BASELINE_DIR fixture,
    # not the repo-root path. Candidate runs in REPO_ROOT in default
    # mode, so candidate-side path being repo-root is CORRECT —
    # only the baseline-side has to point at the worktree.
    local tmpdir bindir evaluator gt gt_log
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    evaluator="$tmpdir/eval.sh"
    gt="$tmpdir/ground-truth.sh"
    gt_log="$tmpdir/gt.log"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":7,"max_score":10,"criteria":{}}'
EOF
    cat > "$gt" <<EOF
#!/bin/bash
echo "\$@" >> "$gt_log"
echo '{"tests_run":true,"tests_pass":true,"tests_rc":0,"tests_tail":"ok"}'
EOF
    chmod +x "$evaluator" "$gt"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_GROUND_TRUTH="$gt" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 227 --compare-baseline \
        >/dev/null 2>&1 || true
    local logged baseline_path candidate_path
    logged=$(cat "$gt_log" 2>/dev/null)
    baseline_path=$(echo "$logged" | sed -n '1p')
    candidate_path=$(echo "$logged" | sed -n '2p')
    rm -rf "$tmpdir"
    # Baseline path must be an absolute path containing 'sdlc-baseline'
    # (the mktemp prefix) — proving it points to BASELINE_DIR, not repo-root.
    if echo "$baseline_path" | grep -qE 'sdlc-baseline.*tests/e2e/fixtures/test-repo$' \
       && [ "$candidate_path" = "tests/e2e/fixtures/test-repo" ]; then
        pass "compare-baseline gate paths: baseline=BASELINE_DIR (Codex F-01), candidate=repo-root (CWD)"
    else
        fail "gate path resolution wrong. baseline='$baseline_path' candidate='$candidate_path'"
    fi
}
test_compare_baseline_gate_baseline_uses_baseline_dir

test_strip_paths_gate_uses_candidate_strip_dir() {
    # Codex F-01 round 2 nit: in --strip-paths mode, the candidate gate
    # must invoke ground-truth with $CANDIDATE_DIR/.../test-repo (the
    # stripped-fixture worktree). Without this, the gate would test the
    # repo's working-tree fixture even though the agent ran against a
    # stripped copy. Mock ground-truth records argv to verify the path.
    local tmpdir bindir evaluator gt gt_log
    tmpdir=$(mktemp -d)
    bindir="$tmpdir/bin"
    evaluator="$tmpdir/eval.sh"
    gt="$tmpdir/ground-truth.sh"
    gt_log="$tmpdir/gt.log"
    _mock_gh "$bindir" "false" "$tmpdir/gh.log"
    _mock_git "$bindir" "abcd1234" "$tmpdir/git.log"
    _mock_claude "$bindir" "$tmpdir/claude.log"
    _mock_curl "$bindir"
    cat > "$evaluator" <<'EOF'
#!/bin/bash
echo '{"score":7,"max_score":10,"criteria":{}}'
EOF
    cat > "$gt" <<EOF
#!/bin/bash
echo "\$@" >> "$gt_log"
echo '{"tests_run":true,"tests_pass":true,"tests_rc":0,"tests_tail":"ok"}'
EOF
    chmod +x "$evaluator" "$gt"
    PATH="$bindir:$PATH" ANTHROPIC_API_KEY=test-key \
        SDLC_LOCAL_SHEPHERD_DRY_RUN=1 \
        SDLC_SHEPHERD_EVALUATOR="$evaluator" \
        SDLC_SHEPHERD_GROUND_TRUTH="$gt" \
        SDLC_SHEPHERD_HISTORY_FILE="$tmpdir/score-history.jsonl" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SHEPHERD" 231 \
        --compare-baseline \
        --strip-paths '[".claude/hooks/sdlc-prompt-check.sh"]' \
        >/dev/null 2>&1 || true
    local logged baseline_path candidate_path
    logged=$(cat "$gt_log" 2>/dev/null)
    baseline_path=$(echo "$logged" | sed -n '1p')
    candidate_path=$(echo "$logged" | sed -n '2p')
    rm -rf "$tmpdir"
    # Both paths must point to mktemp-style strip worktree dirs (not
    # repo-root). Baseline mktemp prefix: "sdlc-baseline-strip", candidate:
    # "sdlc-candidate-strip". Both end in tests/e2e/fixtures/test-repo.
    if echo "$baseline_path" | grep -qE 'sdlc-baseline-strip.*tests/e2e/fixtures/test-repo$' \
       && echo "$candidate_path" | grep -qE 'sdlc-candidate-strip.*tests/e2e/fixtures/test-repo$'; then
        pass "strip-paths gate: baseline=BASELINE_DIR (intact), candidate=CANDIDATE_DIR (stripped) [Codex F-01]"
    else
        fail "strip-paths gate path resolution wrong. baseline='$baseline_path' candidate='$candidate_path'"
    fi
}
test_strip_paths_gate_uses_candidate_strip_dir

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

[ "$FAILED" -gt 0 ] && exit 1
exit 0
