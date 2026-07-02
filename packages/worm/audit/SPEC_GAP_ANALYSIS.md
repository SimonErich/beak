# Spec Gap Analysis — Status Tracker

This file is the canonical EPIC status tracker referenced by the
project constitution. The long-form per-feature audit lives at
[`concept/missing-worm-concept-spec.md`](../concept/missing-worm-concept-spec.md);
this file records completion status for each follow-up EPIC and is
the source of truth for "is the gap closed yet".

## Status legend

- ✓ — complete; gap closed and verified against the audit baseline.
- ◐ — partial; some sub-tasks complete, others outstanding.
- ✗ — outstanding.

## Follow-up EPIC status

| EPIC | Title | Status |
| ---- | ----- | :----: |
| EPIC-014 | Codegen contract (`@Hidden`, `@Appended`, `@Computed`, …) | ✗ |
| EPIC-015 | Connection routing per model via `@Table(connection:)` | ✗ |
| EPIC-016 | `Worm` registry deduplication | ✗ |
| EPIC-017 | Internal ticket reference sweep | ✓ |
| EPIC-018 | Scopes + Strictness wiring | ✗ |
| EPIC-019 | Auto-migration + `schema:dump` | ✗ |
| EPIC-020 | Transactions top-level | ✗ |
| EPIC-021 | Exception hierarchy completion | ✓ |
| EPIC-022 | Performance + E2E test harness | ✗ |

## ✓ EPIC-017 — Internal ticket reference sweep

- Every `WI-XXX` / `AC-N` comment removed from `lib/` and `test/`;
  `grep -rn 'WI-[0-9]\|AC-[0-9]' lib/ test/ --include='*.dart'`
  returns zero.
- Load-bearing intent (N+1 batching, hook cancellation, sealed-union
  exhaustiveness, top-level pagination rationale) rewritten in
  ticket-free language at the original site.
- Reintroduction is prevented by the `no_ticket_reference` rule in
  the sibling `worm_lints` package, wired into `worm/` via
  `analysis_options.yaml` (`analyzer.plugins: [custom_lint]`).
  `dart run custom_lint --fatal-warnings` reports the offending
  lines and exits `1` whenever the rule fires; the clean tree
  exits `0`.

## ✓ EPIC-021 — Exception hierarchy completion

- New concrete exceptions added under `lib/src/exception/`:
  `ConnectionTimeoutException`, `AuthenticationException`,
  `CheckConstraintException`, `SyntaxException`,
  `LazyLoadingException`, `MigrationLockException`,
  `IrreversibleMigrationException`, `UnsupportedOperationException`,
  `OperationCancelledException`.
- Umbrella types `ModelException` and `AdapterException` introduced
  between `WormException` and the model-layer / adapter-layer
  concrete subtypes; reparenting verified by hierarchy tests in
  `test/src/exception/exception_test.dart`.
- `DangerousQueryException` is exposed as a typedef alias for
  `FullTableScanException` in
  `lib/src/exception/dangerous_query_exception.dart`; either name is
  catchable from the other.
- Context-field naming standardized (`model` / `migration` / `field`)
  on `MassAssignmentException`, `ModelNotFoundException`,
  `RelationNotLoadedException`, `UninitializedFieldException`, and
  `MigrationException`; throw sites and tests updated.
- `toString()` outputs `ClassName: message (key: value, …)` with
  null-valued context fields omitted; every concrete exception
  carries an `@override toString()`.
- `ConfigurationException` "feature unsupported" throw sites
  migrated to `UnsupportedOperationException`:
  - `InMemoryAdapter.rawQuery` (`operation: 'rawQuery'`, adapter:
    `InMemoryAdapter`).
  - `InMemoryAdapter.rawExecute` (`operation: 'rawExecute'`,
    adapter: `InMemoryAdapter`).
  - `InMemoryAdapter.executeSchema(SchemaOperation.alter)`
    (`operation: 'executeSchema.alter'`, adapter:
    `InMemoryAdapter`).
  - `EagerLoader._aggregateSpecFor` over a non-`HasMany` /
    non-`HasOne` relation (`operation: 'aggregate.<injectionKey>'`).
- Configuration / registration throw sites (uninitialized registry
  access, missing config keys, unknown-relation lookup) intentionally
  continue to throw `ConfigurationException`.

## Verification

Run from `packages/worm/`:

```
dart analyze         # → No issues found!
dart test            # → all tests passing
dart run custom_lint --fatal-warnings   # → exit 0 on the clean tree
```
