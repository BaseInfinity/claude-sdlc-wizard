#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

echo "=== Docs Usability Tests ==="
echo "Validates documentation from a first-time user perspective"
echo ""

# Helper: extract a ## section from a markdown file (macOS-compatible)
# Usage: extract_section "file" "Section Name"
extract_section() {
    awk -v section="$2" '
        /^## / { if (found) exit; if (index($0, section)) found=1 }
        found { print }
    ' "$1"
}

# ---------------------------------------------------------------------------
# README.md — The front door
# ---------------------------------------------------------------------------

README="$REPO_ROOT/README.md"

# Test: Install section is the first ## heading
test_readme_install_is_first_section() {
    local first_section
    first_section=$(grep -n '^## ' "$README" | head -1)
    if echo "$first_section" | grep -qi 'install'; then
        pass "README: Install is the first section"
    else
        fail "README: Install is NOT the first section (found: $first_section)"
    fi
}

# Test: Install section has a copy-pasteable code block
test_readme_install_has_code_block() {
    local install_section
    install_section=$(extract_section "$README" "Install")
    if echo "$install_section" | grep -q '```'; then
        pass "README: Install section has a code block"
    else
        fail "README: Install section has NO code block — users can't copy-paste"
    fi
}

# Test: Install code block contains the actual install command
test_readme_install_has_npx_command() {
    local install_section
    install_section=$(extract_section "$README" "Install")
    if echo "$install_section" | grep -q 'npx agentic-sdlc-wizard'; then
        pass "README: Install section has npx command"
    else
        fail "README: Install section missing 'npx agentic-sdlc-wizard' command"
    fi
}

# Test: Install section mentions Claude Code (prerequisite)
test_readme_install_mentions_claude_code() {
    local install_section
    install_section=$(extract_section "$README" "Install")
    if echo "$install_section" | grep -qi 'claude code'; then
        pass "README: Install section mentions Claude Code prerequisite"
    else
        fail "README: Install section doesn't mention Claude Code — users won't know what they need"
    fi
}

# Test: Install section mentions it works inside Claude Code session
test_readme_install_mentions_bang_prefix() {
    local install_section
    install_section=$(extract_section "$README" "Install")
    if echo "$install_section" | grep -q '!'; then
        pass "README: Install section mentions ! prefix (works inside Claude Code)"
    else
        fail "README: Install section doesn't mention running from inside Claude Code"
    fi
}

# ---------------------------------------------------------------------------
# ALL root .md files — basic structural health
# ---------------------------------------------------------------------------

# Test: Every root .md file has a title heading within first 5 lines
test_all_docs_have_title() {
    local all_pass=true
    for f in "$REPO_ROOT"/*.md; do
        local basename
        basename=$(basename "$f")
        # SDLC.md starts with an HTML comment (version), skip title check for it
        if [ "$basename" = "SDLC.md" ]; then
            continue
        fi
        # SCORE_TRENDS.md is auto-generated and may be sparse
        if [ "$basename" = "SCORE_TRENDS.md" ]; then
            continue
        fi
        if ! head -5 "$f" | grep -q '^# '; then
            fail "Doc '$basename' has no # title in first 5 lines"
            all_pass=false
        fi
    done
    if [ "$all_pass" = true ]; then
        pass "All docs have a title heading"
    fi
}

# Test: No empty docs (every .md has >5 lines of content)
test_no_empty_docs() {
    local all_pass=true
    for f in "$REPO_ROOT"/*.md; do
        local basename
        basename=$(basename "$f")
        local line_count
        line_count=$(wc -l < "$f" | tr -d ' ')
        if [ "$line_count" -lt 5 ]; then
            fail "Doc '$basename' has only $line_count lines — too sparse"
            all_pass=false
        fi
    done
    if [ "$all_pass" = true ]; then
        pass "All docs have meaningful content (>5 lines)"
    fi
}

# Test: Internal markdown links point to real files
test_no_broken_internal_links() {
    local all_pass=true
    for f in "$REPO_ROOT"/*.md; do
        local basename
        basename=$(basename "$f")
        # Extract markdown links like [text](FILE.md) — skip URLs and anchors
        local links
        links=$(grep -oE '\]\([A-Za-z0-9_.-]+\.md\)' "$f" 2>/dev/null | sed 's/\](\(.*\))/\1/' || true)
        for link in $links; do
            if [ ! -f "$REPO_ROOT/$link" ]; then
                fail "Doc '$basename' links to '$link' which doesn't exist"
                all_pass=false
            fi
        done
    done
    if [ "$all_pass" = true ]; then
        pass "All internal .md links point to existing files"
    fi
}

# ---------------------------------------------------------------------------
# User-facing docs — must have structure (## sections)
# ---------------------------------------------------------------------------

# Test: Key user-facing docs have structured sections
test_user_facing_docs_have_structure() {
    local all_pass=true
    for doc in README.md CONTRIBUTING.md CHANGELOG.md; do
        local filepath="$REPO_ROOT/$doc"
        if [ ! -f "$filepath" ]; then
            fail "User-facing doc '$doc' doesn't exist"
            all_pass=false
            continue
        fi
        local section_count
        section_count=$(grep -c '^## ' "$filepath" || true)
        if [ "$section_count" -lt 2 ]; then
            fail "Doc '$doc' has only $section_count sections — needs structure"
            all_pass=false
        fi
    done
    if [ "$all_pass" = true ]; then
        pass "User-facing docs have structured sections"
    fi
}

# Test: CONTRIBUTING.md has a quick start or getting started section
test_contributing_has_quick_start() {
    local contrib="$REPO_ROOT/CONTRIBUTING.md"
    if [ ! -f "$contrib" ]; then
        fail "CONTRIBUTING.md doesn't exist"
        return
    fi
    if grep -qiE '(quick start|getting started|how to|setup)' "$contrib"; then
        pass "CONTRIBUTING.md has a quick start / getting started section"
    else
        fail "CONTRIBUTING.md has no quick start — contributors don't know where to begin"
    fi
}

# Test: README main install flow does NOT tell user to manually run setup
# (Alternative/manual install in <details> may still need manual invocation — that's OK)
test_readme_install_no_manual_setup() {
    local main_install
    # Extract only the main install flow (before first <details> block)
    main_install=$(extract_section "$README" "Install" | sed '/<details>/,$d')
    if echo "$main_install" | grep -qi 'tell claude.*setup\|run the sdlc wizard setup'; then
        fail "README: Main install still tells users to manually invoke setup — hook auto-invokes now"
    else
        pass "README: Main install doesn't require manual setup invocation"
    fi
}

# Test: README install mentions auto-invoke / automatic setup
test_readme_install_mentions_auto() {
    local install_section
    install_section=$(extract_section "$README" "Install")
    if echo "$install_section" | grep -qi 'auto\|automatic'; then
        pass "README: Install mentions automatic setup"
    else
        fail "README: Install should mention that setup auto-invokes — users need to know it just works"
    fi
}

# ---------------------------------------------------------------------------
# Setup skill — must force-read the wizard doc
# ---------------------------------------------------------------------------

SETUP_SKILL="$REPO_ROOT/cli/templates/skills/setup/SKILL.md"

# Test: Setup skill explicitly instructs Claude to Read the wizard doc
test_setup_skill_reads_wizard_doc() {
    if [ ! -f "$SETUP_SKILL" ]; then
        fail "Setup skill template not found"
        return
    fi
    if grep -qi 'Read.*CLAUDE_CODE_SDLC_WIZARD\|Read.*wizard.*file\|Read.*entire.*wizard' "$SETUP_SKILL"; then
        pass "Setup skill explicitly instructs Claude to read the wizard doc"
    else
        fail "Setup skill never tells Claude to READ the wizard doc — it just says 'Reference' which Claude ignores"
    fi
}

# ---------------------------------------------------------------------------
# Skill consolidation — /testing merged into /sdlc (#28)
# ---------------------------------------------------------------------------

# Test: Hook routes ALL tasks to /sdlc (no separate /testing route)
test_hook_no_testing_route() {
    local HOOK="$REPO_ROOT/cli/templates/hooks/sdlc-prompt-check.sh"
    if grep -q 'skill="testing"' "$HOOK"; then
        fail "Hook still routes to skill=\"testing\" — should route all tasks to /sdlc"
    else
        pass "Hook routes all tasks to /sdlc (no /testing route)"
    fi
}

# Test: /testing skill template does NOT exist (consolidated into /sdlc)
test_no_testing_skill_template() {
    if [ -f "$REPO_ROOT/cli/templates/skills/testing/SKILL.md" ]; then
        fail "Template /testing skill still exists — should be consolidated into /sdlc"
    else
        pass "Template /testing skill removed (consolidated into /sdlc)"
    fi
}

# Test: /sdlc skill has "After Session" content (migrated from /testing)
test_sdlc_has_after_session() {
    local SDLC_SKILL="$REPO_ROOT/cli/templates/skills/sdlc/SKILL.md"
    if grep -qi 'after session\|capture learnings' "$SDLC_SKILL"; then
        pass "/sdlc skill has After Session / capture learnings content"
    else
        fail "/sdlc skill missing After Session content — was this migrated from /testing?"
    fi
}

# Test: /sdlc skill has mocking table (migrated from /testing — zero content loss)
test_sdlc_has_mocking_table() {
    local SDLC_SKILL="$REPO_ROOT/cli/templates/skills/sdlc/SKILL.md"
    if grep -q 'Database.*NEVER' "$SDLC_SKILL" && grep -q 'External APIs.*YES' "$SDLC_SKILL"; then
        pass "/sdlc skill has mocking table (DB=NEVER, APIs=YES)"
    else
        fail "/sdlc skill missing mocking table — was this migrated from /testing?"
    fi
}

# Test: /sdlc skill has unit test qualification criteria (migrated from /testing)
test_sdlc_has_unit_test_criteria() {
    local SDLC_SKILL="$REPO_ROOT/cli/templates/skills/sdlc/SKILL.md"
    if grep -qi 'pure logic only\|no database calls\|input.*output.*transformation' "$SDLC_SKILL"; then
        pass "/sdlc skill has unit test qualification criteria"
    else
        fail "/sdlc skill missing unit test criteria — was this migrated from /testing?"
    fi
}

# Test: /sdlc skill has TDD PROVE content (migrated from /testing)
test_sdlc_has_tdd_prove() {
    local SDLC_SKILL="$REPO_ROOT/cli/templates/skills/sdlc/SKILL.md"
    if grep -qi 'RED.*FAILS\|test.*FAILS.*bug exists\|TDD.*PROVE' "$SDLC_SKILL"; then
        pass "/sdlc skill has TDD Must PROVE content"
    else
        fail "/sdlc skill missing TDD Must PROVE content — was this migrated from /testing?"
    fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "--- README.md (the front door) ---"
test_readme_install_is_first_section
test_readme_install_has_code_block
test_readme_install_has_npx_command
test_readme_install_mentions_claude_code
test_readme_install_mentions_bang_prefix
test_readme_install_no_manual_setup
test_readme_install_mentions_auto

echo ""
echo "--- Setup skill ---"
test_setup_skill_reads_wizard_doc

echo ""
echo "--- Skill consolidation (#28) ---"
test_hook_no_testing_route
test_no_testing_skill_template
test_sdlc_has_after_session
test_sdlc_has_mocking_table
test_sdlc_has_unit_test_criteria
test_sdlc_has_tdd_prove

echo ""
echo "--- All docs structural health ---"
test_all_docs_have_title
test_no_empty_docs
test_no_broken_internal_links

echo ""
echo "--- User-facing docs ---"
test_user_facing_docs_have_structure
test_contributing_has_quick_start

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
