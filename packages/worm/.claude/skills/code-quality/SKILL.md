---
name: code-quality
description: Manual execution workflow for quick static quality checks. Use when validating formatting, analysis, and lightweight quality gates before or after a change. Do not use this skill for broad cleanup or iterative fixing; use `fix-all-issues` for that.
role: manual_execution
scope: general
trigger: explicit_request
disable-model-invocation: true
---
# Code Quality

This is an execution skill for narrow static feedback, not a primary implementation workflow.

Start with `qa-core` and `qa-run-checks`.

## Goal

Use this skill for fast static feedback, not for deep cleanup campaigns.

## Scope

- formatting checks
- static analysis
- lint execution
- quick autofix preview where appropriate

## Rules

- Run the smallest relevant static checks first.
- Treat static failures as blocking until fixed or explicitly deferred.
- Do not use this skill as a substitute for behavior tests when behavior changed.
- Do not add ignores or suppressions just to turn the check green.

## Escalate When Needed

If static issues are widespread or repetitive, switch to `fix-all-issues`.
If the same violation keeps recurring, consider `add-custom-lint`.
