## Preflight Self-Review: `allowedTools` → `permissions.allow` (Issue #197)

**Scope:** Flip Setup Step 9 from writing a top-level `allowedTools` array to writing `permissions.allow`. Add Update skill migration for pre-#197 users. Update wizard doc references. A top-level `allowedTools` in project settings silently disables Claude Code's auto-mode classifier — same failure family as #198 (model pin).

- [x] `skills/setup/SKILL.md` Step 9 rewritten: recommends `permissions.allow`, shows exact JSON shape, explains why `allowedTools` is deprecated
- [x] `skills/update/SKILL.md` Step 7.6 added: detects `allowedTools`, four branches (only legacy → prompt m/k/l, both → conflict prompt, only new → no-op, neither → no-op); byte-for-byte preservation during migration
- [x] `CLAUDE_CODE_SDLC_WIZARD.md` (3 spots): `add gh CLI to allowedTools` → `permissions.allow`; `"allowedTools": [...]` example block → `"permissions": { "allow": [...] }`; `Tool permissions (for allowedTools)` → `permissions.allow`; Adaptive section now names `permissions.allow` with historical note; hook-pattern example now says "Same syntax as `permissions.allow`"
- [x] `tests/test-cli.sh` two new tests: `test_setup_skill_step9_writes_permissions_allow` (grep for `permissions.allow`, reject recommendation patterns like "suggest allowedTools entries" / "write the allowedTools"), `test_update_skill_has_allowedtools_migration` (grep for migration language + issue #197 ref)
- [x] Preserved merge-compat tests: existing tests that verify the CLI merge preserves a user's legacy `allowedTools` still pass (never clobber user data)
- [x] Ran `bash tests/test-cli.sh` → 68/68 pass
- [x] Ran full test suite across 31 scripts — all `Failed: 0`
- [x] Negative control: temporarily reverted Step 9 to "suggest allowedTools entries", test fails loudly; restored, passes

### Specific concerns checked
- **Existing `allowedTools` in user settings is never clobbered:** `test_merge_preserves_custom_keys_and_adds_wizard_hooks` in test-cli.sh continues to pass — the merge doesn't touch user-level keys outside hooks/model/env.
- **Fixture `complex-existing-config/.claude/settings.json` still has legacy `allowedTools`:** kept intentionally. That fixture exercises the migration path in future update-skill tests (not added in this PR — could be a follow-up if we want a runtime migration test harness).
- **CI workflow `allowedTools` references (test-workflow-triggers.sh, ci.yml `claude_args: --allowedTools`):** left alone. Those are CLI args to the Claude Code Action, not project `settings.json`. Different surface, different semantics.
- **Hook pattern syntax text at line 406:** updated to name `permissions.allow` as the reference, since the pattern syntax is identical.

### Known limitations
- Did not run the setup/update skills end-to-end in a real Claude Code session (they execute in the skill model runtime, not in a test harness).
- Did not verify the migration against a real wizard-pre-#197 project. The update-skill test checks content only.
