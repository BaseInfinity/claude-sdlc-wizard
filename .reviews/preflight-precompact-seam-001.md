# Preflight Self-Review: PreCompact seam gate hook (ROADMAP #208)

## Self-review completed
- [x] Hook script written, `set`-guarded, executable
- [x] 9 quality tests added; full 105/105 hook suite passes
- [x] Negative control: 50-line echo bloat injection into a copy of the hook causes the size-cap test to fail at 4793 chars ≥ 1000 (original passes at 893 chars)
- [x] Both `hooks/hooks.json` (plugin) and `cli/templates/settings.json` (CLI) register the hook — event parity maintained
- [x] Hook count tests in `test-cli.sh` / `test-plugin.sh` updated 4 → 5 to match the new event
- [x] Wizard doc + SDLC.md updated with hook row, tree entry, and seam-taxonomy section
- [x] Version floor (CC v2.1.105+) documented in all three places
- [x] Matcher is `"manual"` — auto-compact deliberately NOT gated (rationale in code comment + wizard doc)

## Verified manually
- [x] Hook exits 0 with no stderr when `.reviews/handoff.json` absent and no git ops
- [x] Hook exits 0 when `.reviews/handoff.json` status is CERTIFIED
- [x] Hook exits 2 with HOLD message when status is PENDING_REVIEW (grep-parsed status field, not jq-dependent)
- [x] Hook exits 2 when `.git/rebase-merge/`, `.git/MERGE_HEAD`, or `.git/CHERRY_PICK_HEAD` exist
- [x] Stacked worst-case (all 4 blockers firing) stays under 1KB stderr (893 chars observed)
- [x] TTY guard on stdin (`[ ! -t 0 ] && INPUT=$(cat) || INPUT=""`) prevents hang when hook invoked outside CC

## Known limitations (can't verify / not in scope)
- TodoWrite in-progress state is NOT checked — CC does not persist TodoWrite state to a file readable from hooks. Documented this in ROADMAP #208 acceptance criteria.
- Real CC PreCompact trigger not end-to-end tested (requires running CC v2.1.105+ with `/compact`). Hook is validated by unit tests that shape-match the documented payload schema.
- `rebase-apply` directory check is not exercised by the rebase test (test uses `rebase-merge`). Both are checked in the hook — only one is in the test fixture.
- No explicit test that the `matcher: "manual"` registration works — that's CC's responsibility, not ours.

## Specific concerns flagged for reviewer
1. **Grep-parsed `status` field** in the hook (not jq) — done to avoid a jq dependency. Verify the grep is robust to whitespace variants (`"status": "..."` with spaces vs no spaces).
2. **Heredoc stderr block** — the multi-line HOLD message is emitted via `{ ... } >&2` block. Verify newlines render correctly when CC shows the message to Claude.
3. **`|| rc=$?` in tests** — added to work around `set -e` + hook exiting 2 inside `$()`. Verify this pattern is correct for capturing the hook's exit code.
4. **Size-cap negative control was run on a temp copy** (not the live hook). Sandbox blocked modifying the real hook. Verify the negative control actually fails — measure bloat-injected stderr length yourself.
