---
name: bash parameter expansion consumes closing brace in default
description: ${3:-{}} consumes the closing brace; use ${3:-"{}"} instead
type: feedback
test_expected:
  classification: promote
  target: SDLC.md
---

Bash parameter expansion `${VAR:-default}` treats the first closing brace as the terminator. So `${3:-{}}` does NOT default to the string `{}` — the closing `}` gets consumed by the expansion, producing `{}` then an extra `}` outside the expansion.

Correct: `${3:-"{}"}` (quoted default). Also applies when the default contains any `}` character.

Commonly bites scripts that default JSON parameters.
