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

## This Release (ordered)

| Priority | # | Item | Description |
|----------|---|------|-------------|
| 1 | 64 | Update Notification Hook | DONE — `instructions-loaded-check.sh` checks npm each session. 6 quality tests (fake npm, version comparison, failure modes). Non-blocking, graceful on network failure |
| 2 | 59 | Research: CC Architecture (Public Sources) | DONE — 7-topic deep research (hooks, skills, plugins, settings, upcoming features, Agent SDK, CLI). Key findings: 25 hook events (we use 3), plugin format is the official distribution path, KAIROS/Coordinator Mode coming, `--bare` bypasses wizard entirely. Spawned items #66-71 |
| 3 | 72 | Cross-Model Review Standardization | DONE — Audited 4 repos + external research (14 repos, 7 papers). Rewrote Cross-Model Review section: mission-first handoff (mission/success/failure fields), preflight self-review doc, verification checklist, adversarial framing ("assume bugs present" not "find N bugs"), domain template guidance (code default, adaptable for research/persuasion), convergence reduced to 2-3 rounds (research confirms >3 has <5% value). Anti-patterns documented. 6 quality tests |
| 4 | 73 | Release Planning Gate | DONE — Added as section in SDLC skill (not a separate skill — Prove It absorption check). Before implementing release items: list all, plan each at 95%, identify blocks, present all plans together, user approves batch. Prove It Gate strengthened with absorption check ("can this be a section in existing skill?"). 3 quality tests |
| 5 | 57 | Context Position Audit ("Lost in the Middle") | DONE — Moved "ALL TESTS MUST PASS" from line 369 (61% depth) to line 75 (11% depth) in SKILL.md. Scoring Rubric → Test Failure Recovery → Planning sections → Self-Review → Cross-Model Review → CI loops. 3 quality tests verify position |
| 6 | 56 | Adversarial Review Prompting | DONE — Merged into #72. Mission-first framing, adversarial posture, structured verification checklists, "find at least N" anti-pattern documented. Applied to both SKILL.md and wizard doc |
| 7 | 65 | Testing Diamond Boundary | DONE — Added explicit E2E (UI/browser ~5%) vs Integration (API/no UI ~90%) vs Unit (pure logic ~5%) boundary table to SKILL.md and strengthened wizard wording. 2 quality tests |
| 8 | 69 | Skill Frontmatter Docs | DONE — Expanded wizard "Skill Effort Frontmatter" section into "Skill Frontmatter Fields" with full table: `paths:`, `context: fork`, `effort:`, `disable-model-invocation:`, `argument-hint:`. 2 quality tests |
| 9 | 70 | `--bare` Docs | DONE — Added `--bare` documentation to SKILL.md Context Management section (complete wizard bypass warning). Wizard already had it in Other Notable Changes. 2 quality tests |

## Unprioritized

| # | Item | Description |
|---|------|-------------|
| 51 | Global Install Mode | Support `npm install -g` with a global template that auto-seeds new repos. Currently per-repo only (`npx agentic-sdlc-wizard init` in each repo). Research whether users want a global default config that gets applied automatically |
| 72 | Cross-Model Review Standardization | Audited 4 repos (sdlc-wizard, anticheat, tucson-investigation, states-project-research) + external research (14 repos, 7 papers). **Finding: protocol is universal, prompt is domain-specific.** Divergences: sdlc-wizard uses FIXED/DISPUTED/ACCEPTED response.json (only adopter), anticheat uses version-increment resubmit with preflight docs (proven to reduce findings to 0-1/round), tucson uses numbered fix lists with score tracking (4.6→9.8 over 14 rounds), states-project uses A-F letter grades with 254 regression tests. Missing from wizard: (1) mission-first framing (SUCCESS/FAILURE conditions), (2) specific verification checklists (not "review this"), (3) preflight self-review docs, (4) score tracking, (5) pluggable domain templates. External research confirms: decomposed criteria > monolithic prompt, binary/ternary verdicts > numeric scales, 2 rounds optimal (3 max), Devil's Advocate at 40% weight, xhigh reasoning always. Anticheat mission-first prompt breakthrough: Round 1 ("review this plan") = generic feedback. Round 3 ("THE MISSION: [context]. SUCCESS = [X]. FAILURE = [Y]") = reviewer read raw iMessages, verified claims against source material, found audience-psychology risks nobody caught |
| 73 | Release Planning Gate | New workflow pattern: before implementing any release items, create 95% confidence plans for ALL items and present together. User reviews all plans as a batch — catches issues, conflicts, and sequencing problems before any code is written. If effective, add to wizard as a release workflow section. Evidence: ad-hoc one-at-a-time implementation led to scope creep (ci-analyzer added without validation in v1.22.0). Batch planning would have caught the Prove It Gate violation before implementation |
| 54 | ~~Prototype/Vibe Coding Mode~~ KILLED | Effort levels (`high`/`max`) already cover this. Monthly research bot suggested it (#84) but it's unnecessary — just use lower effort or skip the wizard entirely for throwaway code. Deleted |
| 56 | Research: Adversarial Review Prompting | Deep-dive the "rubber-stamp review" problem (MAST FM-3.1). Research "find at least N problems" forcing technique from r/ClaudeAI 17-papers thread. Test whether adversarial framing improves our self-review and cross-model review quality. Validate with A/B comparison on real PRs. Cross-model review the findings |
| 57 | Research: Context Position Audit ("Lost in the Middle") | Liu et al. 2024 found >30% accuracy drop for info in middle of long context. Audit our CLAUDE.md, wizard doc, SDLC skill, and hook prompts — are critical instructions buried in the middle? Restructure if so. Validate with before/after E2E scores. Cross-model review |
| 58 | Research: OmO/OmX Harness Patterns | ~~Was: claw-code deep-dive. Redirected after research — claw-code is built from leaked CC source, IP contamination risk, avoid.~~ Instead study the legitimate adjacent tools: **oh-my-openagent (OmO, 46K stars)** — multi-model orchestration, provider-agnostic harness, anti-lock-in philosophy. **oh-my-codex (OmX, 8K stars)** — `$team` mode (parallel agent review, relevant to our N-reviewer pipeline), `$ralph` mode (persistent execution loops with architect verification, relevant to our CI shepherd). Also: LogicKor (Korean LLM benchmark) for evaluation methodology. Focus on patterns we can validate and adopt, not code we'd copy. Cross-model review findings |
| 59 | Research: Claude Code Architecture (Public Sources Only) | DONE — see This Release. 7-topic research: hooks (25 events, `if` conditionals, prompt/agent handler types), skills (paths, context:fork, effort frontmatter), plugins (official distribution, namespacing), settings (merge behavior, $schema), upcoming (KAIROS, Coordinator Mode, Agent Teams, ULTRAPLAN), Agent SDK (in-process MCP, --bare, --json-schema), CLI (60+ flags, permission modes). Spawned 6 new items (#66-71) |
| 60 | Research: Forge "Vocabulary Routing" + 10 Principles | Deep-dive `jdforsythe/forge` and the 10 Principles article series. Test the vocabulary routing claim (domain terminology > flattery in activating expert knowledge). Validate the "19 requirements = worse accuracy" claim against our skill/wizard doc size. The 45% threshold for multi-agent ROI — does it hold for our CI pipeline? Cross-model review |
| 61 | Research: Parity Audit Skill for Migrations | Evaluate subsystem gap analysis with coverage ratios as a potential `/migration` skill (pattern seen in multiple harness projects). Would users doing rewrites benefit from automated parity tracking? Is this a real gap or a theoretical nice-to-have? Prove It Gate applies |
| 62 | Research: Bidirectional Plugin Ecosystem Loop | Two-way contribution with Anthropic's `knowledge-work-plugins` ecosystem. Inbound: scan official plugins for patterns that outperform our approach (legal, engineering, etc.), adopt or recommend as complementary. Outbound: contribute our proven patterns (TDD enforcement, Prove It Gate, cross-model review) upstream. `/feedback` skill could route contributions both ways — to our repo AND to official plugin repos. Validate: does the `.claude-plugin` + `skills/` structure they use align with ours? What MCP connectors do they use that we don't? Cross-model review |
| 63 | Evaluate: Batched Codex Release Review | Currently cross-model review runs per-PR. Evaluate whether a batched release-level Codex review (all changes since last release) catches different issues than per-PR reviews. May not be needed — per-PR + release review checklist already covers it. Low priority until evidence suggests a gap |
| 65 | Testing Diamond Boundary Clarification | Wizard's diamond section says E2E = "Playwright/Cypress" and integration = "real DB/cache" but doesn't draw the explicit line: **E2E = tests through the user's actual UI/browser, Integration = tests real systems via API without UI**. Evidence: contract-review-kit install classified Copilot Chat API tests as E2E instead of integration because the boundary wasn't explicit. Small wording fix in wizard doc + SDLC skill |
| 66 | Convert to Plugin Format | Official CC distribution path. Create `.claude-plugin/plugin.json`, move skills to plugin structure, extract hooks to `hooks/hooks.json`. Namespacing trade-off: `/sdlc-wizard:sdlc` vs `/sdlc`. Keep CLI as fallback for non-plugin users. Spawned from #59 research |
| 67 | Add Agent Team Hooks | `TaskCreated`, `TaskCompleted`, `TeammateIdle` are purpose-built SDLC enforcement points for multi-agent workflows. Add to default hook config. Spawned from #59 research |
| 68 | Hook `if` Conditionals | Use CC v2.1.85's `if` field to reduce false positives (e.g., skip TDD check when editing test files, skip on `--bare`). Cleaner than shell-script filtering. Spawned from #59 research |
| 69 | Skill Frontmatter Improvements | Add `paths:` for auto-activation, `effort: high` default, `disable-model-invocation: true` on setup/update skills, `context: fork` for setup. Spawned from #59 research |
| 70 | Document `--bare` Incompatibility | `--bare` mode skips ALL hooks, skills, plugins, CLAUDE.md. Wizard is completely bypassed. Need explicit documentation and CI pipeline guidance. Spawned from #59 research |
| 71 | Monitor KAIROS/Coordinator Mode | Proactive always-on agent mode and multi-agent coordination. Wizard's enforcement model (hooks on tool calls) needs to scale to always-on monitoring. Track feature flags, prepare skill content for both contexts. Spawned from #59 research |
| 64 | Update Notification Hook | `instructions-loaded-check.sh` runs every session but doesn't check for updates. Add a quick `npm view agentic-sdlc-wizard version` check vs installed version in SDLC.md. One-liner: "SDLC Wizard update available: 1.21.0 → 1.22.0 (run /update-wizard)". Non-blocking, <1s overhead |
| 74 | Research: Watercooler Index Articles | Audit all ~8 articles from [softwareautomation.notion.site Watercooler Index](https://softwareautomation.notion.site/Watercooler-Index-1d88569bb6ed8081b90cdf77d71a364e). Stefan's answers are there alongside others. Extract patterns, testing philosophies, SDET insights, and automation opinions that can strengthen the SDLC wizard. Compare community answers against wizard's current guidance — where do we agree, where do we differ, what's missing? |
| 75 | Research: Post-Mortem Frameworks (SBAR, 5 Whys, Blameless) | Evaluate structured post-mortem frameworks for AI agent SDLC. SBAR (Situation, Background, Assessment, Recommendation) from healthcare — would it have caught our past incidents (PR #140 auto-merge, PR #145 skipped shepherd, ci-analyzer unvalidated addition)? Compare 5 Whys, blameless post-mortems, Google SRE retrospectives. Industry data: Gas Town/Refinery auto-merged despite failing tests (prod DB down 2 days), Replit agent deleted prod DB. Does formalizing post-mortems beyond "every mistake becomes a rule" add value? Prove It Gate applies |
| 76 | Research: Promptfoo as E2E Scoring Harness | Evaluate Promptfoo (19K stars, MIT, now OpenAI-owned) as replacement for our custom bash scoring pipeline (evaluate.sh, stats.sh). Its LLM-as-Judge rubric maps 1:1 to our 6 SDLC dimensions, composite formula maps to derived-metric, native multi-trial handles our 5-run comparison. Would replace weeks of custom Node.js with a promptfooconfig.yaml. Question: does it handle our SDP adjustment, CUSUM detection, and score-history.jsonl analytics? stats.sh stays as fallback. Also evaluate for wizard setup recommendation — could the auto wizard suggest Promptfoo to users who need scoring? Prove It Gate applies |
| 77 | Research: Constrain-to-Playbook Prompt Pattern | LegalOn CEO + Stanford hallucination study (17-33% in legal RAG): "check these 12 specific things" > "analyze this" for reducing variance and hallucination. We already do this in cross-model review (verification checklist = pattern-matching), but evaluate whether the pattern should be baked deeper into: (1) SDLC skill's self-review prompts, (2) CI review prompt templates, (3) wizard setup recommendations for users' own review workflows. Evidence from contract-review-kit: 2-line prompt change from open-ended to constrained reduced scoring variance. Could the auto wizard recommend this pattern when it detects review/analysis skills? |

## Review Pipeline

### Now

- Keep local review loop as the default quality bar: Claude self-review first, then local Codex `xhigh` for independent cross-model review on substantial changes.
- Keep GitHub PR automation on the existing Claude review pipeline so SDLC checks continue to work.
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
| Node.js 20 deprecation | N/A | `actions/checkout@v4` + `oven-sh/setup-bun` will be forced to Node 24 on June 2, 2026 | Back burner (revisit May 2026) |

## Back Burner

- Node.js 20 deprecation (June 2, 2026 deadline — `actions/checkout@v4` + `oven-sh/setup-bun` forced to Node 24. Not urgent yet but blocks all CI if ignored. Revisit May 2026)
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
