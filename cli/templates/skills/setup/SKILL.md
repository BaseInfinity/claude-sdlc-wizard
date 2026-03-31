---
name: setup-wizard
description: Setup wizard — scans codebase, asks 18 config questions (including CI shepherd opt-in), generates SDLC files (CLAUDE.md, SDLC.md, TESTING.md, ARCHITECTURE.md), verifies installation. Use for first-time setup or re-running setup.
argument-hint: [optional: regenerate | verify-only]
effort: high
---
# Setup Wizard - Interactive Project Configuration

## Task
$ARGUMENTS

## Purpose

You are an interactive setup wizard. Your job is to scan the project, ask the user ALL configuration questions, and generate the SDLC files. DO NOT skip questions. DO NOT make assumptions. The user's answers drive the output.

## MANDATORY FIRST ACTION: Read the Wizard Doc

**Before doing ANYTHING else**, use the Read tool to read the ENTIRE `CLAUDE_CODE_SDLC_WIZARD.md` file. This file contains all templates, examples, and instructions you need. You CANNOT do this setup correctly without reading it first. Do NOT rely on summaries or references — read the full file now.

After reading, use it as the source of truth for every step below.

## Execution Checklist

Follow these steps IN ORDER. Do not skip or combine steps.

### Step 1: Auto-Scan the Project

Scan the project root for:
- Package managers: package.json, Cargo.toml, go.mod, pyproject.toml, Gemfile, build.gradle, pom.xml
- Source directories: src/, app/, lib/, server/, pkg/, cmd/
- Test directories: tests/, __tests__/, spec/, test files matching *_test.*, test_*.*
- Test frameworks: from config files (jest.config, vitest.config, pytest.ini, etc.)
- Lint/format tools: .eslintrc, biome.json, .prettierrc, rustfmt.toml, etc.
- CI/CD: .github/workflows/, .gitlab-ci.yml, Jenkinsfile
- Feature docs: *_PLAN.md, *_DOCS.md, *_SPEC.md, docs/
- Deployment: Dockerfile, vercel.json, fly.toml, netlify.toml, Procfile, k8s/
- Design system: tailwind.config.*, .storybook/, theme files, CSS custom properties
- Existing docs: README.md, CLAUDE.md, ARCHITECTURE.md

Present findings to the user in a clear summary with detected values.

### Step 2: Ask ALL 18 Questions

Ask every question. Pre-fill detected values but let the user confirm or override.

**Project Structure:**
1. Source directory (detected or ask)
2. Test directory (detected or ask)
3. Test framework (detected or ask)

**Commands:**
4. Lint command
5. Type-check command
6. Run all tests command
7. Run single test file command
8. Production build command
9. Deployment setup (detected environments, confirm or customize)

**Infrastructure:**
10. Database(s) used
11. Caching layer (Redis, etc.)
12. Test duration (<1 min, 1-5 min, 5+ min)

**Output Preferences:**
13. Response detail level (small/medium/large)

**Testing Philosophy:**
14. Testing approach (strict TDD, test-after, mixed, minimal, none yet)
15. Test types wanted (unit, integration, E2E, API)
16. Mocking philosophy (minimal, heavy, no mocking)

**Coverage:**
17. Code coverage preferences (enforce threshold, report only, AI suggestions, skip)

**CI Shepherd (only if CI detected in Step 1):**
18. CI shepherd opt-in — enable full CI shepherd role? (yes/no). If yes, ask sub-questions: CI monitoring detail, review feedback level (L1/L2/L3), bot fallback. Store choice in SDLC.md metadata as `<!-- CI Shepherd: enabled/disabled -->`. If no CI detected, skip and note in SDLC.md as `<!-- CI Shepherd: not applicable -->`.

DO NOT proceed to file generation until ALL 18 questions have answers (or questions are marked N/A).

### Step 3: Generate CLAUDE.md

Using the user's answers, generate `CLAUDE.md` with:
- Project overview (from scan results)
- Commands table (Q4-Q8 answers)
- Code style section (from detected linters/formatters)
- Architecture summary (from scan)
- Special notes (from Q9-Q11)

Reference: See "Step 3" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full template.

### Step 4: Generate SDLC.md

Generate `SDLC.md` with the full SDLC checklist customized to the project:
- Plan mode guidance
- TDD workflow with project-specific commands
- Self-review steps
- CI feedback loop (if CI detected)
- Confidence levels

Include metadata comments:
```
<!-- SDLC Wizard Version: [version from CLAUDE_CODE_SDLC_WIZARD.md] -->
<!-- Setup Date: [today's date] -->
<!-- Completed Steps: 0.4, 1-10 -->
```

Reference: See "Step 4" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full template.

### Step 5: Generate TESTING.md

Generate `TESTING.md` based on Q13-Q16 answers:
- Testing Diamond visualization
- Test types and their purposes
- Mocking rules (from Q15)
- Test file organization (from Q2, Q3)
- Coverage config (from Q16)
- Framework-specific patterns

Reference: See "Step 5" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full template.

### Step 6: Generate ARCHITECTURE.md

Generate `ARCHITECTURE.md` with:
- System overview diagram (from scan)
- Component descriptions
- Environments table (from Q8.5)
- Deployment checklist
- Key technical decisions

Reference: See "Step 6" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full template.

### Step 7: Generate DESIGN_SYSTEM.md (If UI Detected)

Only if design system artifacts were found in Step 1:
- Extract colors, fonts, spacing from config
- Document component patterns
- Reference design sources (Storybook, Figma, etc.)

Skip this step if no UI/design system detected.

### Step 8: Configure Tool Permissions

Based on detected stack, suggest `allowedTools` entries for `.claude/settings.json`:
- Package manager commands (npm, pnpm, yarn, cargo, go, pip, etc.)
- Build/test commands
- CI tools (gh)

Present suggestions and let the user confirm.

### Step 9: Customize Hooks

Update `tdd-pretool-check.sh` with the actual source directory from Q1 (replace generic `/src/` pattern).

### Step 10: Verify Setup

Run verification checks:
1. All generated files exist and are non-empty
2. Hooks are executable (`chmod +x`)
3. `settings.json` is valid JSON
4. Skill frontmatter is correct (name, effort fields)
5. `.gitignore` has required entries (.claude/plans/, .claude/settings.local.json)

Report any issues found.

### Step 11: Instruct Restart and Next Steps

Tell the user:
> Setup complete. Hooks and settings load at session start.
> **Exit Claude Code and restart it** for the new configuration to take effect.
> On restart, the SDLC hook will fire and you'll see the checklist in every response.
>
> **Optional next steps:**
> - Run `/ci-analyzer` to analyze your CI workflows for linting gaps, review hooks, and E2E coverage improvements (GitHub Actions)
> - Run `/claude-automation-recommender` for stack-specific tooling suggestions (MCP servers, formatting hooks, type-checking hooks, plugins)
>
> Both are complementary to the SDLC wizard — they add tooling and CI recommendations, not process enforcement.

## Rules

- NEVER skip a question. If the user says "I don't know", record that and move on.
- NEVER assume answers. If auto-scan can't detect something, ASK.
- ALWAYS show detected values and let the user confirm or override.
- ALWAYS generate metadata comments in SDLC.md (version, date, steps).
- If the user passes `regenerate` as an argument, skip Q&A and regenerate files from existing SDLC.md metadata.
- If the user passes `verify-only` as an argument, skip to Step 10 (verify) only.
