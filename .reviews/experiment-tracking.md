# Review Pipeline Experiment: Claude vs Codex

Tracking Claude vs Codex review findings over 10-20 non-trivial PRs.
Started: 2026-03-29

## How to Use

1. Claude reviews every PR automatically (status quo via `pr-review.yml`)
2. On high-risk/complex PRs, comment `@codex review` to trigger Codex
3. Log results in the table below
4. After 10-20 PRs, evaluate at the Decision Gate

## Tracking

| PR | Risk | Claude Criticals | Claude Suggestions | Codex P0/P1 | Codex P2 | Unique Claude | Unique Codex | Changed Merge? | Notes |
|----|------|------------------|--------------------|-------------|----------|---------------|--------------|----------------|-------|
| | | | | | | | | | |

## Decision Gate

After 10-20 PRs, decide:

- **Codex finds higher-value issues consistently** → promote to first-class reviewer
- **Claude stays better for SDLC/process/testing** → keep Codex as selective second opinion
- **Both valuable** → design graded review policy (label-triggered dual review)

See ROADMAP.md "Review Pipeline" section for full criteria.
