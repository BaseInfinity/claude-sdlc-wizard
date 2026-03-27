# Codex Audit Progress

Purpose: keep the repo-wide audit state explicit so future passes resume from the right place instead of starting over.

## Current Status

- Deep repo audit pass completed on `main` on 2026-03-27.
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
- Scoring-model drift:
  some human-facing docs no longer match the live evaluator.
- CI least privilege:
  `ci.yml` still grants workflow-level write permissions broader than necessary.
- Summary-doc contradictions:
  a few top-level docs still oversimplify or contradict actual behavior.

## Next Audit Phase

Name: `Claim Verification / Adversarial E2E Audit`

Goal:
- Verify that every important repo claim is actually true, currently true, and provable from the repo/workflows/tests.
- Verify that novel features are tested in the same spirit they are marketed.
- Catch "blowing smoke" issues where docs, README, CI/CD docs, or the wizard overclaim or underclaim reality.

## Required Method For Next Pass

1. Build a claim matrix.
   For each major claim in `README.md`, `CI_CD.md`, `CLAUDE_CODE_SDLC_WIZARD.md`, and `ARCHITECTURE.md`:
   - claim text
   - proving file/workflow/test
   - status: proven / partially proven / stale / missing proof

2. Audit novel repo loops explicitly.
   - self-evolving update loop
   - self-heal loop
   - prove-it / native-vs-custom loop
   - scoring / SDP / CUSUM loop
   - PR review loop
   - optional cross-model review posture

3. Run adversarial E2E checks, not just happy-path checks.
   Focus on:
   - stale observability artifacts
   - merge-path persistence assumptions
   - workflow output-shape drift
   - bootstrapping / no-baseline behavior
   - missing-secret / degraded-service behavior
   - docs claiming a feature that is only partial or dormant

4. Add trust tests where needed.
   These are tests that verify claims, not just implementation mechanics.
   Examples:
   - doc summary matches workflow behavior
   - README scoring summary matches evaluator
   - generated/stored observability artifacts are actually current if claimed current
   - repo capabilities are surfaced if they exist

5. Re-score the repo only after the above pass reaches diminishing returns.

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
