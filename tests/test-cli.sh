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

# Test 4: init creates all 10 expected files
test_creates_all_files() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local count=0
    [ -f "$d/.claude/settings.json" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/sdlc-prompt-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/tdd-pretool-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/instructions-loaded-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/model-effort-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/sdlc/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/setup/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/update/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/feedback/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/CLAUDE_CODE_SDLC_WIZARD.md" ] && count=$((count + 1))
    if [ "$count" -eq 10 ]; then
        pass "init creates all 10 expected files"
    else
        fail "init should create 10 files, found $count"
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
    [ -d "$d/.claude/skills/setup" ] || ok=false
    [ -d "$d/.claude/skills/update" ] || ok=false
    if [ "$ok" = true ]; then
        pass "init creates correct directory structure"
    else
        fail "init should create .claude/hooks, .claude/skills/sdlc, .claude/skills/setup, .claude/skills/update"
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

# Test 10: settings.json is valid JSON with 4 hook events
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
    if [ "$hook_count" = "4" ]; then
        pass "settings.json is valid JSON with 4 hook events"
    else
        fail "settings.json should have 4 hook events, found: $hook_count"
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
    grep -q "setup-wizard" "$d/.claude/hooks/instructions-loaded-check.sh" || ok=false
    if [ "$ok" = true ]; then
        pass "Template hooks contain expected content"
    else
        fail "Template hooks should contain SDLC BASELINE, TDD CHECK, SDLC wizard files, setup-wizard"
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

# Test 23: Template setup-wizard skill has correct frontmatter
test_setup_wizard_frontmatter() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ok=true
    grep -q "^name: setup-wizard$" "$d/.claude/skills/setup/SKILL.md" || ok=false
    grep -q "^effort: high$" "$d/.claude/skills/setup/SKILL.md" || ok=false
    if [ "$ok" = true ]; then
        pass "Template setup-wizard skill has correct frontmatter (name + effort)"
    else
        fail "setup-wizard skill should have name: setup-wizard and effort: high in frontmatter"
    fi
    rm -rf "$d"
}

# Test 24: init merges settings.json when existing has valid JSON
test_merge_settings_output() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "allowedTools": ["Read", "Glob"],
  "hooks": {}
}
FIXTURE
    local output
    output=$(cd "$d" && node "$CLI" init 2>&1)
    if echo "$output" | grep -q "MERGE"; then
        pass "init shows MERGE for existing settings.json with valid JSON"
    else
        fail "init should show MERGE when settings.json exists with valid JSON"
    fi
    rm -rf "$d"
}

# Test 25: merge preserves custom keys and adds wizard hooks
test_merge_preserves_keys() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "allowedTools": ["Read", "Glob"],
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "bash my-custom-hook.sh" }
        ]
      }
    ]
  }
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ok=true
    # Custom keys preserved
    grep -q "allowedTools" "$d/.claude/settings.json" || ok=false
    grep -q "my-custom-hook" "$d/.claude/settings.json" || ok=false
    # Wizard hooks added
    grep -q "sdlc-prompt-check" "$d/.claude/settings.json" || ok=false
    grep -q "tdd-pretool-check" "$d/.claude/settings.json" || ok=false
    grep -q "instructions-loaded-check" "$d/.claude/settings.json" || ok=false
    if [ "$ok" = true ]; then
        pass "merge preserves custom keys and adds wizard hooks"
    else
        fail "merge should preserve allowedTools + custom hooks AND add wizard hooks"
    fi
    rm -rf "$d"
}

# Test 26: merge falls back to SKIP for invalid JSON
test_merge_invalid_json_fallback() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    echo "not valid json {{{" > "$d/.claude/settings.json"
    local output
    output=$(cd "$d" && node "$CLI" init 2>&1)
    if echo "$output" | grep -q "SKIP.*settings.json"; then
        pass "merge falls back to SKIP for invalid JSON"
    else
        fail "merge should fall back to SKIP when settings.json has invalid JSON"
    fi
    rm -rf "$d"
}

# Test 27: --force with invalid JSON falls through to OVERWRITE
test_merge_force_invalid_json() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    echo "not valid json {{{" > "$d/.claude/settings.json"
    local output
    output=$(cd "$d" && node "$CLI" init --force 2>&1)
    if echo "$output" | grep -q "OVERWRITE.*settings.json"; then
        pass "--force with invalid JSON falls through to OVERWRITE"
    else
        fail "--force with invalid JSON should show OVERWRITE for settings.json"
    fi
    rm -rf "$d"
}

# Test 28: merge is idempotent — running init twice doesn't duplicate hooks
test_merge_idempotent() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "allowedTools": ["Read"],
  "hooks": {}
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    # Count occurrences of sdlc-prompt-check — should be exactly 1
    local count
    count=$(grep -c "sdlc-prompt-check" "$d/.claude/settings.json")
    if [ "$count" -eq 1 ]; then
        pass "merge is idempotent — no duplicate wizard hooks"
    else
        fail "merge should not duplicate wizard hooks (found $count occurrences)"
    fi
    rm -rf "$d"
}

# Test 29: --force updates wizard hooks but preserves custom keys
test_merge_force_updates_hooks() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "allowedTools": ["Read", "Glob"],
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "bash my-custom-hook.sh" }
        ]
      },
      {
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/sdlc-prompt-check.sh" }
        ]
      }
    ]
  }
}
FIXTURE
    (cd "$d" && node "$CLI" init --force > /dev/null 2>&1)
    local ok=true
    # Custom keys preserved
    grep -q "allowedTools" "$d/.claude/settings.json" || ok=false
    grep -q "my-custom-hook" "$d/.claude/settings.json" || ok=false
    # Wizard hooks present (updated)
    grep -q "sdlc-prompt-check" "$d/.claude/settings.json" || ok=false
    grep -q "tdd-pretool-check" "$d/.claude/settings.json" || ok=false
    grep -q "instructions-loaded-check" "$d/.claude/settings.json" || ok=false
    # Not duplicated
    local sdlc_count
    sdlc_count=$(grep -c "sdlc-prompt-check" "$d/.claude/settings.json")
    [ "$sdlc_count" -eq 1 ] || ok=false
    if [ "$ok" = true ]; then
        pass "--force updates wizard hooks but preserves custom keys"
    else
        fail "--force should update wizard hooks AND preserve custom allowedTools + hooks"
    fi
    rm -rf "$d"
}

# Test 30: init removes obsolete .claude/skills/testing/ on fresh install
test_upgrade_removes_obsolete_testing() {
    local d
    d=$(make_temp)
    # Simulate pre-upgrade state: old testing skill exists
    mkdir -p "$d/.claude/skills/testing"
    echo "old testing skill" > "$d/.claude/skills/testing/SKILL.md"
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    if [ ! -d "$d/.claude/skills/testing" ]; then
        pass "init removes obsolete .claude/skills/testing/ on fresh install"
    else
        fail "init should remove obsolete .claude/skills/testing/ directory"
    fi
    rm -rf "$d"
}

# Test 31: init removes obsolete testing skill even when all managed files exist (SKIP path)
test_upgrade_removes_testing_on_skip_path() {
    local d
    d=$(make_temp)
    # First install — creates all managed files
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    # Simulate stale testing skill left over from old version
    mkdir -p "$d/.claude/skills/testing"
    echo "old testing skill" > "$d/.claude/skills/testing/SKILL.md"
    # Re-run init (no --force) — all managed files are SKIP, but obsolete must still be removed
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    if [ ! -d "$d/.claude/skills/testing" ]; then
        pass "init removes obsolete testing skill even on all-SKIP path"
    else
        fail "init should remove .claude/skills/testing/ even when all managed files are SKIP"
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
test_setup_wizard_frontmatter
test_merge_settings_output
test_merge_preserves_keys
test_merge_invalid_json_fallback
test_merge_force_invalid_json
test_merge_idempotent
test_merge_force_updates_hooks
test_upgrade_removes_obsolete_testing
test_upgrade_removes_testing_on_skip_path

# Test 32: init output shows clear restart instructions with --continue
test_install_restart_messaging() {
    local d
    d=$(make_temp)
    local output
    output=$(cd "$d" && node "$CLI" init 2>&1)
    local ok=true
    # Must mention both restart options clearly
    echo "$output" | grep -q '\-\-continue' || ok=false
    # Must mention that --continue keeps conversation history
    echo "$output" | grep -qi 'keep.*conversation\|conversation.*history' || ok=false
    # Must mention fresh start as alternative
    echo "$output" | grep -qi 'fresh' || ok=false
    if [ "$ok" = true ]; then
        pass "init output shows clear restart instructions with --continue"
    else
        fail "init output should clearly show --continue and fresh start options"
    fi
    rm -rf "$d"
}

test_install_restart_messaging

# Test 33: Template settings.json has env field with CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
test_template_has_autocompact_env() {
    local template="$SCRIPT_DIR/../cli/templates/settings.json"
    local val
    val=$(python3 -c "
import json, sys
with open('$template') as f:
    data = json.load(f)
env = data.get('env', {})
print(env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', ''))
" 2>/dev/null)
    if [ "$val" = "30" ]; then
        pass "Template settings.json has CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=30"
    else
        fail "Template settings.json should have env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=30 (got: '$val')"
    fi
}

# Test 34: Init creates settings.json with env field on fresh install
test_init_has_env_field() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local has_env
    has_env=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
print('yes' if 'env' in data and 'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE' in data['env'] else 'no')
" 2>/dev/null)
    if [ "$has_env" = "yes" ]; then
        pass "Init creates settings.json with env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"
    else
        fail "Init should create settings.json with env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"
    fi
    rm -rf "$d"
}

# Test 35: Merge preserves existing env vars when adding wizard env
test_merge_preserves_existing_env() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "hooks": {},
  "env": {
    "MY_CUSTOM_VAR": "keep-me"
  }
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local result
    result=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
env = data.get('env', {})
custom = env.get('MY_CUSTOM_VAR', '')
wizard = env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', '')
print(f'{custom}|{wizard}')
" 2>/dev/null)
    if [ "$result" = "keep-me|30" ]; then
        pass "Merge preserves existing env vars and adds wizard env"
    else
        fail "Merge should preserve MY_CUSTOM_VAR and add AUTOCOMPACT (got: '$result')"
    fi
    rm -rf "$d"
}

# Test 36: Merge adds wizard env to settings without env field
test_merge_adds_env_to_existing_settings() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "allowedTools": ["Read"],
  "hooks": {}
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local result
    result=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
env = data.get('env', {})
allowed = 'allowedTools' in data
wizard = env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', '')
print(f'{allowed}|{wizard}')
" 2>/dev/null)
    if [ "$result" = "True|30" ]; then
        pass "Merge adds wizard env to settings without env field"
    else
        fail "Merge should add env.AUTOCOMPACT and preserve allowedTools (got: '$result')"
    fi
    rm -rf "$d"
}

# Test 37: Merge does not overwrite user's existing autocompact value.
# Use 50 as the fixture value — distinct from the 30 template default —
# so this test actually proves "no overwrite" rather than coincidentally
# matching the new default.
test_merge_respects_user_autocompact() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "hooks": {},
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"
  }
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
print(data.get('env', {}).get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', ''))
" 2>/dev/null)
    if [ "$val" = "50" ]; then
        pass "Merge respects user's existing AUTOCOMPACT value (50)"
    else
        fail "Merge should not overwrite user's AUTOCOMPACT=50 (got: '$val')"
    fi
    rm -rf "$d"
}

# Test 38: --force overwrites user's autocompact value back to default.
# Fixture value 50 is distinct from the 30 template default.
test_merge_force_resets_autocompact() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "hooks": {},
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"
  }
}
FIXTURE
    (cd "$d" && node "$CLI" init --force > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
print(data.get('env', {}).get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', ''))
" 2>/dev/null)
    if [ "$val" = "30" ]; then
        pass "--force resets AUTOCOMPACT back to template default (30)"
    else
        fail "--force should reset AUTOCOMPACT to 30 (got: '$val')"
    fi
    rm -rf "$d"
}

# Test 39: Setup wizard skill Step 9.5 references settings.json (not shell profile)
test_setup_skill_references_settings_json() {
    local skill="$SCRIPT_DIR/../skills/setup/SKILL.md"
    if grep -q "settings.json" "$skill" && grep -q "Step 9.5" "$skill"; then
        if grep -A20 "Step 9.5" "$skill" | grep -q "settings.json"; then
            pass "Setup skill Step 9.5 references settings.json"
        else
            fail "Setup skill Step 9.5 should reference settings.json"
        fi
    else
        fail "Setup skill should have Step 9.5 referencing settings.json"
    fi
}

# Test 40: Merge handles malformed env (array) — replaces with wizard env
test_merge_malformed_env_array() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "hooks": {},
  "env": ["not", "an", "object"]
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
env = data.get('env', {})
if isinstance(env, dict):
    print(env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', ''))
else:
    print('NOT_OBJECT')
" 2>/dev/null)
    if [ "$val" = "30" ]; then
        pass "Merge handles malformed env (array) — replaces with wizard env"
    else
        fail "Merge should replace malformed array env with wizard env (got: '$val')"
    fi
    rm -rf "$d"
}

# Test 41: Merge handles malformed env (string) — replaces with wizard env
test_merge_malformed_env_string() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "hooks": {},
  "env": "not-an-object"
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    data = json.load(f)
env = data.get('env', {})
if isinstance(env, dict):
    print(env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', ''))
else:
    print('NOT_OBJECT')
" 2>/dev/null)
    if [ "$val" = "30" ]; then
        pass "Merge handles malformed env (string) — replaces with wizard env"
    else
        fail "Merge should replace malformed string env with wizard env (got: '$val')"
    fi
    rm -rf "$d"
}

test_merge_malformed_env_array
test_merge_malformed_env_string
test_template_has_autocompact_env
test_init_has_env_field
test_merge_preserves_existing_env
test_merge_adds_env_to_existing_settings
test_merge_respects_user_autocompact
test_merge_force_resets_autocompact
test_setup_skill_references_settings_json

# Model field merge tests — ensure opus[1m] default is delivered to fresh
# installs and users upgrading from pre-model templates, while respecting
# any explicit model a user has already configured.

test_template_has_model_opus_1m() {
    local template="$SCRIPT_DIR/../cli/templates/settings.json"
    local val
    val=$(python3 -c "
import json
with open('$template') as f:
    print(json.load(f).get('model', ''))
" 2>/dev/null)
    if [ "$val" = "opus[1m]" ]; then
        pass "Template settings.json has model=opus[1m]"
    else
        fail "Template settings.json should have model='opus[1m]' (got: '$val')"
    fi
}

test_fresh_init_writes_model_opus_1m() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    print(json.load(f).get('model', ''))
" 2>/dev/null)
    if [ "$val" = "opus[1m]" ]; then
        pass "Fresh init writes model=opus[1m] to settings.json"
    else
        fail "Fresh init should write model='opus[1m]' (got: '$val')"
    fi
    rm -rf "$d"
}

test_merge_adds_model_when_missing() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "hooks": {},
  "env": { "MY_VAR": "x" }
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    print(json.load(f).get('model', ''))
" 2>/dev/null)
    if [ "$val" = "opus[1m]" ]; then
        pass "Merge adds model=opus[1m] when absent from existing settings"
    else
        fail "Merge should add model='opus[1m]' when missing (got: '$val')"
    fi
    rm -rf "$d"
}

test_merge_respects_user_model() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "model": "sonnet",
  "hooks": {}
}
FIXTURE
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    print(json.load(f).get('model', ''))
" 2>/dev/null)
    if [ "$val" = "sonnet" ]; then
        pass "Merge respects user's explicit model (sonnet)"
    else
        fail "Merge should not overwrite user's model=sonnet (got: '$val')"
    fi
    rm -rf "$d"
}

test_merge_force_resets_model() {
    local d
    d=$(make_temp)
    mkdir -p "$d/.claude"
    cat > "$d/.claude/settings.json" << 'FIXTURE'
{
  "model": "sonnet",
  "hooks": {}
}
FIXTURE
    (cd "$d" && node "$CLI" init --force > /dev/null 2>&1)
    local val
    val=$(python3 -c "
import json
with open('$d/.claude/settings.json') as f:
    print(json.load(f).get('model', ''))
" 2>/dev/null)
    if [ "$val" = "opus[1m]" ]; then
        pass "--force resets model to template default (opus[1m])"
    else
        fail "--force should reset model to 'opus[1m]' (got: '$val')"
    fi
    rm -rf "$d"
}

test_template_has_model_opus_1m
test_fresh_init_writes_model_opus_1m
test_merge_adds_model_when_missing
test_merge_respects_user_model
test_merge_force_resets_model

# === Marketplace Path Check Tests (#174) ===

# Test 42: check warns on ephemeral /tmp/ marketplace path (EPHEMERAL — path exists)
test_check_marketplace_ephemeral_tmp() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    # make_temp creates under $TMPDIR which is /tmp/... — matches ephemeral regex
    local ephemeral_dir
    ephemeral_dir=$(make_temp)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << FIXTURE
{
  "extraKnownMarketplaces": {
    "sdlc-local": {
      "source": { "source": "directory", "path": "$ephemeral_dir" }
    }
  }
}
FIXTURE
    local output
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1)
    if echo "$output" | grep -q "EPHEMERAL"; then
        pass "check warns on ephemeral /tmp/ marketplace path"
    else
        fail "check should warn EPHEMERAL for /tmp/ path (got: $output)"
    fi
    rm -rf "$d" "$fake_home" "$ephemeral_dir"
}

# Test 43: check detects reaped ephemeral path as DANGLING with ephemeral message
test_check_marketplace_reaped_ephemeral() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << 'FIXTURE'
{
  "extraKnownMarketplaces": {
    "my-plugin": {
      "source": { "source": "directory", "path": "/tmp/definitely-reaped-plugin-xyz" }
    }
  }
}
FIXTURE
    local output exit_code
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "DANGLING" && echo "$output" | grep -qi "reaped"; then
        pass "check detects reaped ephemeral path as DANGLING"
    else
        fail "check should show DANGLING + reaped message for missing ephemeral path (exit=$exit_code)"
    fi
    rm -rf "$d" "$fake_home"
}

# Test 44: check errors on dangling (non-existent, non-ephemeral) marketplace path
test_check_marketplace_dangling() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << 'FIXTURE'
{
  "extraKnownMarketplaces": {
    "gone-plugin": {
      "source": { "source": "directory", "path": "/opt/definitely-does-not-exist-xyz" }
    }
  }
}
FIXTURE
    local output exit_code
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "DANGLING"; then
        pass "check errors on dangling marketplace path (exit=$exit_code)"
    else
        fail "check should error on non-existent marketplace path (exit=$exit_code)"
    fi
    rm -rf "$d" "$fake_home"
}

# Test 45: check passes clean with no marketplace entries
test_check_marketplace_no_entries() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    echo '{}' > "$fake_home/.claude/settings.json"
    local output
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1)
    if ! echo "$output" | grep -qi "marketplace\|ephemeral\|DANGLING"; then
        pass "check passes clean with no marketplace entries"
    else
        fail "check should not mention marketplace when no entries exist"
    fi
    rm -rf "$d" "$fake_home"
}

# Test 46: check --json includes marketplace field
test_check_marketplace_json_output() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ephemeral_dir
    ephemeral_dir=$(make_temp)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << FIXTURE
{
  "extraKnownMarketplaces": {
    "test-plugin": {
      "source": { "source": "directory", "path": "$ephemeral_dir" }
    }
  }
}
FIXTURE
    local output
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check --json 2>&1)
    if echo "$output" | python3 -c "import json, sys; d=json.load(sys.stdin); assert 'marketplace' in d" 2>/dev/null; then
        pass "check --json includes marketplace field"
    else
        fail "check --json should include marketplace field"
    fi
    rm -rf "$d" "$fake_home" "$ephemeral_dir"
}

# Test 47: check skips non-directory marketplace sources
test_check_marketplace_skips_non_directory() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << 'FIXTURE'
{
  "extraKnownMarketplaces": {
    "remote-plugin": {
      "source": { "source": "url", "url": "https://example.com/plugin" }
    }
  }
}
FIXTURE
    local output
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1)
    if ! echo "$output" | grep -qi "ephemeral\|DANGLING"; then
        pass "check skips non-directory marketplace sources"
    else
        fail "check should not warn about non-directory marketplace sources"
    fi
    rm -rf "$d" "$fake_home"
}

# Test 48: check suggests stable path for ephemeral marketplace
test_check_marketplace_suggests_fix() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local ephemeral_dir
    ephemeral_dir=$(make_temp)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << FIXTURE
{
  "extraKnownMarketplaces": {
    "my-wizard": {
      "source": { "source": "directory", "path": "$ephemeral_dir" }
    }
  }
}
FIXTURE
    local output
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1)
    if echo "$output" | grep -q "plugins-local"; then
        pass "check suggests stable ~/.claude/plugins-local/ path"
    else
        fail "check should suggest ~/.claude/plugins-local/ for ephemeral paths"
    fi
    rm -rf "$d" "$fake_home" "$ephemeral_dir"
}

# Test 49: check detects /private/var/folders/ as ephemeral (Codex finding #1)
test_check_marketplace_private_var_folders() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    # Create a real dir under /private/var/folders (macOS canonical realpath)
    # Use TMPDIR's realpath which should be under /private/var/folders/
    local real_tmpdir
    real_tmpdir=$(python3 -c "import os; print(os.path.realpath('${TMPDIR:-/tmp}'))")
    local ephemeral_dir
    ephemeral_dir=$(mktemp -d "${real_tmpdir}/sdlc-pvf-test-XXXXXX")
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << FIXTURE
{
  "extraKnownMarketplaces": {
    "pvf-plugin": {
      "source": { "source": "directory", "path": "$ephemeral_dir" }
    }
  }
}
FIXTURE
    local output
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1)
    if echo "$output" | grep -q "EPHEMERAL"; then
        pass "check detects /private/var/folders/ as ephemeral"
    else
        fail "check should detect /private/var/folders/ as ephemeral (got: $output)"
    fi
    rm -rf "$d" "$fake_home" "$ephemeral_dir"
}

# Test 50: check handles malformed source.path (non-string) gracefully (Codex finding #2)
test_check_marketplace_malformed_path() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << 'FIXTURE'
{
  "extraKnownMarketplaces": {
    "bad-plugin": {
      "source": { "source": "directory", "path": {"not": "a-string"} }
    }
  }
}
FIXTURE
    local output exit_code
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check --json 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    # Should not crash — should output valid JSON
    if echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        pass "check handles malformed source.path (non-string) gracefully"
    else
        fail "check should not crash on non-string source.path (exit=$exit_code)"
    fi
    rm -rf "$d" "$fake_home"
}

# Test 51: non-ephemeral DANGLING path shows "does not exist" heading (Codex finding #3)
test_check_marketplace_dangling_heading() {
    local d
    d=$(make_temp)
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    local fake_home
    fake_home=$(make_temp)
    mkdir -p "$fake_home/.claude"
    cat > "$fake_home/.claude/settings.json" << 'FIXTURE'
{
  "extraKnownMarketplaces": {
    "gone-plugin": {
      "source": { "source": "directory", "path": "/opt/definitely-does-not-exist-xyz" }
    }
  }
}
FIXTURE
    local output exit_code
    output=$(cd "$d" && HOME="$fake_home" node "$CLI" check 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    if echo "$output" | grep -q "does not exist:" && ! echo "$output" | grep -q "ephemeral:"; then
        pass "non-ephemeral DANGLING shows 'does not exist' heading, not 'ephemeral'"
    else
        fail "non-ephemeral DANGLING should say 'does not exist:', not 'ephemeral:'"
    fi
    rm -rf "$d" "$fake_home"
}

test_check_marketplace_ephemeral_tmp
test_check_marketplace_reaped_ephemeral
test_check_marketplace_dangling
test_check_marketplace_no_entries
test_check_marketplace_json_output
test_check_marketplace_skips_non_directory
test_check_marketplace_suggests_fix
test_check_marketplace_private_var_folders
test_check_marketplace_malformed_path
test_check_marketplace_dangling_heading

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All CLI distribution tests passed!"
