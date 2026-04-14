# Code Review Exceptions

Known trade-offs evaluated and explicitly accepted. The CI reviewer should
skip suggestions that match entries below — they have already been considered.

## Third-party actions pinned to major tags, not SHAs

**Files:** All `.github/workflows/*.yml`
**Flagged:** Codex main-branch audit (2026-03-27)
**Decision:** KEEP tag pinning — this is a meta-documentation repo, not a deployed service. All referenced actions are from well-known publishers (actions/*, anthropics/*, peter-evans/*, marocchino/*). SHA pinning 20+ references across all workflows creates maintenance churn disproportionate to the supply-chain risk.
**Revisit if:** The repo starts publishing artifacts, running in production environments, or if a referenced action has a security incident.

