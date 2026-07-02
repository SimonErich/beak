---
name: qa-run-checks
description: Primary workflow for choosing and running the smallest sufficient validation scope for a change. Use when deciding what checks to run after edits, during review, or inside QA loops.
role: primary_workflow
scope: general
trigger: direct_match
pairs_with:
  - qa-core
  - code-quality
  - flutter-testing
  - serverpod-testing
  - patrol-e2e-testing
---
# QA Run Checks

This skill should own validation-scope decisions. Use companion execution skills only after this workflow justifies them.

Start with `qa-core`.

## Goal

Run the cheapest set of checks that can still falsify the change with high confidence. Escalate when the blast radius grows.

## Escalation Order

1. Formatting and static analysis
2. Narrow unit or component tests
3. Narrow integration tests
4. End-to-end or workflow tests
5. Broad or full-suite validation only when shared foundations changed

## Scope Selection

Choose checks based on the real blast radius:

- isolated logic change: unit tests first
- UI behavior change: widget/component tests, then E2E only if the flow risk justifies it
- backend contract or persistence change: integration tests first
- shared abstraction, routing, auth, or infra change: broaden the test scope

## Rules

- Prefer scoped checks over full-suite runs when the scope is clear.
- Do not claim a change is verified if the relevant layer was never tested.
- Do not stop at static analysis when behavior changed.
- Do not run expensive suites just to compensate for weak local reasoning.
- If environment limits execution, report `environment-limited` and explain the missing proof.

## Pairings

- Use `code-quality` for quick static checks.
- Use `fix-all-issues` for deep cleanup loops.
- Use `flutter-testing`, `serverpod-testing`, and `patrol-e2e-testing` to choose the right test layer.
- Use `tdd-workflow` when sequencing discipline (red/green/refactor) is the primary risk.
- Use `patrol-test` only when a real end-to-end run is justified.
