# Lessons Learned

Ledger of methodology-worthy lessons captured from real SDLC wizard use. Each entry is a concrete incident, the failure mode, and the rule it became.

Format per entry:

```
## YYYY-MM-DD — short title

**Incident:** what happened
**Failure mode:** the pattern that caused it
**Rule:** the SDLC-worthy rule (drop-in for /sdlc or SKILL.md if it generalizes)
**Memory reference:** path to the corresponding feedback_*.md in auto-memory
```

---

## 2026-04-14 — Stale plan docs quoted as live state (Codex Windows hooks regression)

**Incident:**
During the m365-copilot-kit planning session on 2026-04-14, Claude read `CODEX_ADAPTER_PLAN.md` (authored 2026-04-04) which stated: *"Windows — Codex disables lifecycle hooks on Windows (codex-rs/hooks/src/engine/mod.rs:83-91)"*. Claude quoted this as current truth and dropped a `🚨 Windows hook problem` alarm on the user, claiming their Windows m365-copilot-kit deployment would have no hard SDLC enforcement.

The user pushed back (*"wtf why ddi ou even say that"*). A verification research pass then showed:

- The gate was added 2026-03-20 (openai/codex PR #15252, "Disable hooks on windows for now")
- **The gate was removed 2026-04-09 (PR #17268, "remove windows gate that disables hooks")** — 5 days after the plan doc was written, 5 days before Claude quoted it
- Current `codex-rs/hooks/src/engine/mod.rs` has zero `cfg(windows)`, zero OS-gating, zero feature flags on hooks
- Codex 0.120.0 is post-fix and already installed on the user's Mac
- Every active hook event (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `Stop`) works on Windows in current main

Net: Claude raised a non-issue blocker based on a 10-day-old snapshot. Zero real impact to the kit's architecture, maximum impact to the user's trust and time.

**Failure mode:**
Treating a point-in-time plan document as live state for an actively developed external tool. The plan doc was accurate when it was written. It stopped being accurate 5 days later. Claude quoted it 10 days later without re-verification.

This is the same class of error the session had already flagged for Codex's cross-model reviews — memory entry `reference_codex_cross_model_dialogue.md` includes the rule *"Always verify factual claims the reviewer makes about external systems — codex can be stale."* The rule was applied symmetrically to Codex's review of Claude's work. It was NOT applied to Claude reading the user's own plan doc. Same trap, different source.

**Rule:**

> **Plan docs are snapshots, not live state.** When a methodology doc, research note, audit report, or plan file cites file paths, line numbers, version-specific behavior, or capability limits of an *actively developed external tool*, treat the claim as point-in-time. Before surfacing it forward — especially to raise an alarm or change an architectural decision — re-verify against current source.
>
> - If the doc is older than one week AND cites line numbers OR version-specific behavior of a fast-moving external project, re-verify before quoting
> - If re-verification isn't possible in the moment, prefix the claim with "per doc from <date>, worth re-checking" — don't lead with a 🚨 alarm
> - The rule applies symmetrically to every doc source: Codex reviews, Claude reviews, user's own repo docs, vendor documentation, research agent reports, GitHub READMEs
> - Speed of the underlying project matters most — pin rate-of-change expectations to the repo being quoted, not to the doc being read
> - The cost of re-verification is 2 minutes; the cost of a false-alarm architectural pivot is hours

**Memory reference:**
`~/.claude/projects/-Users-stefanayala/memory/feedback_verify_docs_vs_live_source.md`

**Upstream action required:**
Update `CODEX_ADAPTER_PLAN.md` to remove the Windows-hooks-disabled warning and replace with a version note (something like *"requires Codex ≥ 0.120.0 or `main` post-2026-04-09 PR #17268"*).
