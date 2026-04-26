#!/bin/bash
# Quality test: Step 7.7 dead-plugin cleanup must be reachable when wizard versions match.
#
# Bug fixed in v1.39.1: in v1.39.0, Step 3 of skills/update/SKILL.md said
# "If versions match: stop." That short-circuited Step 7.7 cleanup, so users
# already on the latest wizard with a stale ~/.claude/settings.json plugin
# registration could never reach the auto-cleanup. The hoist makes Step 3's
# match-branch run Step 7.7 before stopping.

set -e

SKILL="${SKILL:-skills/update/SKILL.md}"
PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }

if [ ! -f "$SKILL" ]; then
    echo "FAIL: $SKILL not found"
    exit 1
fi

step3_section=$(awk '/^### Step 3:/,/^### Step 4:/' "$SKILL")
step77_section=$(awk '/^### Step 7\.7:/,/^### Step 8:/' "$SKILL")
# CORE: extract ONLY the "If versions match:" paragraph (not the whole Step 3 section).
# Otherwise unrelated Step 7.7 mentions in Step 3's changelog example would false-green
# the assertion. Range: from the literal match-branch header to the next bold-prefixed
# instruction header ("**If user passed", which marks the next semantic block).
match_branch=$(awk '/^\*\*If versions match:\*\*/,/^\*\*If user passed/' "$SKILL")

# Test 1: Step 3 exists
if [ -n "$step3_section" ]; then
    pass "Step 3 section present"
else
    fail "Step 3 section missing"
fi

# Test 2: Step 7.7 exists
if [ -n "$step77_section" ]; then
    pass "Step 7.7 section present"
else
    fail "Step 7.7 section missing"
fi

# Test 3 (CORE): The "If versions match" paragraph itself must reference Step 7.7.
# Scoped strictly to that paragraph so changelog-example mentions of Step 7.7
# elsewhere in Step 3 cannot mask a regression in the match-branch instruction.
if [ -n "$match_branch" ] && echo "$match_branch" | grep -qE "Step 7\.7"; then
    pass "Step 3 versions-match paragraph references Step 7.7 (cleanup reachable on match)"
else
    fail "Step 3 versions-match paragraph does NOT reference Step 7.7 — cleanup unreachable when up-to-date"
fi

# Test 4: Step 3 must explicitly order Step 7.7 cleanup BEFORE the stop, in the match-branch.
if echo "$match_branch" | grep -qE "Step 7\.7.*(before|first|then).*stop|Run Step 7\.7"; then
    pass "Step 3 match-branch orders Step 7.7 before stop"
else
    fail "Step 3 match-branch must order Step 7.7 BEFORE the stop instruction"
fi

# Test 5: Step 7.7 must explicitly state it runs regardless of version match
# Either a "runs even when up-to-date" note, or a "regardless of version" line.
if echo "$step77_section" | grep -qiE "regardless of version|even when (up.?to.?date|versions match)|version.match.*(does not|not).*(skip|gate|short-circuit)"; then
    pass "Step 7.7 documents it runs regardless of version match"
else
    fail "Step 7.7 must explicitly document it runs even when versions match (so future edits don't silently re-gate it)"
fi

# Test 6: Allowlist must still be present (regression guard — hoist must not delete the cleanup itself)
if echo "$step77_section" | grep -q "sdlc-wizard-local" && echo "$step77_section" | grep -q "sdlc-wizard-wrap"; then
    pass "Step 7.7 allowlist intact (sdlc-wizard-local + sdlc-wizard-wrap)"
else
    fail "Step 7.7 allowlist regressed — must still list sdlc-wizard-local and sdlc-wizard-wrap"
fi

# Test 7: jq cleanup pipeline must still be present
if echo "$step77_section" | grep -q "del(\.enabledPlugins" && echo "$step77_section" | grep -q "del(\.extraKnownMarketplaces"; then
    pass "Step 7.7 jq cleanup pipeline intact"
else
    fail "Step 7.7 jq cleanup pipeline regressed"
fi

# Test 8: backup-with-timestamp instruction intact
if echo "$step77_section" | grep -qE "settings\.json\.bak\.\\\$\(date"; then
    pass "Step 7.7 timestamped backup instruction intact"
else
    fail "Step 7.7 timestamped backup instruction regressed"
fi

# Negative control: a corrupted skill with Step 7.7 deleted from Step 3 must FAIL test 3.
# Verified by mutation testing during PR review (sed -i -e 's/Step 7\.7/STEP_REMOVED/' in a copy).

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
