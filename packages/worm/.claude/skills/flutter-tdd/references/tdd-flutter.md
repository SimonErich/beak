# TDD Flutter Flow

Use this file when implementing Flutter behavior with TDD.

For test quality, coverage, and layer choice, follow `flutter-testing` and `qa-core`.

## Flow

1. Choose the smallest Flutter layer that can prove the behavior (from `flutter-testing`).
2. Write one failing test for one behavior increment.
3. Run tests and confirm red.
4. Implement minimal code to pass only that test.
5. Run relevant checks selected via `qa-run-checks`.
6. Refactor only when all tests are green.
7. Repeat.

## Flutter-Specific Guardrails

- Do not write batches of widget/state tests before implementation.
- Keep tests on public behavior (UI output or observable state), not internals.
- Prefer deterministic seams (clock/random/network injected behind boundaries).
- For bug fixes, add a regression test first, then implement.

## Pairing

- Process guardrail: `tdd-workflow` (`../SKILL.md`)
- Flutter test decisions: `../../flutter-testing/SKILL.md`
- Validation scope: `../../qa-run-checks/SKILL.md`
- Completion gate: `../../verify-implementation/SKILL.md`
