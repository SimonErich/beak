---
name: integration-test
description: Rules for writing Patrol E2E integration tests
paths:
  - integration_test/**/*test.dart
---

# Integration Tests

- Super expensive - REJECT redundant integration tests.
- Use E2E only when risk spans UI + state + networking + persistence.
- Each scenario proves one critical user outcome in the happy path.
- Use stable selectors; wait on real readiness, not arbitrary sleeps.
- Keep test data deterministic; reuse shared robots/fixtures.
- Reject: giant multi-feature scenarios, no durable outcome assertion.
- Run via `patrol test -t integration_test/...` or `patrol-screenshot integration_test/...` to include screenshots
