# Scenario: Version Upgrade Validation

## Complexity
Medium - Testing SDLC enforcement with new Claude Code version

## Task
Implement a simple feature following SDLC principles: Add a `formatDate` function to `src/app.js` that formats dates to ISO 8601 format.

Requirements:
- Accept a Date object as input
- Return the date in ISO 8601 format (YYYY-MM-DD)
- Handle invalid input gracefully (return null)

## Purpose

Validate that SDLC enforcement works correctly with a new Claude Code version.
This scenario runs during version upgrade testing:
1. **Phase A (Regression)**: With current SDLC docs (checks CC version didn't break us)
2. **Phase B (Improvement)**: With updated SDLC docs (checks if suggested changes help)

## Expected SDLC Compliance

### Required Steps
1. **TodoWrite/TaskCreate** - Should create task to track work
2. **Confidence stated** - Should state HIGH/MEDIUM/LOW before implementing
3. **TDD approach**:
   - Write failing test first
   - Implement function
   - Run tests to verify pass
4. **Self-review** - Review implementation before presenting

### Planning Phase
Should consider:
- Input validation (null, undefined, invalid dates)
- Edge cases (midnight, DST boundaries)
- Export pattern (add to module.exports)

## Verification Checklist
- [ ] Task created for tracking
- [ ] Confidence level stated
- [ ] Test written BEFORE implementation
- [ ] Test initially fails (TDD red phase)
- [ ] Implementation added
- [ ] Tests pass (TDD green phase)
- [ ] Self-review performed

## Success Criteria
- Test file has new test for formatDate
- Function exists and handles edge cases
- Tests pass
- TDD sequence verified in output
- Score >= baseline (no regression)
