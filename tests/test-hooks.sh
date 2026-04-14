#!/bin/bash
# Test hook scripts
# Tests: output keywords, JSON handling, missing jq behavior

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
PASSED=0
FAILED=0

# Color output
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

echo "=== Hook Script Tests ==="
echo ""

# ---- sdlc-prompt-check.sh tests ----

# Test 1: Script exists and is executable
test_sdlc_hook_exists() {
    if [ -x "$HOOKS_DIR/sdlc-prompt-check.sh" ]; then
        pass "sdlc-prompt-check.sh exists and is executable"
    else
        fail "sdlc-prompt-check.sh not found or not executable"
    fi
}

# Test 2: Output contains SDLC keywords
test_sdlc_hook_keywords() {
    local output
    output=$("$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    local has_all=true
    for keyword in "TodoWrite" "CONFIDENCE" "TDD" "TESTS" "SDLC"; do
        if ! echo "$output" | grep -qi "$keyword"; then
            has_all=false
            break
        fi
    done
    if [ "$has_all" = "true" ]; then
        pass "sdlc-prompt-check.sh contains all required keywords"
    else
        fail "sdlc-prompt-check.sh missing expected keywords"
    fi
}

# Test 3: Output contains skill auto-invoke rules
test_sdlc_hook_auto_invoke() {
    local output
    output=$("$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    if echo "$output" | grep -q "AUTO-INVOKE"; then
        pass "sdlc-prompt-check.sh contains AUTO-INVOKE rules"
    else
        fail "sdlc-prompt-check.sh should contain AUTO-INVOKE rules"
    fi
}

# Test 4: Output contains workflow phases
test_sdlc_hook_phases() {
    local output
    output=$("$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    if echo "$output" | grep -q "Plan Mode" && echo "$output" | grep -q "Implementation"; then
        pass "sdlc-prompt-check.sh contains workflow phases"
    else
        fail "sdlc-prompt-check.sh should contain workflow phases"
    fi
}

# Test 5: Output is reasonably sized (< 1000 chars for token efficiency)
test_sdlc_hook_size() {
    local output
    output=$("$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    local size
    size=$(echo "$output" | wc -c | tr -d ' ')
    if [ "$size" -lt 1000 ]; then
        pass "sdlc-prompt-check.sh output is token-efficient (${size} chars)"
    else
        fail "sdlc-prompt-check.sh output too large (${size} chars, should be <1000)"
    fi
}

# ---- tdd-pretool-check.sh tests ----

# Test 6: Script exists and is executable
test_tdd_hook_exists() {
    if [ -x "$HOOKS_DIR/tdd-pretool-check.sh" ]; then
        pass "tdd-pretool-check.sh exists and is executable"
    else
        fail "tdd-pretool-check.sh not found or not executable"
    fi
}

# Test 7: Source file edit produces TDD warning JSON
test_tdd_hook_src_warning() {
    local input='{"tool_input": {"file_path": "/project/src/app.js"}}'
    local output
    output=$(echo "$input" | "$HOOKS_DIR/tdd-pretool-check.sh" 2>/dev/null)
    if echo "$output" | grep -q "TDD CHECK"; then
        pass "tdd-pretool-check.sh warns on src/ file edits"
    else
        fail "Should warn when editing src/ files, got: $output"
    fi
}

# Test 8: Source file edit produces valid JSON output
test_tdd_hook_valid_json() {
    local input='{"tool_input": {"file_path": "/project/src/utils/helper.ts"}}'
    local output
    output=$(echo "$input" | "$HOOKS_DIR/tdd-pretool-check.sh" 2>/dev/null)
    if echo "$output" | jq -e '.hookSpecificOutput' > /dev/null 2>&1; then
        pass "tdd-pretool-check.sh outputs valid JSON for src/ edits"
    else
        fail "Output should be valid JSON with hookSpecificOutput, got: $output"
    fi
}

# Test 9: Test file edit exits cleanly (no warning)
test_tdd_hook_test_file_ok() {
    local input='{"tool_input": {"file_path": "tests/test-something.sh"}}'
    local output
    output=$(echo "$input" | "$HOOKS_DIR/tdd-pretool-check.sh" 2>/dev/null)
    if [ -z "$output" ]; then
        pass "tdd-pretool-check.sh allows test file edits silently"
    else
        fail "Test file edits should produce no output, got: $output"
    fi
}

# Test 10: Non-workflow, non-test file produces no output
test_tdd_hook_other_file_ok() {
    local input='{"tool_input": {"file_path": "README.md"}}'
    local output
    output=$(echo "$input" | "$HOOKS_DIR/tdd-pretool-check.sh" 2>/dev/null)
    if [ -z "$output" ]; then
        pass "tdd-pretool-check.sh allows other file edits silently"
    else
        fail "Non-workflow edits should produce no output, got: $output"
    fi
}

# Test 11: Missing file_path in input handled gracefully
test_tdd_hook_missing_path() {
    local input='{"tool_input": {}}'
    local output
    output=$(echo "$input" | "$HOOKS_DIR/tdd-pretool-check.sh" 2>/dev/null)
    local exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        pass "tdd-pretool-check.sh handles missing file_path gracefully"
    else
        fail "Should handle missing file_path without crashing, exit code: $exit_code"
    fi
}

# ---- instructions-loaded-check.sh tests ----

# Test 12: Script exists and is executable
test_instructions_hook_exists() {
    if [ -x "$HOOKS_DIR/instructions-loaded-check.sh" ]; then
        pass "instructions-loaded-check.sh exists and is executable"
    else
        fail "instructions-loaded-check.sh not found or not executable"
    fi
}

# Test 13: Warns when SDLC.md is missing
test_instructions_hook_missing_sdlc() {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/TESTING.md"
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -qi "SDLC.md"; then
        pass "instructions-loaded-check.sh warns when SDLC.md missing"
    else
        fail "Should warn about missing SDLC.md, got: $output"
    fi
}

# Test 14: Warns when TESTING.md is missing
test_instructions_hook_missing_testing() {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/SDLC.md"
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -qi "TESTING.md"; then
        pass "instructions-loaded-check.sh warns when TESTING.md missing"
    else
        fail "Should warn about missing TESTING.md, got: $output"
    fi
}

# Test 15: Warns when both are missing
test_instructions_hook_missing_both() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -qi "SDLC.md" && echo "$output" | grep -qi "TESTING.md"; then
        pass "instructions-loaded-check.sh warns when both files missing"
    else
        fail "Should warn about both missing files, got: $output"
    fi
}

# Test 16: No warning when both files exist
test_instructions_hook_all_present() {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    # Mock claude + npm so CC version check doesn't produce output
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/bash\nif [ "$1" = "--version" ]; then echo "2.1.90 (Claude Code)"; else echo "1.23.0"; fi\n' > "$tmpdir/bin/claude"
    printf '#!/bin/bash\nif [ "$1" = "view" ] && echo "$@" | grep -q "claude-code"; then echo "2.1.90"; elif [ "$1" = "view" ]; then echo "1.23.0"; fi\n' > "$tmpdir/bin/npm"
    printf '#!/bin/bash\nexit 1\n' > "$tmpdir/bin/codex"
    chmod +x "$tmpdir/bin/claude" "$tmpdir/bin/npm" "$tmpdir/bin/codex"
    local output
    output=$(cd "$tmpdir" && PATH="$tmpdir/bin:$PATH" CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if [ -z "$output" ]; then
        pass "instructions-loaded-check.sh silent when all files present"
    else
        fail "Should produce no output when files exist, got: $output"
    fi
}

# Test 17: Exits cleanly (exit 0) regardless of missing files
test_instructions_hook_exit_code() {
    local tmpdir
    tmpdir=$(mktemp -d)
    (cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh") > /dev/null 2>&1
    local exit_code=$?
    rm -rf "$tmpdir"
    if [ "$exit_code" -eq 0 ]; then
        pass "instructions-loaded-check.sh exits cleanly even with missing files"
    else
        fail "Should exit 0 even when files missing, got exit code: $exit_code"
    fi
}

# Test 18: Hook output has no trailing whitespace
test_instructions_hook_no_trailing_whitespace() {
    local tmpdir
    tmpdir=$(mktemp -d)
    # Both files missing = worst case for trailing whitespace
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    # Check that no line ends with trailing whitespace (runtime output)
    if echo "$output" | grep -q '[[:blank:]]$'; then
        fail "instructions-loaded-check.sh output has trailing whitespace"
        return
    fi
    # Also check the script source itself for baked-in trailing whitespace
    if grep -q '[[:blank:]]$' "$HOOKS_DIR/instructions-loaded-check.sh"; then
        fail "instructions-loaded-check.sh source has trailing whitespace"
    else
        pass "instructions-loaded-check.sh output has no trailing whitespace"
    fi
}

# ---- Setup completeness tests (wizard dogfood) ----

# Test 19: SDLC.md contains wizard version metadata comment
test_sdlc_version_metadata() {
    local sdlc_md="$SCRIPT_DIR/../SDLC.md"
    if grep -q '<!-- SDLC Wizard Version: [0-9]' "$sdlc_md"; then
        pass "SDLC.md contains wizard version metadata comment"
    else
        fail "SDLC.md should contain <!-- SDLC Wizard Version: X.X.X --> metadata comment"
    fi
}

# Test 20: SDLC.md wizard version matches wizard document version
test_sdlc_version_matches_wizard() {
    local sdlc_md="$SCRIPT_DIR/../SDLC.md"
    local wizard="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"

    local installed_version
    installed_version=$(grep -o 'SDLC Wizard Version: [0-9.]*' "$sdlc_md" | head -1 | sed 's/SDLC Wizard Version: //')
    local wizard_version
    wizard_version=$(grep -o 'SDLC Wizard Version: [0-9.]*' "$wizard" | head -1 | sed 's/SDLC Wizard Version: //')

    if [ -z "$installed_version" ]; then
        fail "Could not extract version from SDLC.md"
        return
    fi
    if [ "$installed_version" = "$wizard_version" ]; then
        pass "SDLC.md version ($installed_version) matches wizard ($wizard_version)"
    else
        fail "SDLC.md version ($installed_version) != wizard version ($wizard_version)"
    fi
}

# Test 21: SDLC.md contains setup date metadata
test_sdlc_setup_date() {
    local sdlc_md="$SCRIPT_DIR/../SDLC.md"
    if grep -q '<!-- Setup Date: [0-9]' "$sdlc_md"; then
        pass "SDLC.md contains setup date metadata comment"
    else
        fail "SDLC.md should contain <!-- Setup Date: YYYY-MM-DD --> metadata comment"
    fi
}

# Test 22: SDLC.md contains completed steps metadata
test_sdlc_completed_steps() {
    local sdlc_md="$SCRIPT_DIR/../SDLC.md"
    if grep -q '<!-- Completed Steps:' "$sdlc_md"; then
        pass "SDLC.md contains completed steps metadata comment"
    else
        fail "SDLC.md should contain <!-- Completed Steps: ... --> metadata comment"
    fi
}

# Test 23: Light hook references /code-review (not outdated subagent pattern)
test_sdlc_hook_self_review_reference() {
    local output
    output=$("$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    if echo "$output" | grep -q "/code-review"; then
        pass "sdlc-prompt-check.sh references /code-review for self-review"
    else
        fail "sdlc-prompt-check.sh should reference /code-review, not outdated subagent pattern"
    fi
}

# Test 24: SDLC.md update frequency says weekly (not daily)
test_sdlc_update_frequency() {
    local sdlc_md="$SCRIPT_DIR/../SDLC.md"
    if grep -qi "daily.*workflow.*checks\|daily.*checks.*for.*update" "$sdlc_md"; then
        fail "SDLC.md says 'daily' but update workflow runs weekly"
    else
        pass "SDLC.md does not falsely claim daily update checks"
    fi
}

# Test 25: instructions-loaded-check.sh mentions setup-wizard when files missing
test_instructions_hook_mentions_setup_wizard() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "setup-wizard"; then
        pass "instructions-loaded-check.sh mentions setup-wizard when files missing"
    else
        fail "Should mention setup-wizard skill invocation, got: $output"
    fi
}

# Test 26: sdlc-prompt-check outputs setup-wizard directive when SDLC.md missing
test_sdlc_hook_setup_redirect_missing_sdlc() {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/TESTING.md"
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "setup-wizard" && ! echo "$output" | grep -q "SDLC BASELINE"; then
        pass "sdlc-prompt-check.sh redirects to setup-wizard when SDLC.md missing"
    else
        fail "Should output setup-wizard directive (not SDLC BASELINE) when SDLC.md missing"
    fi
}

# Test 27: sdlc-prompt-check outputs setup-wizard directive when TESTING.md missing
test_sdlc_hook_setup_redirect_missing_testing() {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/SDLC.md"
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "setup-wizard" && ! echo "$output" | grep -q "SDLC BASELINE"; then
        pass "sdlc-prompt-check.sh redirects to setup-wizard when TESTING.md missing"
    else
        fail "Should output setup-wizard directive (not SDLC BASELINE) when TESTING.md missing"
    fi
}

# Test 28: sdlc-prompt-check outputs normal baseline when both files exist (non-empty)
test_sdlc_hook_normal_when_setup_complete() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "# SDLC" > "$tmpdir/SDLC.md"
    echo "# Testing" > "$tmpdir/TESTING.md"
    local output
    output=$(CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "SDLC BASELINE" && ! echo "$output" | grep -q "SETUP NOT COMPLETE"; then
        pass "sdlc-prompt-check.sh outputs normal baseline when setup complete"
    else
        fail "Should output SDLC BASELINE (not setup redirect) when both files exist"
    fi
}

# Test 29: sdlc-prompt-check redirects when files are empty stubs
test_sdlc_hook_setup_redirect_empty_stubs() {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "setup-wizard" && ! echo "$output" | grep -q "SDLC BASELINE"; then
        pass "sdlc-prompt-check.sh redirects to setup-wizard for empty stub files"
    else
        fail "Empty stub files should trigger setup-wizard redirect, not baseline"
    fi
}

# Test 30: Template hook behaves identically to repo hook (post-install execution test)
test_template_hook_setup_redirect() {
    local TEMPLATE_HOOK="$SCRIPT_DIR/../hooks/sdlc-prompt-check.sh"
    if [ ! -f "$TEMPLATE_HOOK" ]; then fail "Template hook not found"; return; fi
    local tmpdir
    tmpdir=$(mktemp -d)
    # Templates aren't executable in repo — CLI sets chmod +x at install time
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$tmpdir" bash "$TEMPLATE_HOOK" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "setup-wizard"; then
        pass "Template hook redirects to setup-wizard when files missing"
    else
        fail "Template hook should redirect to setup-wizard, got: $output"
    fi
}

# ---- Effort level recommendation tests ----

# Test 31: Wizard doc has "Effort Level" section
test_wizard_effort_level_section() {
    local wizard="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"
    if grep -q "## .*Effort Level" "$wizard"; then
        pass "Wizard doc has Effort Level section"
    else
        fail "Wizard doc should have an Effort Level section"
    fi
}

# Test 32: Wizard doc recommends high as default effort
test_wizard_effort_high_default() {
    local wizard="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"
    if grep -qi "high.*default\|default.*high" "$wizard" && grep -q "effort.*high\|high.*effort" "$wizard"; then
        pass "Wizard doc recommends high as default effort"
    else
        fail "Wizard doc should recommend high as the default effort level"
    fi
}

# Test 33: Wizard confidence table mentions /effort max for LOW confidence
test_wizard_confidence_effort_max() {
    local wizard="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"
    if grep -q '/effort max' "$wizard" && grep -q 'LOW' "$wizard"; then
        # Verify they appear in proximity (within the confidence table area)
        local section
        section=$(sed -n '/## Confidence Check/,/^## /p' "$wizard")
        if echo "$section" | grep -q '/effort max'; then
            pass "Wizard confidence table mentions /effort max"
        else
            fail "Wizard confidence table should mention /effort max for LOW confidence"
        fi
    else
        fail "Wizard should mention /effort max in confidence section"
    fi
}

# Test 34: SDLC skill confidence table mentions /effort max for LOW confidence
test_skill_confidence_effort_max() {
    local skill="$SCRIPT_DIR/../.claude/skills/sdlc/SKILL.md"
    local section
    section=$(sed -n '/## Confidence Check/,/^## /p' "$skill")
    if echo "$section" | grep -q '/effort max'; then
        pass "SDLC skill confidence table mentions /effort max"
    else
        fail "SDLC skill confidence table should mention /effort max for LOW confidence"
    fi
}

# ---------------------------------------------------------------------------
# SDLC Enforcement Gap Audit Tests
# Verify that documented SDLC sections have TodoWrite enforcement
# ---------------------------------------------------------------------------

SKILL_TEMPLATE="$SCRIPT_DIR/../skills/sdlc/SKILL.md"

# Test: TodoWrite checklist has "capture learnings" / "after session" task
test_todowrite_has_capture_learnings() {
    local todowrite_section
    todowrite_section=$(sed -n '/^TodoWrite(\[/,/^\])/p' "$SKILL_TEMPLATE")
    if echo "$todowrite_section" | grep -qi 'capture.*learning\|after.*session\|learnings'; then
        pass "TodoWrite has capture learnings task"
    else
        fail "TodoWrite missing capture learnings task — After Session section not enforced"
    fi
}

# Test: TodoWrite checklist has scope guard / stay in lane reminder
test_todowrite_has_scope_guard() {
    local todowrite_section
    todowrite_section=$(sed -n '/^TodoWrite(\[/,/^\])/p' "$SKILL_TEMPLATE")
    if echo "$todowrite_section" | grep -qi 'scope.*guard\|stay.*lane\|scope.*check\|only.*related'; then
        pass "TodoWrite has scope guard task"
    else
        fail "TodoWrite missing scope guard task — Scope Guard section not enforced"
    fi
}

# Test: TodoWrite checklist has deployment conditional tasks
test_todowrite_has_deploy_tasks() {
    local todowrite_section
    todowrite_section=$(sed -n '/^TodoWrite(\[/,/^\])/p' "$SKILL_TEMPLATE")
    if echo "$todowrite_section" | grep -qi 'deploy\|post-deploy\|deployment'; then
        pass "TodoWrite has deployment tasks"
    else
        fail "TodoWrite missing deployment tasks — Deployment section not enforced"
    fi
}

# Test: TodoWrite checklist has new pattern approval check
test_todowrite_has_new_pattern_check() {
    local todowrite_section
    todowrite_section=$(sed -n '/^TodoWrite(\[/,/^\])/p' "$SKILL_TEMPLATE")
    if echo "$todowrite_section" | grep -qi 'new.*pattern\|pattern.*approv\|pattern.*exist'; then
        pass "TodoWrite has new pattern approval check"
    else
        fail "TodoWrite missing new pattern check — New Pattern section not enforced"
    fi
}

# Test: TodoWrite checklist has legacy/delete code check
test_todowrite_has_legacy_delete_check() {
    local todowrite_section
    todowrite_section=$(sed -n '/^TodoWrite(\[/,/^\])/p' "$SKILL_TEMPLATE")
    if echo "$todowrite_section" | grep -qi 'legacy\|delete.*old\|fallback.*code\|backward.*compat'; then
        pass "TodoWrite has legacy code delete check"
    else
        fail "TodoWrite missing legacy delete check — DELETE Legacy Code section not enforced"
    fi
}

# Test: Enforcement coverage score — count documented sections with TodoWrite tasks
# This is the "audit score" — tracks how many prose sections have enforcement
test_enforcement_coverage_score() {
    local todowrite_section
    todowrite_section=$(sed -n '/^TodoWrite(\[/,/^\])/p' "$SKILL_TEMPLATE")
    local enforced=0
    local total=12

    # Already enforced (baseline)
    echo "$todowrite_section" | grep -qi 'doc\|read.*doc' && enforced=$((enforced + 1))          # Planning: read docs
    echo "$todowrite_section" | grep -qi 'DRY\|reuse\|pattern.*exist' && enforced=$((enforced + 1)) # DRY scan
    echo "$todowrite_section" | grep -qi 'blast.*radius\|depend' && enforced=$((enforced + 1))    # Blast radius
    echo "$todowrite_section" | grep -qi 'confidence' && enforced=$((enforced + 1))                # Confidence
    echo "$todowrite_section" | grep -qi 'TDD RED\|failing test' && enforced=$((enforced + 1))    # TDD RED
    echo "$todowrite_section" | grep -qi 'self.review\|code.review' && enforced=$((enforced + 1)) # Self-review
    echo "$todowrite_section" | grep -qi 'security' && enforced=$((enforced + 1))                  # Security review

    # New enforcement (gaps we're fixing)
    echo "$todowrite_section" | grep -qi 'capture.*learning\|after.*session' && enforced=$((enforced + 1))  # After Session
    echo "$todowrite_section" | grep -qi 'scope.*guard\|stay.*lane\|scope.*check' && enforced=$((enforced + 1))   # Scope Guard
    echo "$todowrite_section" | grep -qi 'deploy' && enforced=$((enforced + 1))                    # Deploy tasks
    echo "$todowrite_section" | grep -qi 'new.*pattern\|pattern.*approv' && enforced=$((enforced + 1))  # New pattern
    echo "$todowrite_section" | grep -qi 'legacy\|delete.*old\|fallback' && enforced=$((enforced + 1))  # Legacy delete

    if [ "$enforced" -ge "$total" ]; then
        pass "Enforcement coverage: $enforced/$total documented sections have TodoWrite tasks"
    else
        fail "Enforcement coverage: $enforced/$total — missing TodoWrite tasks for $((total - enforced)) documented sections"
    fi
}

# Run all tests
test_sdlc_hook_exists
test_sdlc_hook_keywords
test_sdlc_hook_auto_invoke
test_sdlc_hook_phases
test_sdlc_hook_size
test_tdd_hook_exists
test_tdd_hook_src_warning
test_tdd_hook_valid_json
test_tdd_hook_test_file_ok
test_tdd_hook_other_file_ok
test_tdd_hook_missing_path
test_instructions_hook_exists
test_instructions_hook_missing_sdlc
test_instructions_hook_missing_testing
test_instructions_hook_missing_both
test_instructions_hook_all_present
test_instructions_hook_exit_code
test_instructions_hook_no_trailing_whitespace
test_sdlc_version_metadata
test_sdlc_version_matches_wizard
test_sdlc_setup_date
test_sdlc_completed_steps
test_sdlc_hook_self_review_reference
test_sdlc_update_frequency
test_instructions_hook_mentions_setup_wizard
test_sdlc_hook_setup_redirect_missing_sdlc
test_sdlc_hook_setup_redirect_missing_testing
test_sdlc_hook_normal_when_setup_complete
test_sdlc_hook_setup_redirect_empty_stubs
test_template_hook_setup_redirect
test_wizard_effort_level_section
test_wizard_effort_high_default
test_wizard_confidence_effort_max
test_skill_confidence_effort_max

echo ""
echo "--- Update notification tests ---"

# Test 35: Shows update notification when newer version available
test_update_notification_newer_available() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo '<!-- SDLC Wizard Version: 1.20.0 -->' > "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    # Create fake npm that returns a newer version
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/bash\necho "1.22.0"\n' > "$tmpdir/bin/npm"
    chmod +x "$tmpdir/bin/npm"
    local output
    output=$(cd "$tmpdir" && PATH="$tmpdir/bin:$PATH" CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "update available" && echo "$output" | grep -q "1.20.0" && echo "$output" | grep -q "1.22.0"; then
        pass "Shows update notification when newer version available"
    else
        fail "Should show update notification with both versions, got: $output"
    fi
}

# Test 36: No notification when versions match
test_update_notification_same_version() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo '<!-- SDLC Wizard Version: 1.22.0 -->' > "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/bash\nif echo "$@" | grep -q "claude-code"; then echo "2.1.90"; else echo "1.22.0"; fi\n' > "$tmpdir/bin/npm"
    printf '#!/bin/bash\necho "2.1.90 (Claude Code)"\n' > "$tmpdir/bin/claude"
    chmod +x "$tmpdir/bin/npm" "$tmpdir/bin/claude"
    local output
    output=$(cd "$tmpdir" && PATH="$tmpdir/bin:$PATH" CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "update available"; then
        fail "Should NOT show update notification when versions match, got: $output"
    else
        pass "No update notification when versions match"
    fi
}

# Test 37: No notification when npm is not available
test_update_notification_npm_unavailable() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo '<!-- SDLC Wizard Version: 1.20.0 -->' > "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    # Empty bin dir — npm not in PATH
    mkdir -p "$tmpdir/bin"
    local output
    output=$(cd "$tmpdir" && PATH="$tmpdir/bin" CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    local exit_code=$?
    rm -rf "$tmpdir"
    if [ "$exit_code" -eq 0 ] && ! echo "$output" | grep -q "update available"; then
        pass "No notification and exit 0 when npm unavailable"
    else
        fail "Should silently skip when npm unavailable, exit=$exit_code, got: $output"
    fi
}

# Test 38: No notification when npm fails (e.g., network error)
test_update_notification_npm_fails() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo '<!-- SDLC Wizard Version: 1.20.0 -->' > "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/bash\nexit 1\n' > "$tmpdir/bin/npm"
    chmod +x "$tmpdir/bin/npm"
    local output
    output=$(cd "$tmpdir" && PATH="$tmpdir/bin:$PATH" CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    local exit_code=$?
    rm -rf "$tmpdir"
    if [ "$exit_code" -eq 0 ] && ! echo "$output" | grep -q "update available"; then
        pass "No notification and exit 0 when npm fails"
    else
        fail "Should silently skip when npm fails, exit=$exit_code, got: $output"
    fi
}

# Test 39: No notification when SDLC.md lacks version metadata
test_update_notification_no_version_metadata() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "# SDLC Config" > "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/bash\nif echo "$@" | grep -q "claude-code"; then echo "2.1.90"; else echo "1.22.0"; fi\n' > "$tmpdir/bin/npm"
    printf '#!/bin/bash\necho "2.1.90 (Claude Code)"\n' > "$tmpdir/bin/claude"
    chmod +x "$tmpdir/bin/npm" "$tmpdir/bin/claude"
    local output
    output=$(cd "$tmpdir" && PATH="$tmpdir/bin:$PATH" CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "Wizard.*update available"; then
        fail "Should NOT show wizard notification when SDLC.md has no version metadata, got: $output"
    else
        pass "No notification when SDLC.md lacks version metadata"
    fi
}

# Test 40: Update notification mentions /update-wizard
test_update_notification_mentions_update_wizard() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo '<!-- SDLC Wizard Version: 1.20.0 -->' > "$tmpdir/SDLC.md"
    touch "$tmpdir/TESTING.md"
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/bash\necho "1.22.0"\n' > "$tmpdir/bin/npm"
    chmod +x "$tmpdir/bin/npm"
    local output
    output=$(cd "$tmpdir" && PATH="$tmpdir/bin:$PATH" CLAUDE_PROJECT_DIR="$tmpdir" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "/update-wizard"; then
        pass "Update notification mentions /update-wizard"
    else
        fail "Update notification should mention /update-wizard, got: $output"
    fi
}

test_update_notification_newer_available
test_update_notification_same_version
test_update_notification_npm_unavailable
test_update_notification_npm_fails
test_update_notification_no_version_metadata
test_update_notification_mentions_update_wizard

echo ""
echo "--- Hook if-conditional tests (#68) ---"

# Test: settings.json PreToolUse hook has `if` field
test_settings_has_if_field() {
    local settings="$SCRIPT_DIR/../.claude/settings.json"
    local if_value
    if_value=$(jq -r '.hooks.PreToolUse[0].hooks[0].if // empty' "$settings")
    if [ -n "$if_value" ]; then
        pass "settings.json PreToolUse hook has 'if' field"
    else
        fail "settings.json PreToolUse hook should have 'if' field for conditional filtering"
    fi
}

# Test: if field targets workflow files (*.yml in .github/workflows/)
test_if_field_targets_workflows() {
    local settings="$SCRIPT_DIR/../.claude/settings.json"
    local if_value
    if_value=$(jq -r '.hooks.PreToolUse[0].hooks[0].if // empty' "$settings")
    if echo "$if_value" | grep -qF '.github/workflows/'; then
        pass "if field targets .github/workflows/ files"
    else
        fail "if field should target .github/workflows/ files, got: $if_value"
    fi
}

# Test: CLI template settings.json also has if field
test_template_settings_has_if_field() {
    local template="$SCRIPT_DIR/../cli/templates/settings.json"
    local if_value
    if_value=$(jq -r '.hooks.PreToolUse[0].hooks[0].if // empty' "$template")
    if [ -n "$if_value" ]; then
        pass "CLI template settings.json PreToolUse hook has 'if' field"
    else
        fail "CLI template settings.json should have 'if' field matching repo settings"
    fi
}

# Test: Wizard doc documents the if field
test_wizard_documents_if_field() {
    local wizard="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"
    if grep -q '"if"' "$wizard" || grep -q '`if`.*field\|`if`.*hook\|hook.*`if`' "$wizard"; then
        pass "Wizard doc documents the if field"
    else
        fail "Wizard doc should document the hook if field"
    fi
}

# Test: Wizard settings.json example includes if field
test_wizard_settings_example_has_if() {
    local wizard="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"
    # The settings.json code block in the wizard should show the if field
    if grep -q '"if":' "$wizard"; then
        pass "Wizard settings.json example includes if field"
    else
        fail "Wizard settings.json example should include the if field"
    fi
}

# Test: if field in repo settings matches template settings (parity)
test_if_field_parity() {
    local settings="$SCRIPT_DIR/../.claude/settings.json"
    local template="$SCRIPT_DIR/../cli/templates/settings.json"
    local repo_if template_if
    repo_if=$(jq -r '.hooks.PreToolUse[0].hooks[0].if // empty' "$settings")
    template_if=$(jq -r '.hooks.PreToolUse[0].hooks[0].if // empty' "$template")
    # Template uses /src/ pattern, repo uses .github/workflows/ — both should have if field
    # but values differ because repo is customized for this meta-project
    if [ -n "$repo_if" ] && [ -n "$template_if" ]; then
        pass "Both repo and template settings have if field (parity check)"
    else
        fail "Both repo ($repo_if) and template ($template_if) should have if field"
    fi
}

test_settings_has_if_field
test_if_field_targets_workflows
test_template_settings_has_if_field
test_wizard_documents_if_field
test_wizard_settings_example_has_if
test_if_field_parity

echo ""
echo "--- CWD walk-up tests (#171: monorepo / nested project support) ---"

# Test: Shared helper _find-sdlc-root.sh exists
test_find_sdlc_root_helper_exists() {
    if [ -f "$HOOKS_DIR/_find-sdlc-root.sh" ]; then
        pass "_find-sdlc-root.sh helper exists"
    else
        fail "_find-sdlc-root.sh helper not found (needed by sdlc-prompt-check + instructions-loaded-check)"
    fi
}

# Test: sdlc-prompt-check walks up from CWD to find nested SDLC.md
test_sdlc_hook_cwd_walkup_finds_nested() {
    local tmpdir
    tmpdir=$(mktemp -d)
    # Project at $tmpdir/project/, but CLAUDE_PROJECT_DIR is empty (simulates parent launch)
    mkdir -p "$tmpdir/project/src/components"
    echo "# SDLC" > "$tmpdir/project/SDLC.md"
    echo "# Testing" > "$tmpdir/project/TESTING.md"
    local output
    # Run hook from deep inside the project — CWD walk should find SDLC.md
    output=$(cd "$tmpdir/project/src/components" && CLAUDE_PROJECT_DIR="" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "SDLC BASELINE" && ! echo "$output" | grep -q "SETUP NOT COMPLETE"; then
        pass "sdlc-prompt-check.sh walks up from CWD to find nested SDLC.md"
    else
        fail "sdlc-prompt-check.sh should walk up from CWD when CLAUDE_PROJECT_DIR is empty"
    fi
}

# Test: CWD walk-up prefers nearest SDLC.md (monorepo with per-package setup)
test_sdlc_hook_cwd_walkup_prefers_nearest() {
    local tmpdir
    tmpdir=$(mktemp -d)
    # Monorepo root has SDLC.md, but sub-package also has its own
    echo "# Root SDLC" > "$tmpdir/SDLC.md"
    echo "# Root Testing" > "$tmpdir/TESTING.md"
    mkdir -p "$tmpdir/packages/api/src"
    echo "# API SDLC" > "$tmpdir/packages/api/SDLC.md"
    echo "# API Testing" > "$tmpdir/packages/api/TESTING.md"
    local output
    # CWD is deep inside packages/api — should find packages/api/SDLC.md first
    output=$(cd "$tmpdir/packages/api/src" && CLAUDE_PROJECT_DIR="" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "SDLC BASELINE"; then
        pass "sdlc-prompt-check.sh prefers nearest SDLC.md in monorepo"
    else
        fail "Should find nearest SDLC.md when multiple exist in ancestor chain"
    fi
}

# Test: Falls back to CLAUDE_PROJECT_DIR when CWD walk finds nothing
test_sdlc_hook_cwd_walkup_fallback() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local projdir
    projdir=$(mktemp -d)
    echo "# SDLC" > "$projdir/SDLC.md"
    echo "# Testing" > "$projdir/TESTING.md"
    # CWD has nothing, but CLAUDE_PROJECT_DIR points to valid project
    local output
    output=$(cd "$tmpdir" && CLAUDE_PROJECT_DIR="$projdir" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir" "$projdir"
    if echo "$output" | grep -q "SDLC BASELINE"; then
        pass "sdlc-prompt-check.sh falls back to CLAUDE_PROJECT_DIR when CWD walk fails"
    else
        fail "Should fall back to CLAUDE_PROJECT_DIR when CWD walk finds nothing"
    fi
}

# Test: instructions-loaded-check also walks up from CWD
test_instructions_hook_cwd_walkup() {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/project/src"
    echo '<!-- SDLC Wizard Version: 1.29.0 -->' > "$tmpdir/project/SDLC.md"
    echo "# Testing" > "$tmpdir/project/TESTING.md"
    # Mock npm/claude/codex to prevent version check output
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/bash\nexit 1\n' > "$tmpdir/bin/npm"
    printf '#!/bin/bash\nexit 1\n' > "$tmpdir/bin/claude"
    printf '#!/bin/bash\nexit 1\n' > "$tmpdir/bin/codex"
    chmod +x "$tmpdir/bin/npm" "$tmpdir/bin/claude" "$tmpdir/bin/codex"
    local output
    output=$(cd "$tmpdir/project/src" && PATH="$tmpdir/bin:$PATH" CLAUDE_PROJECT_DIR="" "$HOOKS_DIR/instructions-loaded-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if [ -z "$output" ] || ! echo "$output" | grep -qi "missing"; then
        pass "instructions-loaded-check.sh walks up from CWD (no false warning)"
    else
        fail "instructions-loaded-check.sh should walk up from CWD, got: $output"
    fi
}

# Test: CWD walk-up with empty SDLC.md still triggers setup (non-empty check preserved)
test_sdlc_hook_cwd_walkup_empty_stubs() {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/project/src"
    touch "$tmpdir/project/SDLC.md"   # empty
    touch "$tmpdir/project/TESTING.md" # empty
    local output
    output=$(cd "$tmpdir/project/src" && CLAUDE_PROJECT_DIR="" "$HOOKS_DIR/sdlc-prompt-check.sh" 2>/dev/null)
    rm -rf "$tmpdir"
    if echo "$output" | grep -q "setup-wizard"; then
        pass "CWD walk-up still triggers setup for empty stub files"
    else
        fail "Empty stubs found by CWD walk should still trigger setup-wizard"
    fi
}

test_find_sdlc_root_helper_exists
test_sdlc_hook_cwd_walkup_finds_nested
test_sdlc_hook_cwd_walkup_prefers_nearest
test_sdlc_hook_cwd_walkup_fallback
test_instructions_hook_cwd_walkup
test_sdlc_hook_cwd_walkup_empty_stubs

echo ""
echo "--- SDLC enforcement gap audit ---"
test_todowrite_has_capture_learnings
test_todowrite_has_scope_guard
test_todowrite_has_deploy_tasks
test_todowrite_has_new_pattern_check
test_todowrite_has_legacy_delete_check
test_enforcement_coverage_score

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All hook tests passed!"
