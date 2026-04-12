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
https://raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/main/CHANGELOG.md
```

Extract the latest version from the first `## [X.X.X]` line.

### Step 3: Compare Versions and Show What Changed

Parse all CHANGELOG entries between the user's installed version and the latest. Present a clear summary:

```
Installed: 1.24.0
Latest:    1.30.0

What changed:
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
https://raw.githubusercontent.com/BaseInfinity/agentic-ai-sdlc-wizard/main/CLAUDE_CODE_SDLC_WIZARD.md
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
