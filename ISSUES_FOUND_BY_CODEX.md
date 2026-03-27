# Issues Found By Codex

> Audit log for Codex repo reviews.
>
> This file now contains:
> - The PR-local review for `fix/codex-pass2-findings` (no findings; ready to merge)
> - The current deep `main` audit pass (open findings, if any)
> - The earlier `main` audit pass (already fixed)
> - The PR-local review for `fix/codex-main-audit` (already fixed and merged)
> - The historical `fix/codex-audit-findings` audit record (already fixed)

## Current deep main audit (pass 3, 2026-03-27)

Audit target: merged `main`

### Scope and verification

- Branch state reviewed after `git pull --ff-only origin main` -> already up to date
- Verification run during this pass:
  - `./tests/test-self-update.sh` -> passed (`19` passed, `0` failed)
  - `./tests/test-prove-it.sh` -> passed (`19` passed, `0` failed)
  - `./tests/test-workflow-triggers.sh` -> passed (`156` passed, `0` failed)
  - targeted grep across workflows/tests/docs for:
    - setup-fixture usage vs greenfield fixture usage
    - Step 0.4 / auto-scan coverage
    - friction-driven self-evolution evidence
- Manual review focused on:
  - whether the wizard's setup/onboarding claims are exercised by the live CI/E2E path
  - whether the repo's "self-evolving from friction" story is implemented as an audited capability or only described narratively
  - whether the previously logged observability trust gap is still present on `main`

### Findings

#### P2: the repo's strongest onboarding claim is still only partially proven

- Evidence:
  - The main landing page claims the wizard "auto-detects your stack ... and generates bespoke hooks + skills + docs": `README.md:41`
  - The wizard itself documents a large setup-time auto-scan across package managers, test frameworks, deployment targets, tool permissions, and design-system inputs: `CLAUDE_CODE_SDLC_WIZARD.md:1011-1143`
  - Multiple greenfield/cross-stack fixtures are explicitly described as setup-test assets:
    - `tests/e2e/fixtures/fresh-nextjs/README.md`
    - `tests/e2e/fixtures/fresh-python/README.md`
    - `tests/e2e/fixtures/go-api/README.md`
    - `tests/e2e/fixtures/python-fastapi/README.md`
    - `tests/e2e/fixtures/nextjs-typescript/README.md`
    - `tests/e2e/fixtures/mern-stack/README.md`
  - But the actual simulation/install path does not run the wizard setup flow. It copies already-generated repo artifacts into the canned `test-repo` fixture:
    - local harness: `tests/e2e/run-simulation.sh:49-75`
    - PR CI baseline/candidate install: `.github/workflows/ci.yml:221-229`, `.github/workflows/ci.yml:378-382`, `.github/workflows/ci.yml:931-934`, `.github/workflows/ci.yml:1098-1101`
    - weekly/monthly automation also target the same generated `tests/e2e/fixtures/test-repo`: `.github/workflows/weekly-update.yml:402-405`, `.github/workflows/weekly-update.yml:546-549`, `.github/workflows/monthly-research.yml:302-305`, `.github/workflows/monthly-research.yml:393-396`
  - I did not find workflow/test-harness references that actually execute onboarding against `fresh-nextjs`, `fresh-python`, `go-api`, `python-fastapi`, `nextjs-typescript`, or `mern-stack`; the automated paths all converge on `tests/e2e/fixtures/test-repo`.
- Why this matters:
  - For a normal repo this would be a nice-to-have. For this repo, "language-agnostic bespoke setup" is one of the headline promises.
  - The current CI proves the generated SDLC assets in one canned environment much better than it proves the wizard's ability to detect and generate the right setup for fresh projects across stacks.
- Impact:
  - The repo is stronger at validating "our generated SDLC assets behave correctly" than "the wizard can reliably onboard varied real projects."
  - The extra cross-stack fixtures currently look more like dormant intention than live proof.
- Recommended fix:
  - Add a true setup-path E2E lane that starts from at least one greenfield fixture and one non-Node fixture, runs the wizard setup flow, and verifies the generated files/permissions/docs.
  - If that is too expensive today, narrow the README/wizard wording so it does not imply this path is already proven in CI.

#### P3: the "self-evolving from friction" story is still more narrative than audited capability

- Evidence:
  - The main README presents a core capability as: "Claude proposes process improvements from friction it encounters": `README.md:52`
  - The wizard repeats the same idea:
    - `CLAUDE_CODE_SDLC_WIZARD.md:40`
    - `CLAUDE_CODE_SDLC_WIZARD.md:2528`
    - `CLAUDE_CODE_SDLC_WIZARD.md:3216`
  - The repo does have real self-evolution inputs, but they are external-signal driven:
    - weekly Claude Code release analysis + community scan: `README.md:91-95`, `CI_CD.md:132-158`
    - monthly deep research: `CI_CD.md:160-168`
  - I did not find workflow/test/hook code that captures, stores, or audits "friction encountered" as a first-class input. In repo search, `friction` appears in docs and roadmap language, not in the implementation surface that would make it a concrete capability.
- Why this matters:
  - "Self-evolving from friction" reads like a live feedback loop, not just a philosophy.
  - Right now the repo more clearly proves scheduled external research/update loops than it proves an internal friction-capture loop.
- Impact:
  - A reader can reasonably infer the system automatically learns from its own pain points, when today that improvement path appears to depend on humans noticing friction and encoding changes manually.
- Recommended fix:
  - Either add an explicit friction-capture mechanism (issue template, CI/self-heal summaries, periodic triage prompt, or similar) plus tests/documented outputs, or
  - narrow the wording so it clearly describes a human-in-the-loop practice rather than an already-audited automated capability.

### Revalidated prior open issue

- The pass-2 observability trust concern is still present on current `main`:
  - `tests/e2e/score-history.jsonl` still has `0` entries
  - `SCORE_TRENDS.md` is still a no-data report generated on `2026-02-11`
- That issue is already documented in the earlier pass-2 section below; this pass simply re-confirmed it on the current branch state.

### Verdict

- The repo continues to get stronger, but the remaining gaps are now concentrated in the exact places where this project is most novel:
  - bespoke wizard onboarding
  - self-evolution claims
  - longitudinal proof/observability
- These are no longer generic engineering bugs. They are product-truth gaps.

## PR-local review: `fix/codex-pass2-findings` (2026-03-27)

Audit target: `origin/main...fix/codex-pass2-findings` (PR #95)

### Scope and verification

- Branch state reviewed after `git pull origin fix/codex-pass2-findings` -> already up to date
- Changed surfaces reviewed:
  - `.github/workflows/ci.yml`
  - `tests/test-workflow-triggers.sh`
  - `README.md`
  - `CI_CD.md`
  - `CONTRIBUTING.md`
  - `SCORE_TRENDS.md`
- Verification run during this pass:
  - `./tests/test-workflow-triggers.sh` -> passed (`156` passed, `0` failed)
  - `./tests/test-score-analytics.sh` -> passed (`12` passed, `0` failed)
  - `actionlint -shellcheck=` -> clean
  - `git diff --check origin/main...HEAD` -> clean
  - targeted stale-claim grep across docs/workflow -> clean

### Findings

No findings on this branch.

### What this branch closes

- `ci.yml` now uses read-only workflow-level permissions, with write scope moved to the jobs that actually need it.
- `SCORE_TRENDS.md` is generated before commit and staged together with `tests/e2e/score-history.jsonl` in both Tier 1 and Tier 2 paths.
- `README.md`, `CI_CD.md`, and `CONTRIBUTING.md` are aligned with the live evaluator and current workflow behavior.
- Regression coverage was expanded so the pass-2 fixes are no longer just doc edits; they are guarded by tests.

### Residual rollout note

- `tests/e2e/score-history.jsonl` is still empty on this branch today, so the observability story will only look "lived in" after future PR E2E runs populate history and those updates merge back to `main`.
- That is a rollout/state note, not a merge-blocking defect in this PR.

### Verdict

- Merge-ready.
- After merge, the next Codex pass should return to `main` and continue the claim-verification / adversarial E2E audit described in `CODEX_AUDIT_PROGRESS.md`.

## Current deep main audit (pass 2, 2026-03-27)

Audit target: merged `main`

### Scope and verification

- Branch state reviewed after `git pull --ff-only origin main` -> already up to date
- Verification run during this pass:
  - full local shell suite across `tests/test-*.sh` and `tests/e2e/test-*.sh` -> passed
  - `./tests/test-workflow-triggers.sh` -> passed (`145` passed, `0` failed)
  - `./tests/test-hooks.sh` -> passed
  - `actionlint -shellcheck=` -> clean
  - `shellcheck -x -S warning $(rg --files -g '*.sh')` -> warnings only; manually reviewed for high-signal bugs
  - repo-authored Markdown local-link/anchor scan (excluding vendored `node_modules`) -> clean
- Additional manual review focused on:
  - workflow permissions and trust boundaries
  - score observability artifacts (`score-history.jsonl`, `SCORE_TRENDS.md`)
  - repo-authored docs that describe CI/measurement behavior
- Confidence is high for the workflow/docs findings below.
- Confidence is lower only for hosted-runner behavior that depends on GitHub settings outside the repo.

### Findings

#### P2: repo-level score observability on `main` is not currently trustworthy

- Evidence:
  - The repo presents longitudinal self-measurement as a core capability:
    - `README.md:3` says it "Measures itself getting better over time."
    - `README.md:14-16` says SDP/CUSUM catch drift.
    - `README.md:47-50` advertises E2E scoring and CUSUM drift detection.
    - `CI_CD.md:59` says per-criterion CUSUM tracks drift over time.
  - The tracked history file on `main` is currently empty: `tests/e2e/score-history.jsonl`
  - `ci.yml` only commits score history back to the PR branch:
    - Tier 1: `ci.yml:574-596`
    - Tier 2: `ci.yml:1298-1310`
  - `SCORE_TRENDS.md:3-10` is stale and still claims it is "Updated after each CI E2E run."
  - The workflow generates `SCORE_TRENDS.md` only after the commit/push step and never stages or pushes it:
    - Tier 1 generation: `ci.yml:598-605`
    - Tier 2 generation: `ci.yml:1312-1318`
  - The current workflow regression test only checks that `score-history.jsonl` is committed somewhere, not that the tracked observability artifacts on `main` stay current: `tests/test-workflow-triggers.sh:1561-1566`
- Why this matters:
  - The repo's "measure itself over time" story is one of its main differentiators.
  - Right now, the canonical branch does not provide trustworthy historical score data or a trustworthy trends report.
  - This is a quality/trust issue, not just a cosmetic doc mismatch.
- Impact:
  - CUSUM and trend reporting on `main` are materially weaker than the repo narrative suggests.
  - Readers can believe the observability layer is live and current when the tracked artifacts are stale or empty.
- Recommended fix:
  - Make one canonical persistence path for observability data on `main`:
    - either commit both `tests/e2e/score-history.jsonl` and `SCORE_TRENDS.md` in the same update path, or
    - move trends/history to a dedicated artifact/branch/data store and stop implying the tracked files are always current.
  - Add a regression test for `SCORE_TRENDS.md` freshness/persistence, not just score-history commit presence.
  - If persistence intentionally depends on merge strategy, document that limitation explicitly.

#### P2: scoring docs are no longer fully synchronized with the actual evaluator

- Evidence:
  - `README.md:107-117` says:
    - `TDD GREEN | 2 | Deterministic`
    - `60% deterministic + 40% AI-judged`
  - The actual evaluator and supporting docs say otherwise:
    - deterministic scoring is `task_tracking` (1), `confidence` (1), and `tdd_red` (2): `tests/e2e/lib/deterministic-checks.sh:10-14`
    - LLM-scored criteria include `plan_mode_outline`, `plan_mode_tool`, `tdd_green_ran`, `tdd_green_pass`, `self_review`, and `clean_code`: `tests/e2e/lib/eval-criteria.sh:39-50`
    - `CONTRIBUTING.md:41-54` already documents `tdd_green_ran` and `tdd_green_pass` as AI-judged
  - `CONTRIBUTING.md` also has smaller criterion-definition drift:
    - `task_tracking` says `TaskCreate/TaskUpdate usage`, but the deterministic check is `TodoWrite|TaskCreate`: `CONTRIBUTING.md:45`, `tests/e2e/lib/deterministic-checks.sh:19-27`
    - `plan_mode_tool` says `EnterPlanMode or plan file used`, but the live criterion also counts `TodoWrite`/`TaskCreate` as structured planning: `CONTRIBUTING.md:48`, `tests/e2e/lib/eval-criteria.sh:140-147`
- Why this matters:
  - The scoring model is one of the repo's main "why this is rigorous" claims.
  - Stale scoring docs are more damaging here than they would be in an ordinary app README because readers use them to understand what the CI score actually means.
- Impact:
  - Readers get the wrong mental model of what is objective vs AI-judged.
  - The docs currently understate how much of the score depends on the LLM judge and overstate/understate a few specific criteria.
- Recommended fix:
  - Align the README and CONTRIBUTING scoring descriptions with the live evaluator.
  - If grouped summaries are kept, make them mechanically traceable to the underlying criterion definitions or simplify them to a narrative that cannot drift as easily.
  - Specifically fix the `TDD GREEN` type, the deterministic/AI-judge split, `task_tracking`, and `plan_mode_tool` descriptions.

#### P2: `ci.yml` still grants workflow-level write permissions while `validate` executes PR-controlled scripts

- Evidence:
  - `ci.yml:14-16` grants `contents: write` and `pull-requests: write` at workflow scope.
  - The `validate` job immediately checks out the repo and runs shell scripts from the PR branch:
    - checkout: `ci.yml:19-23`
    - test execution starts at `ci.yml:69` and continues through `ci.yml:136`
  - The write-capable behavior is only needed later for comment/push paths, not for the validation job itself.
- Why this matters:
  - This repo is unusually careful elsewhere about CI safety and prompt/tool restrictions.
  - Leaving write permissions available to the earliest PR-controlled execution path is one of the few remaining least-privilege gaps.
- Impact:
  - Broader-than-necessary token scope during validation.
  - Harder security review posture for a repo that is explicitly selling rigor and CI discipline.
- Recommended fix:
  - Reduce the workflow default to read-only permissions.
  - Grant write permissions at job scope only to jobs that actually need them (PR comments, score-history persistence, etc.).
  - If broad workflow-level permissions are intentionally accepted, document that tradeoff in `CODE_REVIEW_EXCEPTIONS.md`.

#### P3: `CI_CD.md` still has summary-level contradictions about what `ci.yml` does

- Evidence:
  - `CI_CD.md:32` says Tier 1 evaluates "candidate score + SDP scoring + token metrics"
  - The same doc later says token tracking was removed because `claude-code-action@v1` does not expose usage fields: `CI_CD.md:120-124`
  - The workflow overview table says `ci.yml` on "PR, push to main" does "Validation, tests, E2E evaluation": `CI_CD.md:5-11`
  - The same doc later says push to main is "validation only": `CI_CD.md:126-129`
- Why this matters:
  - These are top-of-doc summary statements that shape the reader's first mental model.
  - The repo already did the harder work to fix the underlying implementation; leaving contradictory summaries behind is a pure trust leak.
- Impact:
  - Minor documentation trust leak.
- Recommended fix:
  - Remove "token metrics" from the Tier 1 flow summary until the action exposes usage data again.
  - Make the overview table explicitly match the actual trigger behavior: PRs get E2E, push-to-main is validation-only.

### Positive checks

- Full local shell suite passed on merged `main`.
- `actionlint -shellcheck=` is clean.
- Repo-authored Markdown local links and anchors are intact.
- The earlier workflow correctness fixes (checkout ref, concurrency, stale cadence cleanup, `act` cleanup, permission cleanup for `id-token`) are present on `main`.
- `shellcheck` warnings were reviewed; they looked like low-value robustness/style issues rather than additional repo-level bugs.

### Verdict

- This repo is in much better shape than the earlier audit rounds.
- It is not yet at a clean "nothing substantial left to say" state because the observability layer on `main` still does not fully match the repo's own claims, and CI permission scope can still be tightened.
- After those are fixed, another pass should be much closer to sign-off quality.

## PR-local review: `fix/codex-main-audit` (2026-03-27)

Audit target: `origin/main...fix/codex-main-audit` (PR #94)

### Scope and verification

- Branch state reviewed after `git pull --ff-only origin fix/codex-main-audit`
- Changed surfaces reviewed: workflow YAML, hook guidance, regression tests, audit log updates, and affected docs
- Verification run during this pass:
  - `./tests/test-workflow-triggers.sh` -> failed (`Passed: 144`, `Failed: 1`)
  - `./tests/test-hooks.sh` -> passed
  - `actionlint -shellcheck=` -> clean
  - `git diff --check origin/main...HEAD` -> clean

### Findings

#### P1: FIXED — this branch changes doc counts from 23 to 22, but CI still runs 23 test scripts

- Evidence:
  - `COMPETITIVE_AUDIT.md:27` now says `Comprehensive automated tests across 22 scripts.`
  - `CONTRIBUTING.md:10` now says `Run tests (all 22 scripts that CI validate runs):`
  - The `validate` job in `.github/workflows/ci.yml` still executes 23 `./tests/...` commands.
  - The repo's own regression suite catches this immediately:
    - `tests/test-workflow-triggers.sh` fails with `COMPETITIVE_AUDIT.md has stale test script count (expected 23)`
- Why this matters:
  - This is not just wording drift; the branch is currently failing a repo validation test.
  - The exact-number cleanup is directionally reasonable, but changing two docs to the wrong number makes the branch non-green.
- Impact:
  - PR #94 is not merge-ready as-is.
  - The audit log would become misleading again if this lands without correction.
- Recommended fix:
  - Either change both docs back to `23`, or make them resilient/non-brittle while keeping `tests/test-workflow-triggers.sh` aligned with the chosen wording.
  - If the repo wants to stop hard-coding script counts, update the test accordingly rather than only editing the docs.

### Verdict

- Not merge-ready yet.
- After this count mismatch is fixed and the workflow-trigger suite is green again, this branch looks ready to merge.

## Current main audit (2026-03-27)

Audit target: merged `main`

### Scope and verification

- Repo surfaces manually reviewed: workflows, hooks, skills, prompts, shell tests, E2E scripts/libs, and repo-authored Markdown docs.
- Verification run during this pass:
  - `git pull --ff-only origin main` -> up to date on merged `main`
  - full local shell suite across `tests/test-*.sh` and `tests/e2e/test-*.sh` -> passed
  - `actionlint -shellcheck=` -> clean
  - `shellcheck -x -S warning` across repo shell scripts -> only low-signal warnings beyond the findings below
  - Markdown local-link scan (repo-authored docs only, excluding vendored `node_modules`) -> no broken local links
  - Markdown anchor scan (repo-authored docs only, excluding vendored `node_modules`) -> no broken internal anchors
- Confidence is high for source/docs consistency issues and workflow hygiene findings that are visible from the repo.
- Confidence is lower for behavior that depends on live GitHub hosted-runner semantics or external action implementation details.

### Findings (all fixed)

#### P2: `pr-review.yml` still assumes a single `claude-code-action` output shape — FIXED

- Evidence:
  - `pr-review.yml:286-308` extracts review text with `jq -r '.result // .output // ...'`
  - Other workflows already treat `claude-execution-output.json` as shape-variable and include array/object fallback handling:
    - `weekly-update.yml` extraction steps
    - `monthly-research.yml` extraction steps
- Why this matters:
  - This repo already learned the hard way that `claude-code-action` output is not stable enough to assume one schema.
  - PR review is still using the fragile path, so a schema variation can silently downgrade review comments to "no content captured" instead of posting the real review.
- Impact:
  - Silent loss of the repo's primary PR-review output.
  - Hard to diagnose because the workflow itself can still appear green.
- Recommended fix:
  - Reuse the same array/object extraction pattern already used in `weekly-update.yml` and `monthly-research.yml`.
  - Add a regression test in `tests/test-workflow-triggers.sh` specifically for PR review extraction logic, not just the update/research workflows.

#### P2: the repo hook still tells users to test workflows with `act`, contradicting current repo policy — FIXED

- Evidence:
  - `.claude/hooks/tdd-pretool-check.sh:15-17` tells users: `Test with: act workflow_dispatch --secret-file .env.test`
  - Repo docs and the wizard now say the opposite:
    - `TESTING.md:192`
    - `CI_CD.md:266`
    - `CLAUDE_CODE_SDLC_WIZARD.md:2660-2666`
- Why this matters:
  - Hooks are operational guidance, not passive docs.
  - A contradictory hook message is more likely to be followed in the moment than a doc paragraph, especially during workflow edits.
- Impact:
  - Sends contributors toward an unsupported local workflow-testing path.
  - Reintroduces the same confusion the earlier doc audit already cleaned up elsewhere.
- Recommended fix:
  - Replace the `act` message with the supported path: YAML validation + `./tests/test-workflow-triggers.sh`.
  - Add an explicit test so hook guidance stays aligned with `TESTING.md` and `CI_CD.md`.

#### P2: workflow permissions are still broader than necessary, including unused `id-token: write` on every workflow — FIXED

- Evidence:
  - `ci.yml:14-17`
  - `weekly-update.yml:8-12`
  - `monthly-research.yml:8-12`
  - `pr-review.yml:16-19`
  - `ci-self-heal.yml:9-14`
  - No repo workflow references OIDC consumers or token-request env vars.
- Why this matters:
  - This repo is automation-heavy and frequently runs with write-capable tokens.
  - Unused `id-token: write` and workflow-level broad permissions widen blast radius without providing value.
- Impact:
  - Unnecessary privilege exposure across all jobs.
  - Harder future security review because least-privilege intent is unclear.
- Recommended fix:
  - Drop `id-token: write` unless a workflow actually uses OIDC.
  - Move write permissions down to job scope where possible so validation-only jobs stay read-only.

#### P2: third-party GitHub Actions are pinned only to mutable major tags, not immutable SHAs — DOCUMENTED

- Evidence:
  - Representative examples:
    - `ci.yml` uses `int128/hide-comment-action@v1`, `anthropics/claude-code-action@v1`, `marocchino/sticky-pull-request-comment@v2`
    - `weekly-update.yml` uses `peter-evans/create-pull-request@v7` and `anthropics/claude-code-action@v1`
    - `ci-self-heal.yml` uses `actions/create-github-app-token@v1` and `anthropics/claude-code-action@v1`
- Why this matters:
  - These workflows have write-capable permissions and can push, comment, create PRs, or rerun CI.
  - Mutable tags are a supply-chain trust tradeoff; for a repo that emphasizes rigor and CI integrity, SHA pinning is the safer default.
- Impact:
  - Third-party action updates can change behavior without a repo diff.
  - Harder provenance/reproducibility for audit and incident response.
- Recommended fix:
  - Pin third-party actions to commit SHAs and document update cadence.
  - If tag pinning is an intentional tradeoff, record it in `CODE_REVIEW_EXCEPTIONS.md`.

#### P3: `ci-self-heal.yml` re-dispatches CI even when no autofix commit was created — FIXED

- Evidence:
  - `ci-self-heal.yml:315-316` sets `committed=false` when no changes were found
  - `ci-self-heal.yml:342-355` still dispatches `ci.yml` for the PAT/GITHUB_TOKEN path without checking `steps.commit.outputs.committed == 'true'`
- Why this matters:
  - No-change runs do not need a fresh CI dispatch.
  - This adds workflow noise precisely in cases where the autofix loop already failed to make progress.
- Impact:
  - Wasted CI runs.
  - Extra PR noise and a muddier audit trail on "no fix produced" cases.
- Recommended fix:
  - Gate the dispatch step on `steps.commit.outputs.committed == 'true'`.

#### P3: a few docs still have trust-eroding accuracy drift on `main` — FIXED

- Evidence:
  - `README.md:173` still claims `354+ automated tests`
  - `COMPETITIVE_AUDIT.md:27` claims `490+ automated tests across 23 scripts`
  - `CONTRIBUTING.md:10` says CI validate runs `23 scripts`
  - `ARCHITECTURE.md:188-190` lists `.claude/settings.local.json` in the repo file tree even though it is ignored local state, not a tracked repo file
- Why this matters:
  - This repo sells discipline and accuracy.
  - Small trust leaks in summary docs matter more here than they would in a normal app repo.
- Impact:
  - Readers get conflicting signals about current repo state.
  - Makes it harder to tell which docs are operationally current versus illustrative.
- Recommended fix:
  - Replace brittle exact-count marketing text in `README.md` with a resilient claim or compute it from the current suite.
  - Clarify that `settings.local.json` is local-only/ignored, or remove it from the tracked file-tree diagram.

### Positive checks

- Full local shell suite passed on merged `main`.
- `actionlint -shellcheck=` is clean.
- Repo-authored Markdown local links are intact.
- Repo-authored Markdown anchors are intact.
- Earlier branch-level workflow correctness fixes are present on `main`.

### Lower-priority observations

- `shellcheck -x -S warning` still reports several low-signal script warnings (unused variables, non-constant `source`, style nits), but they looked lower value than the issues above.
- The repo has good structural tests around workflow triggers, but deeper regression coverage is still uneven for hook guidance and PR-review output extraction.

### Recommended fix order

1. Harden `pr-review.yml` output extraction and add a regression test.
2. Fix the `act` contradiction in `.claude/hooks/tdd-pretool-check.sh`.
3. Reduce workflow permissions, starting with unused `id-token: write`.
4. Decide whether to pin third-party actions to SHAs or explicitly document the tag-based tradeoff.
5. Gate CI redispatch on successful autofix commits only.
6. Clean up the remaining README/ARCHITECTURE drift.

---

## Historical branch audit (already fixed)

> **Historical audit record.** This section captures what Codex found during its cross-model review on 2026-03-27 for `fix/codex-audit-findings`. All findings in this historical section were fixed on that branch and later merged.

Audit date: 2026-03-27

## Scope and confidence

- Repo shape audited: workflow YAML, hooks, skills, shell tests, E2E fixtures/scenarios, and repo-authored Markdown docs.
- Verification run during audit:
  - full local shell suite across `tests/test-*.sh` and `tests/e2e/test-*.sh` -> passed
  - `actionlint -shellcheck=` -> clean
  - Markdown local-link scan -> no missing local targets
  - Markdown anchor scan -> no broken internal anchors
- Confidence is high for source/docs consistency issues.
- Confidence is lower for anything that depends on live GitHub repo settings or hosted-action behavior not visible from source.

## Fix status

All findings below have been addressed:

| Round | Findings | Fixed in |
|-------|----------|----------|
| Round 1 (7 findings) | P1: PR review checkout, concurrency, head.ref injection. P2: trivial PR detection, CI wait, self-heal docs. P3: testing guidance. | Commit `fe6f8d8` |
| Round 2 (5 findings) | P1: README raw URL. P2: daily cadence, autofix template distinction, act contradiction. P3: stale counts. | Commit `9cc28a4` |
| Round 3 (1 finding) | P2: README summary still said "Daily/weekly/monthly". | This commit |

## Executive summary

- No open P0 findings reproduced on the current branch.
- No current GitHub Actions structural lint errors after workflow fixes.
- Documentation accuracy was the primary audit gap — all identified inconsistencies have been fixed.

## Findings (all fixed)

### P1: `README.md` points users at the wrong raw install URL — FIXED

- Evidence:
  - `README.md:86-89` tells users to fetch `https://raw.githubusercontent.com/BaseInfinity/sdlc-wizard/main/CLAUDE_CODE_SDLC_WIZARD.md`
  - The repo remote is `BaseInfinity/agentic-ai-sdlc-wizard`
  - `CLAUDE_CODE_SDLC_WIZARD.md:2922-2923` uses the `BaseInfinity/agentic-ai-sdlc-wizard` slug
- Why this matters:
  - This is the first real installation path in the repo README.
  - A wrong raw URL is a first-impression failure and can send users to the wrong resource immediately.
- Impact:
  - Broken or misleading installation guidance right at the repo entry point.
- Recommended fix:
  - Make the README raw URL match the canonical repo slug used everywhere else.
  - Consider centralizing the canonical raw URLs in one place so README and wizard docs cannot drift.

### P2: user-facing docs still promise a daily auto-update cadence that no longer exists — FIXED

- Evidence:
  - `README.md:10-12` says "Daily/weekly/monthly workflows"
  - `README.md:95-99` lists a daily Claude Code release PR cadence
  - `CLAUDE.md:58-61` says "Daily workflow checks Claude Code releases"
  - `CLAUDE_CODE_SDLC_WIZARD.md:94-98` says "Daily workflow tests new Claude Code versions"
  - Actual scheduled workflows are `weekly-update.yml` (`.github/workflows/weekly-update.yml:3-6`) and `monthly-research.yml` (`.github/workflows/monthly-research.yml:3-6`)
- Why this matters:
  - Readers will form expectations about freshness, API spend, and how quickly the system adapts.
  - The repo already consolidated daily/weekly behavior into a weekly workflow; the docs should reflect that plainly.
- Impact:
  - Incorrect mental model for update cadence and cost.
  - Makes the repo look less maintained because core narrative docs disagree with the actual automation.
- Recommended fix:
  - Standardize the story everywhere: weekly release/community scan, monthly deep research.
  - Only mention the old daily flow in historical docs like the changelog or clearly labeled retrospective notes.

### P2: the repo documents two different autofix/review systems as if they are the same current default — FIXED

- Evidence:
  - Current repo docs and workflow use `ci-self-heal.yml` with `AUTOFIX_LEVEL: all-findings`:
    - `.github/workflows/ci-self-heal.yml:16-18`
    - `CI_CD.md:208-214`
  - The main wizard doc still instructs users to create `ci-autofix.yml` and says the default is `criticals`:
    - `CLAUDE_CODE_SDLC_WIZARD.md:989-997`
    - `CLAUDE_CODE_SDLC_WIZARD.md:2717-2750`
- Why this matters:
  - `CLAUDE_CODE_SDLC_WIZARD.md` is the product users copy.
  - Right now the repo-level docs and the install/setup doc describe materially different canonical names and default behaviors.
- Impact:
  - Contributors and users can no longer tell which behavior is the intended default:
    - `ci-self-heal.yml` vs `ci-autofix.yml`
    - `all-findings` vs `criticals`
  - This weakens trust in the automation and makes future audits harder because "expected behavior" is ambiguous.
- Recommended fix:
  - Decide what the canonical public default is.
  - If the repo intentionally runs a more aggressive dogfood config than the distributed template, say that explicitly.
  - Otherwise, align the wizard doc with the repo’s current canonical workflow name and default autofix level.

### P2: workflow local-testing guidance is still internally inconsistent — FIXED

- Evidence:
  - `TESTING.md:190-204` says workflows cannot be tested locally with `act`
  - `CI_CD.md:264-270` says the same
  - `CLAUDE_CODE_SDLC_WIZARD.md:2655-2670` still recommends using `act` locally to test new workflows before merge
- Why this matters:
  - This repo is agent-facing and process-heavy. Humans and agents both rely on these docs operationally.
  - Conflicting guidance about `act` means readers do not know whether workflow validation should be source-level only or runner-level local emulation.
- Impact:
  - Wrong local verification path.
  - More wasted time during workflow debugging.
- Recommended fix:
  - Pick one official position and state scope clearly.
  - Example: "`act` may help for lightweight YAML sanity checks, but this repo does not treat it as a supported or reliable workflow test environment."

### P3: some reference/count docs are stale enough to chip away at trust — FIXED

- Evidence:
  - `COMPETITIVE_AUDIT.md:27` still says "354+ automated tests across 21 scripts"
  - Current CI validate surface and contributor docs are broader:
    - `.github/workflows/ci.yml:70-137`
    - `CONTRIBUTING.md:10-26`
  - `plans/AUTO_SELF_UPDATE.md:47-49` still describes "daily/weekly/monthly" auto-workflows in a current-tense summary section
- Why this matters:
  - These are not catastrophic inaccuracies, but they accumulate.
  - This repo sells rigor. Brittle counts and stale summaries undercut that message.
- Impact:
  - Readers start second-guessing whether numbers and claims elsewhere are current.
- Recommended fix:
  - Prefer resilient wording over brittle counts when possible.
  - Where counts matter, derive them from the current CI/test surface before publishing them.
  - Mark historical plan sections more clearly when they intentionally describe past architecture.

## Positive checks

- No broken local Markdown links found in repo-authored docs.
- No broken Markdown heading anchors found in repo-authored docs.
- `actionlint -shellcheck=` is clean on the current workflow set.
- Full local shell test suite passed on the current branch state.

## Lower-priority observations

- `tests/e2e/lib/json-utils.sh` still emits locale warnings during local test runs. Low severity, but it makes logs noisier than they need to be.
- `shellcheck` still reports a large amount of style/info noise across scripts and workflow `run:` blocks. Most of it did not look like the best use of cleanup time compared with the docs issues above.

## Recommended fix order

1. Fix the broken README raw URL.
2. Standardize the update-cadence story across README, CLAUDE.md, and the wizard doc.
3. Decide and document the canonical autofix workflow name/default behavior.
4. Resolve the `act` contradiction between the wizard doc and the testing/CI docs.
5. Clean up stale counts and current-tense summaries in secondary docs.

## Audit artifacts

- Local tests run: all `tests/test-*.sh` and `tests/e2e/test-*.sh`
- Workflow lint run: `actionlint -shellcheck=`
- Markdown checks:
  - local target existence scan
  - internal anchor existence scan
