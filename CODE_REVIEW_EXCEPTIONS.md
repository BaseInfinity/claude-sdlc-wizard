# Code Review Exceptions

Known trade-offs evaluated and explicitly accepted. The CI reviewer should
skip suggestions that match entries below — they have already been considered.

## grep -A 1 parsing fragility in ci-self-heal.yml

**Files:** `ci-self-heal.yml:178-188`, `tests/test-self-heal-simulation.sh`, `tests/e2e/test-self-heal-simulation.sh`
**Flagged:** PR #71 review
**Decision:** KEEP — `grep -A 1` works with current review template format. The line after the header is always content (no blank line between header and `_None._` or first finding).
**Revisit if:** Review template format changes to insert blank lines between section headers and content.

## Duplicate test functions across unit and e2e self-heal files

**Files:** `tests/test-self-heal-simulation.sh`, `tests/e2e/test-self-heal-simulation.sh`
**Flagged:** PR #71 review
**Decision:** KEEP — these are intentional mirror files. Unit tests run fast locally, e2e tests run in CI with additional integration context. Keeping them in sync is by design.
**Revisit if:** Files diverge in purpose or a shared test library is introduced.
