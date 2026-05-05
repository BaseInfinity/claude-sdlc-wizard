**Findings**

1. **P1**: Same-session BASELINE suppression is not concurrency-safe.
   Evidence: [sdlc-prompt-check.sh](/Users/stefanayala/sdlc-wizard/hooks/sdlc-prompt-check.sh:131) checks for the sentinel before emit, but [sdlc-prompt-check.sh](/Users/stefanayala/sdlc-wizard/hooks/sdlc-prompt-check.sh:164) writes it only after the `cat` block. A 50-process same-session race produced `baseline_outputs=13`, `sentinels=1`.
   Certify condition: make the first-writer decision atomic, with best-effort fallback preserved, and add a parallel same-`session_id` regression test expecting exactly one BASELINE.

2. **P1**: Valid `session_id` input is ignored when `jq` is unavailable or broken.
   Evidence: [sdlc-prompt-check.sh](/Users/stefanayala/sdlc-wizard/hooks/sdlc-prompt-check.sh:47) only reads stdin when `jq` exists, and [sdlc-prompt-check.sh](/Users/stefanayala/sdlc-wizard/hooks/sdlc-prompt-check.sh:51) extracts `session_id` through `jq`. With a fake failing `jq` and valid JSON stdin: `first_baseline=1`, `second_baseline=1`, `sentinels=0`.
   Certify condition: either make `session_id` extraction work without optional `jq`, or explicitly enforce/document `jq` as a runtime dependency and test the dependency behavior.

**Checklist Evidence**

(a) Sequential gate shape is correct: sentinel check at lines 122-132, BASELINE at 137-158, write after emit at 159-168. EFFORT is outside at 90-100; SETUP is outside at 103-112.

(b) SETUP missing test uses sibling tmpdir: [test-baseline-fires-once.sh](/Users/stefanayala/sdlc-wizard/tests/test-baseline-fires-once.sh:110).

(c) Sanitization uses `tr -cd 'A-Za-z0-9._-'` at line 128. Manual malicious id created only `baseline-shown-....badtouchtmpownedstefanayala` inside cache.

(d) Prune is scoped to cache dir and filename pattern: line 167.

(e) Best-effort cache failure verified: cache-dir-is-file manual run returned `rc=0`, `stderr_bytes=0`, `baseline_count=1`.

(f) Version bump grep verified all 7 sites: `package.json:3`, `plugin.json:3`, `marketplace.json:16`, `SDLC.md:1`, `SDLC.md:10`, `CLAUDE_CODE_SDLC_WIZARD.md:2979`, `CLAUDE_CODE_SDLC_WIZARD.md:4058`.

(g) CI path is correct: [.github/workflows/ci.yml](/Users/stefanayala/sdlc-wizard/.github/workflows/ci.yml:218) runs `./tests/test-baseline-fires-once.sh`.

(h) Tests run:
`./tests/test-baseline-fires-once.sh`: 8 passed, 0 failed.
`./tests/test-audit-session-load.sh`: 9 passed, 0 failed.
`./tests/test-hooks.sh`: 154 passed, 0 failed.

Score: **6/10**

**NOT CERTIFIED**