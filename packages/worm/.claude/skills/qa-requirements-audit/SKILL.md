---
name: qa-requirements-audit
description: Primary workflow for auditing requirements, plans, or specs against an implementation. Use when checking what is missing, partially implemented, risky, or unsupported by tests.
role: primary_workflow
scope: general
trigger: direct_match
pairs_with:
  - qa-core
  - qa-run-checks
---
# QA Requirements Audit

This skill should own requirements-vs-implementation audits. Prefer it over compatibility wrappers such as `implementation-matrix`.

Start with `qa-core`.

## Goal

Turn a plan, spec, or user request into a strict completion audit.

## Process

1. Extract each distinct requirement.
2. Group requirements by behavior, data, validation, permissions, UX, and tests.
3. Search for implementation evidence.
4. Mark each requirement as `done`, `partial`, `missing`, `blocked`, or `unverified`.
5. Record the gap, not just the existence of a file.

## Evidence Standard

A requirement is not `done` because a symbol or file exists.

It is only `done` when:

- the intended behavior is implemented
- edge and failure behavior are handled
- the design follows conventions
- tests or other validation prove the requirement

## Required Output

Use a matrix like this:

```markdown
| ID | Requirement | Status | Evidence | Gap |
|---|---|---|---|---|
| R-01 | User can submit valid form data | partial | Submit flow exists | No invalid-input coverage |
| R-02 | Duplicate submissions are rejected | missing | No guard found | Add server and UI protection |
```

Then summarize:

- highest-risk missing behavior
- missing tests
- duplicated or overcomplicated implementation
- recommended implementation order

## Audit Rules

- Prefer behavioral evidence over structural evidence.
- Count missing tests as missing implementation proof.
- Call out unnecessary complexity even when the feature technically exists.
- If repeated gaps follow the same pattern, recommend a reusable fix or lint rule.
