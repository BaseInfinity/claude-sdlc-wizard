---
name: Run full test suite before pushing to main
description: Possibly project-specific, possibly universal SDLC rule
type: feedback
test_expected:
  classification: manual-review
---

Always run the full test suite before pushing to main, even for doc-only changes. Don't filter output with grep — read the whole summary.

Is this a project-specific rule (this meta-repo has doc changes that touch distributed artifacts) or a universal SDLC principle worth promoting to `CLAUDE.md`? Needs human judgement — could go either way.
