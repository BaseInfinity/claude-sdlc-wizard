# Preflight Self-Review: BASELINE block fires once per CC session

## What changed

`hooks/sdlc-prompt-check.sh`:
- Extract `session_id` from stdin JSON alongside existing `prompt` extraction.
- Gate the static SDLC BASELINE `cat << 'EOF'` block on a per-session sentinel `$SDLC_WIZARD_CACHE_DIR/baseline-shown-<safe_sid>`.
- After first emit, `mkdir -p` cache dir + `touch` sentinel; prune sentinels older than 7d via `find -mtime +7 -delete`.
- Sanitize session_id with `tr -cd 'A-Za-z0-9._-'` (defense-in-depth — CC session_ids are UUIDs, but never trust stdin).
- Fallback when no session_id (legacy CC stdin or direct shell test): emit BASELINE every fire (current behavior).

## What did NOT change

- `_find-sdlc-root.sh` walk-up logic
- Effort-bump signal detector + nudge (lines 38-99)
- SETUP-NOT-COMPLETE warning (lines 103-112)
- ROADMAP #224 SDLC_HOOK_FIRE_LOG instrumentation
- Plugin-vs-project dedupe heuristic
- Any other hook in `hooks/`

## Self-review checklist

- [x] `tests/test-baseline-fires-once.sh` — 8/8 PASS (8 cases: first-fire, suppression, different-session re-emit, no-session-id back-compat, SETUP persistence, EFFORT-bump persistence, cache-isolation, byte-shrink)
- [x] `tests/test-hooks.sh` — 154/154 PASS (no regression in existing hook test suite)
- [x] `tests/test-prompt-hook-fires-once.sh` — 6/6 PASS (ROADMAP #224 instrumentation regression, includes byte-identical assertion)
- [x] `tests/test-audit-session-load.sh` — 9/9 PASS (`skills/update/SKILL.md` still under 5K-token threshold)
- [x] `tests/test-cli.sh` — 78/78 PASS
- [x] `tests/test-plugin.sh` — 25/25 PASS
- [x] `tests/test-doc-consistency.sh` — 35/35 PASS
- [x] Cache writes are best-effort: unwritable cache → falls back to current behavior (BASELINE keeps emitting), never errors to user
- [x] session_id sanitized before use in filename
- [x] Comment block on the gating logic explains the *why* (12K token saving, skill duplication once auto-invoked) and the constraints (SETUP/EFFORT-bump must keep firing)
- [x] Version bumped 1.68.0 → 1.69.0 across 7 metadata sites
- [x] `CHANGELOG.md` v1.69.0 entry written with behavior matrix
- [x] `skills/update/SKILL.md` changelog list updated with 1.69.0 entry, older entries collapsed to keep under 5K threshold
- [x] `.github/workflows/ci.yml` wires new test into validate job

## Specific things to verify in review

1. **Race conditions:** if CC parallelism could fire two `UserPromptSubmit` hooks concurrently for the same session_id, both could check `[ -f $sentinel ]` as false, both emit, both touch. Worst case is BASELINE emits twice on a single rare race. Acceptable, but flag if there's a cleaner pattern.

2. **Stale-cache leakage across CC restarts:** sentinel persists on disk. If a user runs the same CC `session_id` again after a restart (does CC ever reuse session_ids? — CC sessions are UUIDs, almost certainly unique), they'd see no BASELINE on their first prompt. Mitigation: 7-day prune. Verify the worst case is acceptable.

3. **Filename injection / path traversal:** session_id from stdin sanitized via `tr -cd 'A-Za-z0-9._-'`. Confirm this is sufficient. CC session_ids are UUIDs (lowercase hex + dashes), so the strip is purely defense-in-depth.

4. **Byte-shrink test (test 8):** asserts second fire output is `<` (first / 5). Currently 823 → 0 chars. If anyone adds new conditional output that fires post-suppression, the test will catch it. Verify the assertion is the right shape.

5. **Back-compat:** `tests/test-hooks.sh` Test 5 (line ~91 `test_sdlc_hook_size`) calls `"$HOOKS_DIR/sdlc-prompt-check.sh"` with NO stdin. The hook reaches `[ ! -t 0 ]` check, finds tty (when run from terminal/test), skips stdin parse, `SESSION_ID` stays empty, BASELINE emits every fire. Test still passes. Confirm I haven't created a hidden coupling.

## Known limitations

- Sentinel doesn't survive `rm -rf $SDLC_WIZARD_CACHE_DIR`. User who clears cache mid-session sees BASELINE re-emit on next prompt — acceptable.
- 7-day prune is on-emit, not periodic. A long-idle session whose sentinel ages out then resumes would see one re-emit. Acceptable.
