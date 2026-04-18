---
name: GITHUB_TOKEN pushes do not trigger workflow events
description: GHA anti-loop protection blocks workflow_run and pull_request events on GITHUB_TOKEN pushes
type: feedback
test_expected:
  classification: promote
  target: SDLC.md
---

GitHub Actions' anti-loop protection means pushes made with the default `GITHUB_TOKEN` do NOT trigger downstream workflow events — neither `push` nor `pull_request` nor `workflow_run`.

Workarounds:
- Use `gh workflow run <workflow>` dispatch with `actions: write` permission to re-trigger
- Use a PAT or GitHub App token for the push
- Use label-based triggers (e.g. `gh pr edit --add-label needs-review`) to re-fire PR reviews after autofixes
