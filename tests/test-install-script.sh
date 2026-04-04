#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_ROOT/install.sh"

PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

# --- Guard: skip content tests if file missing ---

if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo -e "${RED}FAIL${NC}: install.sh does not exist — skipping all tests"
    echo ""
    echo "=== Results ==="
    echo "Passed: 0"
    echo "Failed: 1"
    exit 1
fi

# --- Tests ---

test_script_exists() {
    if [ -f "$INSTALL_SCRIPT" ]; then
        pass "install.sh exists"
    else
        fail "install.sh does not exist"
    fi
}

test_script_is_executable() {
    if [ -x "$INSTALL_SCRIPT" ]; then
        pass "install.sh is executable"
    else
        fail "install.sh is not executable"
    fi
}

test_has_bash_shebang() {
    local first_line
    first_line=$(head -1 "$INSTALL_SCRIPT")
    if echo "$first_line" | grep -q '#!/usr/bin/env bash\|#!/bin/bash'; then
        pass "install.sh has bash shebang"
    else
        fail "install.sh shebang: got '$first_line'"
    fi
}

test_has_strict_mode() {
    if grep -q 'set -euo pipefail' "$INSTALL_SCRIPT"; then
        pass "install.sh uses strict mode (set -euo pipefail)"
    else
        fail "install.sh missing strict mode (set -euo pipefail)"
    fi
}

test_has_download_guard() {
    # Script should be wrapped in { } to prevent partial execution
    # First non-comment, non-shebang, non-blank, non-set line should be {
    local body_start
    body_start=$(grep -n '^{' "$INSTALL_SCRIPT" | head -1 | cut -d: -f1)
    local body_end
    body_end=$(tail -1 "$INSTALL_SCRIPT")

    if [ -n "$body_start" ] && echo "$body_end" | grep -q '^}'; then
        pass "install.sh has { } download guard"
    else
        fail "install.sh missing { } download guard (first body line should be '{', last line should be '}')"
    fi
}

test_checks_node() {
    if grep -q 'command -v node' "$INSTALL_SCRIPT"; then
        pass "install.sh checks for Node.js"
    else
        fail "install.sh does not check for Node.js (command -v node)"
    fi
}

test_checks_node_version() {
    if grep -q '18' "$INSTALL_SCRIPT" && grep -qE 'node -v|node --version' "$INSTALL_SCRIPT"; then
        pass "install.sh checks Node.js version >= 18"
    else
        fail "install.sh does not check Node.js version >= 18"
    fi
}

test_checks_npm() {
    if grep -q 'command -v npm' "$INSTALL_SCRIPT" || grep -q 'command -v npx' "$INSTALL_SCRIPT"; then
        pass "install.sh checks for npm/npx"
    else
        fail "install.sh does not check for npm/npx"
    fi
}

test_handles_global_flag() {
    if grep -q '\-\-global' "$INSTALL_SCRIPT"; then
        pass "install.sh handles --global flag"
    else
        fail "install.sh does not handle --global flag"
    fi
}

test_handles_help_flag() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --help 2>&1) || true
    if echo "$output" | grep -qi 'usage\|install\|sdlc'; then
        pass "install.sh --help shows usage info"
    else
        fail "install.sh --help does not show usage info"
    fi
}

test_no_hardcoded_tmp() {
    # Should use TMPDIR variable, not hardcoded /tmp
    if grep -q '"/tmp' "$INSTALL_SCRIPT"; then
        fail "install.sh has hardcoded /tmp path (use \$TMPDIR)"
    else
        pass "install.sh has no hardcoded /tmp paths"
    fi
}

test_colors_conditional_on_terminal() {
    if grep -q '\-t 1\|tput' "$INSTALL_SCRIPT"; then
        pass "install.sh conditionalizes colors on terminal"
    else
        fail "install.sh does not check for terminal before using colors"
    fi
}

test_references_correct_package() {
    if grep -q 'agentic-sdlc-wizard' "$INSTALL_SCRIPT"; then
        pass "install.sh references correct npm package name"
    else
        fail "install.sh does not reference agentic-sdlc-wizard"
    fi
}

test_has_error_function() {
    if grep -qE '^error\(\)|^  error\(\)' "$INSTALL_SCRIPT" || grep -q 'error()' "$INSTALL_SCRIPT"; then
        pass "install.sh has error() helper function"
    else
        fail "install.sh missing error() helper function"
    fi
}

# --- Integration tests (live execution) ---

make_temp() {
    local d
    d=$(mktemp -d "${TMPDIR:-/tmp}/sdlc-install-test-XXXXXX")
    echo "$d"
}

test_piped_install_creates_files() {
    local dir
    dir=$(make_temp)

    # Simulate curl | bash by piping file to bash
    (cd "$dir" && cat "$INSTALL_SCRIPT" | bash) >/dev/null 2>&1

    local expected_files=(
        ".claude/settings.json"
        ".claude/hooks/sdlc-prompt-check.sh"
        ".claude/hooks/tdd-pretool-check.sh"
        ".claude/hooks/instructions-loaded-check.sh"
        ".claude/skills/sdlc/SKILL.md"
        ".claude/skills/setup/SKILL.md"
        ".claude/skills/update/SKILL.md"
        ".claude/skills/feedback/SKILL.md"
        "CLAUDE_CODE_SDLC_WIZARD.md"
    )

    local missing=0
    for f in "${expected_files[@]}"; do
        if [ ! -f "$dir/$f" ]; then
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -eq 0 ]; then
        pass "Piped install (curl|bash) creates all 9 wizard files"
    else
        fail "Piped install missing $missing of 9 expected files"
    fi

    rm -rf "$dir"
}

test_piped_install_hooks_executable() {
    local dir
    dir=$(make_temp)

    (cd "$dir" && cat "$INSTALL_SCRIPT" | bash) >/dev/null 2>&1

    local all_exec=true
    for hook in sdlc-prompt-check.sh tdd-pretool-check.sh instructions-loaded-check.sh; do
        if [ ! -x "$dir/.claude/hooks/$hook" ]; then
            all_exec=false
        fi
    done

    if [ "$all_exec" = true ]; then
        pass "Piped install sets hooks as executable"
    else
        fail "Piped install did not set all hooks as executable"
    fi

    rm -rf "$dir"
}

test_piped_help_works() {
    local output
    output=$(cat "$INSTALL_SCRIPT" | bash -s -- --help 2>&1) || true
    if echo "$output" | grep -qi 'usage\|install\|sdlc'; then
        pass "Piped --help works (cat script | bash -s -- --help)"
    else
        fail "Piped --help did not show usage"
    fi
}

test_rejects_unknown_args() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --foo 2>&1) || true
    if echo "$output" | grep -qi 'unknown option'; then
        pass "install.sh rejects unknown arguments"
    else
        fail "install.sh does not reject unknown arguments (got: '$output')"
    fi
}

test_npx_auto_confirm() {
    # Regression: npx without -y hangs when piped from curl (stdin exhausted)
    if grep -q 'npx -y' "$INSTALL_SCRIPT"; then
        pass "install.sh uses npx -y (auto-confirm for piped execution)"
    else
        fail "install.sh uses npx without -y flag (will hang when piped from curl)"
    fi
}

test_shebang_no_escaped_bang() {
    # Regression: heredoc-created scripts can get #\! instead of #!
    # This caused exec format error in gh-sdlc-wizard
    local first_bytes
    first_bytes=$(xxd -l 2 -p "$INSTALL_SCRIPT")
    if [ "$first_bytes" = "2321" ]; then
        pass "Shebang is #! (not escaped #\\!)"
    else
        fail "Shebang bytes are '$first_bytes' — expected '2321' (#!)"
    fi
}

# --- Run tests ---

# Structural tests
test_script_exists
test_script_is_executable
test_has_bash_shebang
test_has_strict_mode
test_has_download_guard
test_checks_node
test_checks_node_version
test_checks_npm
test_handles_global_flag
test_handles_help_flag
test_no_hardcoded_tmp
test_colors_conditional_on_terminal
test_references_correct_package
test_has_error_function
test_rejects_unknown_args
test_npx_auto_confirm
test_shebang_no_escaped_bang

# Integration tests (live execution)
test_piped_install_creates_files
test_piped_install_hooks_executable
test_piped_help_works

# --- Results ---

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
