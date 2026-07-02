# Planning for Testability

Optional planning aid used before coding when a task is large or risky.

## Pre-Development Questions

Before writing any code, answer:

1. **What interface changes are needed?**
   - New classes, methods, or widgets the feature requires.
   - What the public API looks like from a caller's perspective.

2. **Which behaviors matter most?**
   - Core behaviors that must be tested first.
   - Order them by risk: highest-risk behavior → first test cycle.

3. **Can we design deep modules?**
   - Simple public interface, complex internal logic.
   - A deep module is easy to test (few entry points) and easy to use.
   - Shallow modules (many methods, little logic each) indicate missing abstraction.

4. **How do we optimize for testability?**
   - Constructor injection for dependencies.
   - Interface boundaries for external services.
   - Deterministic behavior (no hidden time/random/network dependencies).

## Design Rules

- Use constructor injection for dependencies.
- Put external systems behind interfaces.
- Prefer deterministic seams for time, randomness, and network.
- Keep public interfaces simple enough for behavior-first tests.

## Test Ordering Strategy

Order tests by risk and dependency:

1. **Happy path first** — Proves the core behavior works.
2. **Critical edge cases next** — Validates boundary conditions that affect correctness.
3. **Error handling** — Verifies failures are handled gracefully.
4. **Edge cases and corner cases** — Covers remaining scenarios.

Each test in this sequence drives the next slice of implementation.

## Plan Integration

For each phase, specify:
- next behavior to test first
- minimal implementation target
- refactor boundary (green only)
- checks chosen by `qa-run-checks`

## Checklist

- [ ] Interfaces and seams are testable.
- [ ] Test order is explicit.
- [ ] Plan uses one-test-at-a-time slices.
