---
name: flutter-pr-review
description: Primary workflow for reviewing a Flutter pull request. Use when reviewing a Flutter PR, validating a diff before merge, or checking whether changed Flutter code should be accepted. Layer it on top of `qa-review` and `flutter-code-review`.
role: primary_workflow
scope: flutter
trigger: direct_match
pairs_with:
  - qa-core
  - qa-review
  - flutter-code-review
---
# Flutter PR Review

This skill should own Flutter PR review work rather than competing with generic review skills as a peer.

Start with `qa-core`, `qa-review`, and `flutter-code-review`.

## PR Workflow

1. Read the stated goal of the PR.
2. Review the full diff, not just the latest file touched.
3. Check whether the changed code is simpler, clearer, and more reusable than before.
4. Verify that tests and checks match the real blast radius.
5. Reject the PR if important behavior, conventions, or maintainability are unproven.

## PR-Specific Questions

- Does the diff introduce avoidable abstraction or duplication?
- Did the PR move logic to the correct layer?
- Did shared patterns stay consistent across the changed files?
- Are tests proving the changed behavior instead of just exercising the code path?
- Would another agent likely copy this pattern and make the codebase worse?

## Verdict Rules

- `request changes` is the default when there are blocking findings or missing proof.
- `approve` is allowed only when the diff is correct, convention-compliant, maintainable, and sufficiently tested.
- If checks were not run or could not run, say so explicitly and treat the review as incomplete.
