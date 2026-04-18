---
name: macOS bash 3.x has no associative arrays
description: declare -A is unavailable on macOS system bash; use case statements
type: feedback
test_expected:
  classification: promote
  target: SDLC.md
---

macOS ships bash 3.x by default. `declare -A` (associative arrays) is a bash 4+ feature and will fail silently or throw syntax errors on macOS runners.

Workaround: use `case` statements for key/value lookups, or require `#!/usr/bin/env bash` with a documented bash 4+ dependency (brew install bash).
