---
name: setup-wizard
description: Setup wizard — scans codebase, builds confidence per data point, only asks what it can't figure out, generates SDLC files. Use for first-time setup or re-running setup.
argument-hint: [optional: regenerate | verify-only]
effort: high
---
# Setup Wizard - Confidence-Driven Project Configuration

## Task
$ARGUMENTS

## Purpose

You are a confidence-driven setup wizard. Your job is to scan the project, infer as much as possible, and only ask the user about what you can't figure out. The number of questions is DYNAMIC — it depends on how much you can detect. Stop asking when all configuration data points are resolved (detected, confirmed, or answered).

**DO NOT ask a fixed list of questions. DO NOT ask what you already know.**

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
- Branding assets: BRANDING.md, brand/, logos/, style-guide.md, brand-voice.md, tone-of-voice.*
- Existing docs: README.md, CLAUDE.md, ARCHITECTURE.md
- Scripts in package.json (lint, test, build, typecheck, etc.)
- Database config files (prisma/, drizzle.config.*, knexfile.*, .env with DB_*)
- Cache config (redis.conf, .env with REDIS_*)
- Domain indicators (for domain-adaptive TESTING.md):
  - Firmware/Embedded: Makefile with flash/burn targets, .cfg device configs, /sys/ or /dev/tty references, .c/.h source, platformio.ini
  - Data Science: .ipynb notebooks, requirements.txt with pandas/sklearn/tensorflow/torch, data/ or datasets/ dir, models/ dir
  - CLI Tool: package.json with "bin" field (no React/Vue/Angular), bin/ dir, src/cli.*, no src/components/
  - Web/API: default — everything else (web frameworks, src/components/, Playwright/Cypress config)

### Step 2: Build Confidence Map

For each configuration data point, assign a confidence level based on scan results:

**Configuration Data Points:**

| Category | Data Point | How to Detect |
|----------|-----------|---------------|
| Structure | Source directory | Look for src/, app/, lib/, etc. |
| Structure | Test directory | Look for tests/, __tests__/, spec/ |
| Structure | Test framework | Config files (jest.config, vitest.config, pytest.ini) |
| Commands | Lint command | package.json scripts, Makefile, config files |
| Commands | Type-check command | tsconfig.json → tsc, mypy.ini → mypy |
| Commands | Run all tests | package.json "test" script, Makefile |
| Commands | Run single test file | Infer from framework (jest → jest path, pytest → pytest path) |
| Commands | Production build | package.json "build" script, Makefile |
| Commands | Deployment setup | Dockerfile, vercel.json, fly.toml, deploy scripts |
| Infra | Database(s) | prisma/, .env DB vars, docker-compose services |
| Infra | Caching layer | .env REDIS vars, docker-compose redis service |
| Infra | Test duration | Count test files, check CI run times if available |
| Preferences | Response detail level | Cannot detect — ALWAYS ASK |
| Preferences | Testing approach | Cannot detect intent from existing code — ALWAYS ASK |
| Preferences | Mocking philosophy | Cannot detect intent from existing code — ALWAYS ASK |
| Testing | Test types | What test files exist (*.test.*, *.spec.*, e2e/, integration/) |
| Coverage | Coverage config | nyc, c8, coverage.py config, CI coverage steps |
| CI | CI shepherd opt-in | Only if CI detected — ALWAYS ASK |
| Domain | Project domain | Auto-detect from domain indicators above (firmware/data-science/CLI/web). Web/API is the default fallback. One domain per project — dominant signal wins |

**Each data point has one of three states:**
- **RESOLVED (detected):** Found concrete evidence — config file, script, directory exists. No question needed, just confirm.
- **RESOLVED (inferred):** Found indirect evidence — naming patterns, related config. Present inference, let user confirm or correct.
- **UNRESOLVED:** No evidence found — must ask user directly.

**Preference data points** (response detail, testing approach, mocking philosophy, CI shepherd) are ALWAYS UNRESOLVED regardless of what code patterns exist. Current code patterns show what IS, not what the user WANTS going forward.

### Step 3: Present Findings and Fill Gaps

Present ALL detected values organized by state to the user.

**For RESOLVED (detected) items:** Show what was found, let user bulk-confirm with a single "Looks good" or override specific items.

**For RESOLVED (inferred) items:** Show what was inferred with reasoning, ask user to confirm or correct.

**For UNRESOLVED items:** Ask the user directly — these are your questions.

**The ready rule:** You are ready to generate files when ALL data points are resolved (detected, inferred+confirmed, or answered by user). The number of questions you ask depends entirely on how many data points remain unresolved after scanning. A well-configured project might need 3-4 questions (just preferences). A bare repo might need 10+. There is no fixed count.

DO NOT proceed to file generation until all data points are resolved.

### Step 4: Generate CLAUDE.md

Using detected + confirmed values, generate `CLAUDE.md` with:
- Project overview (from scan results)
- Commands table (detected/confirmed commands)
- Code style section (from detected linters/formatters)
- Architecture summary (from scan)
- Special notes (infra, deployment)

Reference: See "Step 8" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full template.

### Step 5: Generate SDLC.md

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
<!-- Completed Steps: step-0.1, step-0.2, step-1, step-2, step-3, step-4, step-5, step-6, step-7, step-8, step-9 -->
```

Reference: See "Step 9" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full template.

### Step 6: Generate TESTING.md (Domain-Adaptive)

Generate `TESTING.md` using the domain-specific template matching the detected project domain:
- **Web/API (default)**: Standard Testing Diamond (E2E/Integration/Unit)
- **Firmware/Embedded**: HIL/SIL/Config Validation/Unit layers
- **Data Science**: Model Evaluation/Pipeline Integration/Data Validation/Unit layers
- **CLI Tool**: CLI Integration/Behavior/Unit layers

Each domain template includes:
- Domain-appropriate testing layer visualization and percentages
- Domain-specific mocking rules (what to mock, what NEVER to mock)
- Test commands and fixture locations
- Domain-specific sections (Device Matrix for firmware, Test Datasets for data science, Behavior Contract for CLI)

Reference: See "Step 9" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full domain-conditional templates.

### Step 7: Generate ARCHITECTURE.md

Generate `ARCHITECTURE.md` with:
- System overview diagram (from scan)
- Component descriptions
- Environments table (from detected deployment config)
- Deployment checklist
- Key technical decisions

Reference: See "Step 6" in `CLAUDE_CODE_SDLC_WIZARD.md` for the full template.

### Step 8: Generate DESIGN_SYSTEM.md (If UI Detected)

Only if design system artifacts were found in Step 1:
- Extract colors, fonts, spacing from config
- Document component patterns
- Reference design sources (Storybook, Figma, etc.)

Skip this step if no UI/design system detected.

### Step 8.5: Generate BRANDING.md (If Branding Detected)

Only if branding-related assets were found in Step 1 (brand/, logos/, style-guide.md, brand-voice.md, existing BRANDING.md, or UI/content-heavy project detected):
- Brand voice and tone guidelines
- Naming conventions (product names, feature names, terminology)
- Visual identity summary (logo usage, color palette references)
- Content style guide (if the project has user-facing copy)

Skip this step if no branding assets or UI/content patterns detected.

### Step 9: Configure Tool Permissions

Based on detected stack, suggest `allowedTools` entries for `.claude/settings.json`:
- Package manager commands (npm, pnpm, yarn, cargo, go, pip, etc.)
- Build/test commands
- CI tools (gh)

Present suggestions and let the user confirm.

### Step 9.5: Context Window Configuration

The CLI ships `cli/templates/settings.json` with `"model": "opus[1m]"` and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=30` (tuned for the 1M context window — compacts at ~300K). This is the SDLC wizard default. Confirm the installed values, or fall back to 200K if the user prefers:

- **1M default (`opus[1m]`):** Confirm `"model": "opus[1m]"` at top level and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "30"` under `env`. Requires Claude Code v2.1.111+ for Opus 4.7.
- **200K fallback (`opus`):** Edit `.claude/settings.json` — change `"model"` to `"opus"` and raise `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` to `"75"` (otherwise `30%` of 200K compacts too early at 60K).

To fall back to 200K, edit `.claude/settings.json`:
```json
{
  "model": "opus",
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75"
  }
}
```

For CI pipelines, consider `"60"` — short tasks benefit from compacting early.

This is project-scoped and shared with the team via git.

### Step 10: Customize Hooks

Update `tdd-pretool-check.sh` with the actual source directory (replace generic `/src/` pattern).

### Step 11: Verify Setup

Run verification checks:
1. All generated files exist and are non-empty
2. Hooks are executable (`chmod +x`)
3. `settings.json` is valid JSON
4. Skill frontmatter is correct (name, effort fields)
5. `.gitignore` has required entries (.claude/plans/, .claude/settings.local.json)

Report any issues found.

### Step 12: Instruct Restart and Next Steps

Tell the user:
> Setup complete. Hooks and settings load at session start.
> **Exit Claude Code and restart it** for the new configuration to take effect.
> On restart, the SDLC hook will fire and you'll see the checklist in every response.
>
> **Optional next steps:**
> - Run `/claude-automation-recommender` for stack-specific tooling suggestions (MCP servers, formatting hooks, type-checking hooks, plugins)
> - After a few sessions, run `/less-permission-prompts` — a native Claude Code skill
>   that scans your transcripts for common read-only Bash/MCP calls and proposes a
>   prioritized allowlist. Reduces permission friction without enabling auto mode.
>
> Both are complementary to the SDLC wizard — they add tooling and quality-of-life, not process enforcement.

## Rules

- NEVER ask what you already know from scanning. If you found it, confirm it — don't ask it.
- NEVER use a fixed question count. The number of questions is dynamic based on scan results.
- ALWAYS show detected values organized by resolution state and let the user confirm or override.
- ALWAYS generate metadata comments in SDLC.md (version, date, steps).
- If most data points are resolved after scanning, present findings for bulk confirmation — don't force individual questions.
- If the user passes `regenerate` as an argument, skip Q&A and regenerate files from existing SDLC.md metadata.
- If the user passes `verify-only` as an argument, skip to Step 11 (verify) only.
