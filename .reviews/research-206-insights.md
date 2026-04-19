# Research: ROADMAP #206 — Claude Code `/insights` Integration

Date: 2026-04-19
Author: Claude (delegated to claude-code-guide sub-agent)

**TL;DR — `/insights` is native CC (v2.1.101, 2026-04-10). Output is qualitative HTML + facet JSON — NO cache-hit, `cache_read_input_tokens`, or degradation signals. Does NOT feed #96 or #204. Recommend: (a) surface in setup skill as complementary, (c) skip programmatic consumption.**

---

## 1. What does `/insights` do?

Built-in analyzer of the user's local CC session history (last 30 days by default). Generates an interactive HTML report at `~/.claude/usage-data/report.html` that auto-opens. Covers: session/message/token/git-activity counts, tool-usage distribution, language breakdown, satisfaction distribution, recurring friction patterns, "what works well," suggested `CLAUDE.md` additions, feature recommendations (e.g., MCP server suggestions when external-tool usage is detected). All analysis is **local** — no data sent to Anthropic.

## 2. Native or community?

**Native**, built into the CLI. Listed in the official commands table at `code.claude.com/docs/en/commands`. Distinct from community wrappers like `claude-insights` (dev.to/yahav10) which *parse* the HTML output.

## 3. When added?

**v2.1.101** (2026-04-10), alongside `/team-onboarding`. Fixes in v2.1.101 (missing report link), v2.1.108 (Windows `EBUSY`). Confirmed via `code.claude.com/docs/en/changelog.md`.

## 4. Cache/degradation signals exposed?

**No.** Report is behavioral/qualitative, not performance/billing. Per the Zolkos deep-dive, each `~/.claude/usage-data/facets/<session-id>.json` contains:

- `underlying_goal`, `goal_categories`
- `outcome` (enum: fully/mostly/partially/not_achieved)
- `user_satisfaction_counts`, `claude_helpfulness` (enum)
- `session_type`, `friction_counts`, `friction_detail`
- `primary_success`, `brief_summary`

**No** `cache_read_input_tokens`, **no** cache-hit ratio, **no** per-turn token breakdown, **no** model-version tracking. Token counts are aggregate totals only.

**Critical finding for #96/#204:** `/insights` does NOT help. Cache signals live in raw session JSONL (`~/.claude/projects/<project>/<session>.jsonl`) where each assistant turn carries `usage.cache_read_input_tokens` / `cache_creation_input_tokens` — that's what community tools (cnighswonger/claude-code-cache-fix, issues #46829 / #46917) actually consume.

## 5. Programmatic consumption?

**Semi — HTML + JSON cache artifacts:**

- Primary output: HTML (`~/.claude/usage-data/report.html`). Parseable via cheerio/BeautifulSoup (claude-insights CLI does this)
- Intermediate: per-session facet JSON at `~/.claude/usage-data/facets/<session-id>.json` — directly hook-readable without running `/insights` first (stable schema)
- **No CLI flag for stdout JSON**, no API endpoint, no MCP tool
- Can't be triggered from a hook — it's an interactive slash command, not a CLI subcommand

## 6. Community feedback

Mixed but net-positive.

Positive: Nate Meyvis ("feels like the future"), producttalk.org, therundown.ai, angelo-lima.fr, Vindler.

Known bug: sampling defect — `/insights` claims to analyze thousands of sessions but generates facets for only 3–5. Narrative sections draw from the facet-ed sessions while aggregate stats come from all data (multiple GH issues). Whole community CLI (`yahav10/claude-insights`) exists purely to post-process HTML into skills/rules — signal that Anthropic hasn't made the data directly actionable.

---

## Recommendation

**(a) Recommend `/insights` in the setup flow. (c) Skip programmatic consumption for #96/#204.**

Concrete steps:

- **Setup skill (additive):** One-liner in `setup-wizard` / `CLAUDE_CODE_SDLC_WIZARD.md`: "Run `/insights` monthly to surface friction patterns and `CLAUDE.md` suggestions from your actual usage." Zero cost, complementary.
- **Do NOT** route `/insights` into #96 (benchmark) or #204 (cache-cost guardrail) — wrong data shape. #204 should target session JSONL directly (`~/.claude/projects/*/session.jsonl`, parse `usage.cache_read_input_tokens` per turn). #96 degradation signal stays on aistupidlevel.info + Piebald system-prompt diffs (#175).
- **Known-bug awareness:** sampling defect means don't trust `/insights` as a quantitative metric — pattern surfacing only.
- **Pre-empts nothing:** `/insights` does not eliminate any existing roadmap item. Narrow qualitative complement.

**Close #206:** Recommend `/insights` in setup skill; no wizard-side consumption. Does not feed #96 or #204 — cache/degradation data lives in session JSONL, not `/insights` output.

---

## Sources

- [Claude Code Commands docs](https://code.claude.com/docs/en/commands)
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog.md) — v2.1.101 introduction
- [Zolkos: Deep Dive into /insights](https://www.zolkos.com/2026/02/04/deep-dive-how-claude-codes-insights-command-works.html) — facet JSON schema
- [Nate Meyvis on /insights](https://www.natemeyvis.com/claude-codes-insights/)
- [Angelo Lima: /insights walkthrough](https://angelo-lima.fr/en/claude-code-insights-command/)
- [yahav10: claude-insights CLI (HTML parser)](https://dev.to/yahav10/i-built-a-cli-that-turns-claude-codes-insights-report-into-actionable-skills-rules-and-workflows-377)
- [The Rundown University /insights guide](https://app.therundown.ai/guides/how-this-hidden-insights-feature-improves-claude-code)
- [Vindler: tailoring /insights](https://vindler.solutions/blog/claude-code-insights-tailoring-guide)
- [Issue #24147 — cache reads 99.93% of quota](https://github.com/anthropics/claude-code/issues/24147)
- [Issue #46829 — cache TTL regression 1h → 5m](https://github.com/anthropics/claude-code/issues/46829)
- [Issue #46917 — v2.1.100+ cache_creation inflation](https://github.com/anthropics/claude-code/issues/46917)
- [cnighswonger/claude-code-cache-fix](https://github.com/cnighswonger/claude-code-cache-fix) — example of session-JSONL cache consumer
