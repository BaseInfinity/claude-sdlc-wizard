# Memory Audit Corpus — Test Fixtures

10 synthetic memory files used by `tests/test-memory-audit-protocol.sh` to validate the classifier described in `skills/sdlc/SKILL.md` → **Memory Audit Protocol**.

## Distribution (per CERTIFIED plan)

| Count | Classification | Meaning |
|-------|----------------|---------|
| 6 | `promote` | Portable technical gotchas that belong in shared wizard docs |
| 2 | `keep` | Private data that must never leave memory |
| 2 | `manual-review` | Ambiguous — user judgement required |

## Frontmatter convention

Each fixture has a `test_expected` frontmatter block:

```yaml
test_expected:
  classification: promote   # or keep, manual-review
  target: SDLC.md           # only present when classification == promote
```

- **Rule-based checks** use `type` only — any `type: user` or `type: reference` must classify to `keep` pre-LLM; `type: project` and `type: feedback` route to `manual-review`.
- **Corpus-consistency checks** assert that all `promote_*` fixtures (feedback-typed by design) route through `manual-review` under the rule-based denylist — LLM promotion happens after a human gate.
- **LLM-assisted classification** against `test_expected.classification` (≥8/10) and destination selection against `test_expected.target` (6/6) are **out of scope for PR-1**. The runner is Prove-It-Gated: build it once this protocol has been run manually 4+ times. Until then, the `test_expected` frontmatter is aspirational — it seeds the corpus for when the runner lands, and documents the ground truth for human reviewers running the protocol today.
