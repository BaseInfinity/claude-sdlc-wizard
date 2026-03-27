# Claude Code SDLC Wizard

A **self-evolving SDLC enforcement system for AI coding agents**. Makes Claude plan before coding, test before shipping, and ask when uncertain. Measures itself getting better over time.

## What This Actually Is

Five layers working together:

```
Layer 5: SELF-IMPROVEMENT
  Weekly/monthly workflows detect changes, test them
  statistically, create PRs. Baselines evolve organically.

Layer 4: STATISTICAL VALIDATION
  E2E scoring with 95% CI (5 trials, t-distribution).
  SDP normalizes for model quality. CUSUM catches drift.

Layer 3: SCORING ENGINE
  7 criteria, 10/11 points. Claude evaluates Claude.
  Before/after wizard A/B comparison in CI.

Layer 2: ENFORCEMENT
  Hooks fire every interaction (~100 tokens).
  PreToolUse blocks source edits without tests.

Layer 1: PHILOSOPHY
  The wizard document. KISS. TDD. Confidence levels.
  Copy it, run setup, get a bespoke SDLC.
```

## Why Someone Uses This

You want Claude Code to follow engineering discipline automatically:
- **Plan before coding** (not guess-and-check)
- **Write tests first** (TDD enforced via hooks)
- **State confidence** (LOW = ask user, don't guess)
- **Track work visibly** (TaskCreate)
- **Self-review before presenting**
- **Prove it's better** (use native features unless you prove custom wins)

The wizard auto-detects your stack (package.json, test framework, deployment targets) and generates bespoke hooks + skills + docs.

## What Makes This Different

| Capability | What It Does |
|---|---|
| **E2E scoring in CI** | Every PR gets an automated SDLC compliance score (0-10) — measures whether Claude actually planned, tested, and reviewed |
| **Before/after A/B testing** | Compares wizard changes against a baseline with 95% confidence intervals to prove improvements aren't noise |
| **SDP normalization** | Separates "the model had a bad day" from "our SDLC broke" by cross-referencing external benchmarks |
| **CUSUM drift detection** | Catches gradual quality decay over time — borrowed from manufacturing quality control |
| **Pre-tool TDD hooks** | Claude can't write code without writing tests first — enforced at the hook level, not just guidance |
| **Self-evolving loop** | Claude proposes process improvements from friction it encounters — you approve, the system gets better |

## How It Works

**Think Iron Man:** Jarvis is nothing without Tony Stark. Tony Stark is still Tony Stark. But together? They make Iron Man. This SDLC is your suit - you build it over time, improve it for your needs, and it makes you both better.

**The dream:** Mold an ever-evolving SDLC to your needs. Replace my components with native Claude Code features as they ship — and one day, delete this repo entirely because Claude Code has them all built in. That's the goal.

```
WIZARD FILE (CLAUDE_CODE_SDLC_WIZARD.md)
  - Setup guide, used once
  - Lives on GitHub, fetched when needed
        |
        | generates
        v
GENERATED FILES (in your repo)
  - .claude/hooks/*.sh
  - .claude/skills/*/SKILL.md
  - .claude/settings.json
  - CLAUDE.md, SDLC.md, TESTING.md, ARCHITECTURE.md
        |
        | validated by
        v
CI/CD PIPELINE
  - E2E: simulate SDLC task -> score 0-10
  - Before/after: main vs PR wizard
  - Statistical: 5x trials, 95% CI
  - Model-aware: SDP adjusts for external conditions
```

## Using It

**Copy-paste:** Download `CLAUDE_CODE_SDLC_WIZARD.md` to your project and follow setup instructions inside.

**Raw URL:** Point Claude to:
```
https://raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/main/CLAUDE_CODE_SDLC_WIZARD.md
```

**Check for updates:** Ask Claude "Check if the SDLC wizard has updates" - Claude reads [CHANGELOG.md](CHANGELOG.md), shows what's new, and offers to apply changes (opt-in each).

## Self-Evolving System

| Cadence | Source | Action |
|---------|--------|--------|
| Weekly | Claude Code releases | PR with analysis + E2E test |
| Weekly | Community (Reddit, HN) | Issue digest |
| Monthly | Deep research, papers | Trend report |

Every update: regression tested -> AI reviewed -> human approved.

## E2E Scoring

Like evaluating scientific method adherence - we measure **process compliance**:

| Criterion | Points | Type |
|-----------|--------|------|
| TodoWrite/TaskCreate | 1 | Deterministic |
| Confidence stated | 1 | Deterministic |
| Plan mode | 2 | AI-judge |
| TDD RED | 2 | Deterministic |
| TDD GREEN | 2 | AI-judge |
| Self-review | 1 | AI-judge |
| Clean code | 1 | AI-judge |

40% deterministic + 60% AI-judged. 5 trials handle variance.

## Model-Adjusted Scoring (SDP)

| Metric | Meaning |
|--------|---------|
| **Raw** | Actual score (Layer 2: SDLC compliance) |
| **SDP** | Adjusted for model conditions |
| **Robustness** | How well SDLC holds up vs model changes |

- **Robustness < 1.0** = SDLC is resilient (good!)
- **Robustness > 1.0** = SDLC is sensitive (investigate)

## Tests Are The Building Blocks

Tests aren't just validation - they're the foundation everything else builds on.

- **Tests >= App Code** - Critique tests as hard (or harder) than implementation
- **Tests prove correctness** - Without them, you're just hoping
- **Tests enable fearless change** - Refactor confidently

## Official Plugin Integration

| Plugin | Purpose | Scope |
|--------|---------|-------|
| `claude-md-management` | **Required** - CLAUDE.md maintenance | CLAUDE.md only |
| `claude-code-setup` | Recommends automations | Recommendations |
| `code-review` | PR review (optional) | PRs only |

## Prove It's Better

Don't reinvent the wheel. Use native/built-in features UNLESS you prove your custom version is better. If you can't prove it, delete yours.

1. Test the native solution — measure quality, speed, reliability
2. Test your custom solution — same scenario, same metrics
3. Compare side-by-side
4. Native >= custom? **Use native. Delete yours.**
5. Custom > native? **Keep yours. Document WHY.** Re-evaluate when native improves.

This applies to everything: native commands vs custom skills, framework utilities vs hand-rolled code, library functions vs custom implementations.

## How This Compares

This isn't the only Claude Code SDLC tool. Here's an honest comparison:

| Aspect | SDLC Wizard | everything-claude-code | claude-sdlc |
|--------|------------|----------------------|-------------|
| **Focus** | SDLC enforcement + measurement | Agent performance optimization | Plugin marketplace |
| **Hooks** | 3 (SDLC, TDD, instructions) | 12+ (dev blocker, prettier, etc.) | Webhook watcher |
| **Skills** | 2 (/sdlc, /testing) | 80+ domain-specific | 13 slash commands |
| **Evaluation** | 95% CI, CUSUM, SDP, Tier 1/2 | Configuration testing | skilltest framework |
| **Self-healing** | CI auto-fix + re-trigger | No | No |
| **Auto-updates** | Weekly CC + community scan | No | No |
| **Install** | Copy wizard file + run setup | npm install | npm install |
| **Philosophy** | Lightweight, prove-it-or-delete | Scale and optimization | Documentation-first |

**Our unique strengths:** Statistical rigor (CUSUM + 95% CI), SDP scoring (model quality vs SDLC compliance), self-healing CI, Prove-It A/B pipeline, comprehensive automated test suite, dogfooding enforcement.

**Where others are stronger:** everything-claude-code has broader language/framework coverage. claude-sdlc has webhook-driven automation. Both have npm distribution.

**The spirit:** Open source — we learn from each other. See [COMPETITIVE_AUDIT.md](COMPETITIVE_AUDIT.md) for details.

## Documentation

| Document | What It Covers |
|----------|---------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design, 5-layer diagram, data flows, file structure |
| [CI_CD.md](CI_CD.md) | All 5 workflows, E2E scoring, tier system, SDP, integrity checks |
| [SDLC.md](SDLC.md) | Version tracking, enforcement rules, SDLC configuration |
| [TESTING.md](TESTING.md) | Testing philosophy, test diamond, TDD approach |
| [CHANGELOG.md](CHANGELOG.md) | Version history, what changed and when |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute, evaluation methodology |

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for evaluation methodology and testing.
