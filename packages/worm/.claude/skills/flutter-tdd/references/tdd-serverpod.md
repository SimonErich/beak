# TDD Serverpod Flow

Use this file when implementing Serverpod behavior with TDD.

For test quality, coverage, and level choice, follow `serverpod-testing` and `qa-core`.

## Flow

1. Choose the layer where the risk lives (application, endpoint, persistence, stream).
2. Write one failing test for one behavior increment.
3. Run tests and confirm red.
4. Implement minimal code in the correct layer to pass.
5. Run relevant checks selected via `qa-run-checks`.
6. Refactor only when all tests are green.
7. Repeat.

## Serverpod-Specific Guardrails

- Do not batch endpoint/application tests before implementation.
- Keep tests on outcomes: returned values, persisted state, auth boundaries, rollback/commit behavior.
- If persistence or transaction behavior is the risk, use integration tests instead of mocked DB behavior.
- For bug fixes, add a regression test first, then implement.

## Pairing

- Process guardrail: `tdd-workflow` (`../SKILL.md`)
- Serverpod test decisions: `../../serverpod-testing/SKILL.md`
- Validation scope: `../../qa-run-checks/SKILL.md`
- Completion gate: `../../verify-implementation/SKILL.md`
