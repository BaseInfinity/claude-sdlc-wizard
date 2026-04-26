#!/bin/bash
# Quality test: cleanupPeriodDays ≥ 30 in template + wizard doc warns about retention.
#
# ROADMAP #225: CC 2.1.117 changed `cleanupPeriodDays` to also cover `~/.claude/tasks/`.
# The SDLC skill uses `TodoWrite` as step 1 of every task, persisted under that dir.
# An aggressive retention policy (e.g. 7 days, default in some CC versions) could
# prune in-progress SDLC checklists from paused long-running features. Wizard pins
# the setting to a safe explicit default in cli/templates/settings.json AND documents
# the gotcha in CLAUDE_CODE_SDLC_WIZARD.md.

set -e

TEMPLATE="${TEMPLATE:-cli/templates/settings.json}"
WIZARD="${WIZARD:-CLAUDE_CODE_SDLC_WIZARD.md}"
PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }

if [ ! -f "$TEMPLATE" ]; then
    echo "FAIL: $TEMPLATE not found"
    exit 1
fi
if [ ! -f "$WIZARD" ]; then
    echo "FAIL: $WIZARD not found"
    exit 1
fi

# ---------------------------------------------------------------------------
# Test 1: cli/templates/settings.json has cleanupPeriodDays as a top-level field.
# ---------------------------------------------------------------------------
if jq -e '.cleanupPeriodDays' "$TEMPLATE" >/dev/null 2>&1; then
    pass "cli/templates/settings.json defines cleanupPeriodDays"
else
    fail "cli/templates/settings.json must define cleanupPeriodDays as top-level field"
fi

# ---------------------------------------------------------------------------
# Test 2: cleanupPeriodDays >= 30 (safe floor for TodoWrite retention).
# ---------------------------------------------------------------------------
period=$(jq -r '.cleanupPeriodDays // empty' "$TEMPLATE" 2>/dev/null)
if [ -n "$period" ] && [ "$period" -ge 30 ] 2>/dev/null; then
    pass "cleanupPeriodDays ($period) >= 30 (safe floor for TodoWrite retention)"
else
    fail "cleanupPeriodDays must be >= 30 — got '$period'"
fi

# ---------------------------------------------------------------------------
# Tests 3-5 must scope to the new "Known CC gotcha" subsection inside Tasks
# System. Generic grep over the whole wizard doc false-greens because earlier
# Tasks System paragraphs already mention TodoWrite. Extract the cleanupPeriodDays
# subsection by header range.
# ---------------------------------------------------------------------------
gotcha_section=$(awk '
  /^#### Known CC gotcha:.*cleanupPeriodDays/ { flag=1; next }
  /^### / && flag { flag=0 }
  /^#### / && flag { flag=0 }
  flag { print }
' "$WIZARD")

# Test 3: subsection exists AND mentions cleanupPeriodDays.
if [ -n "$gotcha_section" ] && echo "$gotcha_section" | grep -qE "cleanupPeriodDays"; then
    pass "Wizard 'Known CC gotcha' subsection references cleanupPeriodDays"
else
    fail "Wizard must have a 'Known CC gotcha' subsection that references cleanupPeriodDays"
fi

# Test 4: subsection mentions the >= 30 recommendation.
if echo "$gotcha_section" | grep -qE "cleanupPeriodDays.*30|30.*cleanupPeriodDays|>=.*30|at least 30|30 or higher"; then
    pass "Wizard subsection recommends cleanupPeriodDays >= 30"
else
    fail "Wizard subsection must recommend a >= 30 retention floor explicitly"
fi

# Test 5: subsection explains WHY (TodoWrite/tasks would be pruned).
if echo "$gotcha_section" | grep -qiE "TodoWrite|tasks.*pruned|tasks.*lost|in-progress.*pruned|persistent.*tasks|tasks/.*directory|~/.claude/tasks"; then
    pass "Wizard subsection explains retention rationale (TodoWrite/tasks lost if too low)"
else
    fail "Wizard subsection must explain WHY 30+ days matters (TodoWrite persistence under ~/.claude/tasks/)"
fi

# ---------------------------------------------------------------------------
# Test 6: Template settings.json still parses as valid JSON.
# ---------------------------------------------------------------------------
if jq empty "$TEMPLATE" 2>/dev/null; then
    pass "cli/templates/settings.json is valid JSON"
else
    fail "cli/templates/settings.json must be valid JSON"
fi

# ---------------------------------------------------------------------------
# Test 7: All 5 template hook events preserved (regression guard).
# ---------------------------------------------------------------------------
if jq -e '
  .hooks.UserPromptSubmit and
  .hooks.PreToolUse and
  .hooks.InstructionsLoaded and
  .hooks.SessionStart and
  .hooks.PreCompact
' "$TEMPLATE" >/dev/null 2>&1; then
    pass "Template hooks block preserved (all 5 events: UserPromptSubmit, PreToolUse, InstructionsLoaded, SessionStart, PreCompact)"
else
    fail "Template hooks block regressed — must keep all 5 hook events (UserPromptSubmit, PreToolUse, InstructionsLoaded, SessionStart, PreCompact)"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
