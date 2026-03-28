# Issues Found By Codex

> **Historical audit record.** This file captures what Codex found during its cross-model review on 2026-03-27. All findings listed below have been fixed on the `fix/codex-audit-findings` branch. This file is preserved as an audit trail — not a live issue tracker.

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
