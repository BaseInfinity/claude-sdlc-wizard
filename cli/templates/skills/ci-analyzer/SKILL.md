---
name: ci-analyzer
description: Analyze existing CI workflows and recommend integration points — linting gaps, review hooks, E2E test coverage, shepherd loop opportunities. GitHub Actions focused.
argument-hint: [optional: path/to/.github/workflows/]
effort: high
---
# CI Workflow Analyzer

## Task
$ARGUMENTS

## Purpose

You analyze the project's existing CI/CD workflows and recommend specific integration points for SDLC enforcement. This is complementary to `/claude-automation-recommender` (which suggests stack-level tooling like MCP servers and formatters). You focus specifically on **CI workflow gaps**.

## Scope (v1)

**Supported CI backend:** GitHub Actions (`.github/workflows/*.yml`)

**If non-GitHub CI detected** (`.gitlab-ci.yml`, `Jenkinsfile`, `circle.yml`, etc.): Report what was found but note that detailed analysis is GitHub Actions only for now. Suggest `/claude-automation-recommender` for general CI tooling.

## Execution

### Step 1: Discover CI Configuration

Scan for CI files:
```
.github/workflows/*.yml    → GitHub Actions (full analysis)
.gitlab-ci.yml             → GitLab CI (detected, not analyzed)
Jenkinsfile                → Jenkins (detected, not analyzed)
.circleci/config.yml       → CircleCI (detected, not analyzed)
bitbucket-pipelines.yml    → Bitbucket (detected, not analyzed)
```

For each GitHub Actions workflow found, read and parse it.

### Step 2: Analyze for Gaps

Check each workflow against these categories:

#### Linting Gaps
- Has test job but no lint step? → Recommend adding lint
- Has lint but no typecheck? → Recommend adding typecheck (if TS/Python/Go project)
- Lint runs AFTER tests? → Recommend lint-first (fails fast, cheaper)
- No format check? → Recommend format verification step

#### Review Hooks
- No PR review workflow? → Recommend PR review automation
- PR review runs on draft PRs? → Recommend skipping drafts
- No review-after-CI pattern? → Recommend gating review behind passing tests
- No sticky comment setup? → Recommend sticky comments over inline for bots

#### E2E Test Coverage
- Has unit tests but no integration/E2E in CI? → Recommend E2E stage
- E2E runs on every push (expensive)? → Recommend label-gated E2E (like `merge-ready`)
- No test matrix (single OS/version)? → Note if project targets multiple platforms

#### Shepherd Integration Points
- Has CI but no self-heal/autofix workflow? → Recommend ci-self-heal pattern
- Has PR review but no feedback loop? → Recommend shepherd CI review loop
- No `workflow_dispatch` on CI workflow? → Recommend adding for re-trigger support
- No SHA-based deconfliction? → Recommend if both shepherd and bot are desired

### Step 3: Present Recommendations

Output a structured recommendation table:

```
| Priority | Category | Gap | Recommendation |
|----------|----------|-----|----------------|
| HIGH     | Linting  | No lint step in CI | Add lint job before test job |
| MEDIUM   | Review   | No PR review workflow | Add PR review with sticky comments |
| LOW      | E2E      | E2E on every push | Gate behind `merge-ready` label |
```

For each HIGH recommendation, include a brief workflow snippet showing where to add it.

### Step 4: Reference Existing Resources

Point to relevant wizard sections:
- Shepherd setup → "CI Feedback Loop — Local Shepherd" in wizard doc
- Bot fallback → "CI Auto-Fix Loop" in wizard doc
- PR review → "PR Review" in wizard doc
- For stack-level tooling (MCP, formatters, type checkers) → `/claude-automation-recommender`

## Rules

- Only analyze GitHub Actions workflows in detail (v1 scope)
- Do NOT generate complete workflow files — give snippets and point to wizard templates
- Do NOT overlap with `/claude-automation-recommender` — they handle MCP servers, formatters, plugins
- Focus on the 3 roadmap categories: linting gaps, review hooks, E2E suggestions
- If no CI exists at all, recommend starting with the wizard's CI templates and skip analysis
