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
| 13 | Cross-model full repo audit | IN PROGRESS — pass 3 done (2 findings: setup-path proof, friction narrative). Building friction capture, roadmapping setup-path E2E |
| 13.5 | Live-fire CI job audit | TODO — verify untested CI paths (see details below) |
| 13.6 | Wire cross-model review into own SDLC | TODO — dogfood codex exec in our local pre-PR loop |
| 14 | Distribution | TODO — npx CLI or curl one-liner (research done) |

## Post-Distribution

| # | Item | Description |
|---|------|-------------|
| 15 | E2E Scenario Coverage Audit | Review scenario gaps: user archetypes, task types, repo types |
| 16 | Scoring System Review | One-time deep audit, then every 2-3 months. Criteria relevance, weighting, LLM judge drift |
| 17 | Setup Drift Prevention | CI detects when installed setup drifts from wizard template |
| 18 | Tool/Plugin Discovery Automation | Weekly-update fetches marketplace.json, diffs against cache, LLM-recommends relevant new CC features |
| 19 | Monthly GC Audit (recurring) | "Less is more" — try removing things, check if scores hold. Fix weak tests or delete fluff |
| 20 | Setup-Path E2E Proof | Run wizard setup against greenfield fixtures (fresh-nextjs, fresh-python) in CI. Proves cross-stack onboarding claim |

## Review Pipeline

### Now

- Keep local review loop as the default quality bar: Claude self-review first, then local Codex `xhigh` for independent cross-model review on substantial changes.
- Keep GitHub PR automation on the existing Claude review pipeline so SDLC checks and `ci-self-heal.yml` continue to work.
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
- Make the PR review layer provider-swappable instead of coupling `ci-self-heal.yml` to a Claude-specific markdown format.
- Move toward a normalized review artifact or check-run parser so Claude and Codex can plug into the same automation.
- Revisit whether default review should be single-provider, dual-provider for labeled PRs, or manual Codex-only cross-review.

## Item 13.5: Live-Fire CI Job Audit

Every CI workflow/job must succeed at least once post-changes before distribution. Current gaps:

| Job/Trigger | Last Green | Gap | Action |
|---|---|---|---|
| `e2e-full-evaluation` (merge-ready label) | Feb 12 | 6+ weeks, massive changes since | Label a test PR with `merge-ready`, verify full Tier 2 pipeline (~$1.50-2.50) |
| `weekly-update.yml` schedule trigger | Never green on schedule (Mar 23 failed: missing label, now fixed) | Untested since label fix | Wait for next Monday or manual dispatch |
| `monthly-research.yml` schedule trigger | Never green on schedule (Mar 1 failed) | Mar 27 manual dispatch passed | Wait for Apr 1 or manual dispatch |
| Stale `ci-autofix.yml` (ID 232420762) | Never (dead workflow) | Orphaned after rename to ci-self-heal.yml | Delete via `gh workflow disable 232420762` or GitHub UI |
| Node.js 20 deprecation | N/A | `actions/checkout@v4` + `oven-sh/setup-bun` will be forced to Node 24 on June 2, 2026 | Track in back burner |

## Back Burner

- Mutation testing (#21, experimental)
- Node.js 20 deprecation (June 2, 2026 deadline — `actions/checkout@v4` + `oven-sh/setup-bun` forced to Node 24. Not urgent yet but blocks all CI if ignored. Revisit May 2026)
- Reviewer severity prompt fix (14% misclassification rate — CI reviewer under-categorizes silent no-op bugs as suggestions. Real but low-impact — hasn't caused a missed bug yet)
