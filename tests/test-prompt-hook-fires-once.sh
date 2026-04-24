#!/bin/bash
# Roadmap #224: regression test for sdlc-prompt-check.sh "fires exactly once"
# instrumentation. CC 2.1.118 shipped a fix for prompt hooks double-firing when
# an agent-hook verifier subagent itself made tool calls. We can't directly
# unit-test CC's behavior, but we can ship instrumentation that records each
# hook invocation so the maintainer can verify the fix holds in real sessions.
#
# Mechanism: when the env var SDLC_HOOK_FIRE_LOG is set, sdlc-prompt-check.sh
# appends a single line per invocation: "<unix-ts>\t<pid>\t<source-marker>".
# Maintainer procedure documented in CLAUDE_CODE_SDLC_WIZARD.md.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/sdlc-prompt-check.sh"
PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

echo "=== Prompt-Hook-Fires-Once Instrumentation Tests (Roadmap #224) ==="
echo ""

# Set up an isolated workspace with a complete SDLC project so the hook reaches
# its main code path (instead of bailing on missing SDLC.md / TESTING.md).
WORKSPACE="${TMPDIR:-/tmp}/sdlc-fire-test-$$"
mkdir -p "$WORKSPACE"
trap 'rm -rf "$WORKSPACE"' EXIT
echo "# SDLC" > "$WORKSPACE/SDLC.md"
echo "# Testing" > "$WORKSPACE/TESTING.md"
LOG="$WORKSPACE/fire.log"

invoke_hook() {
    # cd into WORKSPACE so _find-sdlc-root.sh's `pwd` walk-up finds *this*
    # workspace's SDLC.md, not whatever cwd the test is launched from.
    # Without the cd the test silently exercises the repo root and gives
    # a false-green when run from a parent dir.
    (cd "$WORKSPACE" && SDLC_HOOK_FIRE_LOG="$LOG" CLAUDE_PROJECT_DIR="$WORKSPACE" \
        bash "$HOOK" <<<'{"prompt":"hello"}')
}

invoke_hook_uninstrumented() {
    (cd "$WORKSPACE" && CLAUDE_PROJECT_DIR="$WORKSPACE" \
        bash "$HOOK" <<<'{"prompt":"hello"}')
}

test_counter_records_first_invocation() {
    : > "$LOG"
    invoke_hook > /dev/null
    local lines
    lines=$(wc -l < "$LOG" | tr -d ' ')
    if [ "$lines" = "1" ]; then
        pass "first invocation records exactly 1 line in log"
    else
        fail "first invocation recorded $lines lines (expected 1). Log:"
        cat "$LOG" | sed 's/^/  /'
    fi
}

test_counter_appends_per_invocation() {
    : > "$LOG"
    for i in 1 2 3 4 5; do
        invoke_hook > /dev/null
    done
    local lines
    lines=$(wc -l < "$LOG" | tr -d ' ')
    if [ "$lines" = "5" ]; then
        pass "5 invocations record exactly 5 lines (counter increments correctly)"
    else
        fail "5 invocations recorded $lines lines (expected 5). Log:"
        cat "$LOG" | sed 's/^/  /'
    fi
}

test_counter_is_opt_in() {
    rm -f "$LOG"
    CLAUDE_PROJECT_DIR="$WORKSPACE" bash "$HOOK" <<<'{"prompt":"hello"}' > /dev/null
    if [ ! -f "$LOG" ]; then
        pass "no SDLC_HOOK_FIRE_LOG env → no log file created (instrumentation is opt-in)"
    else
        fail "log file was created without env var being set: $LOG"
    fi
}

test_log_line_shape() {
    : > "$LOG"
    invoke_hook > /dev/null
    local line ts pid marker
    line=$(head -1 "$LOG")
    ts=$(printf '%s' "$line" | awk -F'\t' '{print $1}')
    pid=$(printf '%s' "$line" | awk -F'\t' '{print $2}')
    marker=$(printf '%s' "$line" | awk -F'\t' '{print $3}')
    if [[ "$ts" =~ ^[0-9]+$ ]] && [[ "$pid" =~ ^[0-9]+$ ]] && [ -n "$marker" ]; then
        pass "log line is tab-separated: ts=$ts pid=$pid marker=$marker"
    else
        fail "log line shape unexpected. Line: $line"
    fi
}

test_instrumentation_doesnt_break_output() {
    # Codex round 3 P1: weak assertion just checked "SDLC BASELINE: exists".
    # Strengthen: instrumented stdout/stderr must be byte-identical to the
    # non-instrumented run. Any leak (instrumentation marker on stdout, extra
    # stderr noise) would fail the diff.
    : > "$LOG"
    local with without
    with=$(invoke_hook 2>&1)
    without=$(invoke_hook_uninstrumented 2>&1)
    if [ "$with" = "$without" ]; then
        pass "instrumented output is byte-identical to non-instrumented output"
    else
        fail "instrumentation altered hook output. Diff:"
        diff <(printf '%s' "$without") <(printf '%s' "$with") | sed 's/^/  /'
    fi
}

test_unwritable_log_does_not_crash() {
    local bad_log="/this/path/does/not/exist/fire.log"
    if SDLC_HOOK_FIRE_LOG="$bad_log" CLAUDE_PROJECT_DIR="$WORKSPACE" \
        bash "$HOOK" <<<'{"prompt":"hello"}' > /dev/null 2>&1; then
        pass "hook tolerates unwritable SDLC_HOOK_FIRE_LOG path (does not crash)"
    else
        fail "hook crashed when SDLC_HOOK_FIRE_LOG was unwritable"
    fi
}

test_counter_records_first_invocation
test_counter_appends_per_invocation
test_counter_is_opt_in
test_log_line_shape
test_instrumentation_doesnt_break_output
test_unwritable_log_does_not_crash

echo ""
echo "=== Results ==="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
    exit 1
fi
echo "All instrumentation tests passed."
