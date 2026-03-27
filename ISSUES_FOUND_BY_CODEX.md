# Issues Found By Codex

Audit date: 2026-03-27

## Scope and confidence

- Repo shape audited: 142 tracked files.
- Highest-confidence areas: `.github/workflows/*`, `.claude/*`, `tests/**/*.sh`, root docs, E2E scenarios/baselines, fixture source files.
- Verification run during audit:
  - full local shell test suite across `tests/test-*.sh` and `tests/e2e/test-*.sh` -> passed
  - `actionlint` -> surfaced actionable workflow findings
  - `shellcheck` -> mostly style/info noise; not many high-signal functional failures
- Confidence is highest for source-level logic and workflow design issues.
- Confidence is lower for behavior that depends on GitHub-hosted event semantics or third-party actions unless noted as an inference.

## Executive summary

- No P0 findings.
- The highest-risk area is the PR review workflow, especially the `needs-review` label path on `pull_request_target`.
- CI/CD is functional and well-tested locally, but several workflow decisions create avoidable correctness, review-quality, and maintenance risks.
- The repo is unusually strong on test coverage. Most remaining issues are orchestration/design problems, not simple broken tests.

## Findings

### P1: `needs-review` reruns likely review the wrong checkout

- Evidence:
  - `.github/workflows/pr-review.yml:7-8` uses `pull_request_target` for labeled reruns.
  - `.github/workflows/pr-review.yml:46-49` does a default `actions/checkout@v4` with no explicit `ref`.
  - `.github/workflows/pr-review.yml:261-265` gives the reviewer `Read`, `Grep`, and `Glob` access to the checked-out workspace.
- Why this matters:
  - On `pull_request_target`, the workflow runs in the base-repository context. With no explicit checkout ref, the local workspace for `needs-review` reruns is very likely the base branch, not the PR head.
  - That means the reviewer can read stale files while also reading the PR diff via MCP. For a rerun requested after follow-up changes, this can produce confused or stale review context.
- Impact:
  - Re-review quality degrades exactly in the case where you most need a clean second pass.
- Recommended fix:
  - For labeled reruns, explicitly checkout the PR head SHA or head ref in a safe way.
  - If you keep `pull_request_target`, isolate the trusted operations and make the reviewed workspace explicitly match the PR head.

### P1: label-triggered PR reviews can cancel each other across different PRs

- Evidence:
  - `.github/workflows/pr-review.yml:10-12` sets concurrency group to `${{ github.workflow }}-${{ github.ref }}`.
  - `.github/workflows/pr-review.yml:7-8` uses `pull_request_target` for `labeled`.
- Why this matters:
  - For `pull_request_target`, `github.ref` is tied to the base branch context, not the PR merge ref.
  - In practice, multiple `needs-review` label events against `main` can land in the same concurrency group and cancel one another.
- Impact:
  - Re-review requests on separate PRs can stomp each other and disappear.
- Recommended fix:
  - Key concurrency to PR number for PR review workflows, not `github.ref`.
  - Example direction: `${{ github.workflow }}-pr-${{ github.event.pull_request.number }}`.

### P1: CI mutates PR branches using untrusted branch refs directly inside inline shell

- Evidence:
  - `.github/workflows/ci.yml:579-587`
  - `.github/workflows/ci.yml:1300-1306`
  - `actionlint` flagged both sites as using `github.event.pull_request.head.ref` directly in inline shell.
- Why this matters:
  - This is a workflow hardening problem. Even if Git ref naming rules reduce exploitability, the current pattern is still the exact class of interpolation GitHub and `actionlint` warn against.
  - These steps also perform fetch/checkout/push operations, so they are worth treating conservatively.
- Impact:
  - Security posture is weaker than it should be in a workflow that writes back to contributor branches.
- Recommended fix:
  - Pass the branch ref through `env:` and quote it inside the script.
  - Avoid embedding `${{ github.event.pull_request.head.ref }}` directly inside shell commands.

### P2: “trivial PR” detection is too broad and skips review on risky config changes

- Evidence:
  - `.github/workflows/pr-review.yml:81-118`
  - The workflow treats PRs as trivial if all changed files end in `.md`, `.txt`, `.json`, `.yml`, or `.yaml`.
- Why this matters:
  - In this repo, YAML and JSON are not “trivial” by default.
  - `.github/workflows/*.yml` is core execution logic.
  - JSON changes can affect fixtures, baselines, golden scores, release-analysis fixtures, and workflow behavior.
- Impact:
  - Important workflow/config changes can silently skip AI review.
- Recommended fix:
  - Narrow “trivial” to true docs-only changes.
  - At minimum, exclude `.github/workflows/**`, `tests/fixtures/**`, `tests/e2e/*.json`, and other execution-critical config/data from the trivial bucket.

### P2: PR review waits only for `validate`, not the full CI signal

- Evidence:
  - `.github/workflows/pr-review.yml:120-160`
  - The wait step checks only the `validate` check run by name.
- Why this matters:
  - This repo’s real PR signal is broader than `validate`. `e2e-quick-check` is a required quality gate and often the more interesting signal for SDLC regressions.
  - Today the reviewer may run before quick E2E finishes, or skip after 10 minutes even when the rest of CI would soon provide useful context.
- Impact:
  - Review runs can happen on incomplete signal, reducing cost-efficiency and context quality.
- Recommended fix:
  - Wait for the full required PR check set, not just `validate`.
  - If you want a cost gate, explicitly define which checks must finish before review starts.

### P2: self-heal behavior does not match the documented default safety posture

- Evidence:
  - `.github/workflows/ci-self-heal.yml:16-18` sets `AUTOFIX_LEVEL: all-findings`.
  - `CI_CD.md:204-210` documents `criticals` as the default.
- Why this matters:
  - `all-findings` means the bot will auto-edit on suggestions, not just must-fix findings.
  - That is a materially more aggressive behavior than the docs promise.
- Impact:
  - Unexpected bot churn, noisier history, and greater chance of low-value autofix loops.
- Recommended fix:
  - Either change the workflow default back to `criticals`, or update the docs everywhere and treat `all-findings` as an intentional product decision.

### P3: testing guidance is internally inconsistent and can mislead agents

- Evidence:
  - `.claude/skills/testing/SKILL.md:88-95` says workflow tests should use `act` locally.
  - `TESTING.md:190-204` says workflows cannot be tested locally with `act`.
  - `CONTRIBUTING.md:10-26` still says CI validate runs “all 21 scripts,” while `.github/workflows/ci.yml:70-137` now runs more than that.
  - `plans/AUTO_SELF_UPDATE.md:65-68` still describes PR review as a proper MCP review submission flow, while current implementation is a sticky-comment review in `.github/workflows/pr-review.yml`.
- Why this matters:
  - This repo is explicitly agent-facing. Contradictory operational guidance creates bad self-instructions.
  - The testing skill is especially important because it influences how agents attempt verification.
- Impact:
  - Humans and agents can choose the wrong local workflow, expect the wrong review behavior, or miss part of the actual CI surface.
- Recommended fix:
  - Make `TESTING.md` the source of truth and align the skill/docs/plans to it.
  - Remove or rewrite the `act` guidance unless you want to support it for a clearly scoped subset of workflows.

## Lower-priority observations

- `tests/e2e/run-simulation.sh:109-113` swallows `claude --print` failures with `|| true`, which makes local live E2E diagnosis less direct.
- `tests/e2e/lib/json-utils.sh` currently emits noisy locale warnings from `perl` in local test runs; low severity, but it muddies logs.
- Many `shellcheck` warnings are informational/style-only and do not currently look like the best use of cleanup time compared with the workflow issues above.

## What I explicitly did not count as defects

- Intentionally bad fixture code in `tests/e2e/fixtures/legacy-messy/`.
- Simplified fixture app implementations where the goal is scenario variety, not production quality.
- Pure style/lint suggestions without clear behavioral impact.

## Recommended fix order

1. Fix the `pr-review.yml` label-rerun architecture:
   - explicit checkout of PR head
   - PR-number-based concurrency
2. Harden `ci.yml` score-history branch handling:
   - move `head.ref` into `env:`
   - quote consistently
3. Tighten PR review gating:
   - narrow trivial-PR detection
   - wait on the right CI checks
4. Decide the intended self-heal aggressiveness:
   - `criticals` vs `all-findings`
5. Clean up docs/skill drift:
   - testing guidance
   - contributor test-count accuracy
   - plan docs vs current review implementation

## Audit artifacts

- Local tests run: all `tests/test-*.sh` and `tests/e2e/test-*.sh` passed during this audit.
- Static analyzers run:
  - `actionlint`
  - `shellcheck` on hooks/tests/E2E scripts

