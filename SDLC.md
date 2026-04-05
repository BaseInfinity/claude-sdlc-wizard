<!-- SDLC Wizard Version: 1.27.0 -->
<!-- Setup Date: 2026-01-24 -->
<!-- Completed Steps: step-0.1, step-0.2, step-1, step-2, step-3, step-4, step-5, step-6, step-7, step-8, step-9 -->
# SDLC Configuration

## Wizard Version Tracking

| Property | Value |
|----------|-------|
| Wizard Version | 1.27.0 |
| Last Updated | 2026-04-05 |
| Claude Code Baseline | v2.1.85+ |

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
| `instructions-loaded-check.sh` | Session start | Validates SDLC.md/TESTING.md exist |

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
│   └── instructions-loaded-check.sh  # Session start validation
└── skills/
    ├── sdlc/SKILL.md             # SDLC workflow
    ├── setup/SKILL.md            # Setup wizard
    ├── update/SKILL.md           # Update wizard
    └── feedback/SKILL.md         # Community feedback
```
