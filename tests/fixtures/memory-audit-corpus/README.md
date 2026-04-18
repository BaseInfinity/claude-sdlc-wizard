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

- **Rule-based checks** use `type` only — any `type: user` or `type: reference` must classify to `keep` pre-LLM.
- **LLM classification** tests assert the classifier's output matches `test_expected.classification` on ≥8/10 entries.
- **Destination-selection** tests assert the LLM's suggested target matches `test_expected.target` on **6/6** promote entries.
