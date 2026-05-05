# Preflight Self-Review: SDLC SKILL.md Cross-Model Review trim

## What changed

`skills/sdlc/SKILL.md` Cross-Model Review section: ~70 lines → ~13 lines (4995 → 4422 tokens).

## What stayed (verified)

- "When to run / When to skip / Prerequisites" decision logic
- Reviewer-at-flagship-tier rule (#233)
- Universality clause: "PROTOCOL is universal across domains"
- 4-step structure (preflight → handoff → reviewer → dialogue)
- Required handoff JSON key list with the "without them: 'looks good'" rationale
- `pr_number` PreCompact self-heal opt-in (#209)
- Codex command incantation (single line) with `xhigh` + `dangerouslyDisableSandbox` notes
- 2-3 round convergence rule
- Release-review checklist additions
- Pointer to wizard doc for full protocol

## What moved to wizard doc only

All present in `CLAUDE_CODE_SDLC_WIZARD.md` → "Cross-Model Review Loop" (194 lines):
- Full handoff.json JSON example (was duplicated)
- Full codex exec prompt example (was duplicated)
- Anti-patterns ("find at least N problems", "review this", anchoring)
- Multi-reviewer workflow (Claude review + Codex + human)
- Non-code domain variants (research, persuasion, medical)
- Per-finding action types FIXED|DISPUTED|ACCEPTED detail (kept compressed in 1 line)

## Self-review checklist

- [x] `tests/test-docs-usability.sh` — 29/29 PASS (mocking table + TDD prove + after-session + opus[1m] + autocompact compound + Deployment Tasks all still found)
- [x] `tests/test-doc-consistency.sh` — 35/35 PASS
- [x] `tests/test-prove-it.sh` — 20/20 PASS
- [x] `tests/test-audit-session-load.sh` — 9/9 PASS (SKILL.md still under 5K, now at 4422 tokens with margin)
- [x] `tests/test-memory-audit-protocol.sh` — 12/12 PASS (`### Memory Audit Protocol` heading still present)
- [x] `tests/test-hooks.sh` — 154/154 PASS
- [x] `tests/test-cli.sh` / `test-plugin.sh` / `test-workflow-triggers.sh` — all PASS
- [x] Version bumped 1.70.0 → 1.71.0 across 7 metadata sites
- [x] `skills/update/SKILL.md` "Latest: 1.71.0" matches package.json
- [x] CHANGELOG.md v1.71.0 entry written

## Specific things to verify in review

1. **Wizard doc canonical-source check:** confirm all dropped content lives in `CLAUDE_CODE_SDLC_WIZARD.md` → "Cross-Model Review Loop" (line 3739+). I verified the section is 194 lines and contains the full handoff JSON example, codex commands, etc. Reviewer should spot-check.

2. **No semantic drift in the trim:** key concepts that survived the cut should preserve original meaning. E.g. the original said `mission/success/failure` "give context (without them: generic 'looks good')" — verify the trimmed version preserves the *why*, not just the *what*.

3. **Test coverage verification:** grep `tests/*.sh` for any reference to dropped content (anti-patterns text, multi-reviewer details, non-code-domain). I checked the obvious test files; reviewer should cast a wider net.

## Known limitations

- Users who only read `skills/sdlc/SKILL.md` and never `CLAUDE_CODE_SDLC_WIZARD.md` get a leaner protocol summary. The pointer is at the end of the section, not buried — acceptable.
- The dropped JSON example was identical to the wizard doc's. No content lost.
