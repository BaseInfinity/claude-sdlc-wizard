#!/bin/bash
# Quality test: 2026-04-23 Anthropic post-mortem lessons folded into wizard docs.
#
# ROADMAP #221: three lessons to capture as third-party evidence:
# (a) explicit effort — CC has flipped reasoning_effort defaults; never rely on default
# (b) extended-thinking + caching + idle sessions can drop thinking blocks
# (c) brevity caps in prompts can compound non-linearly (~3% drop per a-blation)
#
# This test asserts:
#   1. Wizard cites the post-mortem (URL or date)
#   2. Wizard's Recommended Effort section explicitly says "don't rely on CC default"
#   3. Wizard documents the extended-thinking/caching/idle-session gotcha
#   4. Regression guard: no SKILL.md or hook stdout has compounding brevity caps
#      ("keep brief", "be concise", "≤N words", etc.) — additions get caught here

set -e

WIZARD="${WIZARD:-CLAUDE_CODE_SDLC_WIZARD.md}"
PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }

if [ ! -f "$WIZARD" ]; then
    echo "FAIL: $WIZARD not found"
    exit 1
fi

# ---------------------------------------------------------------------------
# Test 1: Wizard cites the 2026-04-23 post-mortem (URL or date marker).
# ---------------------------------------------------------------------------
if grep -qE "april-23-postmortem|2026-04-23.*post.?mortem|post.?mortem.*2026-04-23" "$WIZARD"; then
    pass "Wizard cites the 2026-04-23 Anthropic post-mortem"
else
    fail "Wizard must cite the 2026-04-23 post-mortem (URL or date) as third-party evidence"
fi

# ---------------------------------------------------------------------------
# Test 2: Recommended Effort section says "don't rely on CC default".
# Scoped to the Recommended Effort section, not whole doc.
# ---------------------------------------------------------------------------
effort_section=$(awk '
  /^## Recommended Effort/ { flag=1; next }
  /^## / && flag { flag=0 }
  flag { print }
' "$WIZARD")

if [ -n "$effort_section" ] && echo "$effort_section" | grep -qiE "don'?t rely on.*default|never rely on.*default|CC default.*flipped|reasoning_effort.*flipped|default has changed"; then
    pass "Recommended Effort section warns against CC default"
else
    fail "Recommended Effort section must explicitly say 'don't rely on CC default' citing post-mortem evidence"
fi

# ---------------------------------------------------------------------------
# Test 3: Wizard documents the extended-thinking + caching + idle gotcha.
# ---------------------------------------------------------------------------
if grep -qE "thinking block.*drop|dropped.*thinking block|idle.*session.*cache|cache.*idle.*pruning|extended.thinking.*cach" "$WIZARD"; then
    pass "Wizard documents the extended-thinking + caching + idle-session gotcha"
else
    fail "Wizard must document the post-mortem's extended-thinking + caching + idle-session failure mode"
fi

# ---------------------------------------------------------------------------
# Test 4: Regression — no SKILL.md or hook stdout has compounding brevity caps.
# This is a forward-looking guard: future PRs adding "be concise" / "≤N words"
# get caught here. The post-mortem describes a brevity-prompt change that
# correlated with a measurable score drop; we don't want our wizard to accumulate
# the same kind of compounding constraint.
# ---------------------------------------------------------------------------
# Markdown skills: every line is content for Claude — including `#`-prefixed headings
# (e.g., `## Be Concise` would be an instruction). Do NOT filter comment-style lines.
md_hits=$(grep -rEni '(≤[0-9]+ words?|<[0-9]+ words?|under [0-9]+ words?|max [0-9]+ words?|be concise|keep.{0,10}brief|terse only|one short.{0,10}sentence)' \
    skills/*/SKILL.md 2>/dev/null \
    || true)
# Shell hooks: bash `#` comments are not surfaced to Claude, so filter them out.
# Anything that survives the filter is real stdout content.
sh_hits=$(grep -rEni '(≤[0-9]+ words?|<[0-9]+ words?|under [0-9]+ words?|max [0-9]+ words?|be concise|keep.{0,10}brief|terse only|one short.{0,10}sentence)' \
    hooks/*.sh 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
    || true)
brevity_hits="${md_hits}${sh_hits:+$'\n'$sh_hits}"
if [ -z "$brevity_hits" ]; then
    pass "No compounding brevity caps in SKILL.md or hook stdout (regression guard)"
else
    fail "Brevity-cap regression detected — review these and consider relaxing per post-mortem #221:"
    echo "$brevity_hits" | sed 's/^/  /'
fi

# ---------------------------------------------------------------------------
# Test 5: Wizard explicitly references the brevity-audit conclusion (so future
# maintainers know the audit was done and what the policy is).
# ---------------------------------------------------------------------------
if grep -qE "brevity audit|prompt brevity|brevity cap" "$WIZARD"; then
    pass "Wizard documents the brevity-cap audit policy"
else
    fail "Wizard must document the post-mortem brevity-cap audit (so future PRs know the policy)"
fi

# ---------------------------------------------------------------------------
# Test 6: CHANGELOG [1.41.0] entry exists.
# ---------------------------------------------------------------------------
if grep -qE "^## \[1\.41\.0\]" CHANGELOG.md; then
    pass "CHANGELOG [1.41.0] entry exists"
else
    fail "CHANGELOG [1.41.0] entry missing"
fi

# ---------------------------------------------------------------------------
# Test 7: CHANGELOG [1.41.0] mentions post-mortem.
# ---------------------------------------------------------------------------
cl_entry=$(awk '/^## \[1\.41\.0\]/,/^## \[1\.40\.1\]/' CHANGELOG.md | sed '$d' 2>/dev/null || true)
if [ -n "$cl_entry" ] && echo "$cl_entry" | grep -qiE "post.?mortem|april.23|2026-04-23"; then
    pass "CHANGELOG [1.41.0] mentions post-mortem"
else
    fail "CHANGELOG [1.41.0] must mention the post-mortem source"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
