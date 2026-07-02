# Metadata
**Project:** Worm ORM — Dart package in the `beak` monorepo
**Version:** 0.x pre-release (breaking renames permitted; no stability guarantees)
**Audit baseline:** commit `d6f6796` at `packages/worm/` (722/722 passing tests)
**Scope:** All packages in `packages/` — `worm`, `worm_generator`, `worm_postgres`, `worm_mongodb` — share this specification and constitution
**Authoritative sources:**
1. `worm_concept.md` — public API surface (names, signatures, semantics)
2. Constitution document — principles, architecture, governance, testing, performance
3. Audit (`SPEC_GAP_ANALYSIS.md`) — current state vs. spec; priority matrix for follow-up work
4. This spec — synthesis of findings, user decisions, and next-phase requirements

**Key constraint:** Spec examples must compile literally against the code; if not, aliases or renames are added to the code, never the spec.

---

# Source Concept References
- **worm_concept.md** (authoritative spec document) — 2200+ lines covering vision, architecture, models, queries, relations, migrations, seeders, factories, adapters, events, validation, serialization, scopes, soft-deletes, pagination, transactions, CLI, logging, strictness, performance, testing, error handling, naming conventions
- **Constitution document** — principles (type safety, spec compliance, no dead code, no internal ticket references, public API intentionality, Active Record default, one ORM multiple adapters, typed escape hatches), architecture (monorepo layout, barrel exports, registry, connection routing, codegen contract, adapter contract, CLI exit codes), testing (five tiers: unit, contract, integration, E2E, perf regression), UX (naming conventions, error context, CLI structure, mass assignment, strictness escape hatch, docs gating), performance (hard targets, required optimizations, forbidden patterns, slow-query budget), governance (source of truth precedence, change classification, epic discipline, no partial implementations, no skipped hooks, adapter parity, internal references decay, constitution amendments)
- **Audit findings** (v2, committed 2026-05-23) — 100+ specific gaps mapped to code locations; cross-cutting issues (duplicate Worm class, dead code, unused annotations, public-but-internal model state, spec method-name mismatches); recommended follow-up EPICs (EPIC-009 through EPIC-022, with EPIC-023 added as a prerequisite)

---

# Clarified Requirements

**From user answers (resolving prior ambiguities):**

1. **Macros permanently deferred.** Spec aspiration removed; `build_runner` + `source_gen` is the sole codegen path. Constitution updated.

2. **Adapter-state-based transaction queue for `afterCommit`.** The `afterCommit` callback queue lives on the `DatabaseAdapter` (one queue per active transaction); `Worm.transaction` drains it on commit. Clean, testable, no Zone complexity. Blocks EPIC-009 and EPIC-020.

3. **Short operator names are canonical.** Code uses `Operator.eq`, `Operator.gt`, etc.; spec was updated to match. No rename. Code already correct; spec was aspirational. Aliases may be added for user convenience but spec baseline is the short names.

4. **All 7 unused annotations marked `@experimental` immediately.** `@Hidden`, `@Appended`, `@Attribute`, `@CastAs`, `@Fillable`, `@Guarded`, `@Computed` are real annotation classes but have no runtime or codegen consumer. Marking them `@experimental` with a one-line doc stating "consumer not yet shipped" is honest and additive, breaking no existing code. Prevents silent failures for early adopters.

5. **Flat `List<Observer>` is canonical.** Observer registration is `List<Observer>` where each observer self-declares its model type via a `modelType` getter. Spec example updated to match. The type-keyed map shown in prior spec versions is not adopted; the flat list is more extensible (no `Type` ceremony, no duplicate-observer-type conflicts).

6. **Validation uses `Map<Field, List<ValidationRule>>` on Model.** Migrated in EPIC-009 as a 0.x breaking change. Current code uses a separate `Validatable` interface with string keys; that gets replaced. All models updated, all validation tests updated in the same PR.

7. **EPIC-023 (Codegen foundation) is a prerequisite.** EPIC-013 (Relations runtime) and EPIC-015 (Annotation wiring) both depend on the generator emitting relation constants (`User$.posts`) and processing annotations at codegen time. A dedicated EPIC-023 blocks both until it ships.

---

# In Scope

## Core ORM Lifecycle (EPIC-009 finish-out)
- `Model.update(map)` — fill + save shortcut
- `Model.forceDelete()` — unconditional hard delete (lifted from SoftDeletes mixin to every Model)
- `Model.replicate({except: [...]})` — deep copy with new ID, unsaved
- `Model.withoutEvents(callback)` and `Model.withoutEvents([Type, ...], callback)` static muting
- Validation auto-fire in `Model.save()` between `beforeValidate` and `afterValidate` hooks
- `beforeRestore` and `afterRestore` lifecycle events (new enum values; wired through SoftDeletes)
- Transaction-scoped `afterCommit` queue (depends on EPIC-018/020 transaction infrastructure)
- Typed `Map<Field, List<ValidationRule>> rules` getter on Model (breaking change; replaces Validatable interface)
- `updateRules` override for dirty-fields-only validation
- Annotate `Model.relations`, `Model.injectedFields`, `Model.state` with `@internal` or move behind package-private accessors
- Typed `getOriginal<T>(Field<T> field)` overload for stronger static safety

## Query Builder Surface (EPIC-012 completion)
- Scalar aggregate terminals: `sum`, `avg`, `min`, `max` (push down to adapter, never load all rows)
- Streaming terminals: `stream`, `chunk(size, callback)`, `streamChunks(size)` for memory-bounded iteration
- Boolean composition methods: `whereGroup((q) => q.where(...).orWhere(...))`, `whereExists<T>`, `whereColumn(left, right)`
- Query inspection: `toSql()`, `toMongoFilter()`, `explain()`, `debug()` chainable
- Convenience overloads for `where`: 2-arg `where(field, value)` and 3-arg `where(field, op, value)`
- Typed-generic `withoutGlobalScope<X extends GlobalScope<T>>()` (reads `X.name` at compile time)
- Adapter-context gates: `.sql((q) => q.join(...).having(...))` and `.mongo((q) => q.rawFilter({...}).pipeline([...]))`
- `whereRaw(sql, params, allowRaw: true)` escape hatch

## Relations Runtime (EPIC-013, blocked on EPIC-023)
- Typed relation accessors on Model instances: `user.posts.add(post)`, `user.posts.dissociate()`, `user.roles.attach(id)`, `user.roles.detach([ids])`, `user.roles.sync([ids])`
- Constrained eager loading: `withRelation(rel, (q) => q.where(...))`
- Nested eager paths: `User$.posts.include([Post$.comments])`
- `OnDelete.ormCascade` runtime behavior (ORM walks children before parent delete, unlike DB cascade)
- Polymorphic type resolution via central morph-type registry (currently per-relation maps)

## Factory + Seeder (EPIC-011)
- Factory: `.count(n)`, `.create([overrides:])`, `.has(otherFactory, rel)`, `.for_(parent, rel)`, `.sequence([{...}, ...])`, expose `faker` getter on base class
- Seeder: create and track idempotent runs in `worm_seeders` table (via `SeederRecordStore`); add `Seeder.order`; introduce `DatabaseSeeder` master pattern
- `Worm.beginTestTransaction()` and `rollbackTestTransaction()` for test isolation

## Annotation Wiring (EPIC-015, blocked on EPIC-023)
- Codegen reads `@Hidden` → Serializer skips field in output
- Codegen reads `@Appended` → adds getter to hydration extension
- Codegen reads `@Computed` → adds readonly getter (no DB column)
- Codegen reads `@CastAs(DurationCast)` → injects cast into `CastManager`
- Codegen reads `@Fillable`/`@Guarded` → overrides `Model.fillable`/`guarded` lists
- Add `DurationCast` (Duration ↔ milliseconds integer)

## Adapter API Alignment (EPIC-010, critical blocker)
- Rewrite `worm_postgres` compiler against post-EPIC-004 query/schema API
- Rewrite `worm_mongodb` compiler against post-EPIC-004 query/schema API
- Both mix in `ExplainCapable` (required for slow-query debugging)
- Rewrite and re-enable `adapter_contract.dart` harness; run against all three adapters in CI
- Pre-merge gate: `worm_postgres` and `worm_mongodb` must compile + pass contract tests

## Transactions Top-Level (EPIC-020, unblocks EPIC-009)
- `Worm.transaction<T>((txn) async { ... })` static helper with optional `connection:` override
- `Model.save(transaction:)` and `Model.delete(transaction:)` propagation
- `txn.savepoint(() async {})` for DB savepoint support (Postgres-only capability)
- Transaction-scoped `afterCommit` queue (adapter holds one queue per active txn)

## CLI Extensions + Migration Refinements (EPIC-019)
- `worm make:migration --auto` (wire DiffEngine into the CLI)
- `worm schema:dump --prune` flag honored (schema squashing)
- Migration `dependsOn` ordering enforcement
- Composite foreign keys and partial-unique indexes on `IndexDefinition`

## Strictness + Scopes (EPIC-018)
- Auto-application of `@GlobalScope` on every `QueryBuilder<T>` (codegen-driven extension)
- Codegen of typed scope extension methods (not just `List<String> scopeNames`)
- Lazy-loading prevention (throw when accessing unloaded relation in strict mode)
- Read-side `preventFullTableScans` enforcement (`.get()` without `.where()` throws in strict)
- `Worm.unsafe(() async { ... })` escape hatch for bypass; bounds documented
- Unify `preventFullTableScans` and `preventDestructiveWithoutWhere` (currently overlapping; pick one or document distinction)

## Naming + API Aliases (EPIC-014)
- Operator method aliases: `Operator.equals`, `Operator.notEquals`, `Operator.greaterThan`, etc. as `static const` pointers
- Field method aliases: `whereIn`, `whereNotIn` on field operators
- Blueprint aliases: `table.id()` (UUID), `table.intId()` (auto-incr)
- Migration signature: wrap `Migration.up(DatabaseAdapter)` to accept `Schema` facade matching spec
- Support `cursorPaginate(perPage:, after:)` (code currently uses `cursor:`)

## Internal Cleanup (EPIC-016, EPIC-017)
- Delete `lib/src/registry/worm_registry.dart` (duplicate Worm class; dead code accessible only via direct import)
- Delete `test/src/registry/worm_registry_test.dart` (test that anchors dead code)
- Strip every `WI-XXX` and `AC-N` comment from `lib/` and `test/` (internal ticket references)
- Replace with intent-described comments where load-bearing
- Add lint rule preventing reintroduction

## Exception Hierarchy (EPIC-021)
- Add missing exception types: `ConnectionTimeoutException`, `AuthenticationException`, `CheckConstraintException`, `SyntaxException`, `LazyLoadingException`, `MigrationLockException`, `IrreversibleMigrationException`
- Add umbrella types: `ModelException`, `AdapterException`
- Add `UnsupportedOperationException` (currently `ConfigurationException` is thrown)
- Add `OperationCancelledException` (for hook cancellation in-band propagation)
- Alias `FullTableScanException` ↔ `DangerousQueryException` (spec name vs. code name)
- Standardize error-context fields on all exceptions: `table`, `column`, `query`, `migration`, `model` where applicable

## Performance + Testing (EPIC-022)
- Lazy attribute hydration (load only columns from `select([...])`, not entire row)
- Concurrent relation loading via `Future.wait` in eager loader (not sequential per-relation)
- `IN` chunking at 1000 IDs in `InMemoryAdapter` and adapters
- E2E CLI workflow tests (empty project → `init` → `make:model` → `migrate` → `db:seed` → query)
- Performance regression tier suite (10k single inserts, 1k+5k batched eager-load, 50k streamed rows with memory threshold)

## Codegen Foundation (EPIC-023, prerequisite)
- Emit typed relation field constants: `User$.posts`, `User$.profile`, etc. as `RelationField<...>` references
- Codegen reads relation annotations and emits accessor methods on model companions
- Codegen reads custom annotations and passes to runtime consumers (Serializer, CastManager, Model.fillable/guarded)
- No `as` casts in generated code (cast-free constraint from constitution)
- Scope generator emits callable extension methods, not just `List<String> scopeNames`

---

# Out of Scope

- **Macro-based codegen path.** Build_runner is sole mechanism. Macros deferred indefinitely.
- **Multi-database schema sync.** No per-database DDL state machine (schema is per-connection).
- **Sharding / horizontal scaling.** No distributed transaction coordination, shard routing, or cross-shard eager loading.
- **GraphQL / REST API auto-generation.** ORM is not a framework; API layer is application responsibility.
- **GUI migration builder.** CLI tool is the primary interface.
- **Real-time change notifications.** No pub/sub on row changes (application-level event system suffices).
- **Full-text search or trigram indexes.** Adapters may support, but not ORM-owned semantics.
- **Audit trail auto-instrumentation.** Application layer builds this on top of hooks.
- **Row-level security policies.** Authorization is application responsibility; ORM has no RLS support.

---

# Non-goals

- **Backward compatibility with 0.0.x.** 0.x permits breaking renames; no deprecation period.
- **Support for legacy SQL dialects.** Postgres (modern), MongoDB (5.0+), in-memory adapter only.
- **Multiple language bindings.** Dart / Kotlin only; other languages are separate implementations.
- **ORM-driven schema versioning beyond migrations.** Migrations are source-of-truth; schema inference tools are out of scope.
- **Query result caching or materialized views.** Application layer uses caching; ORM is data-accessor.
- **Transparent encryption at the column level (beyond `EncryptedCast`).** `EncryptedCast` is available; transparent storage encryption is adapter responsibility.
- **Custom JSON serialization per-model.** Standard Serializer with descriptor configuration is sufficient.

---

# User Decisions

1. **Macros permanently deferred.** Only `build_runner` + `source_gen` codegen path implemented. Constitution updated to reflect build_runner as sole mechanism. Spec aspirations removed.

2. **Short operator names are canonical.** `Operator.eq`, `Operator.gt`, `Operator.gte`, `Operator.lt`, `Operator.lte`, `Operator.neq` are the authoritative names. Spec updated to match. Aliases for long-form names optional for UX; not required.

3. **Keep flat `List<Observer>` form as canonical.** Observer self-declares model type via `modelType` getter. Type-keyed map form shown in earlier spec versions is not adopted. Flat list is more extensible and avoids duplicate-type conflicts.

4. **Mark all 7 unused annotations `@experimental` immediately.** `@Hidden`, `@Appended`, `@Attribute`, `@CastAs`, `@Fillable`, `@Guarded`, `@Computed` are marked with `@experimental` from `package:meta` and a one-line doc comment stating "runtime consumer has not shipped." Honest, additive, breaks no existing code. Remove from the barrel export when the consumer ships (or after the consumer ships and stable 1.0 is reached).

5. **Adapter-state-based transaction queue for `afterCommit`.** The callback queue lives on `DatabaseAdapter` (one per active transaction). `Worm.transaction` drains on commit. No Zone complexity. Unblocks EPIC-009 and EPIC-020.

6. **Validation uses `Map<Field, List<ValidationRule>>`  on Model.** Migrate in EPIC-009 as a 0.x breaking change. Current `Validatable` interface (string keys) is replaced. All models, tests, validator updated in single PR.

7. **EPIC-023 (Codegen foundation) is a blocking prerequisite.** EPIC-013 (Relations runtime) and EPIC-015 (Annotation wiring) both depend on the generator emitting relation constants and processing annotations. EPIC-023 ships before either.

---

# Open Blockers

None. All prior ambiguities resolved by user answers above.

---

# Codebase Findings

**Audit baseline:** commit `d6f6796`, `packages/worm/` (722/722 passing tests, `dart format` clean, `dart analyze` clean).

## What is implemented and tested
- **Model lifecycle:** save, delete, refresh, fill, dirty tracking, timestamps, mass assignment, all 11 hooks (except `beforeRestore`/`afterRestore`), observer dispatch
- **QueryBuilder:** chainables (where, order, limit, offset, select, distinct, relations, counts), terminals (get, first, find, count, exists, pluck, update, delete, paginate, cursorPaginate)
- **Relations:** all 11 relation types as metadata holders; PivotManager with attach/detach/sync; eager loader with batched queries
- **Migrations:** runner, record store, Blueprint schema builder (not user-facing `Schema` facade), DiffEngine (not wired to CLI), migration template
- **Seeders:** runner, environment filter
- **Factory:** base class with state variations, inline transforms, makeMany
- **Validation:** 16 rules, validator engine, separate Validatable interface (string-keyed)
- **Serialization:** Serializer with cycle detection, depth limiting, reference replacement
- **Scopes:** LocalScope, GlobalScope, auto-application, withoutGlobalScope (string-keyed), scope dispatch
- **Soft deletes:** mixin with delete/restore/forceDelete, trashed scope, blueprint helper
- **Pagination:** Page<T>, CursorPage<T>, paginate, cursorPaginate with cursor encoding
- **Logging:** QueryLogger, NPlusOneDetector, MissingIndexWarner, ExplainRunner, ExplainCapable mixin
- **Strictness:** config flags (preventFullTableScans, preventDestructiveWithoutWhere, warnOnN1Queries, etc.)
- **Exceptions:** 16 concrete subtypes with context fields
- **CLI:** 15 commands (all working; some flags partial)
- **InMemoryAdapter:** complete implementation, all contract methods
- **Event system:** EventDispatcher, full hook enum (11 values), observer registration, event cancellation

## What is incomplete or missing
- `afterCommit` fires immediately, not after transaction commit (needs transaction-scoped queue)
- Validation does not auto-fire in Model.save (validator not invoked between beforeValidate/afterValidate)
- No `Model.update(map)` convenience method
- No top-level `Model.forceDelete()` on every model (only on SoftDeletes mixin)
- No `Model.replicate()` method
- No `Model.withoutEvents()` static muting
- No scalar aggregate terminals (sum, avg, min, max) — only injection variants
- No streaming terminals (stream, chunk, streamChunks)
- No whereGroup, whereExists, whereColumn boolean composition
- No query inspection (toSql, explain, debug)
- No 2-arg / 3-arg where overloads
- No adapter-context gates (.sql(), .mongo()) with AdapterMismatchException
- No typed relation constants (User$.posts) — scope generator emits only List<String>
- No relation accessor methods on Model (user.posts.add, user.roles.attach)
- No constrained eager loading (withRelation with filter)
- No nested eager paths
- No OnDelete.ormCascade runtime behavior
- No Factory.create() persistence path, .count(n), .has, .for_, .sequence()
- No faker getter on Factory base class
- Seeders not tracked (SeederRecord class exists but unused; SeederRunner doesn't write tracking rows)
- No Worm.transaction static helper
- No Model.save(transaction:) propagation
- No savepoint support
- No make:migration --auto wiring
- No schema:dump --prune flag enforcement
- No dependsOn migration ordering enforcement
- Duplicate Worm registry class exists (dead code)
- 27+ internal ticket reference comments survive (WI-XXX, AC-N)
- 7 annotations declared but unused (@Hidden, @Appended, @Attribute, @CastAs, @Fillable, @Guarded, @Computed)
- No DurationCast
- worm_postgres ~120 analyzer errors (pre-EPIC-004 API)
- worm_mongodb ~77 analyzer errors (pre-EPIC-004 API)

## Code smells
- Public mutable internal model state (relations, injectedFields, state)
- String-keyed withoutGlobalScope instead of typed-generic
- Lazy-loading not enforced in strict mode
- Eager loader loads relations sequentially, not concurrently
- SoftDeletes.delete() fires Save lifecycle (beforeSave/afterSave) instead of Delete lifecycle
- Page<T> uses `data` not `items`, `hasMorePages` not `hasNextPage`/`hasPrevPage`, cursorPaginate uses `cursor:` not `after:`
- Adapter contract harness analyzer-excluded (pre-EPIC-004 API)
- worm_config_test.dart analyzer-excluded (references may be stale)
- Migration template uses SchemaDescriptor instead of user-facing Schema facade

---

# Existing Implementations

## Ready to reuse (no changes needed)
- `EventDispatcher`, `LifecycleEvent` (11 hooks), `ModelObserver` — use as-is for EPIC-009 hooks
- `PivotManager` (attach/detach/sync) — wrap with typed relation accessor for EPIC-013
- `Serializer` with cycle detection — expose via `Model.toMap`/`toJson` for EPIC-009
- `FakerService` (130 lines, seedable) — expose as getter on Factory for EPIC-011
- `SeederRecord` (57 lines) — wire into SeederRunner tracking for EPIC-011
- `DiffEngine` — wire into CLI for EPIC-019 make:migration --auto
- `InMemoryAdapter` — adapter layer is complete; use as gold standard
- `ExplainCapable` mixin and `ExplainRunner` — adopt on worm_postgres / worm_mongodb for EPIC-010
- `NPlusOneDetector` and `MissingIndexWarner` — already in use

## Ready to refactor (minor changes)
- `QueryBuilder` — add scalar aggregate terminals, streaming terminals, composition methods, query inspection
- `scope_generator` — add callable extension-method emission (not just List<String>)
- `active_record.dart` — inject Validator invocation, wire afterCommit to transaction queue
- `ActiveRecord.save` — add `transaction:` parameter, dispatch new restore hooks
- `FieldOperators` — add aliases (whereIn, whereNotIn, etc.)
- `Blueprint` — add method aliases (id(), intId(), etc.)
- `eager_loader.dart` — parallelize via Future.wait
- Migration runner — respect dependsOn ordering

## To delete (dead code)
- `worm_registry.dart` (140 lines) — duplicate Worm class, unreachable except via direct import
- `test/src/registry/worm_registry_test.dart` — anchors dead code

---

# Technical Constraints

1. **Type safety is absolute.** No `dynamic` except documented interop (single location); no `Object`/`Object?` when concrete type fits; no `Map<String, dynamic>` as domain type; no `as` casts in hand-written code; `!` only when non-nullness proven by surrounding code. Generated code must be cast-free.

2. **Spec example compilation.** If a spec code sample would not compile against the current API, aliases or overloads are added to the code. Spec examples are the golden truth for user-facing shape.

3. **Adapter parity.** `worm_postgres` and `worm_mongodb` must compile and pass the adapter-contract harness before any PR merges to main that touches `worm` public API. EPIC-010 priority: critical.

4. **No partial implementations on main.** A feature ships annotation → codegen → runtime → test or stays on a branch. Half-baked features mislead users and rot as the codebase evolves. Example: do not land `@Hidden` codegen without Serializer consuming it.

5. **Dirty-only UPDATE enforcement.** When a model is dirty, `save()` must emit SQL touching only dirty columns, never full-row. Currently wired via `Model.state` population; maintained when adding new persistence paths.

6. **Batched eager loading.** N parents + M children → exactly 2 adapter queries (parent batch + child IN-batch), never N+M. IN chunking at 1000 IDs per chunk for adapters that require it.

7. **Transaction-scoped callback queue.** `afterCommit` callbacks must not fire until the outermost transaction commits. Immediate fire-after-save is a correctness bug. Mechanism: adapter-state-based queue.

8. **No string-keyed escape hatches where type fits.** `withoutGlobalScope(String)` is replaced with `withoutGlobalScope<X extends GlobalScope<T>>()`. Validation rules keyed by `Field<T>` not `String`. Global scope bypass reads `GlobalScope.name` at compile time.

9. **Connection routing per model.** `@Table(connection: 'mongo')` annotation is parsed and stored. At runtime, `Model.connectionName` returns the override; codegen injects a per-model override getter. Per-model connection must be honored in all adapter queries.

10. **CLI exit codes match package:args conventions.** `UsageException` → `2`; uncaught exception → `1`; success → `0`.

---

# Best-Practice Guidance

## For Feature Implementers (EPIC EPICs 009-022)
- **Start from the feature you are changing, expand outward.** Before touching a file, read the constitution section on that subsystem. Understand the existing patterns.
- **Reuse before building.** If a class, method, or helper exists (even unused), wire it up rather than rewrite it. Example: `FakerService` already exists; expose as a getter on Factory base.
- **Test behavior, not existence.** A test asserting "method exists" or "mock returned a value" is not a test. Assert the observable effect (row was inserted, relation was loaded, hook fired in order, exception carries context).
- **Fakes and stubs over mocks.** Mock libraries are for cases where a fake is genuinely impractical.
- **Regression test every bug fix.** Reproducer fails first; fix second; test stays.

## For Code Review (QA Gate: EPIC-010+)
- **Run the constitution checklist.** Does the PR touch public API? Matches spec example? Spec updated in same PR? Regression test? Type-safe (no `as` casts)? No dead code introduced? No internal ticket comments?
- **Verify adapter parity.** If worm public API changed, do worm_postgres and worm_mongodb still compile? Do they pass contract tests?
- **Pre-merge gate:** `dart format --set-exit-if-changed .`, `dart analyze`, `dart test` clean in both `packages/worm/` and `packages/worm_generator/`. Once adapters compile, extend gate to all four packages.

## For Architecture Decisions
- **Constitution first.** If uncertain, check the constitution section. If still unclear, amend the constitution in a dedicated chore PR (link the audit rows that justify the change).
- **0.x blessing.** Breaking renames are permitted freely at 0.x; no deprecation period. Use this as cover to fix API shape while the project is young.
- **Macro deferral.** Do not investigate macro-based codegen. Build_runner is sole mechanism. If a future phase reconsiders, it would be a separate architecture review.

---

# Package Considerations

## `packages/worm/` (core library)
- Public barrel: `lib/worm.dart` (single entry point, non-negotiable)
- Internal source: `lib/src/` (all subsystems)
- Public test harness: `lib/testing/` (includes adapter-contract test factory)
- CLI binary: `bin/worm.dart`

## `packages/worm_generator/` (codegen via build_runner)
- Wraps in-package generators from `worm/lib/src/codegen/`
- Must ship callable via `dart run build_runner build`
- EPIC-023 expands generator to emit relation constants and process annotations

## `packages/worm_postgres/` (adapter)
- Implements `DatabaseAdapter` contract fully
- Mixes in `ExplainCapable` for EXPLAIN support
- Must pass `adapter_contract.dart` harness against current `worm` API
- Currently ~120 analyzer errors (EPIC-010 target)

## `packages/worm_mongodb/` (adapter)
- Implements `DatabaseAdapter` contract fully (adapts Mongo client, not SQL)
- Mixes in `ExplainCapable` (Mongo `explain` command)
- Must pass `adapter_contract.dart` harness
- Currently ~77 analyzer errors (EPIC-010 target)
- Requires replica set for transaction support (noted in docs; not enforced)

## Versioning and Release
- All packages share 0.x version (no stability guarantees).
- Breaking API changes require updated audit entries and spec changes in same PR.
- Tag each release (`0.x.y`) across all four packages simultaneously.
- Adapter packages can lag code if they are not ready; pre-merge gate enforces compilation + contract pass as prerequisite for main merge.

---

# Risks

1. **Adapter packages do not compile (EPIC-010 dependency).** All downstream features that touch the query or schema API depend on adapters being able to compile. EPIC-010 unblocks everything. Mitigation: prioritize EPIC-010 before touching public API.

2. **Transaction-scoped callback queue is new architecture.** `afterCommit` fix requires adapter-state-based queue (or alternative mechanism). If the design is wrong, transactions themselves may regress. Mitigation: full test coverage of transaction nesting, concurrent requests, exception rollback.

3. **Codegen foundation (EPIC-023) blocks two EPICs.** EPIC-013 and EPIC-015 cannot start until EPIC-023 ships. Slippage in EPIC-023 cascades. Mitigation: scope EPIC-023 narrowly (relation constants + annotation readers, nothing else).

4. **Breaking change to validation API (EPIC-009).** Switching from `Validatable` (string-keyed) to `Map<Field, List<ValidationRule>>` on Model affects every model and every test that uses validation. Large surface area for bugs. Mitigation: migrate in single PR with comprehensive test updates; freeze other changes.

5. **Lazy hydration complicates select optimization.** Only hydrating columns from `select([...])` requires careful handling in eager-load paths (may need to re-fetch unselected columns). Mitigation: scope laziness narrowly in EPIC-022; mark unselected columns as "not loaded" rather than null; provide `refresh(select: [...])` to re-fetch.

6. **Performance targets may not be met.** 10k inserts < 5s, 50k stream < 50MB growth. If InMemoryAdapter meets them but Postgres/Mongo don't, the bottleneck is adapter-specific, not ORM. Mitigation: establish per-adapter thresholds in EPIC-022; don't wait for all adapters to hit the same target.

7. **Seeder tracking table is a schema migration.** Adding `worm_seeders` table requires a framework migration. Existing projects that upgrade will not auto-create the table. Mitigation: seeder runner gracefully handles missing table (logs warning, skips tracking); users run a one-time migration to add it.

8. **Scope generation can generate incorrect extension names.** If a scope's `name` getter is wrong or duplicates clash, generated extensions won't compile. Mitigation: codegen unit test validates every scope's name for uniqueness; docs recommend kebab-case scope names.

---

# Planning Handoff Notes

## EPIC Sequencing
1. **EPIC-010** (Adapter alignment) — unblock all downstream work; highest priority.
2. **EPIC-023** (Codegen foundation) — relation constants + annotation readers; prerequisite for EPIC-013 and EPIC-015.
3. **EPIC-009** (Model finish-out) — depends on EPIC-020 (transactions) for afterCommit fix; unblock EPIC-020 later.
4. **EPIC-020** (Transactions top-level) — can ship in parallel with EPIC-009 if afterCommit queue is deferred to a follow-up CL.
5. **EPIC-013** (Relations runtime) — depends on EPIC-023; can ship in parallel with EPIC-015.
6. **EPIC-015** (Annotation wiring) — depends on EPIC-023; can ship in parallel with EPIC-013.
7. **EPIC-012** (QueryBuilder surface) — independent; can ship any time.
8. **EPIC-011** (Factory + Seeder) — independent; can ship any time.
9. **EPIC-014** (Spec API aliases) — quick win; alias methods, no structural changes.
10. **EPIC-018** (Scopes + Strictness) — depends on EPIC-023 (codegen of scope extensions).
11. **EPIC-019** (CLI + Migrations) — independent; mid-priority.
12. **EPIC-016** (Worm deduplication) — quick cleanup; can be merged early.
13. **EPIC-017** (Internal references sweep) — low-priority cleanup; can batch into other PRs.
14. **EPIC-021** (Exception hierarchy) — low-priority; fills in missing types.
15. **EPIC-022** (Performance + E2E testing) — last; depends on most of the above being complete.

## Key Decisions Locked In
- Build_runner is sole codegen mechanism (macros deferred indefinitely).
- Operator short names (eq, gt) are canonical; spec matches code, not vice versa.
- Flat `List<Observer>` form is canonical; observers self-declare model type.
- All 7 unused annotations marked `@experimental` immediately (no removal).
- Validation uses typed `Map<Field, List<ValidationRule>>` on Model (breaking change in EPIC-009).
- Adapter-state transaction queue for `afterCommit` (clean, testable design).
- EPIC-023 prerequisite for EPIC-013 and EPIC-015 (unblock parallel work on both).

## Assumptions Baked In
- InMemoryAdapter is the gold standard; all other adapters match its contract.
- Constitution principles are non-negotiable (type safety, spec compliance, no dead code, adapter parity, no partial implementations).
- 0.x permits breaking renames (no deprecation period).
- Audit (`SPEC_GAP_ANALYSIS.md`) is the source of truth for current state; keep it updated after each EPIC ships.

## How to Track Progress
- Update the audit's Executive Summary table after each EPIC ships (flip the `Status` cell from `⚠` to `✓`, move EPIC from "Recommended Follow-up Epics" to a "Completed" section).
- Use the audit as a checklist: each feature row is a specific gap; each EPIC resolves a subset of rows.
- Run `dart format`, `dart analyze`, `dart test` clean in all packages before merging.
- EPIC-010 (adapter alignment) is the gating item; all others follow.