#!/bin/bash
# Tests for "Prove It's Better" library (tests/e2e/lib/prove-it.sh)
# Validates: path allowlist, fixture stripping, overlap signal parsing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASSED=0
FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

echo "=== Prove It's Better Tests ==="
echo ""

# Source the library under test
PROVE_IT="$REPO_ROOT/tests/e2e/lib/prove-it.sh"
if [ ! -f "$PROVE_IT" ]; then
    fail "Library not found: $PROVE_IT"
    echo "=== Results: $PASSED passed, $FAILED failed ==="
    exit 1
fi
source "$PROVE_IT"

# ============================================
# validate_removable_paths() Tests
# ============================================

# Test 1: Accepts known hook path
test_validate_accepts_hook() {
    local INPUT='[".claude/hooks/sdlc-prompt-check.sh"]'
    local RESULT
    RESULT=$(validate_removable_paths "$INPUT" 2>/dev/null || echo "")

    if echo "$RESULT" | grep -q "sdlc-prompt-check.sh"; then
        pass "validate_removable_paths accepts known hook path"
    else
        fail "validate_removable_paths should accept sdlc-prompt-check.sh, got: $RESULT"
    fi
}
test_validate_accepts_hook

# Test 2: Accepts known skill path
test_validate_accepts_skill() {
    local INPUT='[".claude/skills/sdlc/SKILL.md"]'
    local RESULT
    RESULT=$(validate_removable_paths "$INPUT" 2>/dev/null || echo "")

    if echo "$RESULT" | grep -q "sdlc/SKILL.md"; then
        pass "validate_removable_paths accepts known skill path"
    else
        fail "validate_removable_paths should accept sdlc/SKILL.md, got: $RESULT"
    fi
}
test_validate_accepts_skill

# Test 3: Rejects unknown path (security: prevents LLM hallucination)
test_validate_rejects_unknown() {
    local INPUT='["/etc/passwd"]'
    local RESULT
    RESULT=$(validate_removable_paths "$INPUT" 2>/dev/null || echo "")

    if [ -z "$RESULT" ]; then
        pass "validate_removable_paths rejects unknown path"
    else
        fail "validate_removable_paths should reject /etc/passwd, got: $RESULT"
    fi
}
test_validate_rejects_unknown

# Test 4: Handles empty array
test_validate_empty_array() {
    local INPUT='[]'
    local RESULT
    RESULT=$(validate_removable_paths "$INPUT" 2>/dev/null || echo "")

    if [ -z "$RESULT" ]; then
        pass "validate_removable_paths handles empty array"
    else
        fail "validate_removable_paths should return empty for [], got: $RESULT"
    fi
}
test_validate_empty_array

# Test 5: Mixed valid and invalid — only returns valid
test_validate_mixed() {
    local INPUT='[".claude/hooks/tdd-pretool-check.sh", "/etc/shadow", ".claude/skills/testing/SKILL.md"]'
    local RESULT
    RESULT=$(validate_removable_paths "$INPUT" 2>/dev/null || echo "")

    local VALID_COUNT
    VALID_COUNT=$(echo "$RESULT" | grep -c '\.claude/' || true)

    if [ "$VALID_COUNT" -eq 2 ]; then
        pass "validate_removable_paths returns only valid paths from mixed input"
    else
        fail "Expected 2 valid paths, got $VALID_COUNT. Result: $RESULT"
    fi
}
test_validate_mixed

# ============================================
# create_stripped_fixture() Tests
# ============================================

# Test 6: Removes target file from fixture copy
test_strip_removes_file() {
    local TEMP_SRC
    TEMP_SRC=$(mktemp -d)
    local TEMP_DST
    TEMP_DST=$(mktemp -d)

    # Create a minimal fixture
    mkdir -p "$TEMP_SRC/.claude/hooks"
    echo '#!/bin/bash' > "$TEMP_SRC/.claude/hooks/sdlc-prompt-check.sh"
    echo '{"hooks":{}}' > "$TEMP_SRC/.claude/settings.json"
    echo "keep me" > "$TEMP_SRC/README.md"

    create_stripped_fixture "$TEMP_SRC" "$TEMP_DST" '[".claude/hooks/sdlc-prompt-check.sh"]' 2>/dev/null || true

    # Must have copied something AND removed the target
    if [ -f "$TEMP_DST/README.md" ] && [ ! -f "$TEMP_DST/.claude/hooks/sdlc-prompt-check.sh" ]; then
        pass "create_stripped_fixture removes target file"
    else
        fail "create_stripped_fixture should copy fixture and remove sdlc-prompt-check.sh"
    fi

    rm -rf "$TEMP_SRC" "$TEMP_DST"
}
test_strip_removes_file

# Test 7: Keeps unrelated files
test_strip_keeps_unrelated() {
    local TEMP_SRC
    TEMP_SRC=$(mktemp -d)
    local TEMP_DST
    TEMP_DST=$(mktemp -d)

    # Create fixture with target and unrelated files
    mkdir -p "$TEMP_SRC/.claude/hooks"
    echo '#!/bin/bash' > "$TEMP_SRC/.claude/hooks/sdlc-prompt-check.sh"
    echo '#!/bin/bash' > "$TEMP_SRC/.claude/hooks/tdd-pretool-check.sh"
    echo '{"hooks":{}}' > "$TEMP_SRC/.claude/settings.json"
    echo "keep me" > "$TEMP_SRC/README.md"

    create_stripped_fixture "$TEMP_SRC" "$TEMP_DST" '[".claude/hooks/sdlc-prompt-check.sh"]' 2>/dev/null || true

    if [ -f "$TEMP_DST/.claude/hooks/tdd-pretool-check.sh" ] && [ -f "$TEMP_DST/README.md" ]; then
        pass "create_stripped_fixture keeps unrelated files"
    else
        fail "create_stripped_fixture removed files it shouldn't have"
    fi

    rm -rf "$TEMP_SRC" "$TEMP_DST"
}
test_strip_keeps_unrelated

# Test 8: Updates settings.json — removes hook entry for removed hook file
test_strip_updates_settings() {
    local TEMP_SRC
    TEMP_SRC=$(mktemp -d)
    local TEMP_DST
    TEMP_DST=$(mktemp -d)

    # Create fixture with real settings.json structure
    mkdir -p "$TEMP_SRC/.claude/hooks"
    echo '#!/bin/bash' > "$TEMP_SRC/.claude/hooks/sdlc-prompt-check.sh"
    echo '#!/bin/bash' > "$TEMP_SRC/.claude/hooks/tdd-pretool-check.sh"
    cat > "$TEMP_SRC/.claude/settings.json" << 'SETTINGS'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/sdlc-prompt-check.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tdd-pretool-check.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS

    create_stripped_fixture "$TEMP_SRC" "$TEMP_DST" '[".claude/hooks/sdlc-prompt-check.sh"]' 2>/dev/null || true

    # UserPromptSubmit should be gone, PreToolUse should remain
    local HAS_USER_PROMPT HAS_PRE_TOOL
    HAS_USER_PROMPT=$(jq 'has("hooks") and (.hooks | has("UserPromptSubmit"))' "$TEMP_DST/.claude/settings.json" 2>/dev/null || echo "error")
    HAS_PRE_TOOL=$(jq 'has("hooks") and (.hooks | has("PreToolUse"))' "$TEMP_DST/.claude/settings.json" 2>/dev/null || echo "error")

    if [ "$HAS_USER_PROMPT" = "false" ] && [ "$HAS_PRE_TOOL" = "true" ]; then
        pass "create_stripped_fixture updates settings.json (removes hook entry)"
    else
        fail "settings.json not updated correctly. UserPromptSubmit=$HAS_USER_PROMPT (want false), PreToolUse=$HAS_PRE_TOOL (want true)"
    fi

    rm -rf "$TEMP_SRC" "$TEMP_DST"
}
test_strip_updates_settings

# ============================================
# Overlap Signal Parsing Tests
# ============================================

# Test 9: Non-empty replaces_custom → has_overlap=true
test_overlap_detected() {
    local FIXTURE="$REPO_ROOT/tests/fixtures/releases/v99.0.0-overlap.json"

    if [ ! -f "$FIXTURE" ]; then
        fail "Fixture v99.0.0-overlap.json not found (create it first)"
    else
        local REPLACES
        REPLACES=$(jq -r '.plugin_check.replaces_custom | length' "$FIXTURE" 2>/dev/null || echo "0")

        if [ "$REPLACES" -gt 0 ]; then
            pass "Non-empty replaces_custom detected as overlap"
        else
            fail "v99.0.0-overlap.json should have non-empty replaces_custom, got length $REPLACES"
        fi
    fi
}
test_overlap_detected

# Test 10: Empty replaces_custom → has_overlap=false
test_no_overlap() {
    local FIXTURE="$REPO_ROOT/tests/fixtures/releases/v2.1.16-tasks.json"

    local REPLACES
    REPLACES=$(jq -r '.plugin_check.replaces_custom | length' "$FIXTURE" 2>/dev/null || echo "0")

    if [ "$REPLACES" -eq 0 ]; then
        pass "Empty replaces_custom detected as no overlap"
    else
        fail "v2.1.16-tasks.json should have empty replaces_custom, got length $REPLACES"
    fi
}
test_no_overlap

# ============================================
# Workflow Integration Tests
# ============================================

# Test 11: Workflow has prove-it-test job
test_workflow_has_job() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if grep -q "prove-it-test:" "$WORKFLOW" 2>/dev/null; then
        pass "weekly-update.yml has prove-it-test job"
    else
        fail "weekly-update.yml missing prove-it-test job"
    fi
}
test_workflow_has_job

# Test 12: prove-it-test job has has_overlap conditional
test_job_has_conditional() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if grep -q "has_overlap" "$WORKFLOW" 2>/dev/null; then
        pass "prove-it-test job has has_overlap conditional"
    else
        fail "prove-it-test job missing has_overlap conditional"
    fi
}
test_job_has_conditional

# Test 13: YAML validation of weekly-update.yml
test_yaml_valid() {
    local WORKFLOW="$REPO_ROOT/.github/workflows/weekly-update.yml"

    if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW'))" 2>/dev/null; then
        pass "weekly-update.yml is valid YAML"
    else
        fail "weekly-update.yml has invalid YAML"
    fi
}
test_yaml_valid

# ============================================
# Results
# ============================================

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
