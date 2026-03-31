# Roadmap

## Pre-Distribution (ordered)

| # | Item | Status |
|---|------|--------|
| 1 | Weekly workflow consolidation | DONE (PR #70) |
| 2 | Verify all-findings self-heal | DONE (PR #70) |
| 3 | "Prove It's Better" CI automation | DONE (v1.10.0) |
| 4 | Tier 2 E2E full suite audit | DONE (13 scripts, 3 bugs fixed) |
| 5 | Full system audit | DONE (4 bugs, 6 tests, CC overlap audited) |
| 6 | Package self-update for users | DONE (PR #76) |
| 7 | Post-update audit | DONE (PR #75) |
| 8 | Competitive audit | DONE (PR #77) |
| 9 | `--bare` for non-E2E workflows | DONE (PR #81) |
| 10 | Trigger weekly/monthly + audit | DONE (PRs #87, #88) |
| 11 | Re-run wizard on ourselves | DONE (PR #89) |
| 12 | CI efficiency audit | DONE (PR #92) |
| 13 | Cross-model full repo audit | DONE — pass 7 closed (PRs #97-100). No substantive open findings |
| 13.5 | Live-fire CI job audit | DONE — all CI paths verified (PR #102 fixed Tier 2 git init, 5-trial eval passed) |
| 13.6 | Wire cross-model review into own SDLC | DONE — cross-model review is now a first-class SDLC step |
| 14 | Distribution | DONE — `npx agentic-sdlc-wizard init` (PR #103). Zero-dep CLI, 16 tests |

## Post-Distribution

| # | Item | Description |
|---|------|-------------|
| 15 | E2E Scenario Coverage Audit | DONE — added `## Fixture: test-repo` to all 16 scenarios, `get_fixture_for_scenario()` in scenario-selector.sh, 3 new scenarios targeting real fixture gaps (searchTasks, batchComplete, persistence). 5 new tests. Documented 7 existing scenario-fixture mismatches |
| 16 | Scoring System Review | DONE — enforce_tdd_consistency guard, tightened self_review + clean_code prompts, EVAL_PROMPT_VERSION v4→v5. 3 new tests (41 total in eval-validation) |
| 17 | Setup Drift Prevention | DONE — `sdlc-wizard check [--json]` subcommand. SHA-256 content hash, executable permission check, .gitignore line-aware matching, npm update detection. Exits non-zero on MISSING/DRIFT for CI gating. 6 tests |
| 18 | Tool/Plugin Discovery Automation | DONE — existing weekly-update release analysis + prove-it pipeline covers it. No marketplace.json registry exists for CC |
| 19 | Monthly GC Audit (recurring) | "Less is more" — try removing things, check if scores hold. Fix weak tests or delete fluff |
| 20 | Setup-Path E2E Proof | DONE — `test-setup-path.sh` validates init across 7 fixture types (47 tests). Wired into CI |
| 21 | Scan Routing Refactor | DONE — `origin`-typed routing (`external` vs `internal-friction`) replaces count-only `findings_count` gating. Full scan payload handoff between jobs. Friction-only weeks now create digest issues without triggering E2E. 6 new routing tests (176 total workflow tests) |
| 22 | ~~Setup Wizard Skill (CRITICAL)~~ DONE | Added `/setup-wizard` skill (`.claude/skills/setup/SKILL.md`) — 11-step mechanical checklist covering auto-scan, all 16 Q&A questions, file generation, and verification. Updated `instructions-loaded-check.sh` to explicitly invoke `setup-wizard` skill. CLI distributes skill as 8th file. 23 CLI tests, 25 hook tests, 47 setup-path tests passing |
| 23 | ~~Complex Repo Install Test~~ DONE | Fixed settings.json merge bug — init now merges wizard hooks into existing config instead of skip/overwrite. New `complex-existing-config` fixture (custom hooks, skills, commands, settings.local.json, CLAUDE.md). 13 new tests (8 setup-path + 5 CLI merge), 113 total passing. PR #107 |
| 24 | Harness Design for Long-Running Tasks | DONE (Tier 1) — Few-shot calibrated evaluator (7 criterion prompts), critical criteria enforcement (tdd_red + self_review must-pass), scoring rubric shared with generator (SDLC skill). EVAL_PROMPT_VERSION v5→v6. 8 new tests (46+25 total). PR #109. Codex cross-model review caught unenforced critical_miss — fixed. Tier 2 (evaluator tuning loop, contract negotiation) and Tier 3 (file-based handoffs, planner agent) deferred |
| 25 | Codex README/Docs Audit | DONE — Codex audit on all user-facing docs. Fixed install UX (first section, copy-pasteable), honest claims across 6 docs, added Playwright MCP vs Tests section, docs usability regression test (10 checks). Setup wizard auto-invoke UX fix (sdlc-prompt-check.sh redirects to setup-wizard when SDLC files missing) |
| 26 | npm Registry Publish | DONE — published `agentic-sdlc-wizard@1.15.0` to npm. v1.16.0 includes setup-wizard auto-invoke hook fix |
| 27 | ~~Review Pipeline Experiment~~ DONE | Created `AGENTS.md` (Codex review guidelines mirroring Claude PR review prompt), `.reviews/experiment-tracking.md` (tracking table for 10-20 PR comparison). 3 tests. Infrastructure ready — next step: install Codex GitHub App and start tracking |
| 28 | Consolidate /testing into /sdlc | DONE — PR #113. Moved mocking table, unit test criteria, TDD Must PROVE, After Session into /sdlc skill. Deleted /testing skill + hook routing. Added upgrade cleanup (OBSOLETE_PATHS). 4 consolidation tests, 4 effort tests. Zero content loss verified |
| 29 | ~~Effort Level Recommendations~~ DONE | Added `## Recommended Effort Level` section to wizard. `high` default via skill frontmatter, suggest `max` for LOW confidence / FAILED 2x / architecture decisions. Confidence table gets Effort column. 4 tests |
| 30 | ~~Post-Deploy Verification~~ DONE | Added Post-Deploy Verification section to ARCHITECTURE.md template (health checks, log commands, smoke tests per environment, monitoring guidance). SDLC skill deployment section now includes post-deploy verification steps. 3 tests |
| 39 | SDLC Enforcement Gap Audit | DONE — Audited all documented SDLC sections vs TodoWrite/hook/E2E enforcement. Fixed 5 gaps: capture learnings, scope guard, deploy tasks, new pattern approval, legacy delete check. Enforcement coverage 7/12 → 12/12. 6 new tests. Future: add E2E scoring criteria for scope_guard, after_session, deploy |
| 41 | ~~Auto-Update PR CI Trigger~~ DONE | PR #119. Added `gh workflow run ci.yml` dispatch after all 3 `peter-evans/create-pull-request` calls. Added `actions: write` to weekly-update + monthly-research. 4 tests |

## Previous Release (v1.19.0)

| # | Item | Description |
|---|------|-------------|
| 36 | ~~CI Local Shepherd Model~~ DONE | Formalized two-tier CI fix model: shepherd (primary, in-session) + bot (fallback, unattended). SHA-based suppression in ci-self-heal.yml prevents redundant bot runs when shepherd already pushed. Documented comparison table in wizard + CI_CD.md. 9 new tests. PR #124 |
| 35 | ~~Gap Analysis vs `/claude-automation-recommender`~~ DONE | Wizard = enforcement engine, recommender = suggestion engine. Complementary, not competitive. Updated Step 0.3 with comparison table, added Complementary Tools section, setup skill recommends post-setup. 4 new tests. PR #125 |
| 38 | ~~`/clear` vs `/compact` Guidance~~ DONE | Added Context Management section to wizard: comparison table, rules (/compact for continuing, /clear between tasks, /clear after 2+ failures). Documented auto-compact (~95% capacity). Updated SKILL.md with context management section. 4 new tests. PR #126 |
| 42 | ~~Token Efficiency Auditing~~ DONE | Added Token Efficiency section to wizard: /cost monitoring, reduction techniques (compact/clear/subagents/effort), CI cost control (--max-budget-usd, --max-turns), OpenTelemetry for org-wide tracking. Updated CI_CD.md token tracking section. 4 new tests. PR #127 |
| 31 | ~~`/init` for Blank Repos~~ DONE | Verified wizard installs cleanly on blank repos. Added blank-repo fixture, 10 new E2E tests (68 total setup-path). Added guidance: no need for `/init` first, setup wizard generates all docs. PR #128 |
| 43 | ~~Feature Documentation Enforcement~~ DONE | Added ADR pattern guidance (`docs/decisions/`), `claude-md-improver` recommendation for CLAUDE.md health, "Documentation Sync" section in SDLC skill (enforce doc updates when code contradicts/extends documented behavior), docs-in-sync detection guidance. Strengthened transition step and After Session routing. 6 new tests. PR #129 |

## This Release (ordered)

| # | Item | Description |
|---|------|-------------|
| 46 | CC Version-Pinned Update Gate | Turn update PRs from notifications into real quality gates. `weekly-update.yml` installs the specific new CC version (`npm install @anthropic-ai/claude-code@X.Y.Z`) and passes it to E2E via `path_to_claude_code_executable`. Green CI = safe to upgrade. Red = stay on current version until fixed. Prevents blind upgrades. Also enables: version pinning in wizard docs (recommended CC version), regression detection (score drop = don't upgrade), and rollback guidance |
| 32 | N-Reviewer CI Pipeline | Support N parallel code reviewers (Claude, Codex, etc.) commenting on PRs. Agent responds like a dev to each reviewer, iterates until all approve. Depends on Codex experiment (#27) providing data first |
| 37 | Lesson Contribution Hook | Auto-detect key SDLC lessons during sessions. Offer to create GH issue on user's repo. Optionally contribute back to wizard repo. Hook into "After Session" step — if learnings captured, prompt for issue creation |
| 44 | BRANDING.md Detection & Guidance | Research: should the wizard detect/suggest a BRANDING.md (brand voice, tone, naming conventions, visual identity guidelines)? Options: always create, detect from existing assets (logos, style guides, design system), suggest only when UI/content work detected |
| 45 | `/agents` Subagent Exploration | Research: explore Claude Code's `/agents` (custom subagents in `.claude/agents/`). Can an `sdlc-reviewer` or `ci-debug` agent add value beyond hooks+skills? Testing story for agent behavior |

## Unprioritized

_(All items moved to This Release or Back Burner)_

## Review Pipeline

### Now

- Keep local review loop as the default quality bar: Claude self-review first, then local Codex `xhigh` for independent cross-model review on substantial changes.
- Keep GitHub PR automation on the existing Claude review pipeline so SDLC checks and `ci-self-heal.yml` continue to work.
- Pin the GitHub PR reviewer to `claude-opus-4-6` for maximum current Claude review quality.
- Enable Codex GitHub review manually and use it on high-risk PRs first rather than every PR.

### Next: Codex vs Claude Review Experiment

- Evaluate the next 10-20 non-trivial PRs.
- Use the current Claude PR review on all of them.
- Manually trigger Codex review on epic/high-risk PRs with `@codex review`.
- Track for each PR:
  - unique findings from Claude
  - unique findings from Codex
  - false positives / low-value noise
  - merge delay / workflow friction
  - whether findings were severe enough to change the merge decision
  - relative cost and review frequency

### Decision Gate

- If Codex consistently finds higher-value issues with acceptable noise, promote it from optional cross-reviewer to a first-class review provider.
- If Claude remains better for SDLC/process/testing guidance, keep Claude as the default PR reviewer and use Codex only as a selective second opinion.
- If both are valuable, design a graded review policy instead of double-running on every PR.

### Future Work

- Add a dedicated PR label such as `cross-review` or `epic-review` for elevated review requirements.
- Make the PR review layer provider-swappable instead of coupling `ci-self-heal.yml` to a Claude-specific markdown format.
- Move toward a normalized review artifact or check-run parser so Claude and Codex can plug into the same automation.
- Revisit whether default review should be single-provider, dual-provider for labeled PRs, or manual Codex-only cross-review.

## Item 13.5: Live-Fire CI Job Audit

Every CI workflow/job must succeed at least once post-changes before distribution. Current gaps:

| Job/Trigger | Last Green | Gap | Action |
|---|---|---|---|
| `e2e-full-evaluation` (merge-ready label) | Mar 28 (PR #102) | Bug found: missing `git remote add origin` in Tier 2 init | VERIFIED — fix merged, 5-trial Tier 2 passed in 9m5s |
| `weekly-update.yml` schedule trigger | Mar 27 (manual dispatch) | Schedule trigger untested since label fix | VERIFIED — dispatch passed Mar 27 |
| `monthly-research.yml` schedule trigger | Mar 27 (manual dispatch) | Schedule trigger passed Mar 27 | VERIFIED — dispatch passed Mar 27 |
| Stale `ci-autofix.yml` (ID 232420762) | Never (dead workflow) | Orphaned after rename to ci-self-heal.yml | DONE — disabled via `gh workflow disable` on Mar 28 |
| Node.js 20 deprecation | N/A | `actions/checkout@v4` + `oven-sh/setup-bun` will be forced to Node 24 on June 2, 2026 | Back burner (revisit May 2026) |

## Back Burner

- Node.js 20 deprecation (June 2, 2026 deadline — `actions/checkout@v4` + `oven-sh/setup-bun` forced to Node 24. Not urgent yet but blocks all CI if ignored. Revisit May 2026)
- Chaos/Resilience Testing (needs research — beyond mutation testing, think chaos monkey for repos. Inject faults, break things intentionally, see if SDLC catches them. Could be important for AI agent validation or general resilience. Research before committing)
- Agent-agnostic SDLC (generalize wizard beyond Claude Code — Codex CLI, other AI agents. Auto-detect domain from repo contents, generate domain-appropriate hooks/skills. Reference impl: anticheat repo Content SDLC with GRADE labels, multi-source consensus, 219 tests. NOT immediate — needs #28 consolidation first)
- Subagent Model Compliance Audit (transcript audit proved Explore agent uses Haiku 4.5 39% of the time despite CLAUDE_CODE_SUBAGENT_MODEL override. Fix: ANTHROPIC_DEFAULT_*_MODEL env vars. Verify fix next session. Consider: `sdlc-wizard audit` subcommand checking config health + model compliance. Research if users care before shipping)
