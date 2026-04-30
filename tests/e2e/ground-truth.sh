#!/bin/bash
# ROADMAP #96 Phase 2 — independent ground-truth verification.
#
# Runs the fixture's own test suite (`npm test`) post-simulation and emits
# JSON: { "tests_run": bool, "tests_pass": bool, "tests_tail": string,
#         "tests_rc": int, "reason": string }
#
# Combined with the judge score in local-shepherd.sh, this catches "agent
# followed protocol but produced broken code" false-positives — the judge
# can't tell whether `npm test` actually passes; only running it can.
#
# Usage:
#   ./ground-truth.sh /path/to/fixture/dir
#   ./ground-truth.sh --help
#
# Behavior:
#   - No package.json in fixture → tests_run=false (skip, no gate)
#   - No "test" script in package.json → tests_run=false (skip)
#   - Test script exists, exits 0 → tests_run=true, tests_pass=true
#   - Test script exists, exits non-zero → tests_run=true, tests_pass=false
#   - Test script hangs → killed at GROUND_TRUTH_TIMEOUT (default 120s)
#
# Exit codes:
#   0 — emitted valid JSON (tests_pass may be true OR false; caller decides)
#   1 — bad args / fixture dir not found

set -e

USAGE="Usage: $0 <fixture-dir>
  Runs 'npm test' in the fixture directory and emits JSON ground truth.
  GROUND_TRUTH_TIMEOUT=<seconds> caps test runtime (default 120)."

if [ "$#" -eq 0 ]; then
    echo "error: missing argument" >&2
    echo "$USAGE" >&2
    exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "$USAGE"
    exit 0
fi

FIXTURE_DIR="$1"
TIMEOUT="${GROUND_TRUTH_TIMEOUT:-120}"

if [ ! -d "$FIXTURE_DIR" ]; then
    echo "error: fixture dir not found: $FIXTURE_DIR" >&2
    exit 1
fi

# No package.json → skip
if [ ! -f "$FIXTURE_DIR/package.json" ]; then
    jq -nc '{tests_run:false, reason:"no_package_json"}'
    exit 0
fi

# No "test" script → skip
TEST_SCRIPT=$(jq -r '.scripts.test // empty' "$FIXTURE_DIR/package.json" 2>/dev/null)
if [ -z "$TEST_SCRIPT" ]; then
    jq -nc '{tests_run:false, reason:"no_test_script"}'
    exit 0
fi

# Run tests with timeout. macOS doesn't ship `timeout` by default — use
# perl as a fallback so this works on stock systems. (gtimeout from
# coreutils works too if installed, but assume nothing.)
LOG=$(mktemp -t gt-test-out.XXXXXX)
trap 'rm -f "$LOG"' EXIT

# Cross-platform timeout via perl. The inner subshell cd's into the
# fixture; the outer perl wrapper enforces the deadline.
set +e
if command -v timeout >/dev/null 2>&1; then
    ( cd "$FIXTURE_DIR" && timeout "$TIMEOUT" npm test --silent ) > "$LOG" 2>&1
elif command -v gtimeout >/dev/null 2>&1; then
    ( cd "$FIXTURE_DIR" && gtimeout "$TIMEOUT" npm test --silent ) > "$LOG" 2>&1
else
    perl -e '
        use strict; use warnings;
        my ($timeout, $dir, @cmd) = @ARGV;
        my $pid = fork();
        if ($pid == 0) {
            chdir $dir or die "chdir: $!";
            exec @cmd;
            exit 127;
        }
        local $SIG{ALRM} = sub { kill "TERM", $pid; sleep 1; kill "KILL", $pid; exit 124; };
        alarm $timeout;
        waitpid $pid, 0;
        my $rc = $? >> 8;
        exit $rc;
    ' "$TIMEOUT" "$FIXTURE_DIR" npm test --silent > "$LOG" 2>&1
fi
RC=$?
set -e

# Tail the last 1KB of output (jq-safe — strip control chars).
TAIL=$(tail -c 1000 "$LOG" 2>/dev/null | tr -d '\000-\010\013-\037' | head -c 1000)

if [ "$RC" -eq 0 ]; then
    jq -nc --arg tail "$TAIL" \
        '{tests_run:true, tests_pass:true, tests_rc:0, tests_tail:$tail}'
else
    jq -nc --arg tail "$TAIL" --argjson rc "$RC" \
        '{tests_run:true, tests_pass:false, tests_rc:$rc, tests_tail:$tail}'
fi
