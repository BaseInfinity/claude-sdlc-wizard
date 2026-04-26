#!/bin/bash
# Quality test: ROADMAP #218 MCP-tool hook audit conclusion documented in wizard.
#
# CC 2.1.118 introduced `type: "mcp_tool"` for hooks. Question: should any of our
# 5 bash hooks migrate? Audit (2026-04-26) concluded NO — all 5 hooks stay bash:
# (1) bash hooks port to Codex/OpenCode siblings, MCP hooks don't, (2) none of
# our hooks needs cross-tool structured-state surfacing, (3) precompact-seam-check
# needs to BLOCK on exit 2, MCP is for invocation not gating.
#
# This test asserts the audit conclusion is documented in CLAUDE_CODE_SDLC_WIZARD.md
# so future maintainers don't redo the audit. If a future PR migrates a hook to MCP,
# this test should be UPDATED with new rationale, not deleted.

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

# Extract the MCP-tool hook audit section
audit_section=$(awk '
  /^### MCP-tool hooks audit/ { flag=1; next }
  /^### / && flag { flag=0 }
  /^## / && flag { flag=0 }
  flag { print }
' "$WIZARD")

# Test 1: audit section exists
if [ -n "$audit_section" ]; then
    pass "MCP-tool hooks audit section exists in wizard"
else
    fail "Wizard must have an 'MCP-tool hooks audit' subsection documenting the #218 conclusion"
fi

# Test 2: section cites CC 2.1.118 as the trigger
if echo "$audit_section" | grep -qE "2\.1\.118|mcp_tool"; then
    pass "Audit cites CC 2.1.118 / mcp_tool as the trigger feature"
else
    fail "Audit must cite the CC 2.1.118 mcp_tool feature as context"
fi

# Test 3: each hook has a SUBSTANTIVE bullet (not just name + "Stay bash" filler).
# Extract each hook's bullet by line: the line containing the hook name with backticks.
# Each bullet must have BOTH:
#   (i) the hook name in backticks (identifies the bullet)
#   (ii) ≥120 chars of rationale on that bullet line (not filler)
#   (iii) at least one criterion keyword (Portability|gating|local-state|fail-closed|criterion)
all_hooks=true
for h in sdlc-prompt-check instructions-loaded-check tdd-pretool-check model-effort-check precompact-seam-check; do
    bullet=$(echo "$audit_section" | grep "\`$h\.sh\`" || true)
    if [ -z "$bullet" ]; then
        all_hooks=false
        echo "  Missing hook bullet: $h.sh"
        continue
    fi
    bullet_len=${#bullet}
    if [ "$bullet_len" -lt 200 ]; then
        all_hooks=false
        echo "  Bullet too short for $h.sh (${bullet_len} chars, need ≥200) — likely filler"
        continue
    fi
    if ! echo "$bullet" | grep -qiE "Portability|gating|local-state|fail-closed|criterion"; then
        all_hooks=false
        echo "  Bullet for $h.sh lacks any decision-criterion keyword — appears to be filler"
    fi
done
if [ "$all_hooks" = true ]; then
    pass "Each of 5 hooks has substantive per-hook rationale (≥200 chars + criterion keyword)"
else
    fail "Audit must give each hook a SUBSTANTIVE bullet (not 'Stay bash' filler) — see lines above"
fi

# Test 4: conclusion is "stay bash" / "no migration"
if echo "$audit_section" | grep -qiE "stay.*bash|no migration|no MCP migration|remain.*bash|none.*benefit|default.*leave"; then
    pass "Audit conclusion: hooks stay bash"
else
    fail "Audit must explicitly conclude 'all hooks stay bash, no MCP migration'"
fi

# Test 5: portability rationale (bash → Codex/OpenCode siblings)
if echo "$audit_section" | grep -qiE "Codex|OpenCode|portab|sibling"; then
    pass "Audit cites portability to other agent runtimes"
else
    fail "Audit must cite portability — bash hooks port to Codex/OpenCode siblings; MCP hooks don't"
fi

# Test 6: precompact gating rationale must live INSIDE the precompact bullet.
# Just having "block" anywhere in the section isn't enough — the precompact bullet
# itself must explain the fail-closed gating concern.
precompact_bullet=$(echo "$audit_section" | grep '`precompact-seam-check\.sh`' || true)
if [ -n "$precompact_bullet" ] \
   && echo "$precompact_bullet" | grep -qiE "fail-closed|fail-open|exit 2|MCP.*server.*(error|crash|down|timeout|fail)"; then
    pass "Precompact bullet explains fail-closed gating concern with MCP servers"
else
    fail "Precompact bullet must explain exit-2 fail-closed contract vs MCP server fail-open behavior"
fi

# Test 7: CHANGELOG [1.41.1] entry exists and mentions #218
if grep -qE "^## \[1\.41\.1\]" CHANGELOG.md; then
    cl_entry=$(awk '/^## \[1\.41\.1\]/,/^## \[1\.41\.0\]/' CHANGELOG.md | sed '$d')
    if echo "$cl_entry" | grep -qE "#218|MCP|mcp_tool"; then
        pass "CHANGELOG [1.41.1] mentions #218 / MCP audit"
    else
        fail "CHANGELOG [1.41.1] must reference #218 or MCP audit"
    fi
else
    fail "CHANGELOG [1.41.1] entry missing"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
