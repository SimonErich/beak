---
name: tdd-loop
description: The mandatory red/green/refactor workflow for every Beak phase, plus how to structure and run tests per package and how to satisfy the coverage gate.
---

# tdd-loop

Every phase is built **test-first**. No implementation is written before a failing test
that specifies it. This is how you keep an unattended build honest.

## The cycle (per unit of behavior)

1. **RED** — write the smallest test that expresses the next required behavior. Run it.
   Confirm it fails for the *right* reason (missing type/method, wrong result — not a
   compile error in the test itself).
2. **GREEN** — write the minimum code to pass. Nothing speculative.
3. **REFACTOR** — clean names, extract, remove duplication. Keep tests green.
4. Repeat until the phase's public API and Definition of Done are fully covered.

Rules: never weaken/skip/delete a test to go green. Never `// ignore:` a lint to pass
analysis — fix the code. Prefer many small tests over few broad ones.

## Where tests live

- Dart packages (`beak_core`, `beak_backend`, `beak_cli`): `test/`, run with
  `dart test`. Mirror the `lib/src/...` path in `test/...`.
- Flutter package (`beak_frontend`): `test/`, run with `flutter test`
  (`flutter_test` + widget tests). Golden image tests only where visual regressions
  matter; prefer semantics/behavior assertions.
- Integration tests that need Postgres/MinIO go in `test/integration/` and are tagged
  (`@Tags(['integration'])`) so unit runs stay fast; the phase gate runs both.

## Package-specific patterns

- **beak_core** — pure unit tests, zero I/O. Golden JSON tests for `BeakQuerySpec`
  serialization (encode → decode → deep-equal, and pin the exact JSON map). Rule
  enforcement tested per rule. Storage abstraction tested via an in-memory driver.
- **beak_backend (logic)** — worm `InMemoryAdapter` + `Worm.reset()` in `tearDown`;
  drive Shelf handlers with `shelf` `Request`/`Response` directly and assert status +
  JSON body. Use `LoggingAdapter` + `InMemoryQueryLogger` to assert query counts
  (reference-dedup / N+1 proofs).
- **beak_backend (integration)** — bring services up via `melos run up`, wait for
  health, run real CRUD + upload against Postgres + MinIO, tear down.
- **beak_frontend** — pump widgets with a fake `BeakDataSource` (in-memory), assert
  rendered obers_ui widgets, tap actions, verify the emitted `BeakQuerySpec` and
  optimistic/undo behavior. Never hit a real network in widget tests.

## worm test harness (reuse verbatim)

```dart
setUp(() async { Worm.seedRandom(42); await createTestDatabase(); });
tearDown(Worm.reset);
```
`createTestDatabase()`: `InMemoryAdapter()` → `connect()` → `executeSchema(...)` →
`Worm.initialize(...)`. `Worm.reset()` in tearDown is mandatory (double-init throws).

## Coverage gate

- Default threshold: **≥ 85% line coverage per package** (higher for `beak_core`; aim
  100% there since it is pure). `melos run coverage` computes and enforces it.
- Coverage is a floor, not a goal: cover branches and error paths, not just happy paths.
  A phase with 90% coverage but an untested failure mode is not done.

## Definition of Done recap (all green, every phase)

`melos run analyze` (0 issues) · `melos run test` (all pass, no skips) ·
`melos run coverage` (≥ threshold) · `melos run format-check` (clean) · plus the
phase's own proofs. Only then mark `✅ DONE`, update `STATE.md`, and commit.
