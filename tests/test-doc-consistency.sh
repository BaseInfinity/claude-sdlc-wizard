#!/bin/bash
# Test cross-document consistency: hardcoded counts must match filesystem reality
# Roadmap #102: docs drift silently when counts are hardcoded
#
# Philosophy: targeted checks for known-drifting claims, NOT generic
# "grep all numbers" which would be too noisy and brittle.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Strip fenced code blocks from a file before grepping for claims.
# Prevents false positives from example code like: "run 2 workflows"
strip_code_blocks() {
    sed '/^```/,/^```/d' "$1"
}

echo "=== Cross-Document Consistency Tests ==="
echo ""

# ────────────────────────────────────────────
# Workflow Count Consistency
# ────────────────────────────────────────────

echo "--- Workflow Count ---"

ACTUAL_WORKFLOWS=$(ls "$REPO_ROOT"/.github/workflows/*.yml 2>/dev/null | wc -l | tr -d ' ')

# Test 1: README should NOT hardcode workflow count (use count-free language)
test_readme_no_hardcoded_workflow_count() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then fail "README.md not found"; return; fi
    # Should say "All workflows" not "All 7 workflows" or "7 workflows"
    # Strip code blocks to avoid false positives from examples
    if strip_code_blocks "$README" | grep -qE '\b[0-9]+\s+workflows?\b'; then
        local found
        found=$(strip_code_blocks "$README" | grep -oE '\b[0-9]+\s+workflows?\b' | head -1)
        fail "README.md hardcodes workflow count: '$found' (should use count-free language)"
    else
        pass "README.md does not hardcode workflow count"
    fi
}

# Test 2: No doc outside CHANGELOG/ROADMAP/plans claims wrong workflow count
test_no_stale_workflow_count() {
    local stale=""
    # Search for "N workflows" in active docs (not historical)
    for doc in "$REPO_ROOT"/README.md "$REPO_ROOT"/CI_CD.md "$REPO_ROOT"/ARCHITECTURE.md \
               "$REPO_ROOT"/CONTRIBUTING.md "$REPO_ROOT"/COMPETITIVE_AUDIT.md \
               "$REPO_ROOT"/CODE_REVIEW_EXCEPTIONS.md "$REPO_ROOT"/SDLC.md; do
        [ ! -f "$doc" ] && continue
        local basename
        basename=$(basename "$doc")
        # Find lines claiming N workflows where N is wrong (exclude code blocks)
        while IFS= read -r line; do
            local claimed
            claimed=$(echo "$line" | grep -oE '\b[0-9]+\s+workflows?\b' | head -1 | grep -oE '[0-9]+')
            if [ -n "$claimed" ] && [ "$claimed" != "$ACTUAL_WORKFLOWS" ]; then
                stale="$stale\n  $basename: claims $claimed workflows (actual: $ACTUAL_WORKFLOWS)"
            fi
        done < <(strip_code_blocks "$doc" | grep -nE '\b[0-9]+\s+workflows?\b' 2>/dev/null || true)
    done
    if [ -z "$stale" ]; then
        pass "No stale workflow counts in active docs (actual: $ACTUAL_WORKFLOWS)"
    else
        fail "Stale workflow counts found:$stale"
    fi
}

test_readme_no_hardcoded_workflow_count
test_no_stale_workflow_count

# ────────────────────────────────────────────
# CLI File Count Consistency
# ────────────────────────────────────────────

echo ""
echo "--- CLI File Count ---"

# Count FILES entries in init.js (the source of truth)
# The full install output = FILES array entries + the wizard doc (CLAUDE_CODE_SDLC_WIZARD.md)
INIT_JS="$REPO_ROOT/cli/init.js"
FILES_COUNT=$(grep -c "src:.*dest:" "$INIT_JS" 2>/dev/null || echo "0")
# init.js also copies WIZARD_DOC (CLAUDE_CODE_SDLC_WIZARD.md) separately
ACTUAL_CLI_FILES=$((FILES_COUNT + 1))

# Test 3: CI_CD.md file count claims match init.js
test_ci_cd_file_count() {
    local CI_CD="$REPO_ROOT/CI_CD.md"
    if [ ! -f "$CI_CD" ]; then fail "CI_CD.md not found"; return; fi
    # Look for "N files created" or "all N files" in install verification context
    local stale=""
    while IFS= read -r line; do
        local claimed
        claimed=$(echo "$line" | grep -oE '\b[0-9]+\s+files?\b' | head -1 | grep -oE '[0-9]+')
        if [ -n "$claimed" ] && [ "$claimed" != "$ACTUAL_CLI_FILES" ]; then
            stale="$stale\n  claims $claimed files (actual: $ACTUAL_CLI_FILES)"
        fi
    done < <(strip_code_blocks "$CI_CD" | grep -nE '\b[0-9]+\s+files?\s*(created|simulates)' 2>/dev/null || true)
    # Also check "all N files"
    while IFS= read -r line; do
        local claimed
        claimed=$(echo "$line" | grep -oE 'all\s+[0-9]+\s+files' | grep -oE '[0-9]+')
        if [ -n "$claimed" ] && [ "$claimed" != "$ACTUAL_CLI_FILES" ]; then
            stale="$stale\n  claims 'all $claimed files' (actual: $ACTUAL_CLI_FILES)"
        fi
    done < <(strip_code_blocks "$CI_CD" | grep -niE 'all\s+[0-9]+\s+files' 2>/dev/null || true)
    if [ -z "$stale" ]; then
        pass "CI_CD.md CLI file counts match init.js ($ACTUAL_CLI_FILES files)"
    else
        fail "CI_CD.md stale CLI file counts:$stale"
    fi
}

# Test 4: CI_CD.md should prefer count-free language for CLI install verification
test_ci_cd_no_hardcoded_file_count() {
    local CI_CD="$REPO_ROOT/CI_CD.md"
    if [ ! -f "$CI_CD" ]; then fail "CI_CD.md not found"; return; fi
    if strip_code_blocks "$CI_CD" | grep -qE '\b[0-9]+\s+files\s+created\b' || strip_code_blocks "$CI_CD" | grep -qiE 'all\s+[0-9]+\s+files'; then
        fail "CI_CD.md hardcodes CLI file count (should use count-free language like 'all CLI files')"
    else
        pass "CI_CD.md uses count-free language for CLI files"
    fi
}

test_ci_cd_file_count
test_ci_cd_no_hardcoded_file_count

# ────────────────────────────────────────────
# Skill Count Consistency
# ────────────────────────────────────────────

echo ""
echo "--- Skill Count ---"

# Skills live at repo root skills/ (symlinked into .claude/skills/)
ACTUAL_SKILLS=$(ls "$REPO_ROOT"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')

# Test 5: COMPETITIVE_AUDIT.md skill count matches actual
test_competitive_audit_skill_count() {
    local AUDIT="$REPO_ROOT/COMPETITIVE_AUDIT.md"
    if [ ! -f "$AUDIT" ]; then fail "COMPETITIVE_AUDIT.md not found"; return; fi
    # Look for "N skills" in our column (not competitor column like "80+ skills")
    # The pattern is "| N skills" in a table row about us
    local our_claim
    our_claim=$(grep -i 'skill library' "$AUDIT" | grep -oE '\|\s*[0-9]+\s+skills' | tail -1 | grep -oE '[0-9]+' || echo "")
    if [ -z "$our_claim" ]; then
        pass "COMPETITIVE_AUDIT.md does not hardcode our skill count"
    elif [ "$our_claim" = "$ACTUAL_SKILLS" ]; then
        pass "COMPETITIVE_AUDIT.md skill count correct ($our_claim = $ACTUAL_SKILLS)"
    else
        fail "COMPETITIVE_AUDIT.md claims $our_claim skills (actual: $ACTUAL_SKILLS)"
    fi
}

test_competitive_audit_skill_count

# ────────────────────────────────────────────
# Scenario Count Consistency
# ────────────────────────────────────────────

echo ""
echo "--- Scenario Count ---"

ACTUAL_SCENARIOS=$(ls "$REPO_ROOT"/tests/e2e/scenarios/*.md 2>/dev/null | wc -l | tr -d ' ')

# Test 6: No doc outside CHANGELOG/ROADMAP claims wrong scenario count
test_no_stale_scenario_count() {
    local stale=""
    for doc in "$REPO_ROOT"/README.md "$REPO_ROOT"/CI_CD.md "$REPO_ROOT"/TESTING.md \
               "$REPO_ROOT"/CONTRIBUTING.md "$REPO_ROOT"/COMPETITIVE_AUDIT.md; do
        [ ! -f "$doc" ] && continue
        local basename
        basename=$(basename "$doc")
        while IFS= read -r line; do
            local claimed
            claimed=$(echo "$line" | grep -oE '\b[0-9]+\s+scenarios\b' | head -1 | grep -oE '[0-9]+')
            if [ -n "$claimed" ] && [ "$claimed" != "$ACTUAL_SCENARIOS" ]; then
                stale="$stale\n  $basename: claims $claimed scenarios (actual: $ACTUAL_SCENARIOS)"
            fi
        done < <(strip_code_blocks "$doc" | grep -nE '\b[0-9]+\s+scenarios\b' 2>/dev/null || true)
    done
    if [ -z "$stale" ]; then
        pass "No stale scenario counts in active docs (actual: $ACTUAL_SCENARIOS)"
    else
        fail "Stale scenario counts found:$stale"
    fi
}

test_no_stale_scenario_count

# ────────────────────────────────────────────
# CODE_REVIEW_EXCEPTIONS Consistency
# ────────────────────────────────────────────

echo ""
echo "--- Code Review Exceptions ---"

# Test 7: CODE_REVIEW_EXCEPTIONS.md should not hardcode workflow count
test_code_review_exceptions_no_hardcoded_count() {
    local EXCEPTIONS="$REPO_ROOT/CODE_REVIEW_EXCEPTIONS.md"
    if [ ! -f "$EXCEPTIONS" ]; then pass "CODE_REVIEW_EXCEPTIONS.md not found (OK)"; return; fi
    if strip_code_blocks "$EXCEPTIONS" | grep -qE '\b[0-9]+\s+workflows?\b'; then
        local found
        found=$(strip_code_blocks "$EXCEPTIONS" | grep -oE '\b[0-9]+\s+workflows?\b' | head -1)
        fail "CODE_REVIEW_EXCEPTIONS.md hardcodes workflow count: '$found'"
    else
        pass "CODE_REVIEW_EXCEPTIONS.md does not hardcode workflow count"
    fi
}

test_code_review_exceptions_no_hardcoded_count

# ────────────────────────────────────────────
# Cross-Check: init.js FILES vs filesystem
# ────────────────────────────────────────────

echo ""
echo "--- Init.js Source-of-Truth ---"

# Test 8: Every file in init.js FILES actually exists
test_init_js_files_exist() {
    if [ ! -f "$INIT_JS" ]; then fail "cli/init.js not found"; return; fi
    local missing=""
    # Extract src paths from FILES array (lines with both src: and dest:)
    while IFS= read -r src_path; do
        # Check both REPO_ROOT and TEMPLATES_DIR locations
        if [ ! -f "$REPO_ROOT/$src_path" ] && [ ! -f "$REPO_ROOT/cli/templates/$src_path" ]; then
            missing="$missing $src_path"
        fi
    done < <(grep "src:.*dest:" "$INIT_JS" | sed "s/.*src: *['\"]//;s/['\"].*//" )
    if [ -z "$missing" ]; then
        pass "All init.js FILES entries exist on disk ($ACTUAL_CLI_FILES files)"
    else
        fail "init.js references missing files:$missing"
    fi
}

test_init_js_files_exist

# Test 9: Every skill in init.js FILES has a matching SKILL.md on disk
test_init_js_skills_match_disk() {
    if [ ! -f "$INIT_JS" ]; then fail "cli/init.js not found"; return; fi
    local init_skills disk_skills
    # Extract skill paths from FILES array (lines with src: and dest:)
    init_skills=$(grep "src:.*dest:" "$INIT_JS" | sed "s/.*src: *['\"]//;s/['\"].*//" | grep 'skills/' | sort)
    # Get skills from disk (repo root skills/, same path format as init.js)
    disk_skills=$(ls "$REPO_ROOT"/skills/*/SKILL.md 2>/dev/null | \
        sed "s|$REPO_ROOT/||" | sort)
    if [ "$init_skills" = "$disk_skills" ]; then
        pass "init.js skill list matches disk ($(echo "$init_skills" | wc -l | tr -d ' ') skills)"
    else
        local only_init only_disk
        only_init=$(comm -23 <(echo "$init_skills") <(echo "$disk_skills"))
        only_disk=$(comm -13 <(echo "$init_skills") <(echo "$disk_skills"))
        fail "init.js skills != disk skills. Only in init.js: [$only_init] Only on disk: [$only_disk]"
    fi
}

test_init_js_skills_match_disk

# ────────────────────────────────────────────
# Scoring Rubric Consistency
# ────────────────────────────────────────────

echo ""
echo "--- Scoring Rubric ---"

# Test 10: README should not hardcode criteria count (it drifts when rubric changes)
test_readme_no_hardcoded_criteria_count() {
    local README="$REPO_ROOT/README.md"
    if [ ! -f "$README" ]; then fail "README.md not found"; return; fi
    if strip_code_blocks "$README" | grep -qE '\b[0-9]+\s+criteria\b'; then
        local found
        found=$(strip_code_blocks "$README" | grep -oE '\b[0-9]+\s+criteria\b' | head -1)
        fail "README.md hardcodes criteria count: '$found' (should use count-free language)"
    else
        pass "README.md does not hardcode criteria count"
    fi
}

test_readme_no_hardcoded_criteria_count

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

echo "All cross-document consistency tests passed!"
