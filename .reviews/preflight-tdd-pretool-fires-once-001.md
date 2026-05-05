# Preflight Self-Review: tdd-pretool-check.sh fires once per CC session

## What changed

`hooks/tdd-pretool-check.sh`:
- Extract `session_id` from stdin JSON via `grep -o | head -1 | sed` (jq-independent, same pattern as v1.69.0 sdlc-prompt-check.sh).
- Gate the TDD CHECK JSON output on a per-session sentinel `$SDLC_WIZARD_CACHE_DIR/tdd-shown-<safe_sid>`.
- Atomic claim via subshell `set -C` (noclobber) `: > sentinel` — same proven pattern from v1.69.0.
- Fallback when claim fails AND file missing (cache unwritable) → emit (best-effort, never lose nudge).
- Prune sentinels older than 7d on emit.
- Sanitize session_id with `tr -cd 'A-Za-z0-9._-'` before filename use.

## What did NOT change

- File-path matching (`*"/src/"*`) — non-src files still produce zero output.
- The TDD CHECK message text (still emits same JSON when fired).
- jq dependency for file_path extraction (file paths can have escapes; UUIDs cannot).

## Self-review checklist

- [x] `tests/test-tdd-pretool-fires-once.sh` — 9/9 PASS (first-fire, suppression, different-session, no-session_id back-compat, non-src/ no-emit, non-src/-doesn't-consume-sentinel, cache-isolation, 50-parallel concurrency, suppressed-fire-empty)
- [x] `tests/test-hooks.sh` — 154/154 PASS (no regression in existing hook tests; old tests don't pass session_id, so back-compat path keeps them green)
- [x] `tests/test-baseline-fires-once.sh` — 10/10 PASS (v1.69.0 sibling)
- [x] `tests/test-audit-session-load.sh` — 9/9 PASS (SKILL.md still under 5K threshold)
- [x] `tests/test-cli.sh`, `test-plugin.sh`, `test-doc-consistency.sh` — all green
- [x] `tests/test-workflow-triggers.sh` — green after wiring new test into ci.yml + CONTRIBUTING.md
- [x] Version bumped 1.69.0 → 1.70.0 across 7 metadata sites
- [x] CHANGELOG.md v1.70.0 entry written
- [x] CI wiring: `.github/workflows/ci.yml` runs new test
- [x] CONTRIBUTING.md lists new test in dev-loop checklist

## Specific things to verify in review

1. **Non-src/ edit doesn't consume sentinel** — Test 6 covers this. The sentinel write only happens INSIDE the `*"/src/"*` branch. Confirm no path where non-src/ edit could pre-claim the sentinel.

2. **Concurrency same as v1.69.0** — atomic noclobber claim at the top of the src/ branch. Verify the conditional tree (claim succeeds → emit / claim fails AND file exists → suppress / claim fails AND file missing → emit fallback) is identical in semantics to the v1.69.0 BASELINE gate.

3. **session_id grep extraction** — same regex as v1.69.0. Verify it doesn't false-match an escaped `"session_id"` inside `tool_input.content` (which CC sends as part of Write tool calls).

4. **Suppressed fire is empty stdout** — Test 9 asserts. CC's PreToolUse contract treats empty stdout as "allow tool to proceed unmodified". Suppression must NOT emit `{}` or empty JSON wrapper.

5. **Hook still requires jq for file_path** — non-jq users would see no output for any edit, which is the existing behavior. Acceptable.

## Known limitations

- TDD nudge fires once per session, even if the user does 30 unrelated src/ edits over 2 hours. Acceptable trade-off — once Claude has the SDLC skill loaded, the nudge is duplicate.
- Sentinel survives CC restarts (7d prune). User who somehow reuses a session_id post-restart sees no nudge first prompt. CC session_ids are UUIDs — collision is implausible.
