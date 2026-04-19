## Preflight Self-Review: Staleness Nudge (ROADMAP #196)

**Scope:** Strengthen `instructions-loaded-check.sh` so consumers don't go months between `/update-wizard` runs. Adds (1) 24h cache for npm latest-version lookup, (2) loud multi-line nudge when ≥3 minor versions behind, (3) keeps mild one-liner for 1-2 minor gaps.

- [x] `hooks/instructions-loaded-check.sh`: version block rewritten. Cache via `$SDLC_WIZARD_CACHE_DIR/latest-version` (default `~/.cache/sdlc-wizard/`). 24h TTL via stat mtime (macOS `-f %m` / Linux `-c %Y`). Minor delta = latest.minor - installed.minor (major bump → treat as delta=99 so it hits the loud path). Loud nudge: `!! WARNING`, 5 lines, explicit count, "Strongly recommend". Mild nudge: unchanged one-liner
- [x] `tests/test-hooks.sh`: 3 new tests
  - `test_update_notification_loud_when_3_minor_behind` — 1.25.0 vs 1.34.0, asserts "9 minor ... behind" + warning marker + /update-wizard link
  - `test_update_notification_mild_when_2_minor_behind` — 1.32.0 vs 1.34.0, asserts "update available" but NOT loud markers
  - `test_update_notification_uses_daily_cache` — populates cache, swaps npm to one that fails, asserts cached value is still used
- [x] All existing update-notification tests updated to pass `SDLC_WIZARD_CACHE_DIR=$tmpdir/cache` so tests don't pollute each other via the shared `~/.cache` path
- [x] `ROADMAP.md` #196 marked DONE with implementation summary
- [x] Ran `bash tests/test-hooks.sh` → 81/81 pass
- [x] Ran full suite (31 scripts) → all `Failed: 0`
- [x] Negative control: collapsed the loud branch to `if false; then` — loud test fails, cache test fails (proves cache-enables-loud-on-second-run semantics). Restored → 81/81

### Specific concerns checked
- **Hook must never block session start:** hook still exits 0 on every path. Cache directory create is `|| true`, cache write is `|| true`, npm call is `|| LATEST_VERSION=""`, stat variations fall through. No `set -e`.
- **Cache miss path still works when `$SDLC_WIZARD_CACHE_DIR` is unwritable:** if mkdir fails, LATEST_VERSION stays from npm call; cache write silently fails; next run re-fetches. Degrades to pre-#196 behavior.
- **`SDLC_WIZARD_CACHE_DIR` is only a test affordance, not a user-facing flag:** kept it simple and env-var-only, no CLI interface. Documented in ROADMAP entry.
- **Doesn't clobber existing tests:** existing 6 update-notification tests all now pass `SDLC_WIZARD_CACHE_DIR=$tmpdir/cache` so they don't use the real user cache and don't cross-contaminate each other.
- **Major-version bump handled:** if major bump, treats as delta=99 → loud nudge. Doesn't underwarn on `1.99.0 → 2.0.0`.

### Known limitations
- Did not wire this hook into a real consumer repo to verify runtime behavior (the skill runtime is what actually fires it — my test harness runs it directly under `bash`).
- The loud-nudge test grep is reasonably loose to accommodate wording changes (`9.*minor.*behind|behind.*9.*minor|9[[:space:]]*versions.*behind`). This could allow slight language drift without test churn, at the cost of not pinning exact copy.
