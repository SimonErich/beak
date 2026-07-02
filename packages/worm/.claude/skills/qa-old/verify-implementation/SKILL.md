---
name: verify-implementation
description: Mandatory guardrail companion and final quality gate after edits. Use after implementing features, fixing bugs, or changing behavior to decide whether the work is truly complete. This is a completion guardrail, not the primary implementation workflow.
role: guardrail
scope: general
trigger: auto_with_workflow
pairs_with:
  - qa-core
  - qa-run-checks
  - qa-review
---
# Verify Implementation

Start with `qa-core`.

Use this skill at the end of the task to decide whether completion is justified after the primary workflow and checks are done.

## Goal

Decide whether the change is complete, not whether it is close enough.

## Verification Workflow

1. Identify the real blast radius.
2. Use `qa-run-checks` to choose the smallest sufficient validation scope.
3. Use the relevant testing skill:
   - `flutter-testing`
   - `serverpod-testing`
   - `patrol-e2e-testing`
   - Pair `flutter-tdd` if strict red/green/refactor sequencing was required by the task
4. Use `qa-review` if design, duplication, or maintainability is in doubt.
5. Reject completion if important behavior is still unproven.

## Required Gates

- behavior is correct
- failure handling is explicit
- complexity is justified
- existing abstractions were reused when appropriate
- naming is self-documenting enough
- new or changed behavior has regression protection at the right level
- relevant static checks pass
- relevant scoped tests pass

## Completion States

- `accepted`: all relevant proof exists
- `blocked`: failing checks, broken behavior, or rule violations
- `incomplete`: missing tests, missing validation, or missing implementation
- `deferred-by-user`: user knowingly chose to stop short
- `environment-limited`: required checks could not be run

Do not mark work complete under any other label.

## Escalation Rules

- If a bug was fixed without a regression test, the work is incomplete.
- If a shared abstraction changed, broaden the validation scope.
- If repeated rule violations keep appearing, recommend `add-custom-lint`.
- If required checks cannot run, state exactly what proof is still missing.

## Reporting Format

```markdown
## Verification Result

Status: blocked | incomplete | deferred-by-user | environment-limited | accepted

Checks run:
- ...

Blocking findings:
- ...

Missing proof:
- ...
```
