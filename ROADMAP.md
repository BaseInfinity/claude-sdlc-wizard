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

## Previous Release (v1.20.0)

| # | Item | Description |
|---|------|-------------|
| 36 | ~~CI Local Shepherd Model~~ DONE | Formalized local shepherd CI fix model (in-session). Bot fallback (`ci-self-heal.yml`) was later deprecated — local shepherd provides higher quality fixes at lower cost. PR #124 |
| 35 | ~~Gap Analysis vs `/claude-automation-recommender`~~ DONE | Wizard = enforcement engine, recommender = suggestion engine. Complementary, not competitive. Updated Step 0.3 with comparison table, added Complementary Tools section, setup skill recommends post-setup. 4 new tests. PR #125 |
| 38 | ~~`/clear` vs `/compact` Guidance~~ DONE | Added Context Management section to wizard: comparison table, rules (/compact for continuing, /clear between tasks, /clear after 2+ failures). Documented auto-compact (~95% capacity). Updated SKILL.md with context management section. 4 new tests. PR #126 |
| 42 | ~~Token Efficiency Auditing~~ DONE | Added Token Efficiency section to wizard: /cost monitoring, reduction techniques (compact/clear/subagents/effort), CI cost control (--max-budget-usd, --max-turns), OpenTelemetry for org-wide tracking. Updated CI_CD.md token tracking section. 4 new tests. PR #127 |
| 31 | ~~`/init` for Blank Repos~~ DONE | Verified wizard installs cleanly on blank repos. Added blank-repo fixture, 10 new E2E tests (68 total setup-path). Added guidance: no need for `/init` first, setup wizard generates all docs. PR #128 |
| 43 | ~~Feature Documentation Enforcement~~ DONE | Added ADR pattern guidance (`docs/decisions/`), `claude-md-improver` recommendation for CLAUDE.md health, "Documentation Sync" section in SDLC skill (enforce doc updates when code contradicts/extends documented behavior), docs-in-sync detection guidance. Strengthened transition step and After Session routing. 6 new tests. PR #129 |
| 46 | ~~CC Version-Pinned Update Gate~~ DONE | `weekly-update.yml` version-test now passes `path_to_claude_code_executable` to all 3 `claude-code-action` calls, ensuring E2E actually tests the specific new CC version. Added `id: install-cc` + `which claude` path capture. CI_CD.md verdict table, wizard "How We Apply This" updated. 4 new tests (60 total in test-self-update). PR #131 |
| 47 | ~~Tier 1 E2E Flakiness Fix~~ DONE | Regression threshold 1.5→3.0, absorbs ±2-3 point LLM variance (rare extremes ±4 caught by Tier 2). Flaky test prevention guidance + external reference in wizard, SKILL.md. 2 new release consistency tests (64 total in test-self-update). PR #132 |

## Previous Release (v1.22.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 48 | ~~CI Shepherd Opt-In~~ DONE (partial) | Shepherd opt-in question (Q18) added to setup wizard. ci-analyzer skill was also added but deleted — violated Prove It philosophy (existence-only tests, no quality validation, overlap with third-party `/claude-automation-recommender`). Deletion led to Prove It Gate enforcement in SDLC skill |
| 2 | 49 | ~~Cross-Model Release Review Recommendation~~ DONE | Added "releases/publishes" as explicit cross-model review trigger in wizard + SKILL. Release Review Checklist subsection (CHANGELOG consistency, version parity, stale examples, docs accuracy, template parity) with v1.20.0 evidence. Triaged monthly research #84: 4 already done, 2 absorbed into existing items, 1 new unprioritized (#54), 2 skipped. 6 new tests |
| 3 | 50 | ~~Skill Deduplication Audit~~ DONE | Audited all 4 skills: /sdlc (core), /setup (core), /update (core), /ci-analyzer (deleted — unvalidated). Added Prove It Gate enforcement to SDLC skill + wizard doc. Internal consistency test catches stale references across all skills. 3 skills remain, each proven necessary |
| 4 | 52 | ~~Confidence-Driven Setup~~ DONE | Killed the fixed 18 questions. Setup wizard now scans repo, builds confidence per data point, only asks what it can't infer. Question count is DYNAMIC (0-2 for well-configured projects, 10+ for bare repos). 95% aggregate confidence threshold — if scan resolves enough, bulk confirm and generate. Wizard doc updated: Q-numbered questions → data point descriptions with detection hints. 6 new tests replace 2 old. PR #138 |
| 5 | 53 | ~~Plan Auto-Approval Gate~~ DONE | Skip plan approval when confidence >= 95% AND single-file/trivial task. Added to SDLC skill + wizard doc. Still announces approach, just doesn't wait for approval. "When in doubt, wait for approval" as safety valve |
| 6 | 55 | ~~Debugging Methodology~~ DONE | Added systematic Debugging Workflow section: Reproduce → Isolate → Root Cause → Fix → Regression Test. `git bisect` for regressions, environment-specific debugging, "after 2 failed attempts, STOP and ASK USER" |
| 7 | 37 | ~~`/feedback` — Community Contribution Loop~~ DONE | Privacy-first `/feedback` skill: never scans without explicit consent. 4 feedback types (bug, feature, pattern, improvement). Creates GH issues on wizard repo. Distributed via CLI (9 template files) |
| 8 | 44 | ~~BRANDING.md Detection & Guidance~~ DONE | Setup wizard detects branding assets (brand/, logos/, style-guide.md, brand-voice.md). BRANDING.md generated conditionally only when assets found. Template added to wizard doc |
| 9 | 32 | ~~N-Reviewer CI Pipeline~~ DONE | Added Multiple Reviewers section to SDLC skill + wizard doc. Per-reviewer response pattern, conflict resolution (pick stronger argument), max 3 iterations per reviewer, escalate to user |
| 10 | 45 | ~~`/agents` Subagent Exploration~~ DONE | Documented `.claude/agents/` pattern in SDLC skill + wizard doc. Example agents: sdlc-reviewer, ci-debug, test-writer. Skills vs agents comparison. Agents for parallel work and fresh context windows |

## Previous Release (v1.24.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 86 | ~~Fix: E2E tdd_red Detection~~ DONE | PR #150. Three bugs: test-only scored 0, golden outputs were .txt not JSON, golden-scores encoded bug. Codex review caught regex false-positive (contest/ substring) + missing JSON pairing — both fixed. 29 deterministic + 9 regression tests passing |
| 2 | 68 | ~~Hook `if` Conditionals~~ DONE | PR #151. Added CC v2.1.85+ `if` field to PreToolUse hook — TDD check only spawns for source files (repo: `.github/workflows/*`, template: `src/**`). Documented in wizard CC features section. 6 new tests (52 total hook tests) |
| 3 | 88 | ~~Autocompact + Context Model Recommendation~~ DONE | PR #152. Added autocompact env var guidance (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, CLAUDE_CODE_AUTO_COMPACT_WINDOW) with community-recommended thresholds (75% for 200K, 30% for 1M). 1M vs 200K context window comparison table. Setup wizard Step 9.5 for context window configuration. Codex cross-model review caught setup skill parity miss + overclaimed env var documentation status — both fixed. 5 new tests (70 total self-update tests) |

## Previous Release (v1.23.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 64 | ~~Update Notification Hook~~ DONE | `instructions-loaded-check.sh` checks npm each session. 6 quality tests (fake npm, version comparison, failure modes). Non-blocking, graceful on network failure |
| 2 | 59 | ~~Research: CC Architecture (Public Sources)~~ DONE | 7-topic deep research (hooks, skills, plugins, settings, upcoming features, Agent SDK, CLI). Key findings: 25 hook events (we use 3), plugin format is the official distribution path, KAIROS/Coordinator Mode coming, `--bare` bypasses wizard entirely. Spawned items #66-71 |
| 3 | 72 | ~~Cross-Model Review Standardization~~ DONE | Audited 4 repos + external research (14 repos, 7 papers). Rewrote Cross-Model Review section: mission-first handoff, preflight self-review doc, verification checklist, adversarial framing, domain template guidance, convergence 2-3 rounds. 6 quality tests |
| 4 | 73 | ~~Release Planning Gate~~ DONE | Added as section in SDLC skill (Prove It absorption check). Batch planning for releases. 3 quality tests |
| 5 | 57 | ~~Context Position Audit~~ DONE | Moved critical instructions to top 11% of SKILL.md. 3 quality tests |
| 6 | 56 | ~~Adversarial Review Prompting~~ DONE | Merged into #72 |
| 7 | 65 | ~~Testing Diamond Boundary~~ DONE | Explicit E2E vs Integration vs Unit boundary. 2 quality tests |
| 8 | 69 | ~~Skill Frontmatter Docs~~ DONE | Full frontmatter field table. 2 quality tests |
| 9 | 70 | ~~`--bare` Docs~~ DONE | `--bare` bypass warning in SKILL.md + wizard. 2 quality tests |

## Earlier Cycle Items (pre-v1.32.0 batch)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 85 | ~~Automated CC Feature Discovery~~ DONE | Already implemented in weekly-update.yml: fetches CC releases, analyzes with Claude (analyze-release.md), produces relevance/impact JSON, creates PR. GitHub issue per-feature deferred — PR + ROADMAP already cover tracking |
| 2 | 91 | ~~Codex SDLC Adapter~~ DONE | `BaseInfinity/codex-sdlc-wizard` PR #1. 3 hook scripts (bash-guard hard-blocks git commit/push, sdlc-prompt-check, session-start), non-destructive install.sh (6-case config merge, comment-aware), AGENTS.md, upstream-sync workflow. 15 behavioral tests. Codex review caught 2 bugs (commented config lines, macOS sed TOML corruption) — both fixed. ~70% CC parity |
| 3 | 58 | ~~Research: claw-code + OmO/OmX Patterns~~ DONE | Studied claw-code (168K stars), OmO (48K), OmX (16K). 16 candidate patterns identified. Codex certified 8/10 round 3. All candidates require Prove It Gate. Research doc: `RESEARCH_58_CLAW_OMO_OMX.md` |
| 4 | 103 | ~~Fix: self_review 0% in E2E Scoring~~ DONE | Root cause: simulation prompt said "self-review" without explaining HOW (Read/Grep on modified files) or marking it scored. Golden output had text-only review (the exact NO example from the evaluator). Fix: all 5 simulation prompts now explain self-review = Read back modified files + marked scored in IMPORTANT section. Golden output/scores updated. 4 new tests |

## This Release (v1.34.0, shipped 2026-04-17)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 100 | ~~API Feature Detection in Auto-Update~~ DONE | PRs #184, #186, #187. Shepherd pattern: LLM-free weekly detector (`.github/workflows/weekly-api-update.yml`) fetches `platform.claude.com/docs/en/release-notes/api.md`, parses ATX date headers with ordinal normalizer + bullet-summary capture (`scripts/parse-api-changelog.py`), opens/updates single `api-review-needed` tracking issue. State persisted via `scripts/persist-api-state.sh` with non-blocking push (branch-protection safe). Session-time hook (`instructions-loaded-check.sh`) nudges when open issues exist — gated on LOCAL workflow presence so consumer/forks only see their own detector's issues. **E2E verified in prod 2026-04-17** — issue body renders feature text like "We've launched Claude Opus 4.7..." not just the date. 33 tests incl. 8 fixture-based parser tests (bullet capture, subheader boundary, tab scrub, truncation, ordinal dates) + 2 integration tests. Codex xhigh 5 rounds across 2 PRs: 9/10 CERTIFIED. Found-in-prod P0 (`gh api` writes JSON error to stdout not stderr — label-create already_exists check broken after first run) hotfixed in #187 |
| 2 | 189 | ~~Memory Audit Protocol~~ DONE | PR #189. `/sdlc` subsection defines three-bucket classifier (`promote`/`keep`/`manual-review`) with rule-based privacy denylist (`user`/`reference` → keep, `project`/`feedback` → manual-review). Hardened YAML parser normalizes quotes/comments/whitespace. `SDLC.md` seeded with 7 verified technical gotchas (each repro-verified and citing PR# or incident date). 10-fixture corpus (6/2/2) + 12-test suite covers structure, denylist hardening, corpus consistency. Protocol's first dogfood run caught 2 false lessons in private memory (`${3:-{}}` brace-default and `--argjson result` jq-conflict) that Codex verified as wrong — retracted with dated strikethrough rather than shipped. 3 Codex code-review rounds: 4→8→**10/10 CERTIFIED**. Meta-lesson: plan-CERTIFIED ≠ code-CERTIFIED; always run fresh Codex cycle on actual implementation |
| 3 | 183 | ~~Surface `/less-permission-prompts` native skill~~ DONE | PR #183. Added to wizard + setup docs |

## Previous Release (v1.33.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 179 | ~~Model/Effort Upgrade Detection~~ DONE | Session-start hook nudges when `effortLevel` is below recommended `xhigh`. Reads `.claude/settings.local.json` → `.claude/settings.json` → `$HOME/.claude/settings.json`. Non-blocking (exit 0). Bumped `claude-opus-4-6` defaults to `claude-opus-4-7` in pr-review.yml, evaluate.sh, sdp-score.sh, pairwise-compare.sh. Hook wired into SDLC.md table + CLI distributes `model-effort-check.sh` |
| 2 | 180 | ~~SessionStart Model Detection Fix~~ DONE | PR #180. SessionStart hook input doesn't expose model field — switched to effort-only detection; asks Claude to compare recommended model against its own system prompt |
| 3 | 181 | ~~Dual-Channel Install Drift Guardrails~~ DONE | PR #181. `cli/init.js` detects plugin install paths (`~/.claude/plugins-local/sdlc-wizard-wrap/`, `~/.claude/plugins/cache/sdlc-wizard-local/`) and blocks with typed `err.pluginPaths`; `--force` bypass. `instructions-loaded-check.sh` non-blocking nudge when CLI+plugin both present. HOME isolation across test files (`mktemp -d` + `trap`), `path.isAbsolute(home)` guard, `run_init_split` helper. Codex xhigh 4-round: 9/10 CERTIFIED |
| 4 | 182 | ~~opus[1m] as SDLC Default~~ DONE | CLI template ships `"model": "opus[1m]"` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=30` (1M-tuned, compacts at ~300K). `cli/init.js` merges top-level `model` when absent, respects user's explicit choice, `--force` overwrites. Wizard doc + /sdlc skill + /setup skill + SDLC.md all flipped to recommend 1M default. Hooks now recommend `opus[1m]` alias. Baseline bumped to CC v2.1.111+. 9 new tests, 6 existing updated. Codex xhigh 2-round: 9/10 CERTIFIED |

## Previous Release (v1.32.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 178 | ~~Opus 4.7 + xhigh Effort Support~~ DONE | Benchmark workflow adds opus-4-7 model choice + effort input (high/xhigh/max). Hard-fail on xhigh+non-4.7. Effort in artifacts + summaries. Wizard docs updated with xhigh guidance. 39 model-comparison tests |
| 2 | — | ~~Benchmark Ceiling Effect Audit~~ DONE | Cross-model audit (Codex GPT-5.4 xhigh) rated benchmark 2/10 NOT CERTIFIED. 4 P0s: fake trials, answer key leaked, no independent verification, binary rubric. Documented in wizard with 3 concrete fixes. Tracked under #96 |
| 3 | — | ~~Community Discord~~ DONE | Automation Station link in README (sdlc-wizard + codex-sdlc-wizard + project-tracker) |

## Previous Release (v1.31.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 173 | ~~Fix: Hook False-Positive in Non-SDLC Dirs~~ DONE | PR #175. Silent exit when walk-up finds neither SDLC.md nor TESTING.md. Partial setups (one file) still warn. Added `find_partial_sdlc_root` helper. 2 new tests (60 total hook tests) |
| 2 | 174 | ~~Warn on Ephemeral Marketplace Path~~ DONE | CLI `check` scans `~/.claude/settings.json` `extraKnownMarketplaces` for ephemeral (`/tmp/`, `/private/tmp/`, `/var/folders/`) and dangling directory sources. EPHEMERAL warns (exit 0), DANGLING errors (exit 1). Suggests `~/.claude/plugins-local/`. 10 new tests (51 total CLI tests) |

Deferred: #83 (Local Model — needs real demand signal), #82 (Domain DLCs — Stefan's separate track), #71 (KAIROS — watch-only until CC feature exits experimental), #67 (Agent Team Hooks — same)

## Previous Release (v1.30.0) — Domain + Detection

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 78 | ~~Firmware Fixture~~ DONE | Fleshed out firmware-embedded fixture: Python SD card overlay manager, 3 device configs, SIL + config validation tests within fixture. 12 quality tests prove domain indicators, multi-device differentiation, no-web misclassification. Completes the #79 domain-adaptive proof |
| 2 | 94 | ~~Model A/B Comparison Workflow~~ DONE | PRs #164, #165. `workflow_dispatch` benchmark: Opus vs Sonnet on 16 E2E scenarios with 95% CI. Codex GPT-5.4 xhigh reviewed (3 rounds plan, 2 rounds impl). P0 shell injection fix, wizard install verification, jq artifact construction. 37 quality tests. 7 workflows total |
| 3 | 96 | ~~CC Degradation Detection~~ DONE | Score persistence (ci.yml git-commits JSONL to PR branch) + wizard hardening (adaptive thinking context, `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`, anti-laziness guidance). 14 behavioral tests |

## Previous Release (v1.29.0) — Infra + Setup

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 93 | ~~Node.js 20 EOL~~ DONE | PR #160. 5 action version bumps across 6 workflows, 2 third-party actions replaced with gh CLI, 4 node-version bumps 20→22. 13 compliance tests. Expression injection P0 caught by CI reviewer and fixed |
| 2 | 88 | ~~Autocompact in Setup~~ DONE | CLI sets `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` in settings.json `env` field by default. Smart merge preserves existing user env vars on upgrade, `--force` resets to defaults. Setup wizard Step 9.5 customizes for 1M models (30%). 7 new tests (39 total CLI tests) |
| 3 | 80 | ~~Effectiveness Scoreboard~~ DONE | 52 historical catches seeded in `.metrics/catches.jsonl`. `catch-analytics.sh` computes DDE per layer, escape rates, severity breakdown. Results: cross-model-review (48%) and self-review (46%) nearly tied, self-review missed 28 bugs caught downstream. 14 tests. Log automation deferred until analytics proven useful |

## Built With SDLC Wizard

Living tracker of projects shipped using this wizard. **Rule:** only list projects that have been explicitly marked as using SDLC Wizard — no "powered by" claims before that.

| Project | Repo | Status |
|---------|------|--------|
| SDLC Wizard itself | BaseInfinity/agentic-ai-sdlc-wizard | Dogfooded, v1.34.0 |
| Codex SDLC Adapter | BaseInfinity/codex-sdlc-wizard | v1, shipped with SDLC workflow |
| _(add as projects are marked)_ | | |

**TODO:** audit Stefan's GitHub projects + production apps, mark the ones that used the wizard, then list them here. Do not populate from memory — only list what's been marked.

## Previous Release (v1.28.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 79 | ~~Domain-Adaptive Testing Diamond~~ DONE | PR #157. Setup wizard auto-detects domain (firmware/data-science/CLI/web) and generates domain-specific TESTING.md. 4 domains with distinct testing layers. 3 new fixtures, 25 quality tests. Partially satisfies #78 |
| 2 | 92 | ~~Research: Rigorous Autocompact Benchmarking~~ DONE | PR #158. First rigorous autocompact benchmarking methodology — canary fact mechanism, harness script, 3 task complexity levels, CI workflow with matrix strategy, 26 quality tests. Methodology ships before data |

## Previous Release (v1.25.0)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 89 | ~~Claude Code Plugin Format~~ DONE | PR #154. `.claude-plugin/plugin.json` manifest, hooks support, marketplace.json. CLI reads from root. 25 plugin tests. Absorbs #66 + #87 |
| 2 | 90 | ~~Distribution Channels Sprint~~ DONE | 6 channels: npm, plugin, curl, Homebrew, gh extension, GitHub Releases. awesome-claude-skills PR #588 submitted |
| 3 | -- | ~~CC Version Check + Weekly-Update Audit~~ DONE | Workflow working. March 30 detected v2.1.85→v2.1.87. No fix needed |

## Unprioritized

| # | Item | Description |
|---|------|-------------|
| 51 | ~~Global Install Mode~~ KILLED | Per-repo config is the right model. Global defaults would override project-specific SDLC settings — the opposite of what users need. `npx agentic-sdlc-wizard init` is already one command |
| 72 | ~~Cross-Model Review Standardization~~ DONE | Completed in v1.23.0 |
| 73 | ~~Release Planning Gate~~ DONE | Completed in v1.23.0 |
| 54 | ~~Prototype/Vibe Coding Mode~~ KILLED | Deleted — effort levels cover this |
| 56 | ~~Adversarial Review Prompting~~ DONE | Merged into #72 (v1.23.0) |
| 57 | ~~Context Position Audit~~ DONE | Completed in v1.23.0 |
| 58 | ~~Research: claw-code + OmO/OmX Harness Patterns~~ DONE | Studied claw-code (168K stars, Rust CC alternative), OmO (48K stars, 11-agent orchestration), OmX (16K stars, `$ralph`/`$team`). 16 candidate patterns identified (GreenContract, planning gate, planner/executor separation, bounded persistence loop, recovery recipes, etc). Codex certified 8/10 round 3. All candidates require Prove It Gate before adoption. Research doc: `RESEARCH_58_CLAW_OMO_OMX.md` |
| 59 | ~~CC Architecture Research~~ DONE | Completed in v1.23.0. Spawned #66-71 |
| 60 | ~~Research: Forge "Vocabulary Routing" + 10 Principles~~ DONE | Researched 2026-04-06. Forge (102 stars) has zero first-party benchmarks — all claims are unsourced synthesis. Vocabulary routing: independently tested (arxiv 2505.17037), does NOT significantly improve performance, diminishing returns past optimal specificity. 19-requirement accuracy drop: REAL (arxiv 2505.13360, GPT-4o drops to 85% at 19 combined requirements) but applies to competing format constraints on single outputs, not system-level behavioral guidelines like SKILL.md. "10 Principles" article series: doesn't exist. No action needed, but keep 19-requirement finding in mind for future SKILL.md pruning |
| 61 | ~~Research: Parity Audit Skill for Migrations~~ KILLED | No evidence users need this. Theoretical nice-to-have with no real demand signal. Prove It Gate: can't prove value without a user asking for it |
| 62 | ~~Research: Bidirectional Plugin Ecosystem Loop~~ DONE | Absorbed into #89 (Plugin Format) + #90 (Distribution Channels). Plugin format shipped, 6 distribution channels live, awesome-claude-skills PR #588 submitted. Bidirectional contribution = opening issues/PRs on Anthropic repos, not a roadmap item |
| 63 | ~~Evaluate: Batched Codex Release Review~~ KILLED | Per-PR review + release review checklist already covers it. No evidence of gap. The roadmap item itself says "may not be needed" — that's the answer |
| 65 | ~~Testing Diamond Boundary~~ DONE | Completed in v1.23.0 |
| 66 | ~~Convert to Plugin Format~~ Absorbed into #89 | Plugin format + marketplace submission combined into single item #89. Plugins now support hooks (updated finding from 2026-04-03 research) |
| 67 | Add Agent Team Hooks | DEFERRED — Agent Teams requires experimental feature flag (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Hooks would be inert for most users. Main session enforcement already covers subagent workflows (subagents do what the main session tells them). Revisit when Agent Teams exits experimental. Prove It Gate: can't prove value without GA feature |
| 68 | Hook `if` Conditionals | Use CC v2.1.85's `if` field to reduce false positives (e.g., skip TDD check when editing test files, skip on `--bare`). Cleaner than shell-script filtering. Spawned from #59 research |
| 69 | ~~Skill Frontmatter Docs~~ DONE | Completed in v1.23.0 |
| 70 | ~~`--bare` Docs~~ DONE | Completed in v1.23.0 |
| 71 | Monitor KAIROS/Coordinator Mode | Proactive always-on agent mode and multi-agent coordination. Wizard's enforcement model (hooks on tool calls) needs to scale to always-on monitoring. Track feature flags, prepare skill content for both contexts. Spawned from #59 research |
| 64 | ~~Update Notification Hook~~ DONE | Completed in v1.23.0 |
| 74 | ~~Research: Watercooler Index Articles~~ KILLED | Audited all 8 articles. Wizard already reflects 80%+ of Stefan's philosophies (Testing Diamond, anti-mocking, test-code-as-first-class, flaky-tests-are-bugs, CI shepherd). Can't audit yourself against yourself and find gaps — the wizard IS the Watercooler Index codified |
| 75 | ~~Research: Post-Mortem Frameworks~~ KILLED | "Every mistake becomes a rule" already works and is proven by catches data (54 catches, 5 P0s). Formalizing SBAR/5 Whys adds process overhead without evidence of value. Prove It Gate: can't prove SBAR would have caught something our existing system missed |
| 76 | ~~Research: Promptfoo as E2E Scoring Harness~~ DONE | Researched 2026-04-06. **NO-GO.** Promptfoo handles LLM-as-Judge rubrics and multi-trial but has zero statistical analysis (no CI calculation, no CUSUM, no score history). Would only replace evaluate.sh, not stats.sh — half the pipeline stays custom. Also: OpenAI acquired Promptfoo March 2026, Anthropic provider support becoming second-class. Key finding: our custom pipeline already independently implements Promptfoo's best patterns (deterministic-first scoring, binary YES/NO instead of 1-10, calibration examples per criterion). No action needed |
| 77 | ~~Research: Constrain-to-Playbook Prompt Pattern~~ DONE | Researched 2026-04-06. **NO-GO for our prompts.** Pattern is valid (Stanford 17-33% hallucination, binary checks reduce variance) but our PR reviewer already produces specific file:line findings with real P0/P1 bugs. Constraining to binary checks risks reducing recall on novel issues (e.g., `|| true` silent failures wouldn't match any checklist item). Cross-model review confirmed (Codex GPT-5.4 independently reached same NO-GO). Our cross-model review already uses verification_checklist (constrained). Our eval-criteria.sh already uses binary YES/NO with calibration examples (constrained). Only the PR review prompt is open-ended — and it works well that way |
| 78 | E2E Fixture: Firmware/Embedded Domain | Prove wizard handles non-web domains. New fixture: Python + shell SD card overlay with multi-device configs (`.cfg` files), hardware-coupled paths (`/sys/`, `/proc/cpuinfo`), no package manager, committed binaries. Scenario: add device support with appropriate test layers. Validates setup wizard detects firmware patterns and generates domain-adapted TESTING.md (SIL/HIL layers instead of web integration/E2E). Evidence: arkun (Discord) building firmware SDLC for Spruce, spruceOS has zero automated tests despite 12+ device variants and had a merge-revert-revert cycle on 2026-04-02. Reference: `spruceUI/spruceOS` |
| 79 | Domain-Adaptive Testing Diamond | Setup wizard currently generates web-focused testing layers. Add pattern detection for firmware (shell + `/sys/` paths + device configs → SIL/HIL layers), data science (notebooks + pipelines → data validation/model evaluation layers), and CLI tools (shell + no UI → integration-heavy). Generate domain-appropriate TESTING.md with correct testing layers per domain. Depends on #78 for firmware validation. Prove It Gate: must show setup wizard generates different TESTING.md for firmware fixture vs. web fixture |
| 80 | Research: SDLC Effectiveness Scoreboard | Track when each SDLC layer catches bugs/issues: self-review catches, cross-model review catches, CI catches, hook-enforced corrections, post-mortems that became rules. Append-only log (`.metrics/catches.jsonl`?) with category, severity, what caught it, what would have happened without it. Proves ROI ("caught 47 bugs before production"), shows which layers earn their keep, gives users their own scoreboard. Compare: spruceOS (zero SDLC, merge-revert-revert cycles) vs. this repo (systematic catches). Research: what metrics frameworks exist? DORA metrics overlap? Should this be per-repo or aggregated? Could the wizard recommend users track this? |
| 81 | ~~Research: Adversarial Multi-Agent Review Patterns~~ DONE | Absorbed into #72 (Cross-Model Review Standardization, v1.23.0). Researched multi-agent patterns (advocate/adversary/judicial, 5-agent parallel, sequential pipeline). Conclusion: single well-prompted pass with adversarial framing + verification checklist beats multi-agent decomposition at our complexity level. Multi-agent adds orchestration cost without proportional quality gain for code review. Legal domain (contracts, compliance) is where multi-agent shines — different problem structure |
| 82 | Research: Domain-Specific *DLC Variants — IN PROGRESS (Stefan) | Stefan working on this separately. Legal (LDLC), Firmware (FDLC), Research (RDLC), Content (CDLC). #79 (domain-adaptive testing diamond) already shipped firmware/data-science/CLI detection. This extends to domain-specific review checklists beyond just testing layers |
| 83 | Research: Local Model for Sensitive Data | bettercallclaude uses local Ollama for privilege-sensitive legal content (attorney-client privilege can't go to cloud APIs). Pattern: route sensitive operations to local model, non-sensitive to cloud. Would wizard users in legal/healthcare/finance benefit from a "sensitive data routing" recommendation? Setup wizard could detect `.env` patterns, HIPAA references, attorney-client markers and recommend local model fallback. Prove It Gate: is this a real need or theoretical? |
| 84 | ~~Research: Harness Development Life Cycle (HDLC)~~ DONE | Already implemented implicitly — this repo IS the HDLC. We dogfood the wizard on itself, have hook version checks (`instructions-loaded-check.sh`), template parity tests (`test-cli.sh`), review staleness checks, workflow audits (`test-self-update.sh`), and CI that tests CI. The Codex sandbox crash was caught and documented. Formalizing into a named framework adds no value beyond what we already do |
| 85 | Research: Automated CC Feature Discovery | When daily-update detects a new CC version, parse the changelog/release notes and flag features that could improve the SDLC (new tools, flags, slash commands like `/powerup`). Post as a GitHub issue tagged `feature-evaluation` with analysis of what changed and whether it's SDLC-relevant. Could also remind the user at session start: "CC v2.1.90 added X — run `/powerup` to learn about it." Not auto-incorporating — human reviews and decides. Fits under HDLC (#84): the harness should know when its own tools gain new capabilities |
| 86 | ~~Fix: E2E tdd_red Detection (Broken Since Day 1)~~ DONE | Root cause was NOT the scenario design — it was a format mismatch. `claude-code-action@v1` outputs SDK format `{type: "assistant", message: {role, content}}` but `check_tdd_red` expected raw API format `{role, content}`. The jq query never found tool_use blocks in real CI. Fix: added `.message` unwrapping in jq. 2 SDK-format regression tests. One-line fix in deterministic-checks.sh |
| 87 | ~~Research: Plugin/Marketplace Distribution~~ DONE | Researched 2026-04-03. Findings: Claude plugins now support hooks (outdated info said skills-only). 14 AI ecosystem channels audited, 21 classic package managers audited. Top channels: Claude Plugin (#89), awesome lists, curl script, Homebrew tap, gh CLI extension. Absorbed into #89 + #90 |
| 88 | ~~Autocompact Recommendation in Setup Wizard~~ DONE | Shipped in v1.33.0 via #182. CLI template sets `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=30` for 1M default. Wizard doc and /setup skill document the 75% fallback for 200K. 6 autocompact tests verify the gate |
| 89 | Claude Code Plugin Format + Marketplace Submission | Convert wizard to `.claude-plugin/plugin.json` structure. Skills → `skills/`, hooks → `hooks/hooks.json`, settings defaults. Submit to official Claude marketplace (claude.ai/settings/plugins/submit). Namespacing: `/sdlc-wizard:sdlc` vs `/sdlc`. Keep npx CLI as fallback. Absorbs #66 (Convert to Plugin Format) and #87 (marketplace research). Evidence: plugins now support hooks as first-class, confirmed 2026-04-03 |
| 90 | Distribution Channels Sprint | Multi-channel expansion beyond npm: (a) awesome-claude-code + awesome-claude-skills + SkillsMP submissions, (b) `install.sh` curl script, (c) Homebrew tap (`homebrew-sdlc-wizard` repo), (d) GitHub CLI extension (`gh-sdlc-wizard` repo, 30min), (e) GitHub Releases with CI automation, (f) Scoop bucket for Windows, (g) AUR package for Arch. Skip: Flatpak (rejects CLI), Snap (sandbox conflicts), .deb/.rpm (curl covers), pip/cargo/go (wrong ecosystem). Meta-tool: GH Actions release workflow auto-updates all channels on npm publish |
| 91 | Multi-Agent Adapter Layer | Skills (SKILL.md) port directly to any AI agent. Hooks need per-agent adaptation: Codex (notify config), Cursor (.cursorrules + marketplace), Windsurf (.windsurfrules), Aider (conventions). Strategy: adapter layers per agent, not forks. Cursor marketplace submission is medium priority (1-2 days). Codex plugin: Stefan building this weekend. Also consider: Continue.dev, Amazon Q, GitHub Copilot Workspace |
| 92 | Research: Rigorous Autocompact Benchmarking | Nobody has published controlled benchmarks testing different autocompact thresholds. Opportunity to be THE authority. Test: quality metrics (task completion accuracy, code correctness) at 50/60/70/75/80/83% thresholds across 200K and 1M models. Measure: pre/post compaction context preservation, cost per session, degradation curves. Low priority but high differentiation potential |
| 93 | ~~Node.js 20 EOL~~ DONE | Workflows already migrated to Node 24-native action versions: `actions/checkout@v5`, `actions/setup-node@v5`, `actions/upload-artifact@v6`. No `oven-sh/setup-bun` usage in repo. Verified by `tests/test-node24-compliance.sh` (13 tests, all green). Shipped pre-deadline (deadline was June 2, 2026) |
| 183 | Advisor Tool A/B — Light Tier Validation (supersedes #94 research) | **RESEARCH COMPLETE.** aistupidlevel.info independent benchmarks (7-axis, CUSUM, 95% CI) show: Opus 4.6=47/VOLA, Sonnet 4.6=37/DEGR, Codex GPT-5.3=27/DEGR. Degradation confirmed by Anthropic staff (Boris Cherny, GH #42796, 274 comments). Root causes: adaptive thinking under-allocation, medium effort default, "simplest approach" system prompt (v2.1.64). Gap is multi-turn/planning specific — SWE-bench (single-shot) looks fine. **Tiered model strategy decided:** Critical (Opus executor + Codex reviewer), Standard (Opus + optional Codex), Light (Sonnet executor + Opus advisor — advisor compensates for weaker executor), Vibe (Sonnet only). Advisor tool (`advisor-tool-2026-03-01`) is API-only beta, not in CC CLI yet. Opus-advising-Opus is waste — advisor only valuable when executor is weaker. **Next:** build A/B workflow to validate Light tier (Sonnet+advisor vs Opus) on our E2E, integrate aistupidlevel monitoring. Blog: `claude.com/blog/the-advisor-strategy` |
| 95 | Research: Nous Research Comparison | Evaluate `nousresearch.com` — what are they building, how does it compare to SDLC wizard's approach? Are they doing agent enforcement, testing methodology, or something orthogonal? Competitive analysis |
| 96 | ~~Audit: CC Degradation Detection~~ DONE (but benchmark is broken) | Degradation detection infra shipped (score persistence, CUSUM, wizard hardening). BUT: v1.32.0 cross-model audit proved the E2E benchmark has zero discriminating power — 2/10 NOT CERTIFIED. Both Opus 4.6 and 4.7 score 10/10. Fix needed: remove coaching from simulation prompt, add independent npm test verification, use real per-trial fresh runs, calibrate scenarios by difficulty. Until fixed, benchmark measures coached compliance not model quality |
| 97 | Research: Anthropic Policy & Research Alignment | Audit Anthropic's policy/research pages for SDLC relevance: (a) Responsible Scaling Policy (`anthropic.com/responsible-scaling-policy`) — does our enforcement model align with their safety levels? (b) Transparency reports (`anthropic.com/transparency`) — can we reference/align? (c) Constitution (`anthropic.com/constitution`) — SDLC as constitutional AI for dev process? (d) Economic Futures (`anthropic.com/economic-futures`) — positioning for AI-assisted development economy (e) Research page (`anthropic.com/research`) — any papers relevant to agent enforcement, tool use safety, or evaluation methodology. Goal: align wizard's philosophy with Anthropic's public positions where genuine overlap exists |
| 98 | ~~Audit: Community Feedback & Contribution Paths~~ DONE | PR #191. Added `.github/ISSUE_TEMPLATE/` (bug_report, feature_request, question) with GitHub-valid frontmatter + `config.yml` (blank issues disabled, contact links to Discussions + in-session `/feedback`). Added `.github/PULL_REQUEST_TEMPLATE.md` with Prove-It Gate checklist + test plan section. Enabled GitHub Discussions via `gh api ... -f has_discussions=true`. Added README "Feedback" section with live links to all three paths. `tests/test-community-paths.sh` — 14 tests, mutation-verified (deleting config.yml or stripping frontmatter `about:` trips CI loudly). Codex xhigh 2-round code review: 5/10 → 10/10 CERTIFIED |
| 99 | Research: AutoGPT Integration | Evaluate adding SDLC wizard (or ADLC variant) to AutoGPT ecosystem. Can our enforcement patterns translate to AutoGPT's agent framework? Is this an SDLC wizard port or an ADLC wizard use case? Assess: (a) AutoGPT's plugin/extension model, (b) hook equivalents, (c) community size and adoption potential, (d) whether this fits better as SDLC wizard adapter or a separate *DLC variant |
| 102 | ~~Cross-Document Consistency Enforcement~~ DONE | Removed hardcoded counts from README (workflows, criteria), CI_CD.md (CLI files), CODE_REVIEW_EXCEPTIONS (workflows). Fixed stale skill count in COMPETITIVE_AUDIT.md (2→4). `test-doc-consistency.sh` validates workflow/CLI-file/skill/scenario counts against filesystem, checks init.js ↔ disk parity. 10 tests |
| 175 | Research: CC System Prompt Analysis | Review `Piebald-AI/claude-code-system-prompts` for: (a) native coverage overlap — what CC already enforces so we don't reinvent it, (b) adoptable patterns — prompt engineering techniques, tool usage patterns, formatting conventions Anthropic uses internally, (c) change detection — if CC's system prompt shifts (like the degradation Boris confirmed), diffs would show it. Could inform both SDLC wizard (what to add vs what CC handles) and Codex adapter (what patterns translate). First check: is the repo actively maintained and how fresh are the prompts? If it tracks versions over time, that's gold for degradation detection (#96). If stale, limited value |
| 101 | Research: Official Claude Plugins Ecosystem | Evaluate official Claude plugins (`/plugin install frontend-design@claude-plugins-official` etc). Questions: (a) what official plugins exist and what do they do? (b) should SDLC wizard recommend complementary plugins in setup? (c) can we integrate with or reference official plugins? (d) does our plugin format align with the official plugin registry? (e) are there conflicts (e.g., a "code quality" official plugin that overlaps with our enforcement)? Goal: understand the official plugin ecosystem and position SDLC wizard correctly within it |

## Review Pipeline

### Now

- Keep local review loop as the default quality bar: Claude self-review first, then local Codex `xhigh` for independent cross-model review on substantial changes.
- Keep GitHub PR automation on the existing Claude review pipeline so SDLC checks continue to work.
- Pin the GitHub PR reviewer to `claude-opus-4-7` for maximum current Claude review quality.
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
- Make the PR review layer provider-swappable instead of coupling to a Claude-specific markdown format.
- Move toward a normalized review artifact or check-run parser so Claude and Codex can plug into the same automation.
- Revisit whether default review should be single-provider, dual-provider for labeled PRs, or manual Codex-only cross-review.

## Item 13.5: Live-Fire CI Job Audit

Every CI workflow/job must succeed at least once post-changes before distribution. Current gaps:

| Job/Trigger | Last Green | Gap | Action |
|---|---|---|---|
| `e2e-full-evaluation` (merge-ready label) | Mar 28 (PR #102) | Bug found: missing `git remote add origin` in Tier 2 init | VERIFIED — fix merged, 5-trial Tier 2 passed in 9m5s |
| `weekly-update.yml` schedule trigger | Mar 27 (manual dispatch) | Schedule trigger untested since label fix | VERIFIED — dispatch passed Mar 27 |
| `monthly-research.yml` schedule trigger | Mar 27 (manual dispatch) | Schedule trigger passed Mar 27 | VERIFIED — dispatch passed Mar 27 |
| Stale `ci-autofix.yml` (ID 232420762) | Never (dead workflow) | Orphaned after rename to ci-self-heal.yml | DONE — disabled Mar 28, ci-self-heal.yml deleted Mar 31 |
| Node.js 20 deprecation | N/A | `actions/checkout@v4` + `oven-sh/setup-bun` will be forced to Node 24 on June 2, 2026 | Moved to Next Release (#93) |

## Back Burner

- ~~Node.js 20 deprecation~~ → moved to Next Release as #93 (deadline approaching)
- Chaos/Resilience Testing (needs research — beyond mutation testing, think chaos monkey for repos. Inject faults, break things intentionally, see if SDLC catches them. Could be important for AI agent validation or general resilience. Research before committing)
- Agent-agnostic SDLC (generalize wizard beyond Claude Code — Codex CLI, other AI agents. Auto-detect domain from repo contents, generate domain-appropriate hooks/skills. Reference impl: anticheat repo Content SDLC with GRADE labels, multi-source consensus, 219 tests. NOT immediate — needs #28 consolidation first)
- Subagent Model Compliance Audit (transcript audit proved Explore agent uses Haiku 4.5 39% of the time despite CLAUDE_CODE_SUBAGENT_MODEL override. Fix: ANTHROPIC_DEFAULT_*_MODEL env vars. Verify fix next session. Consider: `sdlc-wizard audit` subcommand checking config health + model compliance. Research if users care before shipping)

## Monthly Research #84 Triage (March 2026)

| # | Recommendation | Verdict | Notes |
|---|---------------|---------|-------|
| 1 | Extended thinking for planning | Skip | Already covered: Recommended Effort Level section + `effort: high` frontmatter |
| 2 | Sub-agent TDD hooks | Absorb into #45 | `/agents` Subagent Exploration already covers this research |
| 3 | CLAUDE.md best practices | Done | #43 + #25 + setup wizard Step 8 CLAUDE.md generation |
| 4 | Onboarding realism | Done | #31 (blank repo) + #22 (setup wizard) + #25 (docs audit) |
| 5 | Adversarial review framing | Done | Cross-model review protocol IS adversarial framing |
| 6 | Vibe coding positioning | New #54 | Prototype mode — relaxed SDLC for rapid iteration |
| 7 | Prompt injection resistance | Skip | Out of scope — wizard is a dev process tool, not runtime security |
| 8 | Multi-agent SDLC docs | Absorb into #45 + Back Burner | Already tracked in agent-agnostic SDLC |
| 9 | Competitive audit updates | Done | #8 + weekly auto-scan covers this |

**Result:** 4 already done, 2 absorbed into existing items, 1 new unprioritized (#54), 2 skipped.
