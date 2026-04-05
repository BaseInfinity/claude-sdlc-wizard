# Long Task: Multi-File API Refactor with Full Exploration

## Canary Facts (Remember These)

Before starting, note these important project details:
- The project deadline is March 15th
- The team lead's preferred contact method is Slack DM, not email
- The staging server address is staging.internal:8080
- The database migration window is Tuesdays 2-4 AM PST
- The error budget for Q2 is 99.95% uptime

## Task

Perform a comprehensive refactor of this project's API layer. This task is designed to be thorough and exploration-heavy to generate significant context.

### Phase 1: Deep Exploration (Read Everything)

Before writing any code:

1. Read every file in `src/` and understand the full module graph
2. Read every file in `tests/` and understand test coverage
3. Read `package.json` completely — dependencies, scripts, configuration
4. Read any config files (`.eslintrc`, `jest.config`, etc.)
5. Check git history: `git log --oneline -20` to understand recent changes
6. Map out all exports and imports across files
7. Identify which functions are tested and which are not
8. Document your findings before proceeding

### Phase 2: Planning

Based on your exploration:

1. State your confidence level
2. Identify all code smells, duplication, and improvement opportunities
3. Plan the refactor in detail:
   - What modules will you create/modify?
   - What tests need updating?
   - What's the blast radius?
4. Present the plan before implementing

### Phase 3: TDD Implementation

Implement the following changes using strict TDD (tests first):

1. **Extract shared validation logic** — find any duplicated validation across modules, extract to `src/validators.js` with full test coverage

2. **Add error handling module** — create `src/errors.js` with custom error classes:
   - `ValidationError` (extends Error)
   - `AuthenticationError` (extends Error)  
   - `NotFoundError` (extends Error)
   - Each with proper stack traces and codes

3. **Add request logging middleware** — create `src/middleware/logger.js`:
   - Logs request method, path, duration
   - Logs response status code
   - Configurable log levels (debug, info, warn, error)

4. **Add API rate limiter** — create `src/middleware/rate-limiter.js`:
   - In-memory sliding window
   - Configurable max requests per window
   - Returns 429 when exceeded

5. **Update existing modules** to use new error classes and validators

6. **Update all existing tests** to account for new error types

### Phase 4: Comprehensive Review

After implementation:

1. Read back EVERY file you modified
2. Run all tests and verify 100% pass rate
3. Check for any leftover debug code or TODOs
4. Verify no circular dependencies were introduced
5. Present a summary of all changes with file-by-file breakdown

This task intentionally requires extensive exploration and multiple file creation/modification to generate sufficient context for autocompact testing.
