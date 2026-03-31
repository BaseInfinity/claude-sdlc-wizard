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
    # NOTE (prior bug): An earlier version of the wizard had the "# Note: ISSUE_EOF terminator
    # indentation is intentional" comment placed *inside* the ISSUE_EOF heredoc in the
    # gh issue create --body call. This caused the comment to appear verbatim in generated
    # GitHub Issue bodies. The comment has since been moved to just before the gh issue create
    # call (outside the heredoc). This test validates the YAML is structurally sound, which
    # would catch similar issues that break YAML parsing.
    local temp_yaml
    temp_yaml=$(mktemp "${TMPDIR:-/tmp}/wizard-workflow-XXXXXX.yml")

    # Extract YAML between the notification workflow code fence.
    # FRAGILITY NOTE: The closing-fence detection (grep '^\`\`\`$') will misfire if any
    # nested code fence appears between "name: SDLC Wizard Update Check" and the real
    # closing fence. This is low-risk given the current wizard structure but is line-count
    # sensitive — if the workflow section is restructured, re-verify this extraction logic.
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

    if WIZARD_YAML_PATH="$temp_yaml" python3 -c "import yaml, os; yaml.safe_load(open(os.environ['WIZARD_YAML_PATH']))" 2>/dev/null; then
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
    if grep -A 200 "SDLC Wizard Update Check" "$WIZARD" | grep -q "gh issue create"; then
        pass "Notification workflow creates issues (not PRs)"
    else
        fail "Notification workflow should create issues, not PRs"
    fi
}

# Test 10: Notification workflow deduplicates (checks for existing issue)
test_dedup_check() {
    if grep -A 200 "SDLC Wizard Update Check" "$WIZARD" | grep -q "wizard-update.*open\|--state open.*wizard-update"; then
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
    phase_count=$(grep -Eci "phase [0-9]|step [0-9].*:.*(version|changelog|fetch|apply|compare)" "$WIZARD" || echo "0")
    if [ "$phase_count" -ge 3 ]; then
        pass "Update flow has multi-phase structure ($phase_count phases found)"
    else
        fail "Update flow should have at least 3 phases, found $phase_count"
    fi
}

# Test 13: CHANGELOG URL returns valid content from live repo
test_changelog_url_live() {
    local url="https://raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/main/CHANGELOG.md"
    local content
    content=$(curl -sf --max-time 10 "$url" 2>/dev/null) || {
        pass "SKIPPED (offline): CHANGELOG URL live fetch"
        return
    }
    if echo "$content" | grep -q "# Changelog"; then
        pass "CHANGELOG URL returns valid content from live repo"
    else
        fail "CHANGELOG URL did not return expected content (missing '# Changelog' header)"
    fi
}

# Test 14: Wizard URL returns valid content from live repo
test_wizard_url_live() {
    local url="https://raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/main/CLAUDE_CODE_SDLC_WIZARD.md"
    local content
    content=$(curl -sf --max-time 10 "$url" 2>/dev/null) || {
        pass "SKIPPED (offline): Wizard URL live fetch"
        return
    }
    if echo "$content" | grep -q "SDLC Wizard"; then
        pass "Wizard URL returns valid content from live repo"
    else
        fail "Wizard URL did not return expected content (missing 'SDLC Wizard')"
    fi
}

# Test 15: Local CHANGELOG version matches local wizard version metadata
test_version_consistency() {
    local changelog="$SCRIPT_DIR/../CHANGELOG.md"

    if [ ! -f "$changelog" ]; then
        fail "CHANGELOG.md not found"
        return
    fi

    # Extract latest version from CHANGELOG (first ## [x.y.z] line)
    local changelog_version
    changelog_version=$(grep -m1 '## \[' "$changelog" | sed 's/.*\[\(.*\)\].*/\1/')

    # Extract version from wizard metadata comment
    local wizard_version
    wizard_version=$(grep -o 'SDLC Wizard Version: [0-9.]*' "$WIZARD" | head -1 | sed 's/SDLC Wizard Version: //')

    if [ -z "$changelog_version" ] || [ -z "$wizard_version" ]; then
        fail "Could not extract versions (CHANGELOG: '$changelog_version', wizard: '$wizard_version')"
        return
    fi

    if [ "$changelog_version" = "$wizard_version" ]; then
        pass "Version consistency: CHANGELOG ($changelog_version) matches wizard metadata ($wizard_version)"
    else
        fail "Version mismatch: CHANGELOG says $changelog_version but wizard metadata says $wizard_version"
    fi
}

# Test 16: Wizard contains Cross-Model Review section
test_cross_model_review_section() {
    if grep -q "### Cross-Model Review Loop (Optional)" "$WIZARD"; then
        pass "Wizard contains Cross-Model Review section"
    else
        fail "Wizard should contain '### Cross-Model Review Loop (Optional)' section"
    fi
}

# Test 17: Step registry contains cross-model-review step
test_cross_model_review_step() {
    if grep -q "step-cross-model-review" "$WIZARD"; then
        pass "Step registry contains step-cross-model-review"
    else
        fail "Step registry should contain step-cross-model-review entry"
    fi
}

# Test 18: SKILL.md has a real TodoWrite step for cross-model review (not just a comment)
test_skill_cross_model_review() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/sdlc/SKILL.md"
    # Exclude // comment lines in the TodoWrite block — we need an actual step
    if grep -i 'content:.*cross-model review' "$skill_file" | grep -qv '^\s*//'; then
        pass "SKILL.md has TodoWrite step for cross-model review"
    else
        fail "SKILL.md should have a TodoWrite step (not a comment) for cross-model review"
    fi
}

# Test 19: Wizard embedded SKILL has a real TodoWrite step for cross-model review
test_wizard_skill_cross_model_review() {
    # The wizard's embedded SKILL checklist should have the real step, not just a comment
    if grep -A 500 "## Full SDLC Checklist" "$WIZARD" | grep -i 'content:.*cross-model review' | grep -qv '^\s*//'; then
        pass "Wizard embedded SKILL has TodoWrite step for cross-model review"
    else
        fail "Wizard embedded SKILL should have a TodoWrite step (not a comment) for cross-model review"
    fi
}

# Test 20: SKILL.md has a dedicated cross-model review instructions section
test_skill_cross_model_review_instructions() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/sdlc/SKILL.md"
    if grep -q "## Cross-Model Review" "$skill_file"; then
        pass "SKILL.md has dedicated cross-model review section"
    else
        fail "SKILL.md should have a '## Cross-Model Review' section with instructions"
    fi
}

# Test 21: Wizard embedded SKILL has a dedicated cross-model review section
test_wizard_skill_cross_model_review_instructions() {
    if grep -A 500 "## Full SDLC Checklist" "$WIZARD" | grep -q "## Cross-Model Review"; then
        pass "Wizard embedded SKILL has cross-model review section"
    else
        fail "Wizard embedded SKILL should have a '## Cross-Model Review' section"
    fi
}

# --- /update-wizard Skill Tests (#33) ---

# Test 22: Update skill file exists in local skills directory
test_update_skill_exists() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/update/SKILL.md"
    if [ -f "$skill_file" ]; then
        pass "Update skill file exists at .claude/skills/update/SKILL.md"
    else
        fail "Update skill should exist at .claude/skills/update/SKILL.md"
    fi
}

# Test 23: Update skill template exists in CLI templates
test_update_skill_template_exists() {
    local template_file="$SCRIPT_DIR/../cli/templates/skills/update/SKILL.md"
    if [ -f "$template_file" ]; then
        pass "Update skill template exists at cli/templates/skills/update/SKILL.md"
    else
        fail "Update skill template should exist at cli/templates/skills/update/SKILL.md"
    fi
}

# Test 24: Local and template update skill files are identical
test_update_skill_parity() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/update/SKILL.md"
    local template_file="$SCRIPT_DIR/../cli/templates/skills/update/SKILL.md"
    if diff -q "$skill_file" "$template_file" > /dev/null 2>&1; then
        pass "Local and template update skill files are identical"
    else
        fail "Local and template update skill files have drifted"
    fi
}

# Test 25: Update skill contains key content markers
test_update_skill_content() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/update/SKILL.md"
    local ok=true
    grep -q "name: update-wizard" "$skill_file" || ok=false
    grep -q "WebFetch" "$skill_file" || ok=false
    grep -q "CHANGELOG" "$skill_file" || ok=false
    grep -qi "selective\|per-file\|selectively" "$skill_file" || ok=false
    grep -q "sdlc-wizard check" "$skill_file" || ok=false
    if [ "$ok" = true ]; then
        pass "Update skill contains key content markers"
    else
        fail "Update skill should reference WebFetch, CHANGELOG, selective updates, and sdlc-wizard check"
    fi
}

# Test 26: Step registry includes step-update-wizard
test_step_registry_update_wizard() {
    if grep -q "step-update-wizard" "$WIZARD"; then
        pass "Step registry contains step-update-wizard"
    else
        fail "Step registry should contain step-update-wizard entry"
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
test_changelog_url_live
test_wizard_url_live
test_version_consistency
test_cross_model_review_section
test_cross_model_review_step
test_skill_cross_model_review
test_wizard_skill_cross_model_review
test_skill_cross_model_review_instructions
test_wizard_skill_cross_model_review_instructions
test_update_skill_exists
test_update_skill_template_exists
test_update_skill_parity
test_update_skill_content
test_step_registry_update_wizard

# --- Cross-Model Review Dialogue Tests (#40) ---

# Helper: extract wizard cross-model blocks (embedded SKILL + deep-dive)
wizard_cross_model_blocks() {
    # Embedded SKILL section: ## Cross-Model Review ... ## Test Review
    sed -n '/^## Cross-Model Review (If Configured)/,/^## Test Review/p' "$WIZARD"
    # Deep-dive section: ### Cross-Model Review Loop ... next ### or EOF
    sed -n '/^### Cross-Model Review Loop/,/^### [^C]/p' "$WIZARD"
}

# Test 22: Wizard cross-model sections document response.json protocol
test_wizard_response_protocol() {
    local blocks
    blocks=$(wizard_cross_model_blocks)
    if echo "$blocks" | grep -q "response.json" && echo "$blocks" | grep -q "DISPUTED"; then
        pass "Wizard cross-model sections document response.json dialogue protocol"
    else
        fail "Wizard cross-model sections should document response.json with DISPUTED action"
    fi
}

# Test 23: Wizard cross-model sections document targeted recheck
test_wizard_targeted_recheck() {
    local blocks
    blocks=$(wizard_cross_model_blocks)
    if echo "$blocks" | grep -qi "targeted recheck"; then
        pass "Wizard cross-model sections document targeted recheck for round 2+"
    else
        fail "Wizard cross-model sections should document targeted recheck protocol"
    fi
}

# Test 24: SKILL.md documents the dialogue response protocol (both copies)
test_skill_dialogue_protocol() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/sdlc/SKILL.md"
    local template_file="$SCRIPT_DIR/../cli/templates/skills/sdlc/SKILL.md"
    local ok=true
    for f in "$skill_file" "$template_file"; do
        local section
        section=$(sed -n '/## Cross-Model Review/,/## Test Review/p' "$f")
        if ! echo "$section" | grep -q "FIXED" || ! echo "$section" | grep -q "DISPUTED" || ! echo "$section" | grep -q "ACCEPTED"; then
            ok=false
        fi
    done
    if $ok; then
        pass "Both SKILL.md cross-model sections document FIXED/DISPUTED/ACCEPTED"
    else
        fail "Both SKILL.md cross-model sections should document the dialogue response actions"
    fi
}

# Test 25: Wizard cross-model sections document convergence rule
test_wizard_convergence_rule() {
    local blocks
    blocks=$(wizard_cross_model_blocks)
    if echo "$blocks" | grep -qi "max.*round\|escalate.*user"; then
        pass "Wizard cross-model sections document convergence rule"
    else
        fail "Wizard cross-model sections should document max rounds / escalation"
    fi
}

# Test 26: Local SKILL.md and template SKILL.md cross-model sections match
test_skill_template_parity() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/sdlc/SKILL.md"
    local template_file="$SCRIPT_DIR/../cli/templates/skills/sdlc/SKILL.md"
    local skill_section template_section
    skill_section=$(sed -n '/## Cross-Model Review/,/## Test Review/p' "$skill_file")
    template_section=$(sed -n '/## Cross-Model Review/,/## Test Review/p' "$template_file")
    if [ "$skill_section" = "$template_section" ]; then
        pass "Local and template SKILL.md cross-model sections are identical"
    else
        fail "Local and template SKILL.md cross-model sections have drifted"
    fi
}

# Test 27: All recheck prompts in wizard are consistent (catches deep-dive drift)
test_wizard_recheck_prompt_parity() {
    # Count actual codex exec recheck prompts (quoted strings, not flow diagrams)
    local prompts
    prompts=$(grep -c '"You are doing a TARGETED RECHECK.*First read .reviews/handoff.json' "$WIZARD")
    local total
    total=$(grep -c '"You are doing a TARGETED RECHECK' "$WIZARD")
    if [ "$prompts" -eq "$total" ] && [ "$total" -ge 2 ]; then
        pass "All $total wizard recheck prompts include handoff.json-first instruction"
    else
        fail "Wizard has $total recheck prompts but only $prompts include handoff.json-first ($total expected)"
    fi
}

test_wizard_response_protocol
test_wizard_targeted_recheck
test_skill_dialogue_protocol
test_wizard_convergence_rule
test_skill_template_parity
test_wizard_recheck_prompt_parity

# --- CI Shepherd Model Tests (#36) ---

# Wizard documents two-tier CI fix model
test_wizard_two_tier_model() {
    if grep -q "Two-Tier CI Fix" "$WIZARD" || grep -q "Shepherd vs. Bot" "$WIZARD"; then
        pass "Wizard documents two-tier CI fix model"
    else
        fail "Wizard should document the two-tier (shepherd vs bot) CI fix model"
    fi
}

# Wizard contains shepherd vs bot comparison
test_wizard_shepherd_comparison() {
    if grep -q "Local Shepherd" "$WIZARD" && grep -q "CI Auto-Fix Bot" "$WIZARD"; then
        pass "Wizard contains shepherd vs bot comparison"
    else
        fail "Wizard should contain comparison between Local Shepherd and CI Auto-Fix Bot"
    fi
}

# CI_CD.md documents shepherd tier
test_cicd_shepherd_section() {
    local cicd="$SCRIPT_DIR/../CI_CD.md"
    if grep -q "Local Shepherd" "$cicd"; then
        pass "CI_CD.md documents the local shepherd tier"
    else
        fail "CI_CD.md should document the local shepherd tier"
    fi
}

# SKILL.md labels CI feedback loops as shepherd
test_skill_shepherd_label() {
    local skill_file="$SCRIPT_DIR/../.claude/skills/sdlc/SKILL.md"
    if grep -q "Local Shepherd" "$skill_file"; then
        pass "SKILL.md labels CI feedback loops as Local Shepherd"
    else
        fail "SKILL.md should label CI feedback loops as 'Local Shepherd'"
    fi
}

test_wizard_two_tier_model
test_wizard_shepherd_comparison
test_cicd_shepherd_section
test_skill_shepherd_label

# --- Gap Analysis vs Automation Recommender Tests (#35) ---

# Wizard Step 0.3 references /claude-automation-recommender
test_wizard_recommender_reference() {
    if grep -q "claude-automation-recommender" "$WIZARD"; then
        pass "Wizard Step 0.3 references /claude-automation-recommender"
    else
        fail "Wizard Step 0.3 should reference /claude-automation-recommender by name"
    fi
}

# Wizard documents suggestions-vs-enforcement positioning
test_wizard_gap_analysis() {
    if grep -qi "suggestion.*engine\|enforcement.*engine\|suggestions.*vs.*enforcement" "$WIZARD"; then
        pass "Wizard documents suggestions vs enforcement positioning"
    else
        fail "Wizard should document the suggestions-vs-enforcement gap analysis"
    fi
}

# Wizard Going Further has complementary tools section
test_wizard_complementary_tools() {
    if grep -q "Complementary Tools" "$WIZARD" || grep -q "Stack-Specific Configuration" "$WIZARD"; then
        pass "Wizard has complementary tools section in Going Further"
    else
        fail "Wizard should have a complementary tools section under Going Further"
    fi
}

# Setup wizard skill mentions automation recommender post-setup
test_setup_skill_recommender() {
    local setup_skill="$SCRIPT_DIR/../cli/templates/skills/setup/SKILL.md"
    if grep -q "claude-automation-recommender" "$setup_skill"; then
        pass "Setup wizard skill mentions /claude-automation-recommender"
    else
        fail "Setup wizard skill should mention /claude-automation-recommender for post-setup"
    fi
}

test_wizard_recommender_reference
test_wizard_gap_analysis
test_wizard_complementary_tools
test_setup_skill_recommender

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

echo ""
echo "All self-update mechanism tests passed!"
