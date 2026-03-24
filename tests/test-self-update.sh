#!/bin/bash
# Test self-update mechanism in the wizard document

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZARD="$SCRIPT_DIR/../CLAUDE_CODE_SDLC_WIZARD.md"
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

echo "=== Self-Update Mechanism Tests ==="
echo ""

# Test 1: Wizard contains raw CHANGELOG URL
test_changelog_url() {
    if grep -q "raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/main/CHANGELOG.md" "$WIZARD"; then
        pass "Wizard contains raw CHANGELOG URL"
    else
        fail "Wizard should contain raw.githubusercontent.com CHANGELOG URL"
    fi
}

# Test 2: Wizard contains raw wizard URL
test_wizard_url() {
    if grep -q "raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/main/CLAUDE_CODE_SDLC_WIZARD.md" "$WIZARD"; then
        pass "Wizard contains raw wizard URL"
    else
        fail "Wizard should contain raw.githubusercontent.com wizard URL"
    fi
}

# Test 3: Step registry contains update-notify step
test_step_registry() {
    if grep -q "step-update-notify" "$WIZARD"; then
        pass "Step registry contains step-update-notify"
    else
        fail "Step registry should contain step-update-notify entry"
    fi
}

# Test 4: Update flow mentions CHANGELOG-first approach
test_changelog_first() {
    # The wizard should instruct Claude to fetch CHANGELOG before the full wizard
    if grep -qi "fetch.*changelog.*first\|changelog.*first\|phase 1.*changelog\|step 1.*changelog" "$WIZARD"; then
        pass "Update flow mentions CHANGELOG-first approach"
    else
        fail "Update flow should mention fetching CHANGELOG first"
    fi
}

# Test 5: Optional notification workflow template exists
test_notification_workflow_exists() {
    if grep -q "SDLC Wizard Update Check\|wizard-update-check\|Wizard Update Notification" "$WIZARD"; then
        pass "Optional notification workflow template exists in wizard"
    else
        fail "Wizard should contain optional notification workflow template"
    fi
}

# Test 6: Notification workflow template is valid YAML
test_notification_workflow_yaml() {
    # Extract the workflow YAML block from the wizard and validate it
    local temp_yaml
    temp_yaml=$(mktemp "${TMPDIR:-/tmp}/wizard-workflow-XXXXXX.yml")

    # Extract YAML between the notification workflow code fence
    local in_block=false
    local found=false
    while IFS= read -r line; do
        if echo "$line" | grep -q "name: SDLC Wizard Update Check"; then
            in_block=true
            found=true
            echo "$line" > "$temp_yaml"
            continue
        fi
        if [ "$in_block" = true ]; then
            if echo "$line" | grep -q '^\`\`\`$'; then
                in_block=false
                break
            fi
            echo "$line" >> "$temp_yaml"
        fi
    done < "$WIZARD"

    if [ "$found" = false ]; then
        fail "Could not find notification workflow YAML block"
        rm -f "$temp_yaml"
        return
    fi

    if python3 -c "import yaml; yaml.safe_load(open('$temp_yaml'))" 2>/dev/null; then
        pass "Notification workflow template is valid YAML"
    else
        fail "Notification workflow template is not valid YAML"
    fi

    rm -f "$temp_yaml"
}

# Test 7: Notification workflow uses sparse-checkout
test_sparse_checkout() {
    # The workflow should use sparse-checkout to avoid cloning entire repo
    if grep -A 50 "SDLC Wizard Update Check" "$WIZARD" | grep -q "sparse-checkout"; then
        pass "Notification workflow uses sparse-checkout"
    else
        fail "Notification workflow should use sparse-checkout"
    fi
}

# Test 8: Notification workflow only needs issues:write permission
test_workflow_permissions() {
    if grep -A 10 "SDLC Wizard Update Check" "$WIZARD" | grep -q "issues: write"; then
        pass "Notification workflow uses issues: write permission"
    else
        fail "Notification workflow should use issues: write permission"
    fi
}

# Test 9: Notification workflow creates issues (not PRs)
test_creates_issues() {
    if grep -A 100 "SDLC Wizard Update Check" "$WIZARD" | grep -q "gh issue create"; then
        pass "Notification workflow creates issues (not PRs)"
    else
        fail "Notification workflow should create issues, not PRs"
    fi
}

# Test 10: Notification workflow deduplicates (checks for existing issue)
test_dedup_check() {
    if grep -A 100 "SDLC Wizard Update Check" "$WIZARD" | grep -q "wizard-update.*open\|--state open.*wizard-update"; then
        pass "Notification workflow checks for existing open issues"
    else
        fail "Notification workflow should check for existing open wizard-update issues"
    fi
}

# Test 11: Version metadata format documented
test_version_metadata_format() {
    if grep -q '<!-- SDLC Wizard Version:' "$WIZARD"; then
        pass "Version metadata format documented in wizard"
    else
        fail "Wizard should document version metadata comment format"
    fi
}

# Test 12: Update flow has multi-phase structure
test_multi_phase_flow() {
    # Should have at least 3 phases: version check, changelog, apply
    local phase_count
    phase_count=$(grep -ci "phase [0-9]\|step [0-9].*:.*\(version\|changelog\|fetch\|apply\|compare\)" "$WIZARD" || echo "0")
    if [ "$phase_count" -ge 3 ]; then
        pass "Update flow has multi-phase structure ($phase_count phases found)"
    else
        fail "Update flow should have at least 3 phases, found $phase_count"
    fi
}

# Run all tests
test_changelog_url
test_wizard_url
test_step_registry
test_changelog_first
test_notification_workflow_exists
test_notification_workflow_yaml
test_sparse_checkout
test_workflow_permissions
test_creates_issues
test_dedup_check
test_version_metadata_format
test_multi_phase_flow

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All self-update mechanism tests passed!"
