# Scenario: Add Task Persistence

## Complexity
Medium - new feature requiring file I/O, error handling, and TDD

## Fixture: test-repo

## Task
Add save/load persistence to the `TaskManager` class in `src/app.js`:

1. Add `saveTo(filePath)` method:
   - Serializes tasks and nextId to JSON
   - Writes to the given file path
   - Returns the number of tasks saved

2. Add static `loadFrom(filePath)` method:
   - Reads JSON from the given file path
   - Returns a new `TaskManager` instance with restored state
   - Throws descriptive error if file not found or JSON is invalid

3. Add tests in `tests/app.test.js`:
   - Save and load round-trip preserves all task data
   - Load from non-existent file throws
   - Load from invalid JSON throws
   - nextId continues correctly after load (no ID collisions)

Use `fs` module (already available in Node). Use a temp directory for test files.

## Success Criteria
- Round-trip save/load preserves all task fields
- Error cases handled with descriptive messages
- Tests pass (`npm test`)
- No existing tests broken
- Temp files cleaned up in tests
