#!/bin/bash
# ROADMAP #228 — evaluate.sh CLI mode (Max-subsidized via `claude --print`).
#
# Validates the EVAL_USE_CLI=1 path that swaps the per-criterion Anthropic API
# curl call for a `claude --print` invocation. CI keeps the curl path; local-
# shepherd flips to CLI so #212's "honestly zero-API" claim holds.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALUATE="$SCRIPT_DIR/e2e/evaluate.sh"
SHEPHERD="$SCRIPT_DIR/e2e/local-shepherd.sh"
PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

echo "=== Evaluator CLI Mode Tests (ROADMAP #228) ==="
echo ""

# ---- Static structure checks ----

test_evaluate_has_use_cli_branch() {
    if grep -qE 'EVAL_USE_CLI' "$EVALUATE"; then
        pass "evaluate.sh references EVAL_USE_CLI env var"
    else
        fail "evaluate.sh missing EVAL_USE_CLI branch — ROADMAP #228 not wired"
    fi
}
test_evaluate_has_use_cli_branch

test_evaluate_calls_claude_print_in_cli_mode() {
    if grep -qE 'claude[[:space:]]+--print' "$EVALUATE"; then
        pass "evaluate.sh invokes 'claude --print' in CLI mode"
    else
        fail "evaluate.sh CLI branch must call 'claude --print'"
    fi
}
test_evaluate_calls_claude_print_in_cli_mode

test_evaluate_uses_json_output_format() {
    # CLI mode needs --output-format json so we can extract `.result` reliably.
    # Match across the script (the CLI branch is one of many invocations).
    if grep -qE 'claude[[:space:]]+--print[^|]*--output-format[[:space:]]+json' "$EVALUATE" \
        || grep -qE -- '--output-format[[:space:]]+json' "$EVALUATE"; then
        pass "evaluate.sh CLI branch uses --output-format json"
    else
        fail "evaluate.sh CLI branch must pass --output-format json"
    fi
}
test_evaluate_uses_json_output_format

test_evaluate_caps_max_turns_in_cli_mode() {
    # Single-shot: --max-turns 1. Anything higher invites the agent to loop.
    if grep -qE -- '--max-turns[[:space:]]+1' "$EVALUATE"; then
        pass "evaluate.sh CLI branch caps --max-turns 1 (single-shot)"
    else
        fail "evaluate.sh CLI branch should pass --max-turns 1 to prevent agent loops"
    fi
}
test_evaluate_caps_max_turns_in_cli_mode

test_evaluate_disables_tools_in_cli_mode() {
    # Pure text classification — no tool use. Either --tools "" or
    # --disallowedTools "*" is acceptable.
    if grep -qE -- '--tools[[:space:]]+""' "$EVALUATE" \
        || grep -qE -- "--tools[[:space:]]+''" "$EVALUATE"; then
        pass "evaluate.sh CLI branch disables tools (--tools \"\")"
    else
        fail "evaluate.sh CLI branch should disable tools — pure text response"
    fi
}
test_evaluate_disables_tools_in_cli_mode

test_evaluate_isolates_mcp_in_cli_mode() {
    # Codex round 1 P1 #1: --tools "" only blocks built-in tools. MCP servers
    # configured at user level (e.g., mcp__playwright__*) still appear in
    # system.init.tools. The criterion prompt embeds untrusted execution
    # output → prompt-injection can reach those MCP tools. Both invocations
    # (initial + retry) must pass an empty MCP config + --strict-mcp-config.
    local mcp_count strict_count
    mcp_count=$(grep -cE -- "--mcp-config[[:space:]]+'\{\"mcpServers\":\{\}\}'" "$EVALUATE" || true)
    strict_count=$(grep -cE -- '--strict-mcp-config' "$EVALUATE" || true)
    if [ "$mcp_count" -ge 2 ] && [ "$strict_count" -ge 2 ]; then
        pass "evaluate.sh CLI branch isolates MCP (--mcp-config '{}' + --strict-mcp-config on both calls)"
    else
        fail "evaluate.sh CLI branch missing MCP isolation (mcp_count=$mcp_count, strict_count=$strict_count, need 2 each)"
    fi
}
test_evaluate_isolates_mcp_in_cli_mode

test_evaluate_pins_model_in_cli_mode() {
    # Codex round 1 P1 #2: curl mode hard-codes "model": "claude-opus-4-7".
    # CLI mode without --model defers to the user's CC default — defeats
    # the "same model" parity claim in CHANGELOG/ROADMAP. Both initial +
    # retry CLI invocations must explicitly pin --model claude-opus-4-7.
    local model_count
    model_count=$(grep -cE -- '--model[[:space:]]+claude-opus-4-7' "$EVALUATE" || true)
    if [ "$model_count" -ge 2 ]; then
        pass "evaluate.sh CLI branch pins --model claude-opus-4-7 on both calls"
    else
        fail "evaluate.sh CLI branch missing --model pin (count=$model_count, need >=2 — initial + retry)"
    fi
}
test_evaluate_pins_model_in_cli_mode

test_evaluate_skips_api_key_check_in_cli_mode() {
    # When EVAL_USE_CLI=1 the ANTHROPIC_API_KEY hard-fail must be conditional.
    # Look for either: (a) the env var test wraps the API key check, or
    # (b) the check sits below an early `[ ... = "1" ] && skip` guard.
    if awk '/ANTHROPIC_API_KEY/ && /Error:/' "$EVALUATE" | grep -qE 'EVAL_USE_CLI|use_cli'; then
        pass "evaluate.sh API-key check inline-references EVAL_USE_CLI"
    elif grep -B2 -E 'ANTHROPIC_API_KEY' "$EVALUATE" | grep -qE 'EVAL_USE_CLI'; then
        pass "evaluate.sh gates ANTHROPIC_API_KEY check on EVAL_USE_CLI"
    else
        fail "evaluate.sh must skip ANTHROPIC_API_KEY hard-fail when EVAL_USE_CLI=1"
    fi
}
test_evaluate_skips_api_key_check_in_cli_mode

test_evaluate_extracts_result_field() {
    # claude --print --output-format json returns an array. The text response
    # lives at .[] | select(.type=="result") | .result. Verify we extract it.
    if grep -qE 'select\(\.type[[:space:]]*==[[:space:]]*"result"\)[[:space:]]*\|[[:space:]]*\.result' "$EVALUATE"; then
        pass "evaluate.sh extracts .result from claude --print JSON output"
    else
        fail "evaluate.sh CLI branch must extract .result via jq selector"
    fi
}
test_evaluate_extracts_result_field

test_evaluate_cli_runs_in_clean_cwd() {
    # Project hooks (e.g., sdlc-prompt-check.sh) inject context that pollutes
    # the criterion prompt. CLI invocation must run from a clean cwd
    # (mktemp -d or similar) so project .claude/settings.json doesn't load.
    if grep -B5 -E 'claude[[:space:]]+--print' "$EVALUATE" | grep -qE 'mktemp|\$TMPDIR|cd /tmp'; then
        pass "evaluate.sh CLI branch runs from a clean cwd (avoids hook pollution)"
    else
        fail "evaluate.sh CLI branch should run claude --print from a clean cwd"
    fi
}
test_evaluate_cli_runs_in_clean_cwd

test_evaluate_cli_retries_on_failure() {
    # Match curl-path behavior: retry once on empty response.
    # Search the CLI block for a second `claude --print` invocation.
    local cli_print_count
    cli_print_count=$(grep -cE 'claude[[:space:]]+--print' "$EVALUATE" || true)
    if [ "$cli_print_count" -ge 2 ]; then
        pass "evaluate.sh CLI branch retries on empty response (>=2 invocations)"
    else
        fail "evaluate.sh CLI branch should retry once (only $cli_print_count claude --print calls found)"
    fi
}
test_evaluate_cli_retries_on_failure

test_evaluate_api_mode_unchanged() {
    # The default (curl) path must be intact. Look for the curl + api.anthropic
    # pair to confirm we didn't accidentally remove it.
    if grep -qE 'curl' "$EVALUATE" && grep -qE 'api\.anthropic\.com' "$EVALUATE"; then
        pass "evaluate.sh API path (curl + api.anthropic.com) intact"
    else
        fail "evaluate.sh API path missing — CLI mode must be opt-in, not replacement"
    fi
}
test_evaluate_api_mode_unchanged

# ---- Local-shepherd integration ----

test_shepherd_exports_eval_use_cli() {
    if grep -qE 'EVAL_USE_CLI=1|export EVAL_USE_CLI' "$SHEPHERD"; then
        pass "local-shepherd.sh sets EVAL_USE_CLI=1 before invoking evaluator"
    else
        fail "local-shepherd.sh must export EVAL_USE_CLI=1 to use the Max-subsidized path"
    fi
}
test_shepherd_exports_eval_use_cli

test_shepherd_no_longer_requires_api_key() {
    # The hard-fail block on missing ANTHROPIC_API_KEY must be removed or
    # gated behind a fallback flag (e.g., when EVAL_USE_CLI not set).
    if grep -B2 -A2 -E 'ANTHROPIC_API_KEY' "$SHEPHERD" | grep -qE 'exit 1' \
        && ! grep -B2 -A2 -E 'ANTHROPIC_API_KEY' "$SHEPHERD" | grep -qE '#228|EVAL_USE_CLI|claim'; then
        fail "local-shepherd.sh still hard-fails on missing ANTHROPIC_API_KEY — #228 should drop it"
    else
        pass "local-shepherd.sh no longer hard-fails on missing ANTHROPIC_API_KEY (#228 closed)"
    fi
}
test_shepherd_no_longer_requires_api_key

test_shepherd_documents_zero_api() {
    # The earlier comment said "Evaluator still hits Anthropic API (ROADMAP
    # #228 will migrate)". After this PR it must be updated.
    if grep -qE 'still hits Anthropic API|ROADMAP #228 will migrate' "$SHEPHERD"; then
        fail "local-shepherd.sh still claims evaluator hits API — comment must be updated"
    else
        pass "local-shepherd.sh comment updated (no stale '#228 will migrate' claim)"
    fi
}
test_shepherd_documents_zero_api

# ---- Dynamic mock test ----

# Verify the CLI branch actually invokes a 'claude' binary, by mocking it on
# PATH and running a single criterion through evaluate.sh's helper.
#
# We can't run the full evaluate.sh because it expects a real scenario file +
# Claude execution output. But we CAN source it... no, evaluate.sh runs at
# top level (not a function library). So the cleanest dynamic check is to
# verify the call_criterion_api function exists and can be exercised.
#
# Skip dynamic test for now — static checks above cover the protocol.

# ---- Results ----

echo ""
echo "=== Results ==="
echo "Passed: $PASSED, Failed: $FAILED"
if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
echo "All evaluate-cli-mode tests passed."
