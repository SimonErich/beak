---
name: widget-test
description: Rules for writing Flutter widget tests
paths:
  - test/**/*_widget_test.dart
---

# Widget Tests

- Assert user-visible output, state changes that affect behavior.
- Test disabled/hidden actions, loading, error, recovery behavior.
- Use stable semantic selectors; avoid layout-trivia dependencies.
- Test interaction results, not incidental widget tree structure.
- Keep tests focused on one behavior.
- Reject: existence-only, snapshots of incidental tree.
