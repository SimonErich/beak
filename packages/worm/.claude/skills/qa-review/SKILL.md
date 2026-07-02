---
name: qa-review
description: Primary workflow for ruthless generic code review of files, features, diffs, or agent output. Use when deciding whether work is acceptable and no more specific review overlay is a better fit.
role: primary_workflow
scope: general
trigger: direct_match
pairs_with:
  - qa-core
  - flutter-code-review
  - flutter-pr-review
---
# QA Review

This is the default review owner when a more specific review skill does not clearly fit.

Start with `qa-core`.

## Review Goal

Decide whether the change should be rejected, not whether it can be excused.

## Review Workflow

1. Understand the requested behavior and the claimed scope.
2. Inspect the changed code and the nearby code it depends on.
3. Look for correctness failures first.
4. Then look for complexity, duplication, and maintainability damage.
5. Then inspect tests and validation evidence.
6. Only accept when the change is both correct and maintainable.

## What To Hunt For

### Correctness

- missing cases, wrong conditions, stale state, incorrect defaults
- broken failure handling, swallowed exceptions, unsafe assumptions
- race conditions, idempotency issues, invalid state transitions

### Simplicity and Reuse

- abstractions added before they are needed
- wrappers that hide trivial code
- helpers used once
- duplicated logic that should share one implementation
- multiple sources of truth

### Maintainability

- weak naming, wide APIs, hidden coupling
- large functions or classes that should be split
- comments replacing clear code
- duplicated docs that will drift
- tests that are harder to maintain than the code they protect

### Rule Compliance

- violations of project rules, conventions, architecture, or layering
- local exceptions without justification
- new suppression comments or ignored checks

### Test Quality

- no regression test for a bug fix
- only happy-path coverage
- existence-only assertions
- over-mocking
- brittle waits, selectors, or structure-based assertions

## Reporting Rules

- Findings come first.
- Treat correctness, simplicity, reuse, maintainability, and missing tests as blocking by default.
- Distinguish clearly between `blocked`, `incomplete`, `deferred-by-user`, and `environment-limited`.
- If you did not inspect tests or run checks, say so explicitly.
- If there are no findings, state that explicitly and mention residual risks or unverified areas.

## Verdict Standard

Do not accept a change merely because it works today.

Accept only when:

- the behavior is correct
- the design is no more complex than necessary
- existing abstractions were reused where appropriate
- the code is readable without excessive commentary
- tests and checks prove the important paths
