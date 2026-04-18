#!/bin/bash
# Community feedback + contribution paths tests (#98)
# Validates: issue templates exist with required fields, PR template exists,
# CONTRIBUTING.md is discoverable from README, /feedback skill is wired.
#
# Why: external contributors shouldn't hit a blank "New issue" form. They
# need bug/feature/question routes with labels + minimum field guidance.
# When these paths drift (e.g., template deleted, label missing), external
# feedback quality degrades silently.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISSUE_DIR="$REPO_ROOT/.github/ISSUE_TEMPLATE"
PR_TEMPLATE="$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md"

PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }

echo "=== Community Paths Tests (#98) ==="
echo ""

# ────────────────────────────────────────────
# Issue templates
# ────────────────────────────────────────────

test_issue_template_dir_exists() {
    if [ -d "$ISSUE_DIR" ]; then
        pass ".github/ISSUE_TEMPLATE/ directory exists"
    else
        fail ".github/ISSUE_TEMPLATE/ directory missing — external contributors hit blank issue form"
    fi
}

test_bug_report_template() {
    local f="$ISSUE_DIR/bug_report.md"
    if [ ! -f "$f" ]; then
        fail "bug_report.md template missing"
        return
    fi
    # Must have YAML frontmatter with name, about, labels
    local missing=""
    for key in '^name:' '^about:' '^labels:'; do
        if ! grep -q "$key" "$f"; then
            missing="${missing:+${missing}, }${key//^/}"
        fi
    done
    if [ -z "$missing" ]; then
        pass "bug_report.md has required frontmatter (name/about/labels)"
    else
        fail "bug_report.md missing frontmatter keys: $missing"
    fi
}

test_feature_request_template() {
    local f="$ISSUE_DIR/feature_request.md"
    if [ ! -f "$f" ]; then
        fail "feature_request.md template missing"
        return
    fi
    if grep -q '^name:' "$f" && grep -q '^about:' "$f" && grep -q '^labels:' "$f"; then
        pass "feature_request.md has required frontmatter"
    else
        fail "feature_request.md missing required frontmatter"
    fi
}

test_question_template() {
    local f="$ISSUE_DIR/question.md"
    if [ ! -f "$f" ]; then
        fail "question.md template missing"
        return
    fi
    if grep -q '^name:' "$f" && grep -q '^labels:' "$f"; then
        pass "question.md has required frontmatter"
    else
        fail "question.md missing required frontmatter"
    fi
}

test_issue_templates_reference_feedback_skill() {
    # At least one template should mention /feedback so users know about it
    if grep -rq '/feedback' "$ISSUE_DIR" 2>/dev/null; then
        pass "Issue templates mention /feedback skill as alternative path"
    else
        fail "No issue template mentions /feedback skill — users don't know about in-session feedback"
    fi
}

test_bug_template_mentions_sdlc_version() {
    # Diagnosis requires knowing the user's wizard version
    if grep -qE 'Wizard Version|sdlc[_ -]?wizard.*version|SDLC\.md' "$ISSUE_DIR/bug_report.md" 2>/dev/null; then
        pass "bug_report.md asks for wizard version (critical for diagnosis)"
    else
        fail "bug_report.md doesn't ask for wizard version — triage will be harder"
    fi
}

# ────────────────────────────────────────────
# PR template
# ────────────────────────────────────────────

test_pr_template_exists() {
    if [ -f "$PR_TEMPLATE" ]; then
        pass "PULL_REQUEST_TEMPLATE.md exists"
    else
        fail "PULL_REQUEST_TEMPLATE.md missing — contributors don't know what to include"
    fi
}

test_pr_template_has_test_plan() {
    if [ ! -f "$PR_TEMPLATE" ]; then return; fi
    if grep -qiE 'test plan|test\s*checklist|## tests?' "$PR_TEMPLATE"; then
        pass "PR template has test plan section"
    else
        fail "PR template missing test plan section — TDD evidence won't be captured"
    fi
}

test_pr_template_has_summary_section() {
    if [ ! -f "$PR_TEMPLATE" ]; then return; fi
    if grep -qiE '## summary|## what|## description' "$PR_TEMPLATE"; then
        pass "PR template has summary/what section"
    else
        fail "PR template missing summary section"
    fi
}

# ────────────────────────────────────────────
# Discoverability from README + CONTRIBUTING
# ────────────────────────────────────────────

test_readme_links_to_contributing() {
    if grep -qE 'CONTRIBUTING\.md|contributing\.md|CONTRIBUTING\]' "$REPO_ROOT/README.md"; then
        pass "README links to CONTRIBUTING.md"
    else
        fail "README does not link to CONTRIBUTING.md — discoverability gap"
    fi
}

test_contributing_exists_and_nonempty() {
    local f="$REPO_ROOT/CONTRIBUTING.md"
    if [ -f "$f" ] && [ -s "$f" ]; then
        pass "CONTRIBUTING.md exists and non-empty"
    else
        fail "CONTRIBUTING.md missing or empty"
    fi
}

# ────────────────────────────────────────────
# Run
# ────────────────────────────────────────────

test_issue_template_dir_exists
test_bug_report_template
test_feature_request_template
test_question_template
test_issue_templates_reference_feedback_skill
test_bug_template_mentions_sdlc_version

test_pr_template_exists
test_pr_template_has_test_plan
test_pr_template_has_summary_section

test_readme_links_to_contributing
test_contributing_exists_and_nonempty

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

echo "All community paths tests passed!"
