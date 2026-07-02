---
name: qa-core
description: Mandatory guardrail companion for review, verification, testing strategy, and completion decisions. Use it to set posture and acceptance standards whenever a QA workflow is selected.
role: guardrail
scope: general
trigger: auto_with_workflow
pairs_with:
  - qa-review
  - qa-requirements-audit
  - qa-run-checks
  - verify-implementation
---
# QA Core

This skill sets the QA posture for other review, audit, testing, and verification workflows.

## Mission

Treat generated code as untrusted until it proves itself.

QA exists to reject weak work, not to reward effort. Do not soften findings to spare feelings. If correctness, simplicity, reuse, maintainability, or conventions are weak, the change is not ready.

## Default Stance

- Assume there is a bug, a missing case, an unnecessary abstraction, and a missing test until you prove otherwise.
- Prefer the simplest correct design.
- Prefer reusing an existing abstraction over creating a new one.
- Prefer deleting duplication over documenting duplication.
- Prefer self-documenting code over explanatory prose.

## Non-Negotiables

- Reject duplicated logic, duplicated helpers, duplicated test setup, and duplicated documentation.
- Reject speculative abstractions, indirection without payoff, and helpers used only once.
- Reject comments that restate obvious code. Comments should explain `why`, constraints, or non-obvious tradeoffs.
- Reject weak naming. If names do not explain intent, the code is not self-documenting enough.
- Reject convention drift as a real defect, not a style nit.
- If the same class of violation keeps recurring, recommend enforcing it with `add-custom-lint`.

## Test Doctrine

Testing is the center of QA, not an optional follow-up.

- Every meaningful change needs the smallest test set that proves behavior and protects against regression.
- Tests must verify outcomes, not implementation trivia.
- Require success, failure, boundary, and negative/regression coverage when relevant.
- Prefer a few high-signal tests over many shallow tests.
- Prefer reusable fixtures, builders, robots, and helpers over copied setup.
- Reject tests that only prove a widget exists, a mock returned a stub, or a function was called.
- Reject brittle tests with arbitrary sleeps, unstable selectors, or assertions on incidental structure.

## Review Priorities

Check in this order:

1. Is it correct?
2. Is it simpler than the alternatives?
3. Does it reuse existing patterns instead of inventing new ones?
4. Will it still be understandable and cheap to change later?
5. Does it follow the project's rules and conventions?
6. Do tests prove that?

## Allowed Statuses

Use explicit outcomes:

- `blocked`: must be fixed before acceptance
- `incomplete`: missing proof, missing tests, or unfinished work
- `deferred-by-user`: knowingly left undone by user choice
- `environment-limited`: could not be fully verified because tooling or environment was unavailable
- `accepted`: only when the change survived review and verification

Do not use vague approvals such as "looks fine" or "probably okay".

## Recommended Pairings

- Use `qa-review` for strict code review.
- Use `qa-requirements-audit` for plan/spec vs implementation audits.
- Use `qa-run-checks` to choose and run the right validation scope.
- Use `verify-implementation` as the final quality gate.
- Use `flutter-tdd` when process discipline (one-test-at-a-time red/green/refactor) must be enforced.
- Use `flutter-testing`, `serverpod-testing`, and `patrol-e2e-testing` for layer-specific testing guidance.
- Use `create-reusable-helpers` when evaluating whether a helper should exist at all.
