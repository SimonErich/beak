---
name: flutter-code-review
description: Primary review overlay for Flutter code. Use when auditing Flutter files, features, screens, widgets, or agent-generated Flutter changes for bugs, rule violations, and maintainability risks. Layer it on top of `qa-review`.
role: primary_workflow
scope: flutter
trigger: direct_match
pairs_with:
  - qa-core
  - qa-review
  - flutter-testing
---
# Flutter Code Review

This skill owns Flutter-specific review concerns after `qa-review` establishes the generic review posture.

Start with `qa-core` and `qa-review`.

## Flutter-Specific Checks

### Architecture

- UI may not own business logic.
- State boundaries should be clear and minimal.
- Shared abstractions should be reused instead of recreated locally.

### Simplicity

- Reject widget trees or view models that became harder to read without a real payoff.
- Reject helper extraction that only hides trivial code.
- Reject duplicated presentation logic that should live in one place.

### Maintainability

- Prefer clear names over comments that explain obvious code.
- Watch for oversized widgets, wide constructors, and hidden coupling.
- Flag rebuild scope issues and unnecessary statefulness when they make the code harder to trust.

### Test Quality

- Use `flutter-testing` to judge whether tests prove behavior.
- A Flutter review is incomplete if changed behavior has no meaningful regression protection.

### Rules

- Enforce the project's Flutter, UIKit, and composition rules strictly.
- Treat convention drift as a blocking finding, not a suggestion.

## Reporting

- Findings first.
- Blocking by default for correctness, maintainability, simplicity, reuse, and test gaps.
- If no findings remain, explicitly call out any unverified areas.
