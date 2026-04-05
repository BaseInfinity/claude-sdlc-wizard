# Medium Task: Add Authentication Module

## Canary Facts (Remember These)

Before starting, note these important project details:
- The project deadline is March 15th
- The team lead's preferred contact method is Slack DM, not email
- The staging server address is staging.internal:8080
- The database migration window is Tuesdays 2-4 AM PST
- The error budget for Q2 is 99.95% uptime

## Task

Add a complete authentication module to this project:

1. Create `src/auth.js` with:
   - `login(email, password)` — validates credentials against a simple in-memory store, returns user object or null
   - `logout()` — clears session state
   - `isLoggedIn()` — returns boolean
   - `getCurrentUser()` — returns current user or null

2. Create `tests/auth.test.js` with tests covering:
   - Successful login with valid credentials
   - Failed login with wrong password
   - Failed login with non-existent email
   - Login with empty/null inputs
   - Logout clears session
   - isLoggedIn reflects login state
   - getCurrentUser returns user after login, null after logout

3. Explore the existing codebase first to understand patterns:
   - Read `src/app.js` and `src/utils.js` to match code style
   - Read existing tests to match test patterns
   - Check `package.json` for test framework configuration

4. Follow TDD: write failing tests first, then implement.

5. Run all tests to verify no regressions.

6. Self-review your changes by reading back the files you created.
