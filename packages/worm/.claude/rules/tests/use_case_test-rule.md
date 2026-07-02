---
name: use-case-test
description: Rules for writing Flutter UseCase unit tests
paths:
  - test/**/*_use_case_test.dart
---

# UseCase Tests

- Test every public method: happy path + edge cases + validation failures.
- Use mocktail to mock collaborators (Repository).
- Verify collaborator calls with correct arguments via `verify()`.
- Test exception paths (e.g., throwsArgumentError).
- Use `when()` to stub responses; no hand-rolled fakes.
- Name tests as executable specifications.
