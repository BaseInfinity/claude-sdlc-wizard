---
name: Release cadence tracking with a portable gotcha embedded
description: Current release pace plus a lesson about changelog drift
type: project
test_expected:
  classification: manual-review
---

We've been cutting releases every 2 weeks. During v1.30.0, the changelog consolidation process lost entries because two PRs landed the same day and one's CHANGELOG edits silently overwrote the other's during merge conflict resolution.

The cadence detail is private state. The changelog-drift lesson is portable — might belong in the release-readiness guidance.
