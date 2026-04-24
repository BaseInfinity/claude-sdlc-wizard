---
name: update-wizard
description: Smart update for SDLC wizard — shows changelog, compares files, lets you selectively adopt changes while preserving customizations.
argument-hint: [optional: check-only | force-all]
effort: high
---
# Update Wizard - Smart SDLC Update

## Task
$ARGUMENTS

## Purpose

You are a guided update assistant. Your job is to check what version the user has, show what changed, and walk them through selectively adopting updates while preserving their customizations. DO NOT blindly overwrite files. Show diffs and let the user decide.

## MANDATORY FIRST ACTION: Read the Wizard Doc

**Before doing ANYTHING else**, use the Read tool to read the `CLAUDE_CODE_SDLC_WIZARD.md` file — specifically the "Staying Updated (Idempotent Wizard)" section near the end. This contains the update URLs, version tracking format, and step registry you need. Do NOT proceed without reading it first.

## Execution Checklist

Follow these steps IN ORDER. Do not skip or combine steps.

### Step 1: Read Installed Version

Read `SDLC.md` and extract the version from the metadata comment:
```
<!-- SDLC Wizard Version: X.X.X -->
```
If no version comment exists, treat as `0.0.0` (first-time setup — suggest running `/setup-wizard` instead).

Also note the completed steps from `<!-- Completed Steps: ... -->`.

### Step 2: Fetch Latest CHANGELOG

Use WebFetch to fetch the CHANGELOG:
```
https://raw.githubusercontent.com/BaseInfinity/claude-sdlc-wizard/main/CHANGELOG.md
```

Extract the latest version from the first `## [X.X.X]` line.

### Step 3: Compare Versions and Show What Changed

Parse all CHANGELOG entries between the user's installed version and the latest. Present a clear summary:

```
Installed: 1.24.0
Latest:    1.37.1

What changed:
- [1.37.1] Token-bloat fix: dedupe 2× SDLC BASELINE print when both project + plugin register the same hook (~300 tokens doubled per prompt). 5 hooks gain `dedupe_plugin_or_project()` helper. Codex 2-round 100/100.
- [1.37.0] `monthly-research.yml` workflow deleted (ROADMAP #231 Phase 1) — 0 merged artifacts in 30d while burning $11-23/month; research happens inline now. `model-effort-check.sh` loud WARNING below xhigh (#217) — max preferred, xhigh floor; duplicate effort nudge in `instructions-loaded-check.sh` removed; single source of truth. Both changes Codex-certified.
- [1.36.1] Repo renamed `agentic-ai-sdlc-wizard` → `claude-sdlc-wizard` (matches sibling pattern; npm package unchanged); `npm pkg fix` metadata cleanup; slug migration across docs/tests/configs
- [1.36.0] CC 2.1.118 `/usage` canonical + aliases, Tier 2 dead-gate fix (#215), score-history max_score correctness (#211), setup-bun regression guard (#210), post-mortem learnings (#220-222), GPT-5.5 adoption plan (#223), MCP-tool hooks + #198 re-verify in backlog (#218/#219)
- [1.35.0] PreCompact seam gate + self-heal (#208/#209), effort auto-bump on LOW/FAILED/CONFUSED (#195), wizard staleness nudge (#196), Codex CI-log audit pattern, ...
- [1.34.0] API feature detection shepherd for Claude releases, Memory Audit Protocol with 7 verified lessons (+2 caught-and-retracted), /less-permission-prompts surfaced, ...
- [1.33.0] opus[1m] as SDLC default, dual-channel install drift guardrails, model/effort session-start nudge, ...
- [1.32.0] Opus 4.7 + xhigh support, model/effort upgrade detection, benchmark ceiling audit, ...
- [1.31.0] Hook false-positive fix for non-SDLC dirs, ephemeral marketplace path warning, ...
- [1.30.0] Firmware fixture, model A/B comparison workflow, CC degradation detection, ...
- [1.29.0] Node 24 compliance, autocompact in settings.json, effectiveness scoreboard, ...
- [1.28.0] Autocompact benchmarking methodology, canary fact mechanism, benchmark harness, ...
- [1.27.0] Domain-adaptive testing diamond, 3 domain fixtures, 25 quality tests, ...
- [1.26.0] Codex SDLC Adapter plan, claw-code/OmO/OmX research, CC feature discovery verified, ...
- [1.25.0] Plugin format, 6 distribution channels (curl, Homebrew, gh, GitHub Releases), ...
- [1.24.0] Hook if conditionals, autocompact tuning + 1M/200K guidance, tdd_red fix, ...
```

**If versions match:** Say "You're up to date! (version X.X.X)" and stop.

**If user passed `check-only`:** Stop here after showing what changed. Do not apply anything.

### Step 4: Run Drift Detection

Run the CLI drift checker to see per-file status:
```bash
npx agentic-sdlc-wizard check
```

This reports each managed file as MATCH, CUSTOMIZED, MISSING, or DRIFT. Present the results.

### Step 5: Fetch Latest Wizard Doc

Use WebFetch to fetch the latest wizard:
```
https://raw.githubusercontent.com/BaseInfinity/claude-sdlc-wizard/main/CLAUDE_CODE_SDLC_WIZARD.md
```

This is the source of truth for all templates, hooks, skills, and step registry.

### Step 6: Present Per-File Update Plan

For each managed file from the `sdlc-wizard check` output:

| Status | Action |
|--------|--------|
| MATCH | Skip — already current |
| MISSING | Recommend install — show what the file does |
| CUSTOMIZED | Show what changed in latest vs user's version. Ask: adopt, skip, or merge? |
| DRIFT | Flag the issue (e.g., missing executable permission). Offer to fix |

Read both the installed file and the latest template content. Present a human-readable summary of differences — not a raw diff, but "what was added/changed/removed and why."

**If user passed `force-all`:** Skip per-file approval and apply all updates.

### Step 7: Handle settings.json Specially

NEVER overwrite settings.json. Instead:

1. Read the user's current settings.json
2. Compare against the latest template's hook definitions
3. Describe what hooks changed (added, updated, removed)
4. Offer to merge: update wizard hooks while preserving all custom hooks, permissions, and other settings

The CLI's `init --force` already has smart merge logic for settings.json. If the manual merge gets complicated, suggest: `npx agentic-sdlc-wizard init --force` (it preserves custom hooks).

### Step 7.5: Model Pin Migration (Issue #198)

Wizard versions 1.31.0–1.33.x unconditionally wrote `"model": "opus[1m]"` and `"env": { "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "30" }` to `.claude/settings.json`. Issue #198 flipped that to opt-in because a top-level `model` disables Claude Code's auto-mode for the session.

If the user is upgrading from a pre-#198 version, check their `.claude/settings.json`:

1. **If `model` is `"opus[1m]"` and `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is `"30"`** — this is likely the old wizard-installed pair, not an intentional user choice. Ask:

   > Your `.claude/settings.json` pins `model: "opus[1m]"` with `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=30`.
   > This pair was the SDLC wizard default in 1.31.0–1.33.x, but it disables Claude Code's auto-mode (see issue #198).
   >
   > - **Remove the pin** (recommended for most users) — keeps auto-mode enabled, lets Claude Code pick the model per turn.
   > - **Keep the pin** — you want guaranteed Opus 4.7 + 1M context, and you're OK giving up model auto-selection.
   >
   > Remove, keep, or decide later? `[r/k/l]`

2. **If only one of the two fields matches** (e.g. `model: "opus[1m]"` but custom autocompact, or vice versa) — treat as intentional customization. Do not prompt.

3. **If `model` is some other value** (e.g. `"sonnet"`, `"opus"`) — treat as user's explicit choice. Do not touch.

4. **If neither field is set** — user is already on the new default. No action.

When removing: edit the file in place, drop the `model` key (and the `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` key if nothing else is in `env`, otherwise leave `env` alone). Never touch other keys the user added.

### Step 7.6: `allowedTools` → `permissions.allow` Migration (Issue #197)

Wizard versions before #197 guided users to write a top-level `allowedTools` array in `.claude/settings.json`. Claude Code silently disables its auto-mode classifier when that key is present, even with `defaultMode: "auto"` set globally.

If the user's `.claude/settings.json` has a top-level `allowedTools` array, offer to migrate:

1. **If only `allowedTools` is present** (no `permissions.allow`) — ask:

   > Your `.claude/settings.json` has a top-level `allowedTools` array. This silently disables Claude Code auto-mode (see issue #197). The supported successor is `permissions.allow`, which accepts the same patterns but doesn't trip the auto-mode gate.
   >
   > - **Migrate** (recommended): move all entries into `permissions.allow`, remove the old `allowedTools`.
   > - **Keep** — you have a specific reason to use the legacy key.
   > - **Later** — don't touch it now.
   >
   > `[m/k/l]`

2. **If both `allowedTools` and `permissions.allow` are present** — flag it: the two lists may have diverged. Show both arrays to the user. On migrate, append every entry from `allowedTools` to the end of `permissions.allow` (preserving order within each list), then drop the legacy `allowedTools` key. **Do NOT dedup.** If the same string appears in both lists, it stays in both positions — Claude Code treats duplicate entries as a no-op, but dedup would silently remove user data that the user might have intended. If the user explicitly asks to dedup, do that as a separate follow-up edit.

3. **If only `permissions.allow` is present** — user is already on the new shape. No action.

4. **If neither is present** — no action.

When migrating: preserve every entry byte-for-byte; only the container key changes. Do not reorder, dedup, or expand wildcards. Other top-level keys (hooks, env, model, custom user fields) are never touched.

### Step 8: Apply Selected Changes

For each file the user approved:
- Use the Edit tool to update the file content
- For complete replacements (MISSING files), use Write
- For settings.json, apply the merge from Step 7

### Step 9: Bump Version Metadata

Update the version in `SDLC.md`:
```
<!-- SDLC Wizard Version: X.X.X -->
```
Set it to the latest version.

Also update the completed steps if new steps were applied:
```
<!-- Completed Steps: step-0.1, step-0.2, ..., step-update-wizard -->
```

### Step 10: Verify

Run drift detection again:
```bash
npx agentic-sdlc-wizard check
```

Report final status. All updated files should show MATCH. Files the user chose to skip will still show CUSTOMIZED — that's fine, it's their choice.

## Rules

1. **NEVER modify CLAUDE.md.** It is fully custom to the user's project. The wizard never touches it.
2. **NEVER auto-apply without showing what will change first** (unless `force-all` was passed).
3. **Offline fallback:** If WebFetch fails (network unavailable), tell the user: "Cannot reach GitHub. Run `npx agentic-sdlc-wizard init --force` to update from your locally installed CLI version instead."
4. **First-time users:** If SDLC.md doesn't exist or has no version metadata, suggest `/setup-wizard` instead of `/update-wizard`.
5. **Respect customizations.** When a file is CUSTOMIZED, the user made intentional changes. Show what's different and let them decide — don't pressure them to adopt the latest.
6. **Reference the wizard doc** for full protocol details (step registry, URLs, version tracking) rather than hardcoding values in this skill.
