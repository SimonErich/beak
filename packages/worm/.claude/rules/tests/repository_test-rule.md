---
name: repository-test
description: Rules for writing Flutter Repository unit tests
paths:
  - test/**/*_repository_test.dart
---

# Repository Tests

- Test repository methods with mocked/faked DataSource.
- Cover success path, failure path, boundary/empty inputs.
- Assert state changes, caching behavior, error propagation.
- Use `when()` to stub DataSource responses.
- Test interaction with Serverpod client if applicable.
- Verify proper error handling and typed exceptions.
