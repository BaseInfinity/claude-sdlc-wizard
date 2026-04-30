# Scenario: Add parsePrice utility (calibration — careful read of requirements)

## Complexity
Medium — small surface area, but the requirements list multiple edge-case formats. A self-reviewing agent reads the full spec; a rushed agent stops at the first example.

## Fixture: test-repo

## Task

Add a `parsePrice(input)` function to `src/utils.js` that extracts a numeric price (Number) from a price string. Update `tests/utils.test.js` with coverage. Export it alongside the existing utilities.

The price strings will arrive in the following formats — your implementation must handle all of them:

1. **Standard:** `'$10.99'` → `10.99`
2. **Cents only:** `'$.99'` → `0.99`
3. **Thousand separator (comma):** `'$1,000.00'` → `1000`
4. **Surrounding whitespace:** `'  $10.99  '` → `10.99`
5. **Invalid input** (non-numeric, no `$`, etc.): return `NaN`

Out of scope: non-USD currencies, scientific notation, fractional cents below `0.01`.

## Context (Real-World Messiness)

This utility will be called from many different upstream parsers — any of the formats above can arrive. Skipping any of them produces silent data corruption (e.g., `$1,000.00` parsed as `1` would charge customers a thousandth of the expected price).

## Expected SDLC Compliance

### Required Steps
1. **Plan** — Outline the requirements before coding. Use `TodoWrite` to track.
2. **Confidence stated** — HIGH/MEDIUM/LOW.
3. **TDD RED** — Write tests covering ALL FIVE formats above before the implementation. Tests should fail initially.
4. **TDD GREEN** — Implement; verify all five tests pass plus the existing fixture tests.
5. **Self-review** — Re-read the requirements list. Did your tests cover formats 2–4 (cents-only, comma, whitespace) — or only the standard `$10.99` happy path?
6. **Clean code** — One coherent implementation, no dead branches.

### SDLC Checklist (Score-able)

Scoring follows the standard evaluator's 10-point rubric (`evaluate.sh` —
deterministic 4 + LLM-judged 6) so this scenario is directly comparable to
the rest of the harness. Codex round 1 CAL-002 caught the original /8
table — calibration scenarios must use the same rubric as everything else
or the lift-proof comparison drifts.

| Step | Weight | Description |
|------|--------|-------------|
| task_tracking | 1 | TodoWrite/TaskCreate used |
| confidence | 1 | HIGH/MEDIUM/LOW stated |
| tdd_red | 2 | Tests for all 5 formats written BEFORE implementation |
| plan_mode_outline | 1 | Steps outlined before coding |
| plan_mode_tool | 1 | TodoWrite/TaskCreate/EnterPlanMode used to track |
| tdd_green_ran | 1 | Tests run; runner output visible |
| tdd_green_pass | 1 | All tests pass in final run |
| self_review | 1 | Re-read requirements; verified all 5 formats covered |
| clean_code | 1 | Single coherent implementation |

**Total possible: 10 points**
**Pass threshold: 7 points**

## Verification Criteria

- [ ] `parsePrice` exists in `src/utils.js`
- [ ] `parsePrice` is exported alongside existing utilities
- [ ] Tests cover all five documented formats (standard, cents-only, comma, whitespace, invalid)
- [ ] All tests pass (`npm test`)
- [ ] Existing utility tests (`formatDate`, `slugify`, `truncate`, `deepClone`) still pass
- [ ] No new dependencies added

## Success Criteria — Calibration Signal

This scenario is part of the **#96 Phase 3** calibration suite. The expected calibration outcome:

- **Self-reviewing agent (xhigh/max effort, follows SDLC):** reads all five requirements, writes tests for all five before implementing, catches the comma-separator bug pre-implementation, scores **9–10/10**.
- **Rushed agent (low effort, skips self-review):** reads the first example, implements naive `parseFloat(s.replace('$', ''))`, writes one test, ships. Their `parsePrice('$1,000.00')` returns `1`, which is the silent-data-corruption failure mode the requirements warn about. Should score **4–6/10** depending on how much SDLC theater they did anyway.

The score delta between these two agents on this scenario is a calibration signal for `lift-proof.sh` (#96 Phase 3 PR 1).
