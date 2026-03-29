#!/bin/bash
# Test CLI distribution tool (agentic-sdlc-wizard)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/../cli/bin/sdlc-wizard.js"
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

# Create a fresh temp dir for each test
make_temp() {
    local d
    d=$(mktemp -d "${TMPDIR:-/tmp}/sdlc-cli-test-XXXXXX")
    echo "$d"
}

echo "=== CLI Distribution Tests ==="
echo ""

# Test 1: --help exits 0 and shows usage
test_help() {
    if node "$CLI" --help 2>&1 | grep -q "Usage:"; then
        pass "--help exits 0 and shows usage"
    else
        fail "--help should show usage text"
    fi
}

# Test 2: --version exits 0 and matches package.json
test_version() {
    local cli_version pkg_version
    cli_version=$(node "$CLI" --version 2>&1)
    pkg_version=$(node -e "console.log(require('$SCRIPT_DIR/../package.json').version)")
    if [ "$cli_version" = "$pkg_version" ]; then
        pass "--version ($cli_version) matches package.json"
    else
        fail "--version ($cli_version) should match package.json ($pkg_version)"
    fi
}

# Test 3: init --dry-run creates no files
test_dry_run_no_files() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init --dry-run > /dev/null 2>&1)
    if [ ! -d "$d/.claude" ]; then
        pass "init --dry-run creates no files"
    else
        fail "init --dry-run should not create any files"
    fi
    rm -rf "$d"
}

# Test 4: init creates all 7 expected files
test_creates_all_files() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local count=0
    [ -f "$d/.claude/settings.json" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/sdlc-prompt-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/tdd-pretool-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/instructions-loaded-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/sdlc/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/testing/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/CLAUDE_CODE_SDLC_WIZARD.md" ] && count=$((count + 1))
    if [ "$count" -eq 7 ]; then
        pass "init creates all 7 expected files"
    else
        fail "init should create 7 files, found $count"
    fi
    rm -rf "$d"
}

# Test 5: init sets hooks as executable
test_hooks_executable() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local exec_count=0
    [ -x "$d/.claude/hooks/sdlc-prompt-check.sh" ] && exec_count=$((exec_count + 1))
    [ -x "$d/.claude/hooks/tdd-pretool-check.sh" ] && exec_count=$((exec_count + 1))
    [ -x "$d/.claude/hooks/instructions-loaded-check.sh" ] && exec_count=$((exec_count + 1))
    if [ "$exec_count" -eq 3 ]; then
        pass "init sets all 3 hooks as executable"
    else
        fail "init should set 3 hooks as executable, found $exec_count"
    fi
    rm -rf "$d"
}

# Test 6: init skips existing files without --force
test_skip_existing() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude/hooks"
    echo "existing" > "$d/.claude/settings.json"
    local output
    output=$(cd "$d" && node "$CLI" init 2>&1)
    if echo "$output" | grep -q "SKIP.*settings.json"; then
        # Verify file was NOT overwritten
        local content
        content=$(cat "$d/.claude/settings.json")
        if [ "$content" = "existing" ]; then
            pass "init skips existing files without --force"
        else
            fail "init should not overwrite existing files without --force"
        fi
    else
        fail "init should report SKIP for existing files"
    fi
    rm -rf "$d"
}

# Test 7: init --force overwrites existing files
test_force_overwrite() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude/hooks"
    echo "old" > "$d/.claude/settings.json"
    (cd "$d" && node "$CLI" init --force > /dev/null 2>&1)
    local content
    content=$(cat "$d/.claude/settings.json")
    if [ "$content" != "old" ]; then
        pass "init --force overwrites existing files"
    else
        fail "init --force should overwrite existing files"
    fi
    rm -rf "$d"
}

# Test 8: init creates correct directory structure
test_dir_structure() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ok=true
    [ -d "$d/.claude/hooks" ] || ok=false
    [ -d "$d/.claude/skills/sdlc" ] || ok=false
    [ -d "$d/.claude/skills/testing" ] || ok=false
    if [ "$ok" = true ]; then
        pass "init creates correct directory structure"
    else
        fail "init should create .claude/hooks, .claude/skills/sdlc, .claude/skills/testing"
    fi
    rm -rf "$d"
}

# Test 9: init copies wizard doc
test_wizard_doc() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    if [ -f "$d/CLAUDE_CODE_SDLC_WIZARD.md" ] && grep -q "SDLC Wizard" "$d/CLAUDE_CODE_SDLC_WIZARD.md"; then
        pass "init copies wizard doc with correct content"
    else
        fail "init should copy CLAUDE_CODE_SDLC_WIZARD.md"
    fi
    rm -rf "$d"
}

# Test 10: settings.json is valid JSON with 3 hook events
test_settings_json() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local hook_count
    hook_count=$(python3 -c "
import json, sys
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
hooks = data.get('hooks', {})
print(len(hooks))
" 2>/dev/null)
    if [ "$hook_count" = "3" ]; then
        pass "settings.json is valid JSON with 3 hook events"
    else
        fail "settings.json should have 3 hook events, found: $hook_count"
    fi
    rm -rf "$d"
}

# Test 11: .gitignore gets required entries
test_gitignore_append() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ok=true
    grep -q ".claude/plans/" "$d/.gitignore" || ok=false
    grep -q ".claude/settings.local.json" "$d/.gitignore" || ok=false
    if [ "$ok" = true ]; then
        pass ".gitignore gets required entries"
    else
        fail ".gitignore should contain .claude/plans/ and .claude/settings.local.json"
    fi
    rm -rf "$d"
}

# Test 12: .gitignore entries not duplicated on re-run
test_gitignore_no_dupes() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    (cd "$d" && node "$CLI" init --force > /dev/null 2>&1)
    local count
    count=$(grep -c ".claude/plans/" "$d/.gitignore")
    if [ "$count" -eq 1 ]; then
        pass ".gitignore entries not duplicated on re-run"
    else
        fail ".gitignore should have exactly 1 .claude/plans/ entry, found $count"
    fi
    rm -rf "$d"
}

# Test 13: Template hooks contain expected content
test_hook_content() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ok=true
    grep -q "SDLC BASELINE" "$d/.claude/hooks/sdlc-prompt-check.sh" || ok=false
    grep -q "TDD CHECK" "$d/.claude/hooks/tdd-pretool-check.sh" || ok=false
    grep -q "SDLC wizard files" "$d/.claude/hooks/instructions-loaded-check.sh" || ok=false
    if [ "$ok" = true ]; then
        pass "Template hooks contain expected content"
    else
        fail "Template hooks should contain SDLC BASELINE, TDD CHECK, SDLC wizard files"
    fi
    rm -rf "$d"
}

# Test 14: Template skills have correct frontmatter
test_skill_frontmatter() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ok=true
    grep -q "^name: sdlc$" "$d/.claude/skills/sdlc/SKILL.md" || ok=false
    grep -q "^effort: high$" "$d/.claude/skills/sdlc/SKILL.md" || ok=false
    grep -q "^name: testing$" "$d/.claude/skills/testing/SKILL.md" || ok=false
    grep -q "^effort: high$" "$d/.claude/skills/testing/SKILL.md" || ok=false
    if [ "$ok" = true ]; then
        pass "Template skills have correct frontmatter (name + effort)"
    else
        fail "Skills should have name and effort: high in frontmatter"
    fi
    rm -rf "$d"
}

# Test 15: Template tdd hook uses /src/ pattern (not .github/workflows/)
test_tdd_hook_generic() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    if grep -q '"/src/"' "$d/.claude/hooks/tdd-pretool-check.sh"; then
        if ! grep -q '.github/workflows/' "$d/.claude/hooks/tdd-pretool-check.sh"; then
            pass "Template tdd hook uses /src/ pattern (generic)"
        else
            fail "Template tdd hook should NOT reference .github/workflows/"
        fi
    else
        fail "Template tdd hook should use /src/ pattern"
    fi
    rm -rf "$d"
}

# Test 16: Template settings.json has NO allowedTools key
test_no_allowed_tools() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    if ! grep -q "allowedTools" "$d/.claude/settings.json"; then
        pass "Template settings.json has no allowedTools key"
    else
        fail "Template settings.json should NOT have allowedTools (project-specific)"
    fi
    rm -rf "$d"
}

# Test 17: check on fresh init shows all MATCH
test_check_all_match() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local output
    output=$(cd "$d" && node "$CLI" check 2>&1)
    local exit_code=$?
    if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "MATCH"; then
        pass "check on fresh init shows MATCH and exits 0"
    else
        fail "check on fresh init should show MATCH and exit 0 (exit=$exit_code)"
    fi
    rm -rf "$d"
}

# Test 18: check on modified file shows CUSTOMIZED
test_check_customized() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    echo "modified" >> "$d/.claude/settings.json"
    local output
    output=$(cd "$d" && node "$CLI" check 2>&1)
    if echo "$output" | grep -q "CUSTOMIZED"; then
        pass "check on modified file shows CUSTOMIZED"
    else
        fail "check should show CUSTOMIZED for modified settings.json"
    fi
    rm -rf "$d"
}

# Test 19: check on empty dir shows all MISSING
test_check_all_missing() {
    local d
    d=$(make_temp)
    local output exit_code
    output=$(cd "$d" && node "$CLI" check 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "MISSING"; then
        pass "check on empty dir shows MISSING and exits non-zero"
    else
        fail "check on empty dir should show MISSING and exit non-zero (exit=$exit_code)"
    fi
    rm -rf "$d"
}

# Test 20: check --json outputs valid JSON
test_check_json() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local output
    output=$(cd "$d" && node "$CLI" check --json 2>&1)
    if echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        pass "check --json outputs valid JSON"
    else
        fail "check --json should output valid JSON"
    fi
    rm -rf "$d"
}

# Test 21: check detects non-executable hook (DRIFT)
test_check_drift_permissions() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    chmod -x "$d/.claude/hooks/sdlc-prompt-check.sh"
    local output exit_code
    output=$(cd "$d" && node "$CLI" check 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "DRIFT"; then
        pass "check detects non-executable hook as DRIFT"
    else
        fail "check should detect non-executable hook (exit=$exit_code)"
    fi
    rm -rf "$d"
}

# Test 22: check detects missing .gitignore entries (DRIFT)
test_check_drift_gitignore() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    # Replace .gitignore with commented-out entries (should NOT match)
    echo "# .claude/plans/" > "$d/.gitignore"
    echo "# .claude/settings.local.json" >> "$d/.gitignore"
    local output exit_code
    output=$(cd "$d" && node "$CLI" check 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "DRIFT"; then
        pass "check detects commented .gitignore entries as DRIFT"
    else
        fail "check should detect missing .gitignore entries (exit=$exit_code)"
    fi
    rm -rf "$d"
}

# Run all tests
test_help
test_version
test_dry_run_no_files
test_creates_all_files
test_hooks_executable
test_skip_existing
test_force_overwrite
test_dir_structure
test_wizard_doc
test_settings_json
test_gitignore_append
test_gitignore_no_dupes
test_hook_content
test_skill_frontmatter
test_tdd_hook_generic
test_no_allowed_tools
test_check_all_match
test_check_customized
test_check_all_missing
test_check_json
test_check_drift_permissions
test_check_drift_gitignore

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All CLI distribution tests passed!"
