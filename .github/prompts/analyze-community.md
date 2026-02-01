# Claude Code Community Scan Prompt

You are scanning community discussions about Claude Code to find actionable insights for the SDLC Wizard.

## Wizard Context

The SDLC Wizard enforces:
- **TDD** - Failing tests first, then implementation
- **Planning** - Plan mode before coding
- **Confidence levels** - HIGH/MEDIUM/LOW stated before implementing
- **Tasks** - TodoWrite/TaskCreate for tracking work
- **Self-review** - Review before presenting to user

## What You're Scanning

- Reddit: r/ClaudeAI, r/programming (Claude Code mentions)
- Hacker News: Claude Code discussions
- Dev blogs: Popular posts about Claude Code tips/tricks
- Official community channels (Discord, forums)

## What To Look For

### Actionable Insights
- Patterns that improve SDLC enforcement
- Tips that align with wizard philosophy (KISS, TDD, planning)
- Problems users are having that the wizard could prevent
- Clever uses of hooks, skills, or CLAUDE.md

### Red Flags to Filter Out
- Hype without substance
- Features that would add bloat
- Complexity for complexity's sake
- Things already covered by the wizard

## Expectations

**Most content will be noise - that's expected and OK.**

The goal is to surface the occasional gem, not to act on everything. If nothing is worth reporting, say so.

## Response Format

Respond with valid JSON:

```json
{
  "scan_date": "YYYY-MM-DD",
  "sources_checked": ["reddit", "hackernews", "devblogs", "official"],
  "findings": [
    {
      "source": "reddit/hackernews/devblog/official",
      "url": "link to discussion",
      "title": "Thread/article title",
      "summary": "2-3 sentence summary of what was discussed",
      "relevance": "HIGH" | "MEDIUM" | "LOW",
      "potential_improvement": "How this could improve the wizard (or null if just informational)",
      "category": "tdd" | "planning" | "confidence" | "hooks" | "skills" | "workflow" | "other"
    }
  ],
  "digest_summary": "1-2 paragraph summary of what the community is discussing this week",
  "recommended_actions": [
    {
      "action": "What to do",
      "reasoning": "Why this is worth doing",
      "priority": "HIGH" | "MEDIUM" | "LOW"
    }
  ],
  "nothing_notable": true | false
}
```

## Important Notes

- Quality over quantity - only include genuinely useful findings
- It's OK (even expected) to return `nothing_notable: true` most weeks
- Include source links so humans can verify
- Don't recommend adding features just because they're popular
- Focus on what aligns with wizard philosophy
- Human decides what (if anything) to incorporate
