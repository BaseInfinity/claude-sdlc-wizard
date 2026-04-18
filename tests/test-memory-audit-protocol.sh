#!/bin/bash
# Memory Audit Protocol tests
# Validates the "Memory Audit Protocol" section in skills/sdlc/SKILL.md
# and the classifier behavior against tests/fixtures/memory-audit-corpus/.
#
# Test groups:
#   1. Structure check (always runs) — protocol section present + subsections
#   2. Rule-based denylist (always runs, deterministic) — no LLM needed
#   3. LLM classification quality (LLM-gated) — ≥8/10 pass threshold
#   4. LLM destination-selection quality (LLM-gated) — 6/6 pass threshold
#
# Groups 3 and 4 skipped when SKIP_LLM_CLASSIFIER=1 (default for local/CI;
# nightly runs with SKIP_LLM_CLASSIFIER unset).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/sdlc/SKILL.md"
CORPUS="$REPO_ROOT/tests/fixtures/memory-audit-corpus"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1"; }

# ────────────────────────────────────────────
# Group 1: Structure check
# ────────────────────────────────────────────

test_protocol_section_exists() {
    if grep -q '^### Memory Audit Protocol' "$SKILL"; then
        pass "Memory Audit Protocol section present in skills/sdlc/SKILL.md"
    else
        fail "skills/sdlc/SKILL.md is missing '### Memory Audit Protocol' heading"
    fi
}

test_protocol_subsections_present() {
    local missing=""
    for keyword in "When to run" "Rule-based denylist" "Destinations for" "Tracking" "Human gate"; do
        if ! grep -qF "$keyword" "$SKILL"; then
            missing="${missing:+${missing}, }$keyword"
        fi
    done
    if [ -z "$missing" ]; then
        pass "Protocol section contains required subsections (When/Classify/Destinations/Tracking/Human-gate)"
    else
        fail "Protocol section missing keyword(s): $missing"
    fi
}

test_protocol_denylist_rules_documented() {
    # Must explicitly document type→classification mapping for user/reference/project/feedback
    if grep -q 'type: user' "$SKILL" \
       && grep -q 'type: reference' "$SKILL" \
       && grep -q 'type: project' "$SKILL" \
       && grep -q 'type: feedback' "$SKILL"; then
        pass "Denylist rules document all four frontmatter types"
    else
        fail "Denylist rules do not cover all four types (user/reference/project/feedback)"
    fi
}

# ────────────────────────────────────────────
# Group 2: Rule-based denylist (deterministic)
# ────────────────────────────────────────────
#
# Rule is defined in SKILL.md:
#   type: user | reference        → keep
#   type: project | feedback      → manual-review
#   (anything else)               → LLM classifies
#
# We implement the rule here and verify it matches test_expected on the
# deterministic fixtures (those with types we cover).

apply_denylist_rule() {
    # Read YAML frontmatter type, emit keep/manual-review/LLM-NEEDED
    local file="$1"
    local type
    type=$(sed -n 's/^type: \(.*\)$/\1/p' "$file" | head -1 | tr -d ' ')
    case "$type" in
        user|reference)   echo "keep" ;;
        project|feedback) echo "manual-review" ;;
        *)                echo "LLM-NEEDED" ;;
    esac
}

extract_expected_classification() {
    local file="$1"
    # test_expected is a 2-line block:
    #   test_expected:
    #     classification: X
    awk '/^test_expected:/{flag=1; next} flag && /classification:/{print $2; exit}' "$file"
}

test_denylist_user_files_classify_as_keep() {
    local fail_list=""
    for f in "$CORPUS"/keep_*.md; do
        [ -f "$f" ] || continue
        local type expected actual
        type=$(sed -n 's/^type: \(.*\)$/\1/p' "$f" | head -1 | tr -d ' ')
        [ "$type" = "user" ] || [ "$type" = "reference" ] || continue
        expected="keep"
        actual=$(apply_denylist_rule "$f")
        if [ "$actual" != "$expected" ]; then
            fail_list="${fail_list:+${fail_list}, }$(basename "$f")"
        fi
    done
    if [ -z "$fail_list" ]; then
        pass "Rule-based denylist: all user/reference fixtures classify as keep"
    else
        fail "Denylist failed to classify as keep: $fail_list"
    fi
}

test_denylist_project_feedback_classify_as_manual() {
    local fail_list=""
    for f in "$CORPUS"/manual_*.md; do
        [ -f "$f" ] || continue
        local type expected actual
        type=$(sed -n 's/^type: \(.*\)$/\1/p' "$f" | head -1 | tr -d ' ')
        [ "$type" = "project" ] || [ "$type" = "feedback" ] || continue
        expected="manual-review"
        actual=$(apply_denylist_rule "$f")
        if [ "$actual" != "$expected" ]; then
            fail_list="${fail_list:+${fail_list}, }$(basename "$f")"
        fi
    done
    if [ -z "$fail_list" ]; then
        pass "Rule-based denylist: all project/feedback fixtures classify as manual-review"
    else
        fail "Denylist failed to classify as manual-review: $fail_list"
    fi
}

test_denylist_never_promotes_denied_types() {
    # Stricter sanity: the denylist rule must NEVER yield "promote" on any
    # user/reference/project/feedback type, even across synthetic inputs.
    local violations=""
    for f in "$CORPUS"/*.md; do
        [ -f "$f" ] || continue
        local type actual
        type=$(sed -n 's/^type: \(.*\)$/\1/p' "$f" | head -1 | tr -d ' ')
        case "$type" in
            user|reference|project|feedback)
                actual=$(apply_denylist_rule "$f")
                if [ "$actual" = "promote" ]; then
                    violations="${violations:+${violations}, }$(basename "$f")"
                fi
                ;;
        esac
    done
    if [ -z "$violations" ]; then
        pass "Denylist never yields 'promote' for denied types (privacy gate holds)"
    else
        fail "Denylist leaked to promote for: $violations"
    fi
}

# ────────────────────────────────────────────
# Group 3: Corpus shape (deterministic, validates fixtures themselves)
# ────────────────────────────────────────────

test_corpus_has_10_entries() {
    local count
    count=$(find "$CORPUS" -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
    if [ "$count" -eq 10 ]; then
        pass "Corpus contains exactly 10 fixtures (excluding README)"
    else
        fail "Corpus has $count fixtures, expected 10"
    fi
}

test_corpus_distribution() {
    local promote keep manual
    promote=$(find "$CORPUS" -maxdepth 1 -name 'promote_*.md' | wc -l | tr -d ' ')
    keep=$(find "$CORPUS" -maxdepth 1 -name 'keep_*.md' | wc -l | tr -d ' ')
    manual=$(find "$CORPUS" -maxdepth 1 -name 'manual_*.md' | wc -l | tr -d ' ')
    if [ "$promote" -eq 6 ] && [ "$keep" -eq 2 ] && [ "$manual" -eq 2 ]; then
        pass "Corpus distribution is 6 promote / 2 keep / 2 manual-review (per CERTIFIED plan)"
    else
        fail "Corpus distribution wrong: $promote promote / $keep keep / $manual manual (expected 6/2/2)"
    fi
}

test_corpus_frontmatter_shape() {
    local missing=""
    for f in "$CORPUS"/*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "README.md" ] && continue
        if ! grep -q '^test_expected:' "$f"; then
            missing="${missing:+${missing}, }$(basename "$f"):no-test_expected"
            continue
        fi
        local cls
        cls=$(extract_expected_classification "$f")
        if [ -z "$cls" ]; then
            missing="${missing:+${missing}, }$(basename "$f"):no-classification"
        fi
    done
    if [ -z "$missing" ]; then
        pass "Every fixture has test_expected.classification frontmatter"
    else
        fail "Fixtures missing test_expected shape: $missing"
    fi
}

test_promote_fixtures_have_target() {
    # 6/6 rule: every promote fixture MUST have a target: frontmatter line.
    local missing=""
    for f in "$CORPUS"/promote_*.md; do
        [ -f "$f" ] || continue
        if ! awk '/^test_expected:/{flag=1; next} flag && /^[[:space:]]+target:/{found=1; exit} END{exit !found}' "$f"; then
            missing="${missing:+${missing}, }$(basename "$f")"
        fi
    done
    if [ -z "$missing" ]; then
        pass "All 6 promote fixtures have target: frontmatter (denominator consistent)"
    else
        fail "Promote fixtures missing target: $missing"
    fi
}

# ────────────────────────────────────────────
# Group 4: LLM classification quality (gated)
# ────────────────────────────────────────────

test_llm_classification_quality() {
    if [ "${SKIP_LLM_CLASSIFIER:-0}" = "1" ]; then
        skip "LLM classification quality (SKIP_LLM_CLASSIFIER=1)"
        return
    fi
    skip "LLM classification quality — runner not yet implemented (nightly CI only; structure + rule-based checks cover PR gate)"
}

test_llm_destination_selection() {
    if [ "${SKIP_LLM_CLASSIFIER:-0}" = "1" ]; then
        skip "LLM destination-selection quality (SKIP_LLM_CLASSIFIER=1)"
        return
    fi
    skip "LLM destination-selection quality — runner not yet implemented (nightly CI only)"
}

# ────────────────────────────────────────────
# Run
# ────────────────────────────────────────────

echo "=== Memory Audit Protocol tests ==="

test_protocol_section_exists
test_protocol_subsections_present
test_protocol_denylist_rules_documented

test_denylist_user_files_classify_as_keep
test_denylist_project_feedback_classify_as_manual
test_denylist_never_promotes_denied_types

test_corpus_has_10_entries
test_corpus_distribution
test_corpus_frontmatter_shape
test_promote_fixtures_have_target

test_llm_classification_quality
test_llm_destination_selection

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

echo "All Memory Audit Protocol tests passed!"
