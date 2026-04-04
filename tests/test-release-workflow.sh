#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"

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

# --- Tests ---

test_workflow_exists() {
    if [ -f "$WORKFLOW" ]; then
        pass "release.yml exists"
    else
        fail "release.yml does not exist"
    fi
}

test_yaml_valid() {
    if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW'))" 2>/dev/null; then
        pass "release.yml is valid YAML"
    else
        fail "release.yml is invalid YAML"
    fi
}

test_trigger_on_tag_push() {
    if grep -A2 'on:' "$WORKFLOW" | grep -q "tags:" && grep -q "'v\*'" "$WORKFLOW"; then
        pass "release.yml triggers on tag push (v*)"
    else
        fail "release.yml does not trigger on tag push (v*)"
    fi
}

test_has_contents_write_permission() {
    if grep -q 'contents: write' "$WORKFLOW"; then
        pass "release.yml has contents: write permission"
    else
        fail "release.yml missing contents: write permission"
    fi
}

test_uses_checkout_v4() {
    if grep -q 'actions/checkout@v4' "$WORKFLOW"; then
        pass "release.yml uses actions/checkout@v4"
    else
        fail "release.yml does not use actions/checkout@v4"
    fi
}

test_uses_setup_node_with_registry() {
    if grep -q 'actions/setup-node@v4' "$WORKFLOW" && grep -q 'registry-url' "$WORKFLOW"; then
        pass "release.yml uses setup-node@v4 with registry-url"
    else
        fail "release.yml missing setup-node@v4 with registry-url"
    fi
}

test_uses_gh_release_action() {
    if grep -q 'softprops/action-gh-release' "$WORKFLOW"; then
        pass "release.yml uses softprops/action-gh-release"
    else
        fail "release.yml does not use softprops/action-gh-release"
    fi
}

test_references_npm_token() {
    if grep -q 'NPM_TOKEN' "$WORKFLOW"; then
        pass "release.yml references NPM_TOKEN secret"
    else
        fail "release.yml does not reference NPM_TOKEN secret"
    fi
}

test_generates_release_notes() {
    if grep -q 'generate_release_notes: true' "$WORKFLOW"; then
        pass "release.yml generates release notes automatically"
    else
        fail "release.yml does not generate release notes"
    fi
}

test_npm_publish_step() {
    if grep -q 'npm publish' "$WORKFLOW"; then
        pass "release.yml has npm publish step"
    else
        fail "release.yml missing npm publish step"
    fi
}

test_verifies_tag_on_main() {
    if grep -q 'merge-base --is-ancestor' "$WORKFLOW"; then
        pass "release.yml verifies tag is on main branch"
    else
        fail "release.yml does not verify tag is on main branch"
    fi
}

test_npm_provenance() {
    if grep -q '\-\-provenance' "$WORKFLOW"; then
        pass "release.yml uses npm publish --provenance (SLSA)"
    else
        fail "release.yml missing --provenance flag"
    fi
}

# --- Run tests ---

test_workflow_exists
test_yaml_valid
test_trigger_on_tag_push
test_has_contents_write_permission
test_uses_checkout_v4
test_uses_setup_node_with_registry
test_uses_gh_release_action
test_references_npm_token
test_generates_release_notes
test_npm_publish_step
test_verifies_tag_on_main
test_npm_provenance

# --- Results ---

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
