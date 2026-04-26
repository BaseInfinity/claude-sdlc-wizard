#!/bin/bash
# Quality test: ROADMAP #205 phase (a) — setup wizard detects existing AGENTS.md.
#
# CC issue #6235 (276 comments) is the cross-tool agent-instructions standard.
# Cursor, Continue.dev, Aider, and others converge on AGENTS.md as the
# agent-agnostic parallel to CLAUDE.md. v1.42.0 phase (a): the setup skill's
# auto-scan now lists AGENTS.md and surfaces a dual-maintain decision when found.
# Phases (b) symlink/duplicate writing and (d) drift-consistency test deferred.
#
# This test asserts the detection + decision documentation; it does NOT assert
# any merge/symlink behavior because that's not in phase (a) scope.

set -e

SETUP="${SETUP:-skills/setup/SKILL.md}"
WIZARD="${WIZARD:-CLAUDE_CODE_SDLC_WIZARD.md}"
PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }

if [ ! -f "$SETUP" ]; then
    echo "FAIL: $SETUP not found"
    exit 1
fi

# Test 1: setup skill auto-scan mentions AGENTS.md
auto_scan=$(awk '/^### Step 1: Auto-Scan/,/^### Step 2:/' "$SETUP")
if echo "$auto_scan" | grep -qE "AGENTS\.md"; then
    pass "Setup auto-scan lists AGENTS.md"
else
    fail "Setup Step 1 (Auto-Scan) must include AGENTS.md in scanned files"
fi

# Test 2: setup skill has a dedicated AGENTS.md decision step or subsection
agents_section=$(awk '
  /AGENTS\.md.*[Dd]etect|AGENTS\.md.*[Ii]nterop|AGENTS\.md interop|Step.*AGENTS/ { flag=1 }
  /^### Step / && flag && !/AGENTS/ { flag=0 }
  /^## / && flag { flag=0 }
  flag { print }
' "$SETUP")
if [ -n "$agents_section" ]; then
    pass "Setup skill has an AGENTS.md decision/interop section"
else
    fail "Setup skill must have a step that handles detected AGENTS.md (decision: dual-maintain / merge / link)"
fi

# Test 3: setup decision includes the dual-maintain option
if echo "$agents_section" | grep -qiE "dual.maintain|both.*files|maintain.*both|sync.*claude.*agents|sync.*agents.*claude"; then
    pass "Setup decision describes dual-maintain option"
else
    fail "Setup decision must surface the dual-maintain option (keep both AGENTS.md and CLAUDE.md in sync)"
fi

# Test 4: wizard doc references the AGENTS.md interop pattern
if grep -qE "AGENTS\.md" "$WIZARD"; then
    pass "Wizard doc references AGENTS.md"
else
    fail "Wizard doc must reference AGENTS.md interop standard"
fi

# Test 5: wizard's AGENTS.md subsection (specifically) cites CC #6235 or names
# the cross-tool adopters. Scoped via awk to avoid false-greens elsewhere in the
# doc (e.g., "across tool boundaries" / "cross-tool structured state").
agents_doc_section=$(awk '
  /^### AGENTS\.md interop/ { flag=1; next }
  /^### / && flag { flag=0 }
  /^## / && flag { flag=0 }
  flag { print }
' "$WIZARD")
if [ -n "$agents_doc_section" ] && echo "$agents_doc_section" | grep -qE "#6235|Cursor|Continue\.dev|Aider"; then
    pass "Wizard AGENTS.md subsection cites CC #6235 or names cross-tool adopters"
else
    fail "Wizard AGENTS.md subsection must cite CC #6235 or name Cursor/Continue.dev/Aider as cross-tool adopters"
fi

# Test 6: phase (a) scope is honest — must mention what's deferred
agents_doc=$(awk '
  /AGENTS\.md/ && /[Dd]etect|[Ii]nterop|[Pp]hase|standard/ { flag=1 }
  /^## / && flag { flag=0 }
  flag { print }
' "$WIZARD")
if echo "$agents_doc" | grep -qiE "phase.*a|phase\(a\)|deferred|future|symlink|drift.test"; then
    pass "Wizard documents phase (a) scope honestly (defers symlink/drift-test phases)"
else
    fail "Wizard must be honest about phase (a) scope — note that symlink writing + drift-test are deferred"
fi

# Test 7: CHANGELOG [1.42.0] entry mentions #205
if grep -qE "^## \[1\.42\.0\]" CHANGELOG.md; then
    cl_entry=$(awk '/^## \[1\.42\.0\]/,/^## \[1\.41\.1\]/' CHANGELOG.md | sed '$d')
    if echo "$cl_entry" | grep -qE "#205|AGENTS\.md"; then
        pass "CHANGELOG [1.42.0] mentions #205 or AGENTS.md"
    else
        fail "CHANGELOG [1.42.0] must reference #205 or AGENTS.md"
    fi
else
    fail "CHANGELOG [1.42.0] entry missing"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
