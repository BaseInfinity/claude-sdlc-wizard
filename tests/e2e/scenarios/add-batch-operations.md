# Scenario: Add Batch Operations

## Complexity
Medium - new functionality on existing class, requires TDD and planning

## Fixture: test-repo

## Task
Add a `batchComplete(ids)` method to the `TaskManager` class in `src/app.js`:

1. Accepts an array of task IDs
2. Marks each as completed (reuse existing `completeTask` logic)
3. Returns an object: `{ completed: [...ids], failed: [{id, reason}] }`
4. Continues processing if one ID fails (does not throw on partial failure)
5. Throws if `ids` is not an array or is empty

Add tests in `tests/app.test.js` following the existing test patterns. Cover:
- Batch complete multiple tasks
- Partial failure (one valid, one invalid ID)
- Empty array throws
- All IDs invalid

Export `batchComplete` as part of the existing `TaskManager` class.

## Success Criteria
- Method works correctly for all cases
- Tests pass (`npm test`)
- No existing tests broken
- Error messages are descriptive
