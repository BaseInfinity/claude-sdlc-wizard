---
name: gh api writes JSON errors to stdout
description: gh api error bodies land on stdout not stderr; capture both streams
type: feedback
test_expected:
  classification: promote
  target: SDLC.md
---

When `gh api` returns non-2xx, the JSON error body goes to **stdout**, not stderr. Stderr only gets a one-line prefix like `gh: Validation Failed (HTTP 422)`.

Checking stderr alone for tokens like `already_exists` misses the token and fails loudly.

Correct pattern: `gh api ... >"$out" 2>&1`, then grep `$out` for the token.
