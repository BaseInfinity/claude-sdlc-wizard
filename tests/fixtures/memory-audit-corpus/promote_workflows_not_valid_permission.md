---
name: workflows is not a valid GHA permissions scope
description: including workflows in permissions silently breaks the YAML parser
type: feedback
test_expected:
  classification: promote
  target: SDLC.md
---

In GitHub Actions workflow YAML, `workflows` is NOT a valid `permissions:` scope. Including it causes the parser to silently fail on the entire workflow file — triggers break, the name shows as the file path, and `workflow_run` never fires.

Always run `actionlint` to validate before committing workflow changes. Pushing workflow files from a non-default actor requires a PAT with `workflow` scope or a GitHub App, not YAML permissions.
