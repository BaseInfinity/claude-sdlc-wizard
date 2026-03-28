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
| 13 | Cross-model full repo audit | IN PROGRESS — user running Codex CLI independently |
| 13.5 | Wire cross-model review into own SDLC | TODO — dogfood codex exec in our local pre-PR loop |
| 14 | Distribution | TODO — npx CLI or curl one-liner (research done) |

## Post-Distribution

| # | Item | Description |
|---|------|-------------|
| 15 | Tool/Plugin Discovery Automation | Weekly-update fetches marketplace.json, diffs against cache, LLM-recommends relevant new CC features |
| 16 | E2E Scenario Coverage Audit | Review scenario gaps: user archetypes, task types, repo types |
| 17 | Scoring System Review | One-time deep audit, then every 2-3 months. Criteria relevance, weighting, LLM judge drift |
| 18 | Setup Drift Prevention | CI detects when installed setup drifts from wizard template |
| 19 | Monthly GC Audit (recurring) | "Less is more" — try removing things, check if scores hold. Fix weak tests or delete fluff |

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

## Back Burner

- Mutation testing (#21, experimental)
- Node.js 20 (#68, June 2026)
- Reviewer severity prompt fix (14% misclassification rate — CI reviewer under-categorizes silent no-op bugs as suggestions)
