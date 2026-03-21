# Version Catch-Up: v2.1.15 to v2.1.81

> Completed: 2026-03-20
> Versions covered: 66 minor versions of Claude Code drift
> Result: Wizard v1.8.0

## Why This Happened

The daily-update workflow created PRs #57-#65 with analyses but was disabled (PR #66) to save API tokens. This left 66 versions of drift. We consolidated all changes into one update.

## Process Used

### Change Categories

| Category | Risk | Verification | Count |
|----------|------|-------------|-------|
| **A: Docs-only** | Zero | E2E confirms no regression | ~15 items |
| **B: New additions** | Medium | TDD (write test first) | 2 items |
| **C: Swaps (custom to native)** | High | Before/after E2E comparison | 0 items (none needed) |
| **D: CI optimizations** | Medium | Isolated test | Deferred |

### What We Did

**Phase 1: Housekeeping**
- Closed stale PRs #55 and #65
- Deleted ~46 remote branches
- Updated README with vision statement, "Prove It's Better" philosophy, doc links

**Phase 2: Consolidated Update**
- Category A: Documented all new features (v2.1.49-v2.1.81) in wizard doc
- Category B: TDD for InstructionsLoaded hook (6 tests), effort frontmatter on skills
- Category C: Audited for custom /claude-api — none found
- Version bumps: SDLC.md, CHANGELOG.md, last-checked-version.txt

**Phase 3: Local self-review + all tests**

**Phase 4: CI/CD verification loop**

### Key Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| InstructionsLoaded hook | Implement | Catches missing wizard files early, low cost |
| ConfigChange hook | Skip | No observed problem with settings tampering |
| StopFailure hook | Skip | No API error pattern to solve |
| HTTP hooks | Skip | Shell hooks work fine |
| --bare flag for CI | Defer | Not blocking, follow-up PR |
| Custom /claude-api swap | N/A | No custom skill exists |

## If Auto-Updates Are Paused Again

1. Check `gh pr list --label auto-update` for PRs created before pause
2. Read changelogs for the gap: `gh api repos/anthropics/claude-code/releases`
3. Categorize changes as A/B/C/D using this framework
4. Verify with CI/CD loop
5. This document shows the exact process
