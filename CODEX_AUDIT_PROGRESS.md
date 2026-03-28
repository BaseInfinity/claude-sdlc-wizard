# Codex Audit Progress

Purpose: keep the repo-wide audit state explicit so future passes resume from the right place instead of starting over.

## Current Status

- Deep repo audit passes 1-6 completed on `main`; pass 6 ran on `2026-03-28`.
- Pass 6 re-ran the pass-5 repros with executable proof:
  - `evaluate.sh` now hard-fails total LLM-judge outages with `pass: false` and `error: true`
  - `cusum.sh` now reads CI-shaped `score-history.jsonl` correctly for both total and per-criterion drift
  - `run-simulation.sh` now copies the fixture contents into the temp repo root; a stubbed `claude` binary saw `package.json` at root and no nested `test-repo/`
- Pass 6 also re-checked the pass-4 product-truth gaps:
  - weekly update now consumes open `friction-signal` issues
  - competitive-watchlist docs/tests now truthfully point to the weekly community scan
  - README setup wording is now scoped to generated-asset validation, with setup-path E2E left on the roadmap
- Pass 6 found two remaining substantive issues:
  - the full manual `run-simulation.sh` path still exits on its first warning because `check-compliance.sh` combines `set -e` with warning paths that return non-zero
  - `CLAUDE_CODE_SDLC_WIZARD.md` still claims idempotent / safe reruns without executable proof
- Current open findings are tracked in `ISSUES_FOUND_BY_CODEX.md`.
- Repo is currently assessed at `B+`.
- This is not the final quality bar for the repo.
- Item `13` should remain open; do not mark it `DONE` yet.
- Another pass is only worthwhile after the remaining manual-runner / idempotence issues change.

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

- Manual proof-path closure:
  the `run-simulation.sh` copy-path bug is fixed, but the full-simulation path still aborts on the first warning because `check-compliance.sh` treats warning-only misses as non-zero under `set -e`.
- Wizard rerun truth:
  the wizard still claims idempotent / safe / non-duplicating reruns without executable proof.
- Setup-path proof scope:
  cross-stack onboarding E2E is still roadmap work, but this is now an explicitly documented tradeoff rather than a hidden CI claim.

## Next Audit Phase

Name: `Targeted Closure Follow-up`

Goal:
- Re-check the remaining manual/full E2E runner behavior after `check-compliance.sh` warning semantics are fixed or explicitly scoped.
- Re-check wizard rerun/idempotence wording after proof lands or the claim is narrowed.
- Confirm the only remaining setup-path gap is the explicitly accepted roadmap item, not a hidden trust problem.

## Required Method For Next Pass

1. Re-run the stubbed full `run-simulation.sh` path after the compliance semantics change.
   - verify the temp repo root is still correct
   - verify warning-only checks no longer abort the run
   - verify the script prints a full compliance summary and exits `0` when there are no hard failures

2. Resolve the wizard rerun/idempotence claim one way or the other.
   - add executable rerun/idempotence proof, or
   - narrow/remove wording that implies the safety guarantee is already proven

3. Keep setup-path proof explicitly separated from idempotence truth.
   - setup-path E2E can remain a roadmap tradeoff
   - idempotence/safe-rerun claims should not stay stronger than the proof

4. Only consider item `13` done when the remaining open issues are either fixed, explicitly accepted tradeoffs, or low-value wording nits.

## Progress Estimate

- Roughly `92-95%` through the full repo-visible audit.
- High confidence on:
  - workflow correctness
  - PR review / self-heal mechanics
  - scoring docs vs evaluator
  - evaluator failure semantics
  - CUSUM / observability schema alignment
  - friction-loop consumption
  - competitor/watchlist cadence truth
  - broad docs drift
- Remaining high-value frontier is narrow:
  - manual/full E2E runner warning semantics
  - wizard idempotence / rerun proof or wording
  - final confirmation that only explicit roadmap tradeoffs remain
- That remaining `5-8%` is concentrated in closure work, not broad discovery.

## Stop Condition

The next pass should stop only when:
- the full `run-simulation.sh` path can complete a warning-only stubbed run without aborting early, or the repo explicitly scopes that path as best-effort rather than robust proof, and
- the wizard rerun/idempotence claim is either backed by executable proof or narrowed to match reality, and
- any remaining setup-path gap is just the already-accepted roadmap tradeoff, not a hidden trust problem.

## Notes For Future Codex Pass

- Treat this as a meta-repo audit, not a normal app-repo audit.
- Weight trust, proof, and repo-claim accuracy more heavily than cosmetic polish.
- Prefer consolidating related doc drift into one root-cause finding instead of logging dozens of tiny wording bugs.
- Keep `ISSUES_FOUND_BY_CODEX.md` as the findings ledger.
- Use this file as the pass-state / audit-process ledger.
