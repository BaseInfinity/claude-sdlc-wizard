# Codex Audit Progress

Purpose: keep the repo-wide audit state explicit so future passes resume from the right place instead of starting over.

## Current Status

- Deep repo audit pass completed on `main` on 2026-03-27.
- Claim-verification / adversarial trust pass continued on `main` on 2026-03-27.
- Loop-closure / product-truth pass continued on `main` on 2026-03-27.
- Current open findings are tracked in `ISSUES_FOUND_BY_CODEX.md`.
- Repo is currently assessed at `B+`.
- This is not the final quality bar for the repo.
- Final score should only be revisited after the next claim-verification audit pass.

## What Has Already Been Audited

- GitHub Actions workflows
- Hook scripts
- Skills
- Shell test suite
- E2E scripts and scoring pipeline
- Repo-authored Markdown/docs
- PR review and self-heal pipeline
- Scoring-model documentation vs evaluator implementation

## Current Open Themes

- Observability trust:
  `score-history.jsonl` / `SCORE_TRENDS.md` do not yet fully support the repo's longitudinal measurement claims on `main`.
- Wizard onboarding proof:
  the repo strongly claims stack-aware bespoke setup, but the live CI/E2E path still validates generated assets in `tests/e2e/fixtures/test-repo` much more than it validates the wizard's actual setup flow across fixtures/stacks or rerun/idempotence behavior.
- Self-evolution loop closure:
  the repo now captures `friction-signal` issues, but the weekly/monthly improvement loops still do not prove they consume those issues.
- Competitive-watchlist accuracy:
  the watchlist is real, but docs/tests still blur weekly-vs-monthly behavior and give more confidence than the live wiring warrants.

## Next Audit Phase

Name: `Living-Proof / Loop-Closure Audit`

Goal:
- Verify that the wizard's setup/onboarding path is executable, rerunnable, and not just described.
- Verify that captured signals actually feed the loops they claim to improve.
- Tighten the remaining places where docs/tests overstate what the live paths prove.

## Required Method For Next Pass

1. Add or design true setup-path proof.
   For at least one greenfield fixture and one non-Node fixture:
   - run the wizard setup flow or a close simulation of it
   - verify generated hooks/skills/docs/settings
   - verify claimed auto-detection outputs map to fixture reality
   - rerun setup and verify additive / no-duplicate behavior

2. Audit product-truth claims explicitly.
   Focus on:
   - stack-aware onboarding
   - self-evolution from friction
   - longitudinal measurement / trends
   - prove-it / native-vs-custom posture

3. Prefer trust tests over more static checking.
   Examples:
   - fixture README says it tests onboarding -> a real test/workflow uses it
   - README claim maps to a current proving workflow/test
   - `friction-signal` capture maps to an actual consumer path, or gets narrowed
   - competitive-review docs/tests match the real weekly/monthly wiring

4. Re-score the repo only after the above pass reaches diminishing returns.

## Progress Estimate

- Roughly `75-80%` through the full repo-visible audit.
- High confidence on:
  - workflow correctness
  - PR review / self-heal mechanics
  - scoring docs vs evaluator
  - broad docs drift
  - competitor/comparison surface at a repo-structure level
- Remaining high-value frontier is narrower but deeper:
  - true setup-path proof
  - idempotence / rerun proof
  - friction-loop consumption
  - final trust-test cleanup on novel claims
- That remaining `20-25%` is where most of the A-range / "staff engineer respect" signal now lives.

## Stop Condition

The next pass should stop only when:
- new findings are mostly low-value wording nits, or
- remaining issues are already known and documented tradeoffs, or
- further checking would mostly duplicate existing proof without changing confidence.

## Notes For Future Codex Pass

- Treat this as a meta-repo audit, not a normal app-repo audit.
- Weight trust, proof, and repo-claim accuracy more heavily than cosmetic polish.
- Prefer consolidating related doc drift into one root-cause finding instead of logging dozens of tiny wording bugs.
- Keep `ISSUES_FOUND_BY_CODEX.md` as the findings ledger.
- Use this file as the pass-state / audit-process ledger.
