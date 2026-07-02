---
name: tdd-workflow
description: Process-first test-driven development workflow for Flutter and Serverpod using strict red-green-refactor vertical slices. Use to enforce cycle discipline; defer test content, coverage, and layer specifics to existing testing skills.
role: primary_workflow
scope: flutter
trigger: explicit_request
pairs_with:
  - qa-core
  - qa-run-checks
  - flutter-testing
  - serverpod-testing
  - verify-implementation
---

# TDD Workflow

Use this skill to enforce process discipline when implementing behavior with tests.

## Always-Apply Rules

- One test at a time.
- Every new test must fail before implementation.
- Implement only what the current failing test requires.
- Refactor only when all tests are green.
- Repeat in small vertical slices.

## Scope

This skill defines the TDD process only.

Use other skills for test standards:
- `qa-core` for QA posture and acceptance bar
- `flutter-testing` for Flutter test design and coverage
- `serverpod-testing` for backend test design and coverage
- `qa-run-checks` for minimal sufficient validation scope
- `verify-implementation` for final completion gate

## When To Use

Use this skill when:
- implementing new behavior with tests
- fixing a bug and adding regression protection
- you need to prevent horizontal slicing

Skip this skill for:
- pure refactors already covered by tests
- docs/config-only changes
- exploratory spikes where tests come later

## Routing

- Flutter implementation flow: [tdd-flutter.md](./references/tdd-flutter.md)
- Serverpod implementation flow: [tdd-serverpod.md](./references/tdd-serverpod.md)
- Optional planning aid: [planning-for-testability.md](./references/planning-for-testability.md)

## Minimal Procedure

1. Choose stack flow (`tdd-flutter` or `tdd-serverpod`).
2. Write one test for the next behavior increment.
3. Run it and confirm failure.
4. Implement minimal code to pass.
5. Run relevant tests and checks via `qa-run-checks`.
6. Refactor only on green.
7. Repeat until behavior is complete.

## Core Idea

Vertical-slice TDD prevents horizontal slicing:
- RED: one new failing test
- GREEN: minimal code to pass
- REFACTOR: improve only when green

## Ownership Split

- `tdd-workflow`: process and cycle discipline.
- `flutter-testing` / `serverpod-testing`: what and how to test.
- `qa-run-checks`: which checks to run.
- `verify-implementation`: final completion decision.

## Vertical Slice Cycle

`RED -> GREEN -> REFACTOR -> repeat`

### RED
- Write exactly one test for the next behavior increment.
- Run tests and confirm failure.
- If it passes, either behavior already exists or the test is wrong.

### GREEN
- Implement the minimum code to pass that test only.
- Do not generalize for future tests.
- Run relevant tests; all must pass.

### REFACTOR
- Refactor only when all tests are green.
- Keep behavior unchanged.
- Re-run tests after refactor.
