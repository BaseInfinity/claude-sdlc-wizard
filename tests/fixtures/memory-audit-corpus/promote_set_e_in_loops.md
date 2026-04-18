---
name: set -e kills loop on non-zero inside for/while
description: Under `set -e`, a non-zero exit from any command inside a `for` or `while` loop terminates the script — even when the failure is expected
type: feedback
test_expected:
  classification: promote
  target: SDLC.md
---

Under `set -e`, a non-zero exit from any command inside a `for` or `while` loop terminates the entire script — even when the failure is expected and you want the loop to continue. This bites scripts that grep in a loop (grep returns 1 on no-match), or that iterate over optional checks.

Why: `set -e` treats the loop body as a single compound statement; any failing simple command inside halts execution.

How to apply: for expected failures inside a loop body, append `|| true` to the command that might fail with a non-error condition. Example:
```bash
for f in *.log; do
  grep WARN "$f" || true   # no-match is fine, keep iterating
done
```

Source: documented in MEMORY.md general lessons (bash gotchas section).
