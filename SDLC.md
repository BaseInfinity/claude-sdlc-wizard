<!-- SDLC Wizard Version: 1.33.0 -->
<!-- Setup Date: 2026-01-24 -->
<!-- Completed Steps: step-0.1, step-0.2, step-1, step-2, step-3, step-4, step-5, step-6, step-7, step-8, step-9 -->
# SDLC Configuration

## Wizard Version Tracking

| Property | Value |
|----------|-------|
| Wizard Version | 1.33.0 |
| Last Updated | 2026-04-14 |
| Claude Code Baseline | v2.1.111+ (required for Opus 4.7 / `opus[1m]`) |
| Recommended Model | `opus[1m]` (Opus 4.7, 1M context) — run `/model opus[1m]` |
| Recommended Effort | `xhigh` — run `/effort xhigh` |

See `CLAUDE_CODE_SDLC_WIZARD.md` → "1M vs 200K Context Window" for the rationale and pricing notes.

## SDLC Enforcement

This repository uses the SDLC Wizard to enforce:

### 1. Planning Before Coding
- Complex tasks require planning before coding
- Multi-step tasks use `TodoWrite` or `TaskCreate`
- Confidence levels stated before implementation

### 2. TDD Approach
- Write failing tests first
- Implement to pass tests
- Refactor while keeping green

### 3. Self-Review
- Review changes before presenting
- Verify tests pass
- Check for obvious issues

## Hooks Installed

| Hook | Trigger | Purpose |
|------|---------|---------|
| `sdlc-prompt-check.sh` | Every prompt | SDLC baseline reminder |
| `tdd-pretool-check.sh` | Before Write/Edit | TDD reminder for workflows |
| `instructions-loaded-check.sh` | Session start | Validates SDLC.md/TESTING.md exist, effort/model check |
| `model-effort-check.sh` | Session start | Nudges upgrade when effort/model is behind recommended |

## Skills Available

| Skill | Invocation | Purpose |
|-------|------------|---------|
| SDLC | `/sdlc` | Full SDLC workflow guidance |
| Setup | `/setup` | Confidence-driven project setup wizard |
| Update | `/update` | Smart update with drift detection |
| Feedback | `/feedback` | Privacy-first community feedback |

## Compliance Verification

To verify SDLC compliance:

1. **Manual check**: Start new Claude session, observe hook output
2. **E2E test**: Run `./tests/e2e/run-simulation.sh`
3. **PR review**: Non-trivial PRs trigger AI code review workflow after CI passes

## Updating the Wizard

When Claude Code releases new features:

1. Weekly workflow checks for updates
2. HIGH/MEDIUM relevance creates PR
3. Review and merge if valuable
4. Update version tracking here

## Configuration Files

```
.claude/
├── settings.json                  # Hook configuration
├── hooks/
│   ├── sdlc-prompt-check.sh      # SDLC baseline
│   ├── tdd-pretool-check.sh      # TDD reminder
│   ├── instructions-loaded-check.sh  # Session start validation + effort/model
│   └── model-effort-check.sh     # SessionStart upgrade nudge
└── skills/
    ├── sdlc/SKILL.md             # SDLC workflow
    ├── setup/SKILL.md            # Setup wizard
    ├── update/SKILL.md           # Update wizard
    └── feedback/SKILL.md         # Community feedback
```

## Lessons Learned

Portable technical gotchas promoted from private memory via the Memory Audit Protocol (see `skills/sdlc/SKILL.md` → "After Session (Capture Learnings)" → "Memory Audit Protocol"). Each entry is sourced from a real debugging session; the source memory file records the original incident.

### GitHub CLI + Actions

- **`gh api` writes JSON errors to stdout, not stderr.** On non-2xx responses, the error body JSON lands on stdout; stderr only gets the one-line `gh: ... (HTTP 4xx)` prefix. Redirecting `2>"$err"` and grepping for tokens like `already_exists` silently misses them. Capture both: `gh api ... >"$out" 2>&1`, then grep `$out`. (Source: PR #187 prod hotfix, 2026-04-17)
- **`workflows` is NOT a valid YAML `permissions:` scope.** Including it causes the parser to silently fail on the entire workflow file — triggers break, name shows the file path, `workflow_run` never fires. Run `actionlint` before committing workflow edits. Pushing workflow files requires a PAT with `workflow` scope or a GitHub App, not YAML permissions.
- **GITHUB_TOKEN pushes do NOT trigger workflow events.** GitHub's anti-loop protection blocks `push`, `pull_request`, and `workflow_run` for commits pushed with the default `GITHUB_TOKEN`. Workarounds: `gh workflow run` dispatch (needs `actions: write`), a PAT/GitHub App token, or label-based re-triggers (`gh pr edit --add-label needs-review`).
- **GitHub Actions `${{ }}` in bash `run:` blocks command-substitutes backticks.** LLM-generated evidence text with backtick-quoted commands (``` `npm test` ```) gets executed as command substitution — npm ENOENT + exit 129. Pass untrusted content via step `env:` block instead of inline `${{ }}`.

### Bash

- **macOS ships bash 3.x by default** — no `declare -A` (associative arrays), no `${var@Q}` quoting. Use `case` statements for lookups; require `#!/usr/bin/env bash` + brew-installed bash 4+ if you genuinely need the newer features.
- **Parameter-expansion default consumes closing brace.** `${3:-{}}` does NOT default to `{}` — the closing `}` terminates the expansion. Correct form: `${3:-"{}"}` (quoted default). Bites scripts defaulting JSON parameters.
- **`--argjson result` in `jq` conflicts with jq's internal `result` name.** Causes parse errors. Rename the jq variable (e.g. `--argjson crit_result`). General rule: avoid short jq arg names that shadow built-ins.

### Testing

- **Separate stderr from stdout when capturing output for JSON parsing.** `2>&1` mixes stderr into stdout, causing silent JSON parse failures that defaulted scores to 0 (incident: 2026-02-06 E2E silent-zero bug). Use `2>"$err_file"` and check exit code separately.
- **`continue-on-error: true` + `|| echo "fallback"` masks real failures.** Always audit these patterns for silent bugs — they convert step failures into green checks while hiding the underlying incident.

