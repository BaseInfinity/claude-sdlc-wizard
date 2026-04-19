## Preflight Self-Review: Model Pin Opt-In (Issue #198)

**Scope:** Flip `"model": "opus[1m]"` + `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "30"` from unconditional wizard default to opt-in during setup Step 9.5. Preserves Claude Code's auto-mode for default installs.

- [x] `cli/templates/settings.json` — removed both `model` and `env` blocks; only `hooks` remain
- [x] `.claude/settings.json` (self-dogfood) — same removal, kept in sync
- [x] `skills/setup/SKILL.md` Step 9.5 rewritten as `[y/N]` opt-in prompt, default No, explicit auto-mode callout
- [x] `skills/update/SKILL.md` — new Step 7.5 migration block detects pre-#198 `opus[1m]+30` pair, prompts remove/keep/later; leaves other model values alone
- [x] `CLAUDE_CODE_SDLC_WIZARD.md` — reframed "Recommended" → "Opt-in (issue #198)"; 1M vs 200K table now shows auto-mode column + opt-in language
- [x] `tests/test-cli.sh` flipped: template has no model pin, fresh init writes no model, merge doesn't add model when missing, `--force` preserves user model. Autocompact tests similarly flipped. Two new tests: setup skill opt-in framing + update skill migration
- [x] `tests/test-doc-consistency.sh` flipped: template has no model/env, wizard doc frames opus[1m] as opt-in (mentions #198 or auto-mode), repo settings match template
- [x] Checked: skills/setup and .claude/skills/setup are hardlinks (same inode) — one edit updates both
- [x] Ran `bash tests/test-cli.sh` → 67/67 pass
- [x] Ran `bash tests/test-doc-consistency.sh` → 21/21 pass
- [x] Ran full suite across all 31 test scripts — every one reports "Failed: 0"

### Specific concerns checked
- **Auto-mode disable mechanism (root cause of #198):** verified `cli/init.js` `mergeSettings` only writes `model` when `template.model` is truthy. Template now has no `model`, so the code path is dead — fresh installs and upgrades get no pin.
- **User opt-in path survives `--force`:** test `test_merge_force_preserves_user_model` asserts a user's explicit `"model": "sonnet"` is NOT overwritten by `init --force`. Same for `test_merge_force_preserves_user_autocompact`.
- **Pre-#198 migration is non-destructive by default:** update skill Step 7.5 asks, never silently removes. Only the exact old pair (`opus[1m]` + `30`) triggers the prompt; any customization (other model, other autocompact value) is left alone.
- **Step 9.5 prompt is genuinely default-No:** wording reads "Default answer is **No**" and "`[y/N]`", and says "Make no edits" on No. Matches the test-cli regex `default.*no|\[y/N\]`.
- **Autocompact pairing still sane on opt-out:** default install with no `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` → falls back to upstream default (~95%). On 200K that's fine.

### Known limitations
- Did not run the live setup skill end-to-end in a real session — the setup skill executes in Claude Code, not in test harness. The test here is that the instruction text contains the opt-in framing; runtime behavior is left to the skill's model to execute.
- Did not test upgrade from pre-#198 on a real repo with existing `opus[1m]` pin. Update skill test checks the skill content only.
