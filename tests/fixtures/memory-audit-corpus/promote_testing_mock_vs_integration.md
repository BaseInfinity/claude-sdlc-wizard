---
name: Integration tests catch mock drift that unit mocks hide
description: Mocked tests passing while integration tests fail = mock drift
type: feedback
test_expected:
  classification: promote
  target: TESTING.md
---

Heavy mocking in unit tests creates a silent failure mode: the mock returns the shape the test expects, but the real dependency's shape has drifted. Unit tests stay green; production breaks.

Integration tests against the real dependency (database, external API, file system) catch this class of bug. Per the Testing Diamond, prefer integration tests over unit-with-mocks for anything that crosses a real boundary.
