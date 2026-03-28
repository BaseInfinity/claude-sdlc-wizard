# Codex Audit Progress

Purpose: keep the repo-wide audit state explicit so future passes resume from the right place instead of starting over.

## Current Status

- Deep repo audit passes 1-5 completed on `main` on 2026-03-27.
- Pass 5 extended coverage into evaluator failure semantics, CUSUM/schema alignment, and the local/manual E2E runner path.
- Pass 5 found new open issues:
  - evaluator false-green behavior when all LLM-judged criteria fail
  - CUSUM drift logic/tests still targeting an obsolete JSONL schema
  - `run-simulation.sh` full path operating in the wrong working tree while docs/tests only prove validation mode
- Current open findings are tracked in `ISSUES_FOUND_BY_CODEX.md`.
- Repo is currently assessed at `B+`.
- This is not the final quality bar for the repo.
- Item `13` should remain open; do not mark it `DONE` yet.
- Final score should only be revisited after a post-fix closure pass.

## What Has Already Been Audited

- GitHub Actions workflows
- Hook scripts
- Skills
- Shell test suite
- E2E scripts and scoring pipeline
- Evaluator failure semantics / degraded-judge behavior
- CUSUM / score-history schema alignment
- Local/manual E2E runner path
- Repo-authored Markdown/docs
- PR review and self-heal pipeline
- Scoring-model documentation vs evaluator implementation

## Current Open Themes

- Evaluator trust:
  `evaluate.sh` can still emit a passing/warning result even when every LLM-scored criterion falls back due to API failure.
- Observability trust:
  `score-history.jsonl` / `SCORE_TRENDS.md` do not yet fully support the repo's longitudinal measurement claims on `main`, and `cusum.sh` still reads an obsolete JSONL shape instead of the one CI writes.
- Wizard onboarding proof:
  the repo strongly claims stack-aware bespoke setup, but the live CI/E2E path still validates generated assets in `tests/e2e/fixtures/test-repo` much more than it validates the wizard's actual setup flow across fixtures/stacks or rerun/idempotence behavior.
- Local manual-proof path:
  `tests/e2e/run-simulation.sh` is the documented manual E2E runner, but its full-simulation path is currently miswired and untested compared with validation mode.
- Self-evolution loop closure:
  the repo now captures `friction-signal` issues, but the weekly/monthly improvement loops still do not prove they consume those issues.
- Competitive-watchlist accuracy:
  the watchlist is real, but docs/tests still blur weekly-vs-monthly behavior and give more confidence than the live wiring warrants.

## Next Audit Phase

Name: `Post-Fix Closure Audit`

Goal:
- Re-check the pass-5 fixes on evaluator failure handling, CUSUM/schema alignment, and the manual E2E runner path.
- Re-check the still-open pass-3/pass-4 product-truth gaps after fixes land.
- Decide whether the remaining issues are substantive or just wording/accepted tradeoffs.

## Required Method For Next Pass

1. Re-run the pass-5 failure reproductions after fixes land.
   - stub total LLM-judge failure and verify `evaluate.sh` returns a failing `error: true` result
   - seed a CI-shaped `score-history.jsonl` record and verify both total and per-criterion CUSUM read correctly
   - run `run-simulation.sh` with a stubbed `claude` binary and verify the fixture root is the actual repo root, not a nested subdirectory

2. Resume the prior product-truth closure work.
   Focus on:
   - stack-aware onboarding / setup proof
   - rerun/idempotence proof
   - friction-loop consumption
   - competitive-watchlist cadence truth

3. Prefer executable proof over doc-only reassurance.
   Examples:
   - a claimed "manual E2E" path really exercises the intended fixture root
   - a drift-detection claim is proven against the schema CI actually writes
   - evaluator failures surface as evaluator failures, not degraded passing scores

4. Only consider item `13` done when the remaining open issues are either fixed, explicitly accepted tradeoffs, or low-value wording nits.

## Progress Estimate

- Roughly `85-90%` through the full repo-visible audit.
- High confidence on:
  - workflow correctness
  - PR review / self-heal mechanics
  - scoring docs vs evaluator
  - evaluator failure semantics
  - CUSUM / observability schema alignment
  - broad docs drift
  - competitor/comparison surface at a repo-structure level
- Remaining high-value frontier is narrower but deeper:
  - true setup-path proof
  - idempotence / rerun proof
  - friction-loop consumption
  - post-fix revalidation of the evaluator / CUSUM / local E2E runner paths
  - final trust-test cleanup on novel claims
- That remaining `10-15%` is concentrated in closure work, not broad discovery.

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
