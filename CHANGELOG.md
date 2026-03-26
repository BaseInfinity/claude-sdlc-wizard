# Changelog

All notable changes to the SDLC Wizard.

> **Note:** This changelog is for humans to read. Don't manually apply these changes - just run the wizard ("Check for SDLC wizard updates") and it handles everything automatically.

## [1.15.0] - 2026-03-25

### Added
- aistupidlevel.info as Source 3 in external benchmark cascade (DailyBench -> LiveBench -> aistupidlevel -> baseline)
- Competitive watchlist in `analyze-community.md` — weekly scan now checks 5 named repos for new releases/patterns
- `COMPETITIVE_AUDIT.md` — honest ecosystem comparison, unique strengths, tracked gaps, contribution ideas
- README "How This Compares" section with honest positioning table
- Token usage tracking gap documented (blocked until `claude-code-action` exposes usage data)
- 3 new tests in `test-external-benchmark.sh` for aistupidlevel integration
- 2 new tests in `test-prove-it.sh` for competitive watchlist and README positioning

### Changed
- Roadmap reordered: competitive audit (#10) marked DONE

## [1.14.0] - 2026-03-24

### Fixed
- CI re-trigger bug: `workflow_dispatch` caused `e2e-quick-check` to skip, blocking auto-merge (PR #75). Jobs now accept dispatch events with simulation steps gated behind PR-only checks
- SDLC.md version stuck at 1.9.0 (should be 1.14.0)
- CONTRIBUTING.md missing 11 test scripts, outdated scoring criteria, wrong repo URL in discussions link

### Added
- 3 tests in `test-workflow-triggers.sh`: verify required CI jobs accept `workflow_dispatch`
- 4 integration tests in `test-prove-it.sh`: prove `compare_ci` detects REGRESSION/STABLE/IMPROVED with synthetic scores
- 3 E2E tests in `test-self-update.sh`: verify live CHANGELOG and wizard URLs return valid content
- `should_simulate` gate in CI: dispatch runs produce green checks without burning API credits
- Documented `workflow_dispatch` behavior in `ci-self-heal.yml`

### Changed
- Roadmap reordered: competitive audit (#10) before distribution (#30)
- CONTRIBUTING.md scoring criteria updated to v3 multi-call judge + v3.1 pairwise tiebreaker
- CONTRIBUTING.md test list updated to all 21 CI validate scripts

## [1.13.0] - 2026-03-23

### Changed
- Rewrote "Staying Updated" section with explicit fetch URLs, CHANGELOG-first update flow, and 4-phase process
- Claude now shows users what changed (via CHANGELOG) before offering to apply updates
- Fixed "CHANGELOG is for Humans, Not Claude" — Claude reads CHANGELOG first to drive the update flow

### Added
- Optional "Wizard Update Notification" GitHub Action template — weekly check, creates issue when newer version exists ($0 cost, no API key)
- `step-update-notify` in wizard step registry (optional step for CI notification)
- 12 new tests in `tests/test-self-update.sh` (URL correctness, YAML validation, workflow template, step registry)

## [1.12.0] - 2026-03-23

### Fixed
- Apply step in `weekly-update.yml` and `monthly-research.yml` never propagated changes to test fixture (baseline == candidate, verdict always STABLE, comparison useless)
- Stale output file between baseline and candidate simulations in both auto-update workflows (same bug as ci.yml, fixed in #24)
- `sdp-score.sh` default model `claude-sonnet-4` corrected to `claude-opus-4-6` (matches evaluate.sh)
- README "All 6 workflows" corrected to "All 5 workflows" (stale since v1.9.0 consolidation)

### Added
- 6 new audit tests: apply step propagation (2), stale output cleanup (2), SDP model consistency (1), README accuracy (1)
- Native CC feature overlap analysis: all 5 custom features audited — KEEP CUSTOM (no overlap with CC v2.1.81)

### Audited (no changes needed)
- All 5 custom features (hooks + skills): value is in content (SDLC philosophy, TDD enforcement), not framework
- Noted for future: `continue-on-error` patterns, `/tmp` hardcodes, permission scoping

## [1.11.0] - 2026-03-23

### Fixed
- Stale output file between baseline and candidate simulations in Tier 2 (candidate eval could read baseline data on silent failure)
- Comment "3x evaluations" corrected to "5x evaluations" in ci.yml Tier 2 header
- `run-tier2-evaluation.sh` silent `score=0` fallback replaced with proper error handling (stderr separation, exit on failure)

### Added
- 13 test scripts wired into CI validate job (228 additional tests now run on every PR)
- Tests for Tier 2 comment accuracy and stale output cleanup
- Tests for `run-tier2-evaluation.sh` error handling (no stderr suppression, no silent fallback)

### Removed
- Legacy duplicate `tests/test-self-heal-simulation.sh` (690 lines, subset of e2e version)

## [1.10.0] - 2026-03-22

### Added
- "Prove It's Better" CI automation — when weekly-update detects a CC release that overlaps a custom wizard feature, CI auto-runs a side-by-side Tier 2 comparison and recommends KEEP CUSTOM / SWITCH TO NATIVE / TIE
- `tests/e2e/lib/prove-it.sh` — path validation allowlist + fixture stripping library
- `prove-it-test` job in `weekly-update.yml` — only runs when overlap detected ($0 extra on typical weeks)
- Custom feature inventory table in `analyze-release.md` — tells Claude what to check for overlap
- `has_overlap` / `overlap_paths` outputs wired from `check-updates` job
- 13 new tests in `tests/test-prove-it.sh` (allowlist validation, fixture stripping, settings.json updates, overlap signal parsing, workflow integration)
- Test fixture `tests/fixtures/releases/v99.0.0-overlap.json`

## [1.9.1] - 2026-03-22

### Verified
- `all-findings` self-heal (#27): PR #70 confirmed `workflow_run` triggers on review suggestions, `AUTOFIX_LEVEL=all-findings` passes filtering, Claude invoked in `review-findings` mode

### Added
- Real CI review format parsing test (h4 headers, `_None._` italic, line references)
- Roadmap ordering in AUTO_SELF_UPDATE.md

## [1.9.0] - 2026-03-21

### Changed
- Consolidated `daily-update.yml` + `weekly-community.yml` into single `weekly-update.yml`
  - 4 jobs: check-updates, version-test, scan-community, community-e2e-test
  - Single Monday 9 AM UTC schedule (was two separate cron entries)
  - Reduces workflow count from 6 to 5, auto-update workflows from 3 to 2
  - Cost: ~$2.50/week combined (unchanged)
- Updated all docs and 25+ tests to reference `weekly-update.yml`

### Added
- 5 new workflow consolidation tests: 4-job structure, dependency chains, permissions, single cron

## [1.8.1] - 2026-03-21

### Fixed
- `tdd_red` deterministic checker: now parses JSON execution output via jq (was always scoring 0/2 due to regex mismatch with claude-code-action JSON format)
- Score history push: checkout actual PR branch before push (was silently failing from detached HEAD)
- `instructions-loaded-check.sh`: explicit `exit 0` for defensive safety

### Changed
- Phase 5: Re-enabled all auto-update workflow schedules
  - `weekly-update.yml` (formerly `daily-update.yml` + `weekly-community.yml`): Mondays 9 AM UTC
  - `monthly-research.yml`: re-enabled (1st of month 11 AM UTC)
- Golden scores: `high-compliance.tdd_red` updated to 0 (text golden files lack JSON tool_use blocks; tdd_red correctness verified via dedicated JSON unit tests)

### Added
- 7 new tests: JSON-based tdd_red checks (5), empty/nonexistent file edge cases (2)
- 3 new workflow trigger tests: weekly schedule validation, all-schedules-active, score-history-checkout

## [1.8.0] - 2026-03-20

### Added
- Version catch-up: consolidated update from Claude Code v2.1.15 to v2.1.81 (66 minor versions)
- `InstructionsLoaded` hook (`instructions-loaded-check.sh`) — validates SDLC.md and TESTING.md exist at session start (v2.1.69+)
- `effort: high` frontmatter on `/sdlc` and `/testing` skills (v2.1.80+)
- "Prove It's Better" core philosophy — use native features unless custom is proven better via E2E comparison
- Vision statement in README — "Mold an ever-evolving SDLC... replace with native... one day delete this repo"
- Documentation section in README linking ARCHITECTURE.md, CI_CD.md, SDLC.md, TESTING.md, CHANGELOG.md, CONTRIBUTING.md
- Documented new built-in commands in wizard: `/memory`, `/simplify`, `/batch`, `/loop`, `/effort`
- Documented security hardening fixes (v2.1.49, v2.1.72, v2.1.74, v2.1.77, v2.1.78)
- Documented `${CLAUDE_SKILL_DIR}` variable, `agent_id`/`agent_type` hook metadata
- Documented `CLAUDE_CODE_SIMPLE` bypass risk, HTML comment behavior, 128k output tokens, `--bare` flag
- 7 new hook tests (18 total) for InstructionsLoaded hook
- `plans/CATCHUP.md` — documents the version catch-up process for future reference

### Changed
- Claude Code baseline bumped from v2.1.15+ to v2.1.81+
- Wizard version bumped from 1.7.0 to 1.8.0
- Prerequisites updated: minimum v2.1.69+ (was v2.1.16+)
- `.github/last-checked-version.txt` updated to v2.1.81
- Scheduled workflow triggers disabled (PR #66) to save API tokens — re-enable in Phase 5

### Audited (Category C: no swap needed)
- No custom `/claude-api` skill exists — nothing to swap with native built-in

## [1.7.0] - 2026-02-15

### Added
- CI Auto-Fix Loop (`ci-self-heal.yml`) — automated fix cycle for CI failures and PR review findings
- Multi-call LLM judge (v3) — per-criterion API calls with dedicated calibration examples
- Golden output regression — 3 saved outputs with verified expected score ranges catch prompt drift
- Per-criterion CUSUM — tracks individual criterion drift, not just total score
- Pairwise tiebreaker (v3.1) — holistic comparison with full swap when scores within 1.0
- Deterministic pre-checks — grep-based scoring for task_tracking, confidence, tdd_red (free, fast)
- 3 real-world scenarios: multi-file-api-endpoint, production-bug-investigation, technical-debt-cleanup
- Score analytics (`score-analytics.sh`) — history parsing, trends, per-criterion averages, reports
- Score history persistence — results committed back to repo after each E2E evaluation
- Historical context in PR comments — scenario average and weakest criterion
- Color-coded PR comments — emoji indicators for PASS/WARN/FAIL per criterion
- Binary sub-criteria scoring with workflow input validation (PR #32)
- Evaluate bug regression tests (`test-evaluate-bugs.sh`)
- Score analytics tests (`test-score-analytics.sh`)
- Self-heal simulation tests (25 tests) — retry counting, AUTOFIX_LEVEL filtering, findings parsing, branch safety
- Self-heal live fire test procedure — validated full workflow_run → Claude fix → commit cycle (PR #52)

### Fixed
- `workflow_run` trigger dead for ci-autofix — invalid `workflows: write` permission scope caused GitHub parser to silently fail; removed it + renamed to `ci-self-heal.yml`
- Tier 1 E2E flakiness — regression threshold widened from -0.5 to -1.5 (absorbs ±1 LLM noise)
- Silent zero scores from `2>&1` mixing stderr into stdout (PR #33)
- Token/cost metrics always N/A — removed dead extraction code (action doesn't expose usage data)
- Score history never persisting (ephemeral runner) — added git commit step
- `show_full_output` invalid action input — deleted
- `configureGitAuth` crash — added `git init` before simulation
- `error_max_turns` on hard scenarios — bumped from 45 to 55
- Autofix can't push workflow files — requires PAT with `workflow` scope or GitHub App (not YAML permissions)
- `git push` silent error swallowing in `weekly-community.yml` — removed `|| echo` fallback
- Missing `pull-requests: write` permission in `monthly-research.yml` — e2e-test job creates PRs but permission wasn't declared
- Workflow input validation audit — removed `prompt_file`, `direct_prompt`, `model` invalid inputs across all 3 auto-update workflows
- `outputs.response` doesn't exist — read from execution output file instead
- CI re-trigger 403 in self-heal loop — missing `actions: write` permission for `gh workflow run` dispatch

### Changed
- `monthly-research.yml` schedule enabled (1st of month, 11 AM UTC) — Item 23 Phase 3
- `weekly-community.yml` schedule enabled (Mondays 10 AM UTC) — Item 23 Phase 2
- `daily-update.yml` schedule re-enabled (9 AM UTC) — Item 23 Phase 1
- All auto-update workflows create PRs (removed "LOW → direct commit" path)
- Evaluation uses `claude-opus-4-6` model (was hardcoded to `claude-sonnet-4`)
- E2E scenarios expanded from 10 to 13

## [1.6.0] - 2026-02-06

### Added
- Full test coverage for stats library, hooks, and compliance checker (34 new tests)
- Extended SDP calculation and external benchmark tests (9 new tests)
- Future roadmap items 14-19 in AUTO_SELF_UPDATE.md

### Fixed
- Version format validation before npm install (security: prevents injection)
- Hardcoded `/home/runner/work/_temp/` paths replaced with `${RUNNER_TEMP:-/tmp}`
- Silent fallback to v0.0.0 on API failure (now fails loudly)
- Duplicate prompt sources in daily-update workflow (prompt_file + inline prompt)
- Hardcoded output path in pr-review workflow
- Weekly community workflow hardcoded output path

### Changed
- Documentation overhaul: TESTING.md, CI_CD.md, CONTRIBUTING.md, README.md updated
- SDLC.md version tracking updated from 1.0.0 to 1.6.0

### Files Added
- `tests/test-stats.sh` - Statistical functions tests (14 tests)
- `tests/test-hooks.sh` - Hook script tests (11 tests)
- `tests/test-compliance.sh` - Compliance checker tests (9 tests)

### Files Modified
- `.github/workflows/daily-update.yml` - Security + correctness fixes
- `.github/workflows/pr-review.yml` - Hardcoded path fix
- `.github/workflows/weekly-community.yml` - Hardcoded path fix
- `tests/test-sdp-calculation.sh` - Extended (5 new tests)
- `tests/test-external-benchmark.sh` - Extended (4 new tests)

## [1.5.0] - 2026-02-03

### Added
- SDP (SDLC Degradation-adjusted Performance) scoring to distinguish "model issues" from "wizard issues"
- External benchmark tracking (DailyBench, LiveBench) with 24-hour caching
- Robustness metric showing how well SDLC holds up vs model changes
- Two-layer scoring: L1 (Model Quality) + L2 (SDLC Compliance)

### How It Works
PR comments now show three metrics:
- **Raw Score**: Actual E2E measurement
- **SDP Score**: Adjusted for external model conditions
- **Robustness**: < 1.0 = resilient, > 1.0 = sensitive

When model benchmarks drop but your SDLC score holds steady, that's a sign your wizard setup is robust.

### Files Added
- `tests/e2e/lib/external-benchmark.sh` - Multi-source benchmark fetcher
- `tests/e2e/lib/sdp-score.sh` - SDP calculation logic
- `tests/e2e/external-baseline.json` - Baseline external benchmarks
- `tests/test-external-benchmark.sh` - Benchmark fetcher tests
- `tests/test-sdp-calculation.sh` - SDP calculation tests

### Files Modified
- `tests/e2e/evaluate.sh` - Outputs SDP alongside raw scores
- `.github/workflows/ci.yml` - PR comments include SDP metrics
- Documentation updated (README, CONTRIBUTING, CI_CD, AUTO_SELF_UPDATE)

## [1.4.0] - 2026-01-26

### Added
- Auto-update system for staying current with Claude Code releases
- Daily workflow: monitors official releases, creates PRs for relevant updates
- Weekly workflow: scans community discussions, creates digest issues
- Analysis prompts with wizard philosophy baked in
- Version tracking files for state management

### How It Works
GitHub Actions check for Claude Code updates daily (official releases) and weekly (community discussions). Claude analyzes relevance to the wizard, and HIGH/MEDIUM confidence updates create PRs for human review. Most community content is filtered as noise - that's expected.

### Files Added
- `.github/workflows/daily-update.yml`
- `.github/workflows/weekly-community.yml`
- `.github/prompts/analyze-release.md`
- `.github/prompts/analyze-community.md`
- `.github/last-checked-version.txt`
- `.github/last-community-scan.txt`

### Required Setup
Add `ANTHROPIC_API_KEY` to repository secrets for workflows to function.

## [1.3.0] - 2026-01-24

### Added
- Idempotent wizard - safe to run on any existing setup
- Setup tracking comments in SDLC.md (version, completed steps, preferences)
- Wizard step registry for tracking what's been done
- Backwards compatibility for old wizard users

### Changed
- "Staying Updated" section rewritten for idempotent approach
- Update flow now checks plugins and questions, not just files
- One unified flow for setup AND updates (no separate paths)

### How It Works
The wizard now tracks completed steps in SDLC.md metadata comments. Old users running "check for updates" will be walked through only the new steps they haven't done yet.

## [1.2.0] - 2026-01-24

### Added
- Official plugin integration (claude-md-management, code-review, claude-code-setup)
- Step 0.1-0.4: Plugin setup before auto-scan
- "Leverage Official Tools" principle in Philosophy section
- Post-mortem learnings table (what goes where)
- Testing skill "After Session" section for capturing learnings
- Clear update workflow in "Staying Updated" section

### Changed
- Step 0 restructured: plugins first, then SDLC setup, then auto-scan
- Stay Lightweight section now includes official plugin table
- Clarified plugin scope: claude-md-management = CLAUDE.md only

### Files Affected
- `.claude/skills/testing/SKILL.md` - Add "After Session" section
- `SDLC.md` - Consider adding version comment

## [1.1.0] - 2026-01-23

### Added
- Tasks system documentation (v2.1.16+)
- $ARGUMENTS skill parameter support (v2.1.19+)
- Ike the cat easter egg (8 pounds, Fancy Feast enthusiast)
- Iron Man analogy for human+AI partnership

### Changed
- Test review preference: user chooses oversight level
- Shared environment awareness (not everyone runs isolated)

## [1.0.0] - 2026-01-20

### Added
- Initial SDLC Wizard release
- TDD enforcement hooks
- SDLC and Testing skills
- Confidence levels (HIGH/MEDIUM/LOW)
- Planning mode integration
- Self-review workflow
- Testing Diamond philosophy
- Mini-retro after tasks

