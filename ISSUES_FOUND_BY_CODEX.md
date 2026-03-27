# Issues Found By Codex

> Audit log for Codex repo reviews.
>
> This file now contains two sections:
> - The current PR-local review for `fix/codex-main-audit`
> - The current deeper `main` audit pass (open findings, if any)
> - The historical `fix/codex-audit-findings` audit record (already fixed)

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
