#!/bin/bash
# Setup-Path E2E Proof: verify `init` works on every project type
# Tests that the wizard installs cleanly into real project fixtures
# without clobbering existing files.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/../cli/bin/sdlc-wizard.js"
FIXTURES_DIR="$SCRIPT_DIR/e2e/fixtures"
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

# Create a fresh temp dir with a fixture copied into it
make_fixture() {
    local fixture_name="$1"
    local d
    d=$(mktemp -d "${TMPDIR:-/tmp}/sdlc-setup-test-XXXXXX")
    cp -R "$FIXTURES_DIR/$fixture_name/." "$d/"
    echo "$d"
}

echo "=== Setup-Path E2E Tests ==="
echo ""

# ─────────────────────────────────────────────────────
# Per-fixture tests: init into each project type
# ─────────────────────────────────────────────────────

FIXTURE_NAMES="fresh-nextjs fresh-python go-api legacy-messy mern-stack nextjs-typescript python-fastapi complex-existing-config blank-repo"

for fixture in $FIXTURE_NAMES; do
    # Test: init exits 0
    d=$(make_fixture "$fixture")
    if (cd "$d" && node "$CLI" init > /dev/null 2>&1); then
        pass "[$fixture] init exits 0"
    else
        fail "[$fixture] init should exit 0"
    fi

    # Test: all 9 wizard files created
    count=0
    [ -f "$d/.claude/settings.json" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/sdlc-prompt-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/tdd-pretool-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/hooks/instructions-loaded-check.sh" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/sdlc/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/setup/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/update/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/.claude/skills/ci-analyzer/SKILL.md" ] && count=$((count + 1))
    [ -f "$d/CLAUDE_CODE_SDLC_WIZARD.md" ] && count=$((count + 1))
    if [ "$count" -eq 9 ]; then
        pass "[$fixture] all 9 wizard files created"
    else
        fail "[$fixture] expected 9 wizard files, found $count"
    fi

    # Test: hooks are executable
    exec_count=0
    [ -x "$d/.claude/hooks/sdlc-prompt-check.sh" ] && exec_count=$((exec_count + 1))
    [ -x "$d/.claude/hooks/tdd-pretool-check.sh" ] && exec_count=$((exec_count + 1))
    [ -x "$d/.claude/hooks/instructions-loaded-check.sh" ] && exec_count=$((exec_count + 1))
    if [ "$exec_count" -eq 3 ]; then
        pass "[$fixture] all 3 hooks are executable"
    else
        fail "[$fixture] expected 3 executable hooks, found $exec_count"
    fi

    # Test: settings.json is valid JSON
    if python3 -c "import json; json.load(open('$d/.claude/settings.json'))" 2>/dev/null; then
        pass "[$fixture] settings.json is valid JSON"
    else
        fail "[$fixture] settings.json should be valid JSON"
    fi

    # README must survive init — proves init doesn't clobber project files
    if [ -f "$d/README.md" ]; then
        original=$(cat "$FIXTURES_DIR/$fixture/README.md")
        installed=$(cat "$d/README.md")
        if [ "$original" = "$installed" ]; then
            pass "[$fixture] README.md untouched after init"
        else
            fail "[$fixture] README.md was modified by init"
        fi
    else
        pass "[$fixture] no README.md to verify (skip)"
    fi

    rm -rf "$d"
done

# ─────────────────────────────────────────────────────
# Project-specific file preservation tests
# ─────────────────────────────────────────────────────

# Node projects: package.json preserved
for fixture in fresh-nextjs legacy-messy nextjs-typescript; do
    d=$(make_fixture "$fixture")
    original=$(cat "$FIXTURES_DIR/$fixture/package.json")
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    installed=$(cat "$d/package.json")
    if [ "$original" = "$installed" ]; then
        pass "[$fixture] package.json preserved after init"
    else
        fail "[$fixture] package.json was modified by init"
    fi
    rm -rf "$d"
done

# Python projects: pyproject.toml preserved
for fixture in fresh-python python-fastapi; do
    d=$(make_fixture "$fixture")
    original=$(cat "$FIXTURES_DIR/$fixture/pyproject.toml")
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    installed=$(cat "$d/pyproject.toml")
    if [ "$original" = "$installed" ]; then
        pass "[$fixture] pyproject.toml preserved after init"
    else
        fail "[$fixture] pyproject.toml was modified by init"
    fi
    rm -rf "$d"
done

# Go project: go.mod preserved
d=$(make_fixture "go-api")
original=$(cat "$FIXTURES_DIR/go-api/go.mod")
(cd "$d" && node "$CLI" init > /dev/null 2>&1)
installed=$(cat "$d/go.mod")
if [ "$original" = "$installed" ]; then
    pass "[go-api] go.mod preserved after init"
else
    fail "[go-api] go.mod was modified by init"
fi
rm -rf "$d"

# ─────────────────────────────────────────────────────
# Cross-fixture behavior tests
# ─────────────────────────────────────────────────────

# Test: .gitignore created for project without one
d=$(make_fixture "fresh-python")
(cd "$d" && node "$CLI" init > /dev/null 2>&1)
if [ -f "$d/.gitignore" ] && grep -q ".claude/plans/" "$d/.gitignore"; then
    pass "[fresh-python] .gitignore created with wizard entries"
else
    fail "[fresh-python] .gitignore should be created with .claude/plans/"
fi
rm -rf "$d"

# Test: .gitignore appended for project with existing one
d=$(make_fixture "fresh-nextjs")
echo "node_modules/" > "$d/.gitignore"
(cd "$d" && node "$CLI" init > /dev/null 2>&1)
if grep -q "node_modules/" "$d/.gitignore" && grep -q ".claude/plans/" "$d/.gitignore"; then
    pass "[fresh-nextjs] existing .gitignore preserved and wizard entries appended"
else
    fail "[fresh-nextjs] .gitignore should keep existing entries and add wizard ones"
fi
rm -rf "$d"

# Test: idempotent — re-running init skips existing files
d=$(make_fixture "go-api")
(cd "$d" && node "$CLI" init > /dev/null 2>&1)
output=$(cd "$d" && node "$CLI" init 2>&1 || true)
if echo "$output" | grep -q "SKIP"; then
    pass "[go-api] re-running init skips existing files"
else
    fail "[go-api] re-running init should show SKIP for existing files"
fi
rm -rf "$d"

# Test: --force overwrites on re-run
d=$(make_fixture "mern-stack")
(cd "$d" && node "$CLI" init > /dev/null 2>&1)
echo "modified" > "$d/.claude/settings.json"
(cd "$d" && node "$CLI" init --force > /dev/null 2>&1)
content=$(cat "$d/.claude/settings.json")
if [ "$content" != "modified" ]; then
    pass "[mern-stack] --force overwrites existing wizard files"
else
    fail "[mern-stack] --force should overwrite existing wizard files"
fi
rm -rf "$d"

# Test: existing src/ directory not touched (critical for all project types)
d=$(make_fixture "nextjs-typescript")
original_src_count=$(find "$d/src" -type f | wc -l | tr -d ' ')
(cd "$d" && node "$CLI" init > /dev/null 2>&1)
installed_src_count=$(find "$d/src" -type f | wc -l | tr -d ' ')
if [ "$original_src_count" = "$installed_src_count" ]; then
    pass "[nextjs-typescript] src/ directory file count unchanged"
else
    fail "[nextjs-typescript] src/ had $original_src_count files, now has $installed_src_count"
fi
rm -rf "$d"

# Test: existing tests/ directory not touched
d=$(make_fixture "python-fastapi")
if [ -d "$FIXTURES_DIR/python-fastapi/tests" ]; then
    original_test_count=$(find "$d/tests" -type f | wc -l | tr -d ' ')
    (cd "$d" && node "$CLI" init > /dev/null 2>&1)
    installed_test_count=$(find "$d/tests" -type f | wc -l | tr -d ' ')
    if [ "$original_test_count" = "$installed_test_count" ]; then
        pass "[python-fastapi] tests/ directory file count unchanged"
    else
        fail "[python-fastapi] tests/ had $original_test_count files, now has $installed_test_count"
    fi
else
    pass "[python-fastapi] no tests/ dir to verify (skip)"
fi
rm -rf "$d"

# ─────────────────────────────────────────────────────
# Complex existing config tests (existing .claude/ dir)
# ─────────────────────────────────────────────────────

d=$(make_fixture "complex-existing-config")
(cd "$d" && node "$CLI" init > /dev/null 2>&1)

# Test: custom hook preserved
original=$(cat "$FIXTURES_DIR/complex-existing-config/.claude/hooks/custom-lint.sh")
installed=$(cat "$d/.claude/hooks/custom-lint.sh")
if [ "$original" = "$installed" ]; then
    pass "[complex-existing-config] custom hook preserved after init"
else
    fail "[complex-existing-config] custom-lint.sh was modified by init"
fi

# Test: custom skill preserved
original=$(cat "$FIXTURES_DIR/complex-existing-config/.claude/skills/deploy/SKILL.md")
installed=$(cat "$d/.claude/skills/deploy/SKILL.md")
if [ "$original" = "$installed" ]; then
    pass "[complex-existing-config] custom skill preserved after init"
else
    fail "[complex-existing-config] deploy/SKILL.md was modified by init"
fi

# Test: custom command preserved
original=$(cat "$FIXTURES_DIR/complex-existing-config/.claude/commands/review.md")
installed=$(cat "$d/.claude/commands/review.md")
if [ "$original" = "$installed" ]; then
    pass "[complex-existing-config] custom command preserved after init"
else
    fail "[complex-existing-config] commands/review.md was modified by init"
fi

# Test: settings.local.json preserved
original=$(cat "$FIXTURES_DIR/complex-existing-config/.claude/settings.local.json")
installed=$(cat "$d/.claude/settings.local.json")
if [ "$original" = "$installed" ]; then
    pass "[complex-existing-config] settings.local.json preserved after init"
else
    fail "[complex-existing-config] settings.local.json was modified by init"
fi

# Test: CLAUDE.md preserved
original=$(cat "$FIXTURES_DIR/complex-existing-config/CLAUDE.md")
installed=$(cat "$d/CLAUDE.md")
if [ "$original" = "$installed" ]; then
    pass "[complex-existing-config] CLAUDE.md preserved after init"
else
    fail "[complex-existing-config] CLAUDE.md was modified by init"
fi

# Test: settings.json has wizard hooks after merge
if grep -q "sdlc-prompt-check" "$d/.claude/settings.json"; then
    pass "[complex-existing-config] settings.json has wizard hooks after init"
else
    fail "[complex-existing-config] settings.json should have wizard hooks after merge"
fi

# Test: settings.json preserves allowedTools
if grep -q "allowedTools" "$d/.claude/settings.json"; then
    pass "[complex-existing-config] settings.json preserves allowedTools"
else
    fail "[complex-existing-config] settings.json should preserve allowedTools after merge"
fi

# Test: settings.json preserves custom hooks
if grep -q "custom-lint" "$d/.claude/settings.json"; then
    pass "[complex-existing-config] settings.json preserves custom hooks"
else
    fail "[complex-existing-config] settings.json should preserve custom hooks after merge"
fi

rm -rf "$d"

# ─────────────────────────────────────────────────────
# Blank repo tests (no CLAUDE.md, no manifest, no src)
# ─────────────────────────────────────────────────────

d=$(make_fixture "blank-repo")
(cd "$d" && node "$CLI" init > /dev/null 2>&1)

# Test: .gitignore created from scratch on blank repo
if [ -f "$d/.gitignore" ] && grep -q ".claude/plans/" "$d/.gitignore" && grep -q "settings.local.json" "$d/.gitignore"; then
    pass "[blank-repo] .gitignore created from scratch with wizard entries"
else
    fail "[blank-repo] .gitignore should be created with .claude/plans/ and settings.local.json"
fi

# Test: no CLAUDE.md generated (CLI doesn't generate it — setup wizard does)
if [ ! -f "$d/CLAUDE.md" ]; then
    pass "[blank-repo] no CLAUDE.md generated by CLI (setup wizard handles this)"
else
    fail "[blank-repo] CLI should not generate CLAUDE.md — that's the setup wizard's job"
fi

# Test: no src/ or tests/ directories created
if [ ! -d "$d/src" ] && [ ! -d "$d/tests" ]; then
    pass "[blank-repo] no src/ or tests/ directories created"
else
    fail "[blank-repo] init should not create src/ or tests/ directories"
fi

rm -rf "$d"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All setup-path E2E tests passed!"
