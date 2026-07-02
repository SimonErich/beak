---
name: flutter-testing
description: Primary workflow for writing high-quality Flutter unit, widget, and state tests. Use when adding test coverage for Flutter code, validating UI behavior, testing Signals or view models, or reviewing whether Flutter tests are strong enough.
role: primary_workflow
scope: flutter
trigger: direct_match
pairs_with:
  - qa-core
  - qa-run-checks
  - patrol-e2e-testing
  - flutter-tdd
---
# Flutter Testing

This skill should own Flutter test-design decisions.

Start with `qa-core`.

If strict test-first sequencing is required, pair with `flutter-tdd`.

## Goal

Prove Flutter behavior with the cheapest reliable test at the correct layer.

## Choose The Smallest Useful Layer

- pure logic, mappers, extensions: unit test
- view model or state transitions: unit test with real lightweight collaborators or fakes
- widget behavior and rendering decisions: widget test
- full user workflow: only escalate to `patrol-e2e-testing` when lower layers cannot prove the risk

Do not jump to broader tests because local tests are poorly designed.

## Required Test Matrix

For each meaningful behavior, cover the relevant subset of:

- success path
- failure path
- boundary or empty input
- negative or regression case
- state transition before and after the action

Bug fixes need a regression test. New async behavior needs success and failure coverage.

## What Good Flutter Tests Assert

- user-visible output
- state changes that matter to behavior
- disabled or hidden actions when rules forbid them
- loading, error, and recovery behavior
- interaction results, not incidental widget structure

## Maintainable Test Design

- Prefer shared builders, fixtures, and test harnesses over copied setup.
- Keep each test focused on one behavior.
- Name tests as executable specifications.
- Use deterministic inputs; avoid time-based or random assertions unless controlled.
- Reuse stable selectors or semantics when interaction is needed.

## Reject These Patterns

- existence-only tests
- snapshots of incidental tree structure
- verifying mock calls instead of outcomes
- mocking the thing under test
- duplicating large setup blocks across tests
- brittle assertions tied to layout trivia or styling internals

## Minimal Review Checklist

- Does the test prove behavior rather than implementation detail?
- Does it cover at least one failure or negative path where relevant?
- Is there unnecessary duplication in the setup?
- Is the test easier to maintain than the bug it prevents?
- Would this test still be valuable after a refactor?

If the answer to any of these is no, the test is not good enough.
