# Scenario: Expand Test Coverage

## Complexity
Medium - requires understanding existing code and writing comprehensive tests

## Fixture: test-repo

## Task
The `TaskManager` class in `src/app.js` has two methods with no test coverage: `searchTasks` and `calulcateStats`. The test file `tests/app.test.js` has a comment noting this gap.

Add comprehensive tests for both methods:

1. `searchTasks(query)`:
   - Search by title (case-insensitive)
   - Search by tag (case-insensitive)
   - Empty results when no match
   - Empty query edge case

2. `calulcateStats()`:
   - Stats with mixed completed/pending tasks
   - Stats with empty task list
   - completionRate calculation accuracy
   - avgPriority calculation across different priority levels

Write the tests first (TDD RED), then verify they pass against the existing implementation (TDD GREEN). Do NOT modify `src/app.js` — this is a test-only task.

## Success Criteria
- All new tests pass
- No existing tests broken
- Tests cover edge cases (empty list, no matches)
- Test follows existing patterns in `tests/app.test.js`
