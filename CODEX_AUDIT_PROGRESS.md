# Codex Audit Progress

Purpose: keep the repo-wide audit state explicit so future passes resume from the right place instead of starting over.

## Current Status

- Deep repo audit pass completed on `main` on 2026-03-27.
- Claim-verification / adversarial trust pass continued on `main` on 2026-03-27.
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
  the repo strongly claims stack-aware bespoke setup, but the live CI/E2E path still validates generated assets in `tests/e2e/fixtures/test-repo` much more than it validates the wizard's actual setup flow across fixtures/stacks.
- Self-evolution proof:
  the repo clearly proves scheduled external update/research loops, but the "friction encountered" feedback loop is still narrative unless it becomes an explicit captured/tested mechanism.

## Next Audit Phase

Name: `Setup-Path / Product-Truth Audit`

Goal:
- Verify that the wizard's setup/onboarding path is executable, not just described.
- Verify that the repo's most novel product claims are backed by first-class proof or are narrowed to honest wording.
- Catch remaining places where repo narrative outruns what the live paths actually prove.

## Required Method For Next Pass

1. Add or design true setup-path proof.
   For at least one greenfield fixture and one non-Node fixture:
   - run the wizard setup flow or a close simulation of it
   - verify generated hooks/skills/docs/settings
   - verify claimed auto-detection outputs map to fixture reality

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
   - "friction" wording maps to an actual captured signal, or gets narrowed

4. Re-score the repo only after the above pass reaches diminishing returns.

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
