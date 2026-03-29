# Code Review Exceptions

Known trade-offs evaluated and explicitly accepted. The CI reviewer should
skip suggestions that match entries below — they have already been considered.

## grep -A 1 parsing fragility in ci-self-heal.yml

**Files:** `ci-self-heal.yml:178-188`, `tests/e2e/test-self-heal-simulation.sh`
**Flagged:** Anticipated from PR #71 review
**Decision:** KEEP — `grep -A 1` works with current review template format. The line after the header is always content (no blank line between header and `_None._` or first finding).
**Revisit if:** Review template format changes to insert blank lines between section headers and content.

## Third-party actions pinned to major tags, not SHAs

**Files:** All `.github/workflows/*.yml`
**Flagged:** Codex main-branch audit (2026-03-27)
**Decision:** KEEP tag pinning — this is a meta-documentation repo, not a deployed service. All referenced actions are from well-known publishers (actions/*, anthropics/*, peter-evans/*, marocchino/*). SHA pinning 20+ references across 5 workflows creates maintenance churn disproportionate to the supply-chain risk.
**Revisit if:** The repo starts publishing artifacts, running in production environments, or if a referenced action has a security incident.

