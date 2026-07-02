---
name: fix-all-issues
description: Fixes all linting and analysis issues.
user-invocable: true
disable-model-invocation: true
---
# Fix All Issues

## Goal

Drive a large batch of quality problems to completion without hiding defects.

## Cleanup Loop

1. Apply safe autofixes and formatting: `$ dart format .`
2. Run static analysis checks: use skill @qa-checks
3. Fix remaining issues manually.
4. Re-run the relevant tests for any behavior touched.
5. Repeat until clean or explicitly blocked.

## Rules

- Never suppress warnings to fake a clean result.
- When the same class of problem appears repeatedly, recommend a lint instead of repeated manual policing.

## Output

Report:

- what was auto-fixed
- what required manual fixes
- what remains blocked
- what still needs behavior-level verification
