# Worm Spec Audit — Gaps and Issues (v2, deep rewrite)

Generated **2026-05-23**, against merged main at commit `d6f6796` (post EPIC-000/002/004/005/006/007 + monorepo restructure).

Audit baseline: `dart format` clean, `dart analyze` clean, `dart test` passes **722 / 722** in `packages/worm/` and **9 / 9** in `packages/worm_generator/`. Sibling adapters `packages/worm_postgres/` (~120 errors) and `packages/worm_mongodb/` (~77 errors) do not compile — same root cause (pre-EPIC-004 query API) and tracked as EPIC-010 below.

This file is the single source of truth for **what the merged code actually implements** vs **what [worm_concept.md](worm_concept.md) describes**, word-for-word. Every claim cites `file:line`.

Severity legend: **Critical** (blocks core ORM use) · **High** (key feature missing) · **Medium** (nice-to-have) · **Low** (cosmetic / docs).
Status legend: ✓ Implemented · ⚠ Partial · ✗ Missing · ✗ Wrong · ○ Untested.

---

## SQLite Adapter + Cross-DB Optimization Pass (2026-06-14)

**New `worm_sqlite` package.** A full third backend was added (in-process via the `sqlite3` package, system `libsqlite3` — no server needed): `SqliteCompiler` (descriptors → parameterised `?`-placeholder SQL incl. joins / GROUP BY / HAVING / grouped-aggregate push-down / IN-chunking under the 999-param limit), `SqliteRunner` (shared execution engine for the adapter + its transaction wrapper), `SqliteAdapter` (`.memory()` / `.open(path)` factories, `PRAGMA foreign_keys = ON`, savepoints, EXPLAIN QUERY PLAN), and `SqliteErrorMapper` (UNIQUE/PK/FK extended result codes → typed exceptions). **52 tests pass** — the full adapter contract suite (CRUD, operators, composition, sort/pagination, aggregations incl. grouped, schema, streaming, raw, transaction rollback), compiler goldens, and integration (unique-violation mapping, transaction rollback, eager-load + grouped aggregates). One bug was caught and fixed while building it: the transaction wrapper initially re-wrapped the caller's rollback exception (same class of bug found earlier in Mongo) — fixed so the original exception propagates unchanged.

**Cross-DB verification (live).** All six packages green: `worm` 1194, `worm_generator` 21, `worm_postgres` 130 (live PG 16), `worm_mongodb` 105 (live Mongo 7 replica set), `worm_sqlite` 52 (in-process), `worm_lints` clean. The grouped-aggregate push-down and the relation+aggregate eager-load path are each verified against InMemory + Postgres + Mongo + SQLite.

**Complex-query measurement (live SQLite).** A multi-relationship + nested + grouped-aggregate query over **500 users / 2 500 posts / 7 500 comments** resolves in **5 SELECTs, ~27 ms** — constant query count regardless of row volume (no N+1), nested children batched per level, aggregates rolled up in the DB.

**SQLite-specific perf win implemented:** `insertMany` now emits batched multi-row `INSERT … VALUES (…),(…)` (chunked under the param limit) instead of one statement per row.

### Remaining optimization potential

**Performance.** (a) ✓ **SQLite prepared-statement cache + WAL implemented.** `SqlitePreparedCache` (bounded LRU, dispose-on-evict, hit/miss metrics, cleared on DDL) compiles each distinct SQL once and reuses it; `connect()` now sets `journal_mode = WAL` + `synchronous = NORMAL` + `foreign_keys = ON`, and `insertMany` batches multi-row inserts. Measured on in-process SQLite: bulk-insert 10 000 rows in ~16 ms; 10 000 cached single-row selects in ~46 ms at a **0.0001 miss rate** (one compile, 9 999 reuses). A **read connection pool was deliberately not built**: the `sqlite3` binding is synchronous, so within one Dart isolate queries already serialise — a pool yields no concurrency there and would hand out separate empty in-memory databases; cross-isolate concurrency is a different architecture (one connection per isolate) and out of scope. (b) Mongo's grouped-aggregate pipeline could pass `allowDiskUse` for very large group sets. (c) An opt-in identity map / second-level cache would dedupe repeated loads within a unit of work. (d) Lazy/streaming hydration for very large result sets (`stream()` exists; model-level streaming chunking is wired).

**Security.** Parameterisation is now verified across all three SQL dialects (`$N` for PG, `?` for SQLite, native BSON for Mongo) plus the NoSQL operator-injection guard and escaped `LIKE`→regex. Next: full-database encryption-at-rest as an adapter option (SQLCipher for SQLite; field-level `EncryptedCast` already exists); document the raw escape hatches (`whereRaw`, `.sql` HAVING expression, `.mongo(rawFilter:)`) as the only developer-trusted surfaces.

**Developer experience.** The same typed, declarative API now drives three databases through one `DatabaseAdapter` contract — swapping backends is a one-line `Worm.initialize` change. Next DX steps: `Worm.sqlite(path)` / `Worm.postgres(url)` convenience constructors, and surfacing the `MissingIndexWarner` + an FK-auto-index default in the migration generator.

### Perf #2 (eager-load column projection) — design boundary, not a gap

Projecting a subset of a related model's columns conflicts with worm's **strict typed hydration**: generated `fromRow` constructs the model through an all-required constructor and throws `FormatException` on any missing non-nullable column. Useful column projection therefore requires **partial-model support** (a separate construction path + per-instance loaded-column tracking + access guards) — a substantial, design-heavy feature, not a quick projection flag. The clean, already-available projection paths are `pluck` (single column → typed list), `.sql((q) => q.select([...]))` (raw rows), and `withCount`/`withSum` (no hydration — now DB-rolled-up). Recommendation: keep typed eager loading as full-model by contract; add partial models only as a deliberate, separately-designed feature.

---

## Performance Analysis & Improvements (2026-06-14)

Deep-dived the complex-query execution paths (multi-relationship eager loading, nested relations, `withCount`/`withSum` aggregates, joins, multi-table filters). The core architecture is sound: eager loading is **batched** (constant query count regardless of row count — a new perf benchmark proves a relation + 2 aggregates issues exactly **4 SELECTs** for both 100 and 1000 parents, no N+1), dirty-tracking emits minimal UPDATEs, and Postgres pools connections + caches prepared statements.

**Improvements implemented (all green, incl. a live-Postgres integration test):**
- **Concurrent eager loading.** Independent top-level relation loads and aggregate injections now run via `Future.wait` instead of sequentially, cutting a multi-relationship query's latency from sum-of-round-trips to the slowest single one. Gated on `Worm.currentTransaction == null` so it never issues overlapping queries on a transaction's single connection. Validated against the live Postgres pool.
- **Aggregate query projection.** `withCount`/`withSum`/`withExists` previously fetched **every child column** of **every child row** to roll up in Dart; they now project only the grouping key (`[fk]`) plus, for SUM, the summed column — slashing wire + hydration cost.
- **`exists()` short-circuits.** Was `COUNT(*) > 0` (scans all matches); now a `LIMIT 1` probe via `selectOne` that stops at the first row.

**Follow-up round (also implemented, verified live):**
- **DB-side aggregate push-down ✓.** `withCount`/`withSum`/`withExists` no longer fetch N child rows: a new `DatabaseAdapter.aggregateGrouped` runs a `GROUP BY fk` rollup returning one value per parent. The base class ships a default (in-memory rollup, so third-party adapters need no change); **Postgres** overrides it with `SELECT fk, COUNT(*)/SUM(col) … GROUP BY fk` and **Mongo** with a `$group` pipeline. Verified by an adapter-contract test running against InMemory + live Postgres + live Mongo. Turns O(child rows) transfer into O(parents).
- **Join projection guidance ✓.** `SqlQueryContext` now documents that `.join(...)` should pair with `.select([...])` (a bare join is `SELECT *`, which collides same-named columns across tables) and that the joinless `withRelations` path is the recommended default for loading related models.

**Recommended next (documented, larger scope — not yet implemented):**
1. **Column projection for eager-loaded relations.** Let `withRelation`/`withRelations` request a subset of child columns for wide tables. Requires a per-relation column API plus threading a projection through every relation type's `loadWithFilter` (only 3 of ~10 currently override it) — a consistent feature is its own focused effort and an API-design decision, not a partial bolt-on.
2. **Index guidance.** Foreign-key columns used by eager loads / aggregate rollups (`posts.user_id`, …) and any `groupBy` column should be indexed; the `MissingIndexWarner` already flags un-indexed scans when the adapter supports `EXPLAIN`. Worth surfacing in user docs + the migration generator's defaults (auto-index FK columns).

---

## Live-DB Verification + Security Audit (2026-06-14)

The adapter suites were run against **real databases in Docker** (Postgres 16; MongoDB 7 replica set). Final state: `worm` **1193**, `worm_generator` **21**, `worm_postgres` **127** (live PG), `worm_mongodb` **103** (live Mongo) — all green, all five packages `analyze` + `format` clean.

**Three real bugs found (only a live DB exposed them) and fixed:**
- **Mongo `insert`/`insertMany` silently swallowed write errors** — a unique-key violation returned "success". Now the `WriteResult`/`BulkWriteResult` is inspected and surfaced as `UniqueConstraintException` via `MongoErrorMapper.fromWriteCommandError`. (Data-integrity bug; regression-tested.)
- **Mongo scalar aggregations (`sum`/`avg`/`min`/`max`) all threw** — the pipeline was `List<Map<String, Object?>>` where `modernAggregate` requires `List<Map<String, Object>>`. Fixed the top-level stage typing (group body keeps `_id: null`).
- **Postgres prepared-statement-cache test** measured lifetime miss-rate including `setUp` DDL; reset to measure steady-state.

**Security audit — strong posture, no injection vectors in normal use:**
- **Postgres: no SQL injection.** Every value is bound server-side as a `$N` parameter (verified `session.execute(sql, parameters:)` binds, never re-interpolates); identifiers go through `_quoteIdent` (escapes `"`); savepoint names are internally generated (`worm_sp_<n>`); `LIMIT`/`OFFSET` are typed ints. `RawNode` (`whereRaw`) still parameterizes its values; HAVING `expression` is a documented developer-only escape hatch.
- **Mongo:** values pass as native BSON (no string concatenation); `LIKE`→regex is `RegExp.escape`d (no regex/ReDoS injection). **Added a NoSQL operator-injection guard** (`_guardScalar`) that rejects `$`-keyed map values in scalar predicates (e.g. `{$ne: null}`), covering `eq`/comparison/`in`/`between`; regression-tested.

**Mongo transactions — made honest (driver limitation).** `mongo_dart` 0.9.4 has no client-session / transaction API, so atomic multi-document commit/rollback is impossible. The adapter previously claimed `supportsTransactions: true` on a replica set while providing no isolation/rollback — an unsafe false guarantee. Now `supportsTransactions` is `false` and `transaction()` throws a clear `TransactionException` citing the driver; the misleading `replicaSetEnabled` flag and the dead `MongoTransactionAdapter` were removed. Real Mongo transactions require a transaction-capable driver (tracked as a follow-up).

---

## Finishing Pass — Completion Update (2026-06-14)

The remaining open EPICs in "Recommended Follow-up Epics" below were completed in a finishing pass. The per-section tables and Executive Summary further down are point-in-time at `d6f6796` and were **not** rewritten — this block is the authoritative status for the items it lists. Current health: all five packages `dart analyze` clean; `worm` **1193** tests pass, `worm_generator` **21**, `worm_postgres` **74** (+3 DB-gated skipped), `worm_mongodb` **57** (+3 skipped), `worm_lints` clean.

Resolved:

- **EPIC-009 (Model finish-out):** ✓ `Model.update(map)`, top-level `Model.forceDelete()`, typed `getOriginalValue<T>(Field<T>)`, parameterized `toMap({only, hidden, includeRelations, maxDepth})`; validation now auto-fires inside `save()` via typed `Map<Field, List<ValidationRule>> rules` / `updateRules` (dirty-only on update); `relations`/`injectedFields`/`state` marked `@internal`; `afterCommit` now defers until transaction commit (see EPIC-020); `beforeRestore`/`afterRestore` added and wired through `SoftDeletes.restore()`. **Note:** `replicate({except})` is a base method that throws by default with a `replicatedAttributes({except})` helper for overrides — Dart cannot construct a subtype generically and the constructor-based hydration round-trip is unsafe to auto-generate, so this is the clean, honest shape rather than generator emission.
- **EPIC-011 (Factory + Seeder):** ✓ Seeder `muteEvents` flag wired through `Worm.withoutEvents`. (Factory `count/create/has/for_/sequence/faker`, seeder tracking/order/`DatabaseSeeder`, and `beginTestTransaction` were already delivered pre-pass.)
- **EPIC-012 (QueryBuilder surface):** ✓ `withCount(rel, filter:)`, `insertMany([...])` terminal, typed `withRelations([RelationField])` (string form renamed `withRelationPaths`), and SQL `join`/`leftJoin`/`groupBy`/`having` on `SqlQueryContext` compiled by both `SqlCompiler` and the Postgres compiler. (Scalar aggregates, streaming, boolean composition, `toSql`/`explain`, and the `.sql()`/`.mongo()` gates were already present.)
- **EPIC-018 (Strictness):** ✓ global `preventSilentMassAssignment` now enforced in `Model.fill` (relaxed inside `Worm.unsafe`).
- **EPIC-020 (Transactions):** ✓ `Worm.transaction((txn) async {}, {connection})` with join-on-nest semantics, `Model.save/delete(transaction:)` propagation, `TransactionContext.savepoint()` (capability-gated; `InMemoryAdapter` now supports savepoints via nested snapshots), and transaction-scoped `afterCommit` draining on commit / discard on rollback.
- **EPIC-014 / §25 (Naming):** ✓ `NamingConvention` now handles irregular plurals, `-x/-ch/-sh`, `-y`, `-f/-fe`, uncountables, and last-segment pluralization, plus `pivotTableName(a, b)` (reused by the generator).
- **EPIC-015 (Annotation wiring) / §5.6:** ✓ `CustomCast<T>(fromDb:, toDb:)` convenience cast added. (`@Hidden`/`@Appended`/`@Computed`/`@CastAs`/`@Fillable`/`@Guarded` wiring and `DurationCast` were already delivered.)
- **Per-model connection routing (§2/§3):** ✓ generator emits a `connectionName` override from `@Table(connection:)`.
- **EPIC-022 (Performance/E2E):** ✓ a performance regression tier already exists at `test/src/performance/performance_regression_test.dart` (10k inserts, 1k+5k eager-load 2-query assertion, 50k-stream memory bound).

---

## Corrections to v1 of this audit

The first version of this file (commit `c9e7145`) was rushed. Several material claims were wrong, and many subtle gaps were missed. This rewrite corrects them. The corrections, in order of impact:

1. **§5 Model:** v1 called `Model` a "5-member marker, no save/delete/refresh." Reality: [model.dart](packages/worm/lib/src/model/model.dart) is 206 lines and has `save`, `delete`, `refresh`, `fill`, `isDirty`, `dirtyFields`, `setAttribute`, `getAttribute`, `getOriginal`, `hydrateAttribute`, `markPersisted`, `withoutTimestamps`, `afterCommit`, `getInjected`, `exists`, `tableName`, `connectionName`, `primaryKeyColumn`, `createdAtColumn`, `updatedAtColumn`, `usesTimestamps`, `fillable`, `guarded`, `strictMassAssignment`, plus the `ModelHooks` mixin with all 11 lifecycle hooks. The Active-Record orchestration is in a separate 199-line [active_record.dart](packages/worm/lib/src/model/active_record.dart). `Repository<T>` exists at [repository.dart:34](packages/worm/lib/src/model/repository.dart#L34). What's actually missing: `replicate`, top-level `update(map)`, top-level `forceDelete`, `Worm.withoutEvents` static muting.
2. **§12 Events / observers:** v1 said "two-line marker, no dispatcher." Reality: full event subsystem — [event_dispatcher.dart](packages/worm/lib/src/event/event_dispatcher.dart) (65 lines), [lifecycle_event.dart](packages/worm/lib/src/event/lifecycle_event.dart) (76 lines, enum has all 11 spec hooks), [lifecycle_handler.dart](packages/worm/lib/src/event/lifecycle_handler.dart) (27 lines), [model_observer.dart](packages/worm/lib/src/event/model_observer.dart) (103 lines). What's actually missing: `Worm.withoutEvents`, deferred-until-commit semantics on `afterCommit` (the callback fires immediately after the local op, not after the wrapping transaction commits — see [active_record.dart:192–198](packages/worm/lib/src/model/active_record.dart#L192)), `beforeRestore` / `afterRestore` in the soft-delete path.
3. **§6 QueryBuilder:** v1 claimed `exists`, `pluck`, `firstOrFail`, `findOrFail`, `select`, `distinct`, `cursorPaginate`, `withoutGlobalScope` were "missing from builder." All are present in [query_builder.dart](packages/worm/lib/src/query/query_builder.dart) at lines 297, 300, 243, 273, 127, 134, 356, 138. What's actually missing: scalar aggregate terminals (`sum`/`avg`/`min`/`max`), `stream`, `chunk`, `streamChunks`, `toSql`, `explain`, `whereGroup`, `whereExists`, `whereColumn`, the 3-arg `where(field, op, value)`, `whereRaw`, `join`/`leftJoin`/`groupBy`/`having`, and the `.sql()` / `.mongo()` adapter-context gates.
4. **§13 Validation:** v1 said "10 rules implemented." Actual count is 16 ([rules/](packages/worm/lib/src/validation/rules/) holds `after`, `before`, `confirmed`, `date`, `email`, `in`, `max_length`, `max`, `min_length`, `min`, `not_in`, `regex`, `required`, `unique`, `url`, `uuid`). Missing from spec: `IntegerRule`, `Numeric`, `Custom(validator)`. v1 also missed that the code uses a separate [Validatable](packages/worm/lib/src/validation/validatable.dart) interface with string keys instead of the spec's `Map<Field, List<ValidationRule>> rules` on Model. v1 missed that `Unique(ignoreId: id)` is in fact supported via the `exceptId` parameter. v1 missed [ValidationException.fromUniqueConstraint](packages/worm/lib/src/exception/validation_exception.dart#L47).
5. **§14 Serialization:** v1 said "Serializer is a marker." Reality: full 108-line [serializer.dart](packages/worm/lib/src/serialization/serializer.dart) with cycle detection, depth limiting, and reference replacement, backed by a 238-line test file. What's actually missing: `Model.toMap/Model.toJson` convenience methods, runtime processing of `@Hidden`/`@Appended`/`@Computed` annotations, and the `toMap(visible:, hidden:, includeRelations:, maxDepth:)` parameter API the spec calls for.
6. **§9 Seeder:** v1 said seeders are tracked in `worm_seeders`. **Wrong** — [seeder_runner.dart](packages/worm/lib/src/seeder/seeder_runner.dart) has no tracking table at all; every run re-applies every seeder.
7. **§10 Factory:** v1 called it "a 24-line skeleton." Actual [factory_base.dart](packages/worm/lib/src/factory/factory_base.dart) is 108 lines with named `state()` variations, inline `withTransform()`, and a private `_StatefulFactory<T>` chainer. What's actually missing: `.create()` persist path, `.count(n)`, `.has(otherFactory, rel)`, `.for_(parent, rel)`, `.sequence([...])`, `.overrides:`, faker wiring on the base.
8. **§7 Relations:** v1 missed [PivotManager](packages/worm/lib/src/relation/pivot.dart) (which has functioning `attach`, `detach`, `sync` — but exposed only as a standalone manager, not via the model's relation accessor).
9. **§23 Exceptions:** v1 listed 14 exception types. Actual count under [exception/](packages/worm/lib/src/exception/) is **16 concrete subtypes** (plus the `WormException` base and the `exception.dart` barrel = 18 files). Six exception types in code are *not* in the spec (`CastException`, `ConfigurationException`, `FactoryException`, `RelationNotLoadedException`, `TransactionException`, `UninitializedFieldException`).
10. **New cross-cutting issues** v1 missed entirely:
    - **Duplicate `Worm` class** — [worm.dart:21](packages/worm/lib/src/registry/worm.dart#L21) (209 lines, observer-aware, async `initialize`) and [worm_registry.dart:23](packages/worm/lib/src/registry/worm_registry.dart#L23) (140 lines, sync, no observers, no `ModelRegistration`) both declare `final class Worm` in the same package. The registry barrel [registry.dart](packages/worm/lib/src/registry/registry.dart) only re-exports `worm.dart`, so `worm_registry.dart` is dead code accessible only via a direct `package:worm/src/registry/worm_registry.dart` import — yet its companion test file [worm_registry_test.dart](packages/worm/test/src/registry/worm_registry_test.dart) does exactly that and runs as part of the suite, anchoring the dead code.
    - **Spec method-name mismatches**: spec writes `Operator.equals`, `Operator.greaterThan`; code has `Operator.eq`, `Operator.gt`. Spec writes `field.whereIn(values)`; code has `field.inList(values)`. Spec writes `table.id()`, `table.intId()`; code has `table.idUuid()`, `table.idIncrements()`. Spec writes `Future<void> up(Schema schema)`; code is `Future<void> up(DatabaseAdapter adapter)`. The spec's examples won't compile against the current code without alias methods or a rename.
    - **Internal ticket comments**: 27+ occurrences of `WI-001`, `WI-002`, `WI-006`, `WI-007`, `WI-008`, `AC-1`…`AC-10` survive in `lib/` and test files — violates the `CLAUDE.md` rule "don't reference the current task, fix, or callers."
    - **Unused annotations**: [annotations.dart](packages/worm/lib/annotations.dart) declares 22 annotation classes; 7 of them (`@Appended`, `@Hidden`, `@Attribute`, `@CastAs`, `@Fillable`, `@Guarded`, `@Computed`) are not read by any runtime or codegen code.
    - **Templates** emit `SchemaDescriptor.createTable(...)` ([templates.dart:40](packages/worm/lib/src/cli/templates.dart#L40)), bypassing the Blueprint DSL the spec example wants in §8.3.
    - **Missing `DurationCast`** under [cast/casts/](packages/worm/lib/src/cast/casts/) (12 casts present out of 13 in spec §5.6).
    - **`make:migration --auto`** flag not registered on the command ([make_migration_command.dart:11-17](packages/worm/lib/src/cli/commands/make_migration_command.dart#L11)) — `DiffEngine` exists but is unreachable from the CLI.
    - **`afterCommit` does not actually defer until commit** — [active_record.dart:48-49 + 192-198](packages/worm/lib/src/model/active_record.dart#L192) flushes registered callbacks immediately after the local save/delete returns, with no transaction-context check.

---

## Executive Summary

| § | Spec area | Status | Severity | One-line reality |
|---|---|---|---|---|
| 1 | Vision & Philosophy | ✓ | — | No executable surface; type-safe-field claim mostly holds but `whereRaw` escape hatch is not implemented. |
| 2 | Architecture & Packages | ⚠ | Medium | Monorepo layout matches; adapter packages don't compile; per-model `@Table(connection:)` routing unwired. |
| 3 | Configuration | ⚠ | Medium | `WormConfig`/`ConnectionConfig`/`StrictnessConfig`/`LogConfig` exist; `SslMode` enum (spec) is a bool in code; multi-connection routing not enforced. |
| 4 | Code Generation | ⚠ | Medium | `worm_generator` build_runner path works; macro path absent; relation accessors not generated; annotation-driven generation incomplete. |
| 5 | Model System | ⚠ | High | Most surface present and tested. Missing: `replicate`, `update(map)`, top-level `forceDelete`, `Worm.withoutEvents`. Validation hook not auto-fired in `save`. Three public-but-`@internal`-shaped fields leak. |
| 6 | Type-Safe Query Builder | ⚠ | High | Builder is rich (chainables, scopes, eager-load injections, 12 terminals). Missing: scalar aggregates, streaming, `whereGroup/whereExists/whereColumn`, raw, joins/groupBy/having, `.sql()`/`.mongo()` contexts, 3-arg `where`. Spec name renames everywhere. |
| 7 | Relationships | ⚠ | High | All 11 relation types declared as data holders; `PivotManager` works standalone. Missing: runtime accessors on Model (`user.posts.add`, `user.roles.attach`), constrained eager loading, `OnDelete.ormCascade` runtime, polymorphic type resolution. |
| 8 | Migration System | ⚠ | High | Runner + record store + Blueprint + DiffEngine all built. `Migration.up(Schema)` is wrong signature (code uses `DatabaseAdapter`). `table.id()/intId()` aliases missing. `make:migration --auto` not wired. `dependsOn` not enforced. |
| 9 | Seeder System | ⚠ | High | Runner + environment filter present. **No tracking table.** No `DatabaseSeeder` master pattern. `Seeder.order` missing. |
| 10 | Factory System | ⚠ | High | Base, `state(name)`, inline `withTransform`, faker_service exist. Missing: persistence (`create`), `count(n)`, relation graphs (`has`/`for_`), `sequence`, `overrides`. |
| 11 | Database Adapters | ⚠ | Critical | InMemoryAdapter complete; **`worm_postgres` and `worm_mongodb` do not compile**. `.sql()`/`.mongo()` context gates missing. |
| 12 | Events & Lifecycle Hooks | ⚠ | High | Dispatcher + observer + all 11 events exist. `Worm.withoutEvents` missing; `afterCommit` fires immediately rather than at transaction commit; `beforeRestore`/`afterRestore` missing. |
| 13 | Validation | ⚠ | Medium | 16 of 19 rules; `Unique(ignoreId:)` works via `exceptId:`; engine is solid. Not auto-fired on `Model.save`; uses `Validatable` interface (string keys) instead of `Model.rules` (typed Field keys). |
| 14 | Serialization | ⚠ | High | Cycle-aware Serializer + Descriptor work. No `Model.toMap`/`toJson` convenience. `@Hidden`/`@Appended`/`@Computed` annotations declared but ignored. |
| 15 | Scopes | ⚠ | High | `LocalScope`, `GlobalScope`, auto-application, `withoutGlobalScope(name)`, `withoutGlobalScopes()` all present. Codegen emits only scope **names** (`List<String> scopeNames`), not typed extension methods. No typed-generic `withoutGlobalScope<X>()`. |
| 16 | Soft Deletes | ✓ | — | `SoftDeletes` mixin, `SoftDeleteScope` global, `withTrashed`/`onlyTrashed`/`isTrashed`, blueprint `softDeletes()` all present. Partial-unique-index `.sql((idx) => idx.where(...))` not exposed on `IndexDefinition`. |
| 17 | Pagination & Chunking | ⚠ | High | `Page<T>`, `CursorPage<T>`, `paginate`, `cursorPaginate` all wired. **`stream`, `chunk`, `streamChunks` missing.** |
| 18 | Transactions | ✗ | High | Adapter `transaction((tx) async {})` exists. **`Worm.transaction` static helper missing**, `Model.save(transaction:)` propagation missing, `txn.savepoint` missing. |
| 19 | CLI Tool | ⚠ | Medium | All 15 commands present; `--auto`, `--prune`, `--all` flags partial / not honored. |
| 20 | Logging & Debugging | ⚠ | Medium | Full logging stack with NPlusOneDetector + MissingIndexWarner + ExplainRunner. Builder doesn't expose `toSql`/`toMongoFilter`/`explain`/`debug`. |
| 21 | Strictness Mode | ⚠ | Medium | Flags exist; `preventFullTableScans` and `preventDestructiveWithoutWhere` overlap (the same code path raises both). `preventLazyLoading`/`preventSilentMassAssign` flags exist; lazy-loading and mass-assign-enforce-only-in-strict aren't implemented to enforce. No `Worm.unsafe()`. |
| 22 | Performance | ⚠ | Medium | Dirty tracking + batched eager loading + dirty-only UPDATE all work. `IN` chunking, lazy hydration, concurrent relation loading absent in worm core. |
| 23 | Error Handling | ⚠ | Medium | 16 concrete exception subtypes; 9 spec types missing, 6 extra types not in spec; `DangerousQueryException` named `FullTableScanException` in code; umbrella `ModelException`/`AdapterException` absent. |
| 24 | Testing Strategy | ⚠ | High | Tier-1 unit suite is strong (722 passing). Adapter contract harness ([adapter_contract.dart](packages/worm/lib/testing/adapter_contract.dart)) is pre-EPIC-004 — analyzer-excluded, paired test renamed `.pending_*`. No real-DB integration, no E2E CLI tests, no perf regression. `Worm.beginTestTransaction()` missing. |
| 25 | Naming Conventions | ⚠ | Low | Camel↔snake, basic pluralization, override via annotations all work. Pluralizer is naive (no irregular plurals). Pivot-name composition (`Role` + `User` → `role_user`, alphabetical singular) not encoded in `NamingConvention` — only documented in `pivot.dart` as a user-supplied string. |
| **CC** | **Cross-cutting** | ⚠ | Mixed | See dedicated section below: duplicate `Worm`, internal ticket comments, unused annotations, public-but-internal model state, spec method-name mismatches. |

**Top 5 critical fixes (ranked):**

1. **EPIC-010: Adapter API alignment.** Without compiling adapter packages, descriptor → SQL/Mongo compilation is unverified end-to-end. Highest leverage.
2. **EPIC-016: Worm registry deduplication.** A duplicate `Worm` class is a foot-gun that violates DRY and is easily resolvable.
3. **EPIC-009: Model finish-out.** Add `replicate`/`update(map)`/top-level `forceDelete`, wire validation into `save`, fix `afterCommit` to be transaction-aware.
4. **EPIC-018: Transactions top-level.** `Worm.transaction((txn) async {})` plus `Model.save(transaction:)` propagation.
5. **EPIC-013: Relations runtime.** Make `user.posts.add(post)` actually work; expose pivot ops via the relation accessor.

---

## Per-Section Findings

### Section 1 — Vision & Philosophy

No executable surface. The doc's claims need spot-checking against the rest of this audit:

| Spec claim | Reality |
|---|---|
| "No string-based field references in queries. Every column [...] is statically typed" | Mostly true via [Field](packages/worm/lib/src/query/field.dart) + [Predicate.fieldName](packages/worm/lib/src/query/predicate.dart#L25). But the runtime guarded escape hatch the spec promises (`whereRaw(..., allowRaw: true)`) is **not implemented**. |
| "A typo is a compile-time error" | True for column access. False for global-scope bypass (`withoutGlobalScope('soft_deletes')` is a string — typo silently no-ops, [query_builder.dart:138](packages/worm/lib/src/query/query_builder.dart#L138)). |
| "Active Record as the default. Data Mapper as opt-in." | True: [model.dart](packages/worm/lib/src/model/model.dart) + [repository.dart:34](packages/worm/lib/src/model/repository.dart#L34) coexist; `Repository<T>` is a pass-through to `ActiveRecord` static helpers. |
| "Macros (with build_runner fallback)" | **False.** No macro path; only build_runner is implemented in [worm_generator/](packages/worm_generator/). |

**Severity:** Low overall — these are aspirational statements. Track the broken sub-claims under their respective sections.

---

### Section 2 — Architecture & Package Structure

| Item | Status | Sev | Evidence |
|---|---|---|---|
| Monorepo at `packages/.git` with `worm/`, `worm_postgres/`, `worm_mongodb/`, `worm_generator/` siblings | ✓ | — | `git ls-files` |
| `lib/worm.dart` barrel exports every subsystem | ✓ | — | [worm.dart](packages/worm/lib/worm.dart) — 24 export lines |
| `bin/worm.dart` CLI entry point | ✓ | — | [bin/worm.dart](packages/worm/bin/worm.dart) |
| `Worm.initialize({models, adapters, observers})` | ✓ for adapters + observer storage; ⚠ for `models` runtime use | High | [worm.dart:42-80](packages/worm/lib/src/registry/worm.dart#L42); observers are dispatched via `observersFor(type)` ([worm.dart:171](packages/worm/lib/src/registry/worm.dart#L171)) which is consumed by [active_record.dart:171-177](packages/worm/lib/src/model/active_record.dart#L171). `models` are stored but only consumed by `registrationOf<T>()` lookups, not by codegen or runtime routing. |
| Per-model `@Table(connection: 'mongo')` override applied at runtime | ⚠ | Medium | Annotation accepts `connection` field ([annotations.dart:15](packages/worm/lib/annotations.dart#L15)), but `Model.connectionName` ([model.dart:55](packages/worm/lib/src/model/model.dart#L55)) hard-codes `'default'`. The annotation value never reaches the model. |
| Morph type resolution via registry | ✗ | High | Registry indexes by `Type`, not by polymorphic type-name string. `MorphTo.types` ([annotations.dart:205-211](packages/worm/lib/annotations.dart#L205)) is an in-memory map carried by the annotation — no central resolver. |

**Subtle deviations from spec:**

- Spec §2.3 shows `Worm.initialize(models: [User, Post, Comment, Profile, Role], ...)` — passing **types**. Code expects `List<ModelRegistration>` ([worm.dart:45](packages/worm/lib/src/registry/worm.dart#L45)). User code must wrap each type in a `ModelRegistration` constructor.
- Spec §2.1 lists `lib/src/codegen/` as the codegen home. Code has `lib/src/codegen/` **and** a separate `packages/worm_generator/`. Both contain codegen logic; relationship between them is "the in-package one defines `ModelDescriptor` + generators that the standalone package wraps via build_runner." Acceptable but undocumented.

**Code smells:** none in this section.

**Test coverage gaps:** No test exercises `@Table(connection: 'mongo')` end-to-end.

---

### Section 3 — Configuration & Connection Management

| Item | Status | Sev | Evidence |
|---|---|---|---|
| `WormConfig` with `defaultConnection`, `connections`, `logging`, `strictness` | ✓ | — | [worm_config.dart](packages/worm/lib/src/config/worm_config.dart) |
| `ConnectionConfig` with host, port, database, username, password, useSsl, poolSize, etc. | ✓ | — | [connection_config.dart](packages/worm/lib/src/config/connection_config.dart) |
| `StrictnessConfig` with `preventLazyLoading`, `preventFullTableScans`, `preventSilentMassAssignment`, `warnOnN1Queries`, `warnOnMissingIndex`, `preventDestructiveWithoutWhere`, `slowQueryThreshold` | ✓ | — | [strictness_config.dart](packages/worm/lib/src/config/strictness_config.dart) |
| `LogConfig` (`enabled`, `level`, `file`, `slowQueryThreshold`, `logQueryParameters`, `formatQueries`) | ✓ | — | [query_logger.dart:36](packages/worm/lib/src/logging/query_logger.dart#L36) |
| `SslMode.prefer/disable/require/verifyCa/verifyFull` enum | ✗ | Medium | Spec §3.1 example uses `sslMode: SslMode.prefer`; code has `useSsl: bool` ([connection_config.dart](packages/worm/lib/src/config/connection_config.dart)). No 4-way SSL enum. |
| Pool size, idle timeout, max-total enforced | ⚠ | Medium | All three fields exist; only `worm_postgres` pool would honor them, and that package is broken (EPIC-010). |
| Per-isolate pool instances | ✗ | Low | Adapter responsibility; not implemented. |
| Connection health checks + automatic reconnect | ✗ | Low | Adapter responsibility; not implemented. |
| Per-model `@Table(connection:)` runtime routing | ✗ | Medium | See §2. |

**Test coverage gaps:** `test/src/config/worm_config_test.dart` is analyzer-excluded ([dart_test.yaml](packages/worm/dart_test.yaml)) — it tests scaffolded `ConnectionConfig.driver` API that doesn't exist on the current `ConnectionConfig`.

---

### Section 4 — Code Generation

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `@WormModel()` macro path | ✗ | Medium | No macro source file under `lib/src/codegen/`. Spec §4.3 describes one in detail. |
| `build_runner` fallback path | ✓ | — | [worm_generator/](packages/worm_generator/) — sibling package with `build_runner` + `source_gen`. |
| Companion class `User$` with `Field<T>` constants | ✓ | — | [companion_generator.dart](packages/worm/lib/src/codegen/companion_generator.dart) emits `static const id = Field<String>('id', columnName: 'id')` etc. |
| Hydration extension (`fromRow`) | ✓ | — | [hydration_generator.dart](packages/worm/lib/src/codegen/hydration_generator.dart) |
| Hydration extension `toRow(onlyDirty:)` | ✗ | High | The generator emits a plain `toRow()`; the spec's `toRow(onlyDirty: true)` path doesn't exist. ActiveRecord pulls dirty values via `model.state.dirty` directly ([active_record.dart:160-169](packages/worm/lib/src/model/active_record.dart#L160)), so the lack of generated `onlyDirty:` is a missed optimization opportunity but does not currently break anything. |
| Query starter `UserQuery.query()`, `find`, `all` | ✓ | — | [query_starter_generator.dart](packages/worm/lib/src/codegen/query_starter_generator.dart) |
| Typed scope extensions (`UserScopes` with typed scope methods) | ⚠ | High | [scope_generator.dart](packages/worm/lib/src/codegen/scope_generator.dart) emits only `List<String> scopeNames`. Spec §4.2.D shows the generator emits actual extension methods (`active()`, `createdAfter(date)`) — not implemented. |
| Relation accessors (`User$.posts`, `User$.profile` as typed `RelationField<...>`) | ✗ | Medium | Generator does not emit relation constants. |
| Factory definition skeleton | ✗ | Low | Spec §4.2.A mentions it; not generated. Templates ([templates.dart](packages/worm/lib/src/cli/templates.dart)) emit a hand-coded factory skeleton via `make:factory`. |

**Subtle deviations:**

- Spec §4.2.A shows the field constant as `static const id = Field<String>('id', columnName: 'id')` — i.e. *generated* identifier is the field's Dart name. Reality matches.
- Spec §4.5 ("Naming Convention: Dart camelCase ↔ DB snake_case") — verified working in [naming_convention.dart:26-49](packages/worm/lib/src/naming/naming_convention.dart#L26).

**Code smells in the generator:** Build output uses `as ` casts in places (per spec, generator should be cast-free) — needs grep audit on EPIC-009/015 follow-up.

**Test coverage gaps:** `companion_generator_test.dart`, `hydration_generator_test.dart`, `query_starter_generator_test.dart`, `worm_file_generator_test.dart` exist. No test asserts that the generated scope extension defines callable methods (only that names are listed).

---

### Section 5 — Model System (the most-corrected v1 entry)

**Spec §5.1** describes ~30 members on `Model`. The actual code (compiled, tested):

| Spec member | Status | Evidence |
|---|---|---|
| `Object get id` abstract | ✓ | [model.dart:43](packages/worm/lib/src/model/model.dart#L43) |
| `Map<String, Object?> toRow()` abstract | ✓ | [model.dart:46](packages/worm/lib/src/model/model.dart#L46) |
| `String? get tableName` | ✓ | [model.dart:52](packages/worm/lib/src/model/model.dart#L52) — defaults to `null` and defers to registry |
| `String get connectionName` | ✓ (but hard-coded) | [model.dart:55](packages/worm/lib/src/model/model.dart#L55) — always `'default'`, never honors `@Table(connection:)` |
| `String get primaryKeyColumn` | ✓ | [model.dart:58](packages/worm/lib/src/model/model.dart#L58) |
| `String get createdAtColumn`, `updatedAtColumn` | ✓ | [model.dart:61, 64](packages/worm/lib/src/model/model.dart#L61) |
| `bool get usesTimestamps` | ✓ | [model.dart:68](packages/worm/lib/src/model/model.dart#L68) |
| `List<String> get fillable`, `guarded` | ✓ | [model.dart:71, 74](packages/worm/lib/src/model/model.dart#L71) |
| `bool get strictMassAssignment` | ✓ | [model.dart:79](packages/worm/lib/src/model/model.dart#L79) |
| `bool get exists` | ✓ | [model.dart:82](packages/worm/lib/src/model/model.dart#L82) |
| `bool isDirty([field])` | ✓ | [model.dart:86-89](packages/worm/lib/src/model/model.dart#L86) |
| `Set<String> get dirtyFields` | ✓ | [model.dart:92](packages/worm/lib/src/model/model.dart#L92) |
| `setAttribute(name, value)` | ✓ | [model.dart:95](packages/worm/lib/src/model/model.dart#L95) |
| `getAttribute(name)` | ✓ | [model.dart:100](packages/worm/lib/src/model/model.dart#L100) |
| `getOriginal(name)` | ✓ | [model.dart:103](packages/worm/lib/src/model/model.dart#L103) — spec writes `getOriginal<T>(Field<T> field)`; code is untyped `Object? getOriginal(String name)` |
| `hydrateAttribute(name, value)` | ✓ | [model.dart:110](packages/worm/lib/src/model/model.dart#L110) |
| `markPersisted()` | ✓ | [model.dart:116](packages/worm/lib/src/model/model.dart#L116) |
| `fill(Map data)` | ✓ | [model.dart:127](packages/worm/lib/src/model/model.dart#L127) — honors `fillable`/`guarded`, throws `MassAssignmentException` only when `strictMassAssignment` is `true`. Per spec the default is silent skip, which matches. |
| `update(Map data)` (fill + save shortcut) | ✗ | High — spec §5.1 line 457 lists `Future<void> update(Map<String, dynamic> data)`. Not on Model. |
| `withoutTimestamps(callback)` | ✓ (instance method) | [model.dart:150](packages/worm/lib/src/model/model.dart#L150) — spec also shows a static form `Model.withoutTimestamps(() => model.save())`. Static form not present. |
| `afterCommit(callback)` | ⚠ | High — present at [model.dart:165](packages/worm/lib/src/model/model.dart#L165), but the callbacks fire **immediately** after `save`/`delete` completes ([active_record.dart:192-198](packages/worm/lib/src/model/active_record.dart#L192)), not after the wrapping transaction commits. Spec §12.4 promises "fires only after the wrapping transaction commits." |
| `getInjected<T>(name)` | ✓ | [model.dart:174-191](packages/worm/lib/src/model/model.dart#L174) |
| `Future<bool> save()` | ✓ | [model.dart:198](packages/worm/lib/src/model/model.dart#L198) → [active_record.dart:31-50](packages/worm/lib/src/model/active_record.dart#L31). Spec signature is `Future<void> save()`; code returns `bool` (`false` if a `before*` hook cancels). |
| `Future<bool> delete()` | ✓ | [model.dart:202](packages/worm/lib/src/model/model.dart#L202) → [active_record.dart:54-71](packages/worm/lib/src/model/active_record.dart#L54) |
| `Future<void> forceDelete()` (top-level) | ✗ | Critical — only on the [SoftDeletes mixin](packages/worm/lib/src/model/soft_deletes.dart). Spec §5.1 line 429 puts it on every `Model`. |
| `Future<void> refresh()` | ✓ | [model.dart:205](packages/worm/lib/src/model/model.dart#L205) → [active_record.dart:74-97](packages/worm/lib/src/model/active_record.dart#L74) |
| `Model replicate({List<String> except})` | ✗ | High — spec §5.1 line 435. Not implemented. |
| `Map<Field, List<ValidationRule>> get rules` on Model | ✗ | High — code uses a separate [Validatable](packages/worm/lib/src/validation/validatable.dart) interface with `Map<String, List<ValidationRule>>`. Spec wants typed `Field`-keyed map on Model itself. |
| `static withoutEvents(callback)` / `static withoutEvents(types, callback)` | ✗ | High — spec §12.6 lines 1878-1885. No static muting helper anywhere. |
| `@override` lifecycle hooks (`beforeCreate`, `afterCreate`, etc.) | ✓ | [model_hooks.dart](packages/worm/lib/src/model/model_hooks.dart) — mixin applied to `Model` ([model.dart:20](packages/worm/lib/src/model/model.dart#L20)). All 11 hooks present. |

**Active Record orchestration ([active_record.dart](packages/worm/lib/src/model/active_record.dart)):**

- Hook order on save: `beforeValidate → afterValidate → beforeSave → beforeCreate/Update → INSERT/UPDATE → afterCreate/Update → afterSave → _flushAfterCommit`. Matches spec §12.1 order with one omission: **`beforeValidate` and `afterValidate` fire but no validation actually runs in between** — validator is not invoked. The spec promises automatic validation in §13.3 line 1948.
- Insert path stamps `createdAt`/`updatedAt` from `DateTime.now().toUtc()` ([active_record.dart:110-117](packages/worm/lib/src/model/active_record.dart#L110)).
- Update path emits only dirty columns when `state.attributes` is populated ([active_record.dart:160-169](packages/worm/lib/src/model/active_record.dart#L160)). Spec §22.1 ("Dirty tracking → minimal UPDATE") satisfied for models that use `setAttribute`. Hand-rolled models that override `toRow()` and don't touch the state map fall back to a full-row UPDATE.

**Code smells:**

| File:line | Smell | Severity |
|---|---|---|
| [model.dart:29](packages/worm/lib/src/model/model.dart#L29) | `relations` is a public mutable `Map<String, Object?>` — spec calls it an internal eager-load cache. Should be `@internal` or behind a private setter. | Medium |
| [model.dart:35](packages/worm/lib/src/model/model.dart#L35) | `injectedFields` same. | Medium |
| [model.dart:40](packages/worm/lib/src/model/model.dart#L40) | `state` (`ModelState`) is public and mutable. External code can directly mutate the dirty set. Same `@internal` recommendation. | Medium |
| [model.dart:34, 67, 78, 94, 126, 149, 170, 197](packages/worm/lib/src/model/model.dart#L34) | Doc comments reference peakz internal `AC-N` numbers ("(AC-7)", "(AC-2)", etc.). 8 occurrences in this file alone. | Low |
| [model.dart:103](packages/worm/lib/src/model/model.dart#L103) | `getOriginal` returns `Object?` instead of `T?` per the spec's typed-field API. | Medium |

**Test coverage:**

- [test/src/model/active_record_test.dart](packages/worm/test/src/model/active_record_test.dart) — covers save/delete/refresh, hook order, dirty-only UPDATE.
- [test/src/model/dirty_tracking_test.dart](packages/worm/test/src/model/dirty_tracking_test.dart)
- [test/src/model/lifecycle_order_test.dart](packages/worm/test/src/model/lifecycle_order_test.dart)
- [test/src/model/timestamps_test.dart](packages/worm/test/src/model/timestamps_test.dart)
- [test/src/model/mass_assignment_test.dart](packages/worm/test/src/model/mass_assignment_test.dart)
- [test/src/model/observer_test.dart](packages/worm/test/src/model/observer_test.dart)
- [test/src/model/repository_test.dart](packages/worm/test/src/model/repository_test.dart)

**Untested:**
- `afterCommit` deferred-until-commit semantics (no transaction-wrapper test).
- `replicate` (missing).
- `update(map)` (missing).
- Top-level `forceDelete` (missing).
- Static `withoutEvents` (missing).
- Validation auto-fire in `save` (validation must be invoked manually).

---

### Section 5.6 — Attribute Casting (subsection)

12 of 13 spec casts are present under [lib/src/cast/casts/](packages/worm/lib/src/cast/casts/):

| Spec cast | Code | Status |
|---|---|---|
| `String`, `int`, `double`, `bool` | `string_cast.dart`, `int_cast.dart`, `double_cast.dart`, `bool_cast.dart` | ✓ |
| `DateTime` | `date_time_cast.dart` | ✓ |
| `Duration` → integer milliseconds | — | **✗ Missing** (spec §5.6 line 658) |
| `Map<String, dynamic>` → JSONB | `json_map_cast.dart` | ✓ |
| `List<T>` → JSON array | `json_list_cast.dart` | ✓ |
| `Enum` → string (or int) | `enum_cast.dart` | ✓ |
| `Decimal` | `decimal_cast.dart` + [decimal.dart](packages/worm/lib/src/cast/decimal.dart) (canonical-string `Decimal` class) | ✓ |
| `Uri` | `uri_cast.dart` | ✓ |
| `BigInt` | `big_int_cast.dart` | ✓ |
| `EncryptedCast()` | `encrypted_cast.dart` | ✓ |
| `CustomCast<T>(fromDb:, toDb:)` user-extensible | — | ✗ — spec §5.6 line 649-653; no convenience constructor. Users can subclass `AttributeCast`. |
| `@Column(cast: ...)` annotation runtime application | ✗ | The `@CastAs(...)` annotation exists ([annotations.dart:273](packages/worm/lib/annotations.dart#L273)) but no codegen reads it and `Model.toRow`/`fromRow` don't apply casts. Casts are wired manually via `CastManager.register`. |

**Code smells:**

- [bool_cast.dart:10](packages/worm/lib/src/cast/casts/bool_cast.dart#L10) — `field` parameter defaults to magic string `'value'`. Error messages cite this default. Should be a required param.
- [decimal.dart:42](packages/worm/lib/src/cast/decimal.dart#L42) — `_pattern` regex has no inline grammar comment.

**Test coverage:** [casts_roundtrip_test.dart](packages/worm/test/src/cast/casts_roundtrip_test.dart) hits all 12 casts present.

---

### Section 6 — Type-Safe Query Builder

**[query_builder.dart](packages/worm/lib/src/query/query_builder.dart) is 467 lines.** Audit of every spec feature:

**Chainables:**

| Spec method | Code | Status |
|---|---|---|
| `.where(field, value)` 2-arg | ✗ | Only `.where(PredicateTree)` exists ([:90](packages/worm/lib/src/query/query_builder.dart#L90)). Spec example `where(User$.email, 'jane@example.com')` doesn't compile. |
| `.where(field, op, value)` 3-arg | ✗ | Same. |
| `.where(predicateTree)` | ✓ | [:90](packages/worm/lib/src/query/query_builder.dart#L90) |
| `.where(User$.age.gte(18))` shorthand via extension | ✓ | via [FieldOperators](packages/worm/lib/src/query/field_operators.dart) |
| `.orWhere` | ✓ | [:98](packages/worm/lib/src/query/query_builder.dart#L98) |
| `.whereGroup((q) => q.where(...).orWhere(...))` | ✗ | High — `PredicateTree` supports grouping via `GroupNode`, but no builder method exposes it. Spec §6.4 uses this prominently. |
| `.whereExists<Post>((q) => q.whereColumn(...))` | ✗ | High |
| `.whereColumn(left, right)` | ✗ | High |
| `.whereRaw(sql, params, allowRaw: true)` | ✗ | Medium |
| `.orderBy(field, descending)` | ✓ | [:105](packages/worm/lib/src/query/query_builder.dart#L105) |
| `.limit(n)` | ✓ | [:119](packages/worm/lib/src/query/query_builder.dart#L119) |
| `.offset(n)` | ✓ | [:123](packages/worm/lib/src/query/query_builder.dart#L123) |
| `.select([User$.name, User$.email])` | ✓ | [:127](packages/worm/lib/src/query/query_builder.dart#L127) |
| `.distinct()` | ✓ | [:134](packages/worm/lib/src/query/query_builder.dart#L134) |
| `.withRelations([User$.posts, User$.profile])` | ⚠ | High — takes `List<String>` ([:161](packages/worm/lib/src/query/query_builder.dart#L161)), not typed relation references. |
| Nested eager loading `User$.posts.include([Post$.comments])` | ✗ | High |
| `.withRelation(rel, (q) => q.where(...))` constrained eager loading | ✗ | High — spec §7.3 |
| `.withCount(rel)`, `.withSum(rel, col)`, `.withExists(rel)` | ✓ | [:167, 180, 198](packages/worm/lib/src/query/query_builder.dart#L167) |
| `.withCount(rel, alias:, filter:)` (constrained subquery alias) | ⚠ | Aliasing is via `injectKey:`. No `filter:` (constrained subquery). |

**Terminals:**

| Spec terminal | Code | Status |
|---|---|---|
| `.get()` | ✓ | [:212](packages/worm/lib/src/query/query_builder.dart#L212) |
| `.first()` | ✓ | [:227](packages/worm/lib/src/query/query_builder.dart#L227) |
| `.firstOrFail()` | ✓ | [:243](packages/worm/lib/src/query/query_builder.dart#L243) |
| `.find(id)` | ✓ | [:256](packages/worm/lib/src/query/query_builder.dart#L256) |
| `.findOrFail(id)` | ✓ | [:273](packages/worm/lib/src/query/query_builder.dart#L273) |
| `.count()` | ✓ | [:286](packages/worm/lib/src/query/query_builder.dart#L286) |
| `.exists()` | ✓ | [:297](packages/worm/lib/src/query/query_builder.dart#L297) — counts and `> 0`s; could be optimized to `LIMIT 1` adapter call. |
| `.sum(field)` | ✗ | Critical — only the *injection* variant `withSum` exists. Spec §6.5 line 826 shows scalar terminal. |
| `.avg(field)` | ✗ | Critical |
| `.min(field)` | ✗ | Critical |
| `.max(field)` | ✗ | Critical |
| `.pluck(field)` | ✓ | [:300](packages/worm/lib/src/query/query_builder.dart#L300) |
| `.update(map)` | ✓ | [:314](packages/worm/lib/src/query/query_builder.dart#L314) |
| `.delete()` | ✓ | [:328](packages/worm/lib/src/query/query_builder.dart#L328) |
| `.paginate(page:, perPage:)` | ✓ | [:341](packages/worm/lib/src/query/query_builder.dart#L341) |
| `.chunk(size, callback)` | ✗ | High — spec §17.3 |
| `.streamChunks(size)` | ✗ | High |
| `.stream()` | ✗ | High |
| `.toSql()` | ✗ | Medium — adapter has `compileToString` but no builder-level surface. |
| `.toMongoFilter()` | ✗ | Medium |
| `.explain()` | ✗ | Medium |
| `.debug()` chainable | ✗ | Low |

**Adapter-context gates:**

| Spec method | Code | Status |
|---|---|---|
| `.sql((q) => q.join(...).having(...).groupBy(...))` | ✗ | Medium — no SQL-only context. |
| `.mongo((q) => q.rawFilter({...}).pipeline([...]))` | ✗ | Medium — no Mongo-only context. |
| `AdapterMismatchException` thrown when wrong context | ⚠ | Exception exists ([adapter_mismatch_exception.dart](packages/worm/lib/src/exception/adapter_mismatch_exception.dart)); no code throws it because the gates don't exist. |

**Subtle name deviations (spec example would not compile against code):**

| Spec writes | Code has |
|---|---|
| `Operator.equals` | `Operator.eq` ([operator.dart](packages/worm/lib/src/query/operator.dart)) |
| `Operator.notEquals` | `Operator.neq` |
| `Operator.greaterThan` | `Operator.gt` |
| `Operator.greaterThanOrEqual` | `Operator.gte` |
| `Operator.lessThan` | `Operator.lt` |
| `Operator.lessThanOrEqual` | `Operator.lte` |
| `field.whereIn(values)` | `field.inList(values)` ([field_operators.dart](packages/worm/lib/src/query/field_operators.dart)) |
| `field.whereNotIn(values)` | `field.notInList(values)` |

These need either renames or alias methods to make spec examples compile literally.

**Code smells:**

- [query_builder.dart:339-340](packages/worm/lib/src/query/query_builder.dart#L339): `// (per WI-007 the canonical API lives there)` — internal ticket reference.
- `Field<Object?>` widely used (e.g. [:64](packages/worm/lib/src/model/active_record.dart#L64), [:80](packages/worm/lib/src/model/active_record.dart#L80)) which sidesteps generics for the primary-key column. Acceptable but worth a note about loss of static safety.

**Test coverage:**

- [test/src/query/](packages/worm/test/src/query/) — 7 test files including `fluent_qb_goldens_test.dart` (golden snapshots) and `query_builder_exec_test.dart` (terminal execution).
- **Untested:** scalar aggregates (missing); `stream`/`chunk` (missing); `toSql`/`explain`/`debug` (missing); `whereGroup`/`whereExists`/`whereColumn` (missing). All untested because they don't exist.

---

### Section 7 — Relationships

11 relation classes exist as **immutable metadata holders** under [lib/src/relation/](packages/worm/lib/src/relation/):

| Spec relation | Code class | Status |
|---|---|---|
| `@HasOne` | `HasOneRelation` ([has_one.dart](packages/worm/lib/src/relation/has_one.dart)) | ✓ — annotation + class |
| `@HasMany` | `HasManyRelation` ([has_many.dart](packages/worm/lib/src/relation/has_many.dart)) | ✓ |
| `@BelongsTo` | `BelongsToRelation` ([belongs_to.dart](packages/worm/lib/src/relation/belongs_to.dart)) | ✓ |
| `@BelongsToMany` | `BelongsToManyRelation` ([belongs_to_many.dart](packages/worm/lib/src/relation/belongs_to_many.dart)) | ✓ |
| `@HasOneThrough` | `HasOneThroughRelation` ([has_one_through.dart](packages/worm/lib/src/relation/has_one_through.dart)) | ✓ |
| `@HasManyThrough` | `HasManyThroughRelation` ([has_many_through.dart](packages/worm/lib/src/relation/has_many_through.dart)) | ✓ |
| `@MorphOne` | `MorphOneRelation` ([morph_one.dart](packages/worm/lib/src/relation/morph_one.dart)) | ✓ |
| `@MorphMany` | `MorphManyRelation` ([morph_many.dart](packages/worm/lib/src/relation/morph_many.dart)) | ✓ |
| `@MorphTo` | `MorphToRelation` ([morph_to.dart](packages/worm/lib/src/relation/morph_to.dart)) | ✓ |
| `@MorphToMany` | `MorphToManyRelation` ([morph_to_many.dart](packages/worm/lib/src/relation/morph_to_many.dart)) | ✓ |
| Sealed `Morph*` union | ✓ | [morph.dart](packages/worm/lib/src/relation/morph.dart) |

**Eager loader:** [eager_loader.dart](packages/worm/lib/src/relation/eager_loader.dart) — batched, AC-4 docstring claims "exactly N+1 queries for N parents" but actual count is 2 queries total (parent batch + child IN-batch).

**Runtime relation accessors on Model:**

| Spec usage | Code reality |
|---|---|
| `final posts = await user.posts;` | ✗ — `Model.relations['posts']` is the only access; untyped `Map` lookup. |
| `await user.posts.add(post);` (associate + save) | ✗ — no `add` API. |
| `await post.author.dissociate();` | ✗ |
| `await user.roles.attach(adminRole.id);` | ⚠ — [PivotManager.attach](packages/worm/lib/src/relation/pivot.dart#L40) exists but is constructed standalone; not exposed as `user.roles.attach(...)`. |
| `await user.roles.detach([adminRole.id]);` | ⚠ — `PivotManager.detach` exists (same standalone caveat). |
| `await user.roles.sync([role1.id, role2.id]);` | ⚠ — `PivotManager.sync` exists, returns `PivotSyncResult`. |
| `attach(role.id, pivot: {assignedAt: now, assignedBy: id})` | ✓ on `PivotManager`; not on `user.roles`. |
| `withPivot: [...]` annotation honored | ⚠ — annotation field exists; runtime ignores it. |
| Pivot `timestamps: true` | ⚠ — annotation field exists; runtime ignores it. |

**`OnDelete`:**

| Spec value | Code |
|---|---|
| `OnDelete.cascade` | ✓ enum value ([on_delete.dart](packages/worm/lib/src/schema/on_delete.dart)); honored by Blueprint FK SQL ([blueprint.dart:372](packages/worm/lib/src/schema/blueprint.dart#L372)). |
| `OnDelete.ormCascade` (ORM walks children) | ✗ — no runtime walks children on `Model.delete`. |
| `OnDelete.setNull` | ✓ enum value; honored by Blueprint. |
| `OnDelete.restrict` | ✓ |
| `OnDelete.noAction` | ✓ |

**Polymorphic types:**

- `MorphTo.types` field carries the `{'Post': Post, 'Video': Video}` map ([annotations.dart:205-211](packages/worm/lib/annotations.dart#L205)).
- No central morph-type registry resolves a `commentable_type` string ('Post', 'Video') to the actual model `Type` at hydration time. Eager-loader uses the per-relation map; cross-relation polymorphic resolution doesn't exist.

**Code smells:**

- [morph.dart:6](packages/worm/lib/src/relation/morph.dart#L6) — comment `Per WI-006 the four morph relation kinds are kept...`
- [eager_loader.dart:20](packages/worm/lib/src/relation/eager_loader.dart#L20) — comment `AC-4: executes exactly N+1 queries`
- [relation_definition.dart:144](packages/worm/lib/src/relation/relation_definition.dart#L144) — `public surface for the AC-5 guarantee`

**Test coverage:**

- [test/src/relation/eager_loading_test.dart](packages/worm/test/src/relation/eager_loading_test.dart)
- [test/src/relation/morph_test.dart](packages/worm/test/src/relation/morph_test.dart) (716 lines)
- [test/src/relation/morph_polymorphic_test.dart](packages/worm/test/src/relation/morph_polymorphic_test.dart)
- [test/src/relation/morph_to_test.dart](packages/worm/test/src/relation/morph_to_test.dart)
- [test/src/relation/pivot_test.dart](packages/worm/test/src/relation/pivot_test.dart)
- [test/src/relation/through_relations_test.dart](packages/worm/test/src/relation/through_relations_test.dart)
- **Untested:** all the missing runtime accessor methods (because they don't exist).

---

### Section 8 — Migration System

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `class CreateUsersTable extends Migration` with `up(Schema schema) async`, `down(Schema schema) async` | ✗ wrong sig | High | Code is `Future<void> up(DatabaseAdapter adapter)` ([migration_base.dart:24](packages/worm/lib/src/migration/migration_base.dart#L24)). Spec example at §8.3 lines 1202, 1220 wouldn't compile. |
| `name` getter | ✓ | — | [migration_base.dart:17](packages/worm/lib/src/migration/migration_base.dart#L17) |
| `dependsOn` getter | ✗ | Medium | Not declared. |
| Schema Builder API | ✓ as Blueprint | — | [blueprint.dart](packages/worm/lib/src/schema/blueprint.dart) — 407 lines, fluent. |
| Schema name `Schema` (matching spec signature) | ✗ | Medium | Class is `Blueprint`. Spec calls it `Schema`. |
| `table.id()` UUID PK | ✗ wrong name | Medium | Code has `idUuid({name: 'id'})` ([blueprint.dart:193](packages/worm/lib/src/schema/blueprint.dart#L193)). |
| `table.intId()` auto-increment PK | ✗ wrong name | Medium | Code has `idIncrements({name: 'id'})` ([blueprint.dart:185](packages/worm/lib/src/schema/blueprint.dart#L185)). |
| `table.string`, `text`, `integer`, `bigInteger`, `decimal`, `float`, `double`, `boolean`, `dateTime`, `date`, `time`, `json`, `binary`, `enumField`, `timestamps`, `softDeletes`, `uuid` | ✓ | — | [blueprint.dart:52-180](packages/worm/lib/src/schema/blueprint.dart#L52) — plus jsonb, doublePrecision, tsvector, interval, inet, macaddr, point, line, box, money, bit, xml, array (extras not in spec). |
| `.notNull`, `.unique`, `.defaultValue`, `.nullable`, `.index`, `.comment`, `.after` modifiers | ⚠ | Low | `notNull`/`unique`/`defaultValue`/`nullable` work; `comment` and `after` partial. |
| Foreign keys (`.foreign('users', 'id')`, `.references().on().onDelete()`) | ✓ short form; ⚠ fluent form | Medium | Short form via `.foreign(...)` ([blueprint.dart:228](packages/worm/lib/src/schema/blueprint.dart#L228)). `.references().on().onDelete()` fluent chain not present — uses named parameters instead. |
| Composite FK `foreign([col1, col2]).references([col1, col2]).on(table)` | ✗ | Low | Not supported. |
| Simple `table.index(['col'])` and `table.unique(['col'])` | ✓ | — | [blueprint.dart:204, 224](packages/worm/lib/src/schema/blueprint.dart#L204) |
| Partial index `.sql((idx) => idx.where(...))` (Postgres only) | ✗ | Low | Not on `IndexDefinition`. |
| `worm make:migration --auto` | ✗ | High | `DiffEngine` exists ([diff_engine.dart](packages/worm/lib/src/migration/diff_engine.dart)); CLI command ([make_migration_command.dart:11-17](packages/worm/lib/src/cli/commands/make_migration_command.dart#L11)) has only `--table`. |
| Generated migration file uses Worm Schema Builder syntax (not raw SQL) | n/a | — | Because `--auto` isn't wired, no generation. The template ([templates.dart:40-50](packages/worm/lib/src/cli/templates.dart#L40)) hand-codes `SchemaDescriptor.createTable(...)`, not Blueprint. |
| `worm migrate`, `migrate:rollback`, `migrate:refresh`, `migrate:fresh`, `migrate:status`, `migrate --pretend`, `migrate --force` | ✓ | — | All five commands present; each tested in `worm_command_runner_test.dart`. |
| Migration tracking table (spec: `_worm_migrations`) | ⚠ name | Low | Tracked as `worm_migrations` (no leading underscore). [migration_record_store.dart:15](packages/worm/lib/src/migration/migration_record_store.dart#L15) |
| `dependsOn: [CreateUsersTable]` ordering | ✗ | Medium | Migrations run in registered order; runner doesn't honor `dependsOn`. |
| `worm schema:dump`, `schema:dump --prune` | ⚠ | Medium | Command exists; output minimal; `--prune` flag not honored ([schema_dump_command.dart](packages/worm/lib/src/cli/commands/schema_dump_command.dart)). |

**Subtle deviations:**

- Spec's migration example body (§8.3) writes `await schema.create('users', (table) { table.id(); ... })`. Code's body is `await adapter.executeSchema(SchemaDescriptor.createTable(table: 'users', columns: <SchemaColumn>[...]))`. Conceptually equivalent; syntactically incompatible.
- `table.softDeletes()` adds a nullable `deleted_at` column matching spec.

**Code smells:**

- [schema_dump_command.dart:19](packages/worm/lib/src/cli/commands/schema_dump_command.dart#L19): `// production) — see WI-007 AC #5.`
- [templates.dart](packages/worm/lib/src/cli/templates.dart) hand-codes the generated migration body using `SchemaDescriptor`, not the user-facing Blueprint DSL. This is a UX regression versus the spec.

**Test coverage:**

- [migration_runner_test.dart](packages/worm/test/src/migration/migration_runner_test.dart) — applies/rollback/refresh/fresh/status.
- [diff_engine_test.dart](packages/worm/test/src/migration/diff_engine_test.dart)
- **Untested:** `--auto` flow (missing), `dependsOn` (missing), schema squash `--prune` (broken flag).

---

### Section 9 — Seeder System

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `class UserSeeder extends Seeder` with `environment`, `order`, `run()` | ⚠ | High | Code is `Seeder` ([seeder_base.dart](packages/worm/lib/src/seeder/seeder_base.dart)) with `name`, `environment`, `Future<void> run(DatabaseAdapter adapter)` — no `order`. |
| `Environment` enum: development, staging, production, testing, all | ✓ | — | [environment.dart](packages/worm/lib/src/seeder/environment.dart) — all 5 present. |
| `class DatabaseSeeder extends Seeder { @override List<Type> get call => [...]; }` master pattern | ✗ | Medium | No master-seeder convention. |
| **Tracking table `_worm_seeders`** with `id`, `seeder`, `executed_at`, `environment` columns | ✗ | High | `SeederRunner.run` ([seeder_runner.dart:38-51](packages/worm/lib/src/seeder/seeder_runner.dart#L38)) does **not write** to any tracking table. Seeders re-apply on every invocation. The `SeederRecord` class in [seeder_record.dart](packages/worm/lib/src/seeder/seeder_record.dart) is dead code. |
| `worm db:seed` | ✓ | — | [db_seed_command.dart](packages/worm/lib/src/cli/commands/db_seed_command.dart) |
| `worm db:seed --class=UserSeeder` | ✓ | — | `seederClass:` param on `run()` |
| `worm db:seed --env=development` | ✓ | — | |
| `worm db:seed --force` (re-run) | ⚠ | Medium | `force:` skips the environment filter but not a tracking check (since there's no tracking). |
| `worm migrate:fresh --seed` | ⚠ | Medium | Migrate:fresh accepts `--seed` flag; chaining-into-seeder requires manual setup. |
| `muteEvents: true` performance flag | ✗ | Medium | No event-system flag (depends on §12 finishing). |
| `User.query().insertMany([...])` (bulk insert without events) | ⚠ | Medium | Adapter `insertMany` exists ([database_adapter.dart](packages/worm/lib/src/adapter/database_adapter.dart)); not exposed as a QueryBuilder terminal. |

**Code smells:**

- [seeder_record.dart](packages/worm/lib/src/seeder/seeder_record.dart) is **dead code** because `SeederRunner` doesn't write tracking rows.
- `runOne(name)` ([seeder_runner.dart:56](packages/worm/lib/src/seeder/seeder_runner.dart#L56)) is documented as "thin alias kept for older call sites" — leaves a deprecation trail without an explicit `@Deprecated` annotation.

**Test coverage:**

- [test/src/seeder/seeder_runner_test.dart](packages/worm/test/src/seeder/seeder_runner_test.dart) — environment filter, force flag, named seeder.
- [test/src/seeder/environment_test.dart.pending_seeder_api_rewrite](packages/worm/test/src/seeder/environment_test.dart.pending_seeder_api_rewrite) — pending after EPIC-007 API change.
- **Untested:** tracking, idempotency, master seeder.

---

### Section 10 — Factory System

[factory_base.dart](packages/worm/lib/src/factory/factory_base.dart) is **108 lines** (v1 audit said 24).

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `class UserFactory extends Factory<User>` with `definition()` | ✓ | — | [:22-37](packages/worm/lib/src/factory/factory_base.dart#L22) |
| `Factory<User>.make()` (in-memory) | ✓ | — | [:37](packages/worm/lib/src/factory/factory_base.dart#L37) |
| `Factory<User>.makeMany(n)` | ✓ | — | [:40](packages/worm/lib/src/factory/factory_base.dart#L40) |
| Named states `admin()`, `inactive()`, `withBio()` via `stateVariations` map | ✓ | — | [:30, :47](packages/worm/lib/src/factory/factory_base.dart#L30) |
| Inline `state((u) => u..role = 'admin')` → `withTransform` | ✓ | — | [:62](packages/worm/lib/src/factory/factory_base.dart#L62) |
| `.count(n)` chainable | ✗ | Critical | Spec uses `UserFactory().count(50).create()`. Code has only `.makeMany(n)`. |
| `.create()` (persist via adapter) | ✗ | Critical | Spec line 1585. Not on Factory. |
| `.create(overrides: {...})` | ✗ | High | |
| `.has(PostFactory().count(3), 'posts')` relation graphs | ✗ | High | |
| `.for_(existingUser, 'author')` belongsTo bind | ✗ | High | |
| `.sequence([{role:'admin'},{role:'editor'},{role:'viewer'}])` | ✗ | Medium | |
| `faker` integration on base class | ⚠ | Medium | [faker_service.dart](packages/worm/lib/src/factory/faker_service.dart) (130 lines) exists with seedable random and `faker.person.name()` etc., but is NOT exposed as a getter on `Factory<T>`. Users must construct `FakerService` themselves. |
| Reproducible (seedable) faker output | ✓ | — | `FakerService(seed: 42)` |

**Code smells:**

- `_StatefulFactory<T>` ([:68](packages/worm/lib/src/factory/factory_base.dart#L68)) is a clean immutable chainer — good design.
- No `@Deprecated` markers.

**Test coverage:**

- [test/src/factory/factory_base_test.dart](packages/worm/test/src/factory/factory_base_test.dart)
- [test/src/factory/sequence_test.dart](packages/worm/test/src/factory/sequence_test.dart)
- **Untested:** anything spec calls "create" path (because it's missing).

---

### Section 11 — Database Adapters

| Item | Status | Sev | Evidence |
|---|---|---|---|
| `abstract class DatabaseAdapter` with 21 methods | ✓ | — | [database_adapter.dart:27-126](packages/worm/lib/src/adapter/database_adapter.dart#L27) |
| `AdapterCapabilities` flags: `supportsTransactions`, `supportsSavepoints`, `supportsStreaming`, `supportsRawQuery`, `supportsReturning`, `supportsJoins`, `supportsPreparedStatements`, `supportsPartialIndexes`, `supportsAggregations`, `supportsSchemaIntrospection`, `supportsExplain` | ✓ | — | [adapter_capabilities.dart](packages/worm/lib/src/adapter/adapter_capabilities.dart) — 11 flags total (spec lists 9; code adds `supportsAggregations` and `supportsSchemaIntrospection`). |
| Spec flag `supportsJsonOperations` | ✗ | Low | Not present. |
| Spec flag `supportsFullTextSearch` | ✗ | Low | Not present. |
| Spec flag `supportsCursorPagination` | ✗ | Low | Not present. |
| Spec flag `supportsSchemaAlter` | ✗ | Low | Not present (`InMemoryAdapter.executeSchema` throws `ConfigurationException` for `SchemaOperation.alter`). |
| `InMemoryAdapter` ✓ complete | ✓ | — | [in_memory_adapter.dart](packages/worm/lib/src/adapter/in_memory_adapter.dart) — implements full DatabaseAdapter contract, mixes in `ExplainCapable`. |
| `worm_postgres` adapter compiles | ✗ | **Critical** | ~120 analyzer errors against pre-EPIC-004 API. |
| `worm_mongodb` adapter compiles | ✗ | **Critical** | ~77 analyzer errors. |
| `.sql((q) => q.join(...))` context | ✗ | Medium | |
| `.mongo((q) => q.rawFilter({...}).pipeline([...]))` context | ✗ | Medium | |
| `AdapterMismatchException` runtime guard | ⚠ | Medium | Exception type exists; gates don't fire. |

**`ExplainCapable` mixin** ([explain_runner.dart](packages/worm/lib/src/logging/explain_runner.dart)) is the canonical EXPLAIN contract — adapters mix it in and return `Future<ExplainResult>`. `DatabaseAdapter` itself has no abstract `explain` (Phase 1a added one, the EPIC-007 merge removed it).

**Specific errors in `worm_postgres`:** see [worm_postgres/README.md](packages/worm_postgres/README.md) — pre-EPIC-004 references to `Predicate.column`, `descriptor.predicates`, `SchemaOperation.createTable/dropTable/truncateTable`, `OrderBy`, untyped `List<String>` for `SchemaDescriptor.columns`, `Future<String> explain` (removed from interface).

---

### Section 12 — Events & Lifecycle Hooks

(v1 audit was very wrong here; the dispatcher exists.)

| Spec hook | Code | Status |
|---|---|---|
| `beforeValidate`, `afterValidate` | ✓ | [lifecycle_event.dart:34-38](packages/worm/lib/src/event/lifecycle_event.dart#L34); fired from active_record `save()` [:32-39](packages/worm/lib/src/model/active_record.dart#L32) |
| `beforeSave`, `afterSave` | ✓ | [:40, :47](packages/worm/lib/src/model/active_record.dart#L40) |
| `beforeCreate`, `afterCreate` | ✓ | [:103, :120](packages/worm/lib/src/model/active_record.dart#L103) |
| `beforeUpdate`, `afterUpdate` | ✓ | [:128, :149](packages/worm/lib/src/model/active_record.dart#L128) |
| `beforeDelete`, `afterDelete` | ✓ | [:56, :68](packages/worm/lib/src/model/active_record.dart#L56) |
| `afterHydrate` | ✓ | [:96](packages/worm/lib/src/model/active_record.dart#L96) — fires after `refresh()`. Not fired on bare hydration via `markPersisted()`. |
| `beforeRestore`, `afterRestore` | ✗ | Medium | Spec §16.2 line 1770. Soft-delete `restore()` uses plain `save()`, fires generic save hooks instead. |
| Event cancellation via `return false` from `before*` | ✓ | [event_dispatcher.dart:40-46](packages/worm/lib/src/event/event_dispatcher.dart#L40) |
| `afterCommit(callback)` fires **only** after wrapping transaction commits | ✗ | High | Code fires immediately after the local op (no transaction-context check). [active_record.dart:48-49, :69, :192-198](packages/worm/lib/src/model/active_record.dart#L192) |
| `Model.withoutEvents(() async {})` static muting | ✗ | High | Spec §12.6 line 1878. Not implemented. |
| `Model.withoutEvents([EventType.afterCreate], () async {})` selective muting | ✗ | Medium | Same. |
| `Observer<User>` with all hooks | ✓ | [model_observer.dart](packages/worm/lib/src/event/model_observer.dart) — 103 lines, every hook overridable. |
| Observer registration via `Worm.initialize(observers: {User: [UserObserver()]})` | ✓ | — | [worm.dart:42-80](packages/worm/lib/src/registry/worm.dart#L42); dispatched via `Worm.observersFor(type)` ([worm.dart:171](packages/worm/lib/src/registry/worm.dart#L171)) consumed by `ActiveRecord._dispatcherFor` ([active_record.dart:171-178](packages/worm/lib/src/model/active_record.dart#L171)). |

**Subtle deviations:**

- Spec §12.3 example: `Worm.initialize(observers: {User: [UserObserver()], Post: [PostObserver(), SearchIndexObserver()]})`. Code expects `List<Observer<Object>> observers = ...` (flat list, not type-keyed map). Observers self-report their model type via `modelType` getter. Functionally equivalent; spec API surface different.
- Spec §12.5: `throw OperationCancelledException('Cannot delete user with active subscription')` from a `before*` hook. Code defines no `OperationCancelledException` — throw would propagate as a regular exception. The "return `false`" cancellation path works.

**Code smells:**

- [event_dispatcher.dart:15](packages/worm/lib/src/event/event_dispatcher.dart#L15): `(AC-4)` comment.
- [model_observer.dart:14](packages/worm/lib/src/event/model_observer.dart#L14): `(AC-4)`.
- [model_hooks.dart:11](packages/worm/lib/src/model/model_hooks.dart#L11): `(AC-4)`.

**Test coverage:**

- [test/src/event/event_dispatcher_test.dart](packages/worm/test/src/event/event_dispatcher_test.dart)
- [test/src/model/lifecycle_order_test.dart](packages/worm/test/src/model/lifecycle_order_test.dart)
- [test/src/model/observer_test.dart](packages/worm/test/src/model/observer_test.dart)
- **Untested:** `afterCommit` transaction-context behavior; `withoutEvents` (missing).

---

### Section 13 — Validation

16 rules under [lib/src/validation/rules/](packages/worm/lib/src/validation/rules/):

| Spec rule | Code | Status |
|---|---|---|
| `Required()` | `required_rule.dart` | ✓ |
| `Email()` | `email_rule.dart` | ✓ |
| `MinLength(n)`, `MaxLength(n)` | `min_length_rule.dart`, `max_length_rule.dart` | ✓ |
| `Min(n)`, `Max(n)` | `min_rule.dart`, `max_rule.dart` | ✓ |
| `IntegerRule()` | — | ✗ |
| `Numeric()` | — | ✗ |
| `Unique()`, `Unique(ignoreId: id)` | `unique_rule.dart` (with `exceptId:` param) | ✓ |
| `In(values)`, `NotIn(values)` | `in_rule.dart`, `not_in_rule.dart` | ✓ |
| `Regex(pattern)` | `regex_rule.dart` | ✓ |
| `Url()` | `url_rule.dart` | ✓ |
| `Uuid()` | `uuid_rule.dart` | ✓ |
| `Date()` | `date_rule.dart` | ✓ |
| `After(date)`, `Before(date)` | `after_rule.dart`, `before_rule.dart` | ✓ |
| `Confirmed(field)` | `confirmed_rule.dart` | ✓ |
| `Custom(validator)` user-extensible | — | ✗ |

**Engine:**

- [validator.dart](packages/worm/lib/src/validation/validator.dart) (90 lines): `Validator(rules)`, `validate(values) → Map<String, List<String>>`, `validateOrThrow()`, `validateSync()` (throws if any rule is async), `validateModel(Validatable)`.
- [validation_result.dart](packages/worm/lib/src/validation/validation_result.dart): `ValidationResult.valid()`, `ValidationResult.invalid(message)`.
- [validation_exception.dart:47](packages/worm/lib/src/exception/validation_exception.dart#L47): `ValidationException.fromUniqueConstraint(UniqueConstraintException)` — maps DB constraint violation to a validation error.

**Integration with Model:**

- Spec §13.1: `@override Map<Field, List<ValidationRule>> get rules => {User$.name: [Required(), MinLength(2)], ...}` on Model.
- Reality: separate `Validatable` interface ([validatable.dart](packages/worm/lib/src/validation/validatable.dart)) with `Map<String, List<ValidationRule>>` — string keys, not typed `Field` keys.
- **Validation does NOT auto-fire during `save()`.** `ActiveRecord.save` fires `beforeValidate` and `afterValidate` hooks but doesn't invoke a Validator between them ([active_record.dart:32-39](packages/worm/lib/src/model/active_record.dart#L32)). Users must run `Validator.validate(...)` manually before calling `save`.

**`updateRules` (dirty-fields-only):**

- Spec §13.1 lines 1914-1917 — separate `updateRules` getter for update path.
- Not implemented.

**Code smells:**

- [unique_rule.dart](packages/worm/lib/src/validation/rules/unique_rule.dart) constructor requires `adapter`, `tableName`, `column` parameters — tight coupling. Spec example shows `Unique()` with no args (relies on Model context).

**Test coverage:**

- [test/src/validation/validator_test.dart](packages/worm/test/src/validation/validator_test.dart) (196 lines)
- [test/src/validation/validation_rules_test.dart](packages/worm/test/src/validation/validation_rules_test.dart) (282 lines, comment header `WI-001 AC #3`, `WI-002 AC #16`)
- [test/src/validation/unique_rule_test.dart](packages/worm/test/src/validation/unique_rule_test.dart) (111 lines)
- **Untested:** auto-fire from `save` (because it doesn't auto-fire); `updateRules` (missing); typed `Field`-keyed rules (not the API the code exposes).

---

### Section 14 — Serialization

`Serializer` is real and well-tested.

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `user.toMap()` | ✗ | High | No `toMap` on Model. Users must build a `SerializationDescriptor` and pass to `Serializer.toMap(descriptor)`. |
| `user.toJson()` | ✗ | High | Same. |
| `@Column(hidden: true)` honored | ⚠ | High | `@Hidden` annotation exists ([annotations.dart:257](packages/worm/lib/annotations.dart#L257)) — not read by any codegen or runtime. The Serializer respects a `hidden: Set<String>` field on the descriptor, but users must populate it manually. |
| `@Appended` getter included in serialization output | ⚠ | High | Annotation declared but unused at runtime. |
| `toMap(includeRelations: true)` | ✗ | High | `Serializer.toMap(Serializable root)` takes no such param — only `maxDepth` constructor arg. |
| `toMap(visible: [...])` whitelist | ⚠ | Medium | `SerializationDescriptor.visible` field exists; no convenience param. |
| `toMap(hidden: [...])` extra-hide | ⚠ | Medium | Same. |
| `toMap(maxDepth: 2)` | ⚠ | Medium | `Serializer(maxDepth: 2)` constructor param — yes, but at construct time, not per-call. |
| Cycle detection (replace circular ref with `{ref: true, type, id}`) | ✓ | — | [serializer.dart:33-108](packages/worm/lib/src/serialization/serializer.dart#L33) — `seen` map + `_reference()` helper. |

**Code smells:**

- 7 annotations declared in `annotations.dart` are ignored by the runtime (`@Hidden`, `@Appended`, `@Attribute`, `@CastAs`, `@Fillable`, `@Guarded`, `@Computed`).

**Test coverage:**

- [test/src/serialization/serializer_test.dart](packages/worm/test/src/serialization/serializer_test.dart) (238 lines) — cycles, depth, refs, hidden, appended (via descriptor, not annotation). Contains `WI-006 AC literal examples` group.

---

### Section 15 — Scopes

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `@Scope()` annotation on static method | ✓ | — | [annotations.dart:230](packages/worm/lib/annotations.dart#L230) |
| Generated typed extension `UserScopes on QueryBuilder<User> { QueryBuilder<User> active() => ... }` | ✗ | High | [scope_generator.dart](packages/worm/lib/src/codegen/scope_generator.dart) emits only `static const List<String> scopeNames = [...]`. No callable extension methods. |
| `LocalScope<T>` runtime class | ✓ | — | [local_scope.dart](packages/worm/lib/src/scope/local_scope.dart) |
| `query.scope(MyLocalScope())` application | ✓ | — | [query_builder.dart:145](packages/worm/lib/src/query/query_builder.dart#L145) |
| `@GlobalScope(ActiveScope)` annotation | ✓ | — | [annotations.dart:239](packages/worm/lib/annotations.dart#L239) |
| `class ActiveScope extends GlobalScope<Post>` | ✓ | — | [global_scope.dart:14](packages/worm/lib/src/scope/global_scope.dart#L14) |
| Global scope auto-applies to every `QueryBuilder<T>` | ✓ | — | [query_builder.dart:372-413](packages/worm/lib/src/query/query_builder.dart#L372) (via `QueryContext.globalScopes`) |
| `.withoutGlobalScope<ActiveScope>()` typed-generic bypass | ✗ | High | [:138](packages/worm/lib/src/query/query_builder.dart#L138) takes a `String name` — string-based, not type-safe. |
| `.withoutGlobalScopes()` (all) | ✓ | — | [:142](packages/worm/lib/src/query/query_builder.dart#L142) |

**Code smells:** none significant.

**Test coverage:** [test/src/scope/scope_test.dart](packages/worm/test/src/scope/scope_test.dart), [test/src/scope/soft_deletes_test.dart](packages/worm/test/src/scope/soft_deletes_test.dart).

---

### Section 16 — Soft Deletes

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `with SoftDeletes` mixin | ✓ | — | [soft_deletes.dart](packages/worm/lib/src/model/soft_deletes.dart) (45-126) |
| `DateTime? deletedAt` | ✓ | — | [soft_deletes.dart:64-69](packages/worm/lib/src/model/soft_deletes.dart#L64) |
| `delete()` performs soft-delete (sets `deletedAt`) | ✓ | — | |
| `restore()` clears `deletedAt` | ✓ | — | |
| `forceDelete()` hard-delete | ✓ | — | |
| `isTrashed` getter | ✓ | — | |
| `withTrashed()` | ✓ | — | [query_builder.dart:149](packages/worm/lib/src/query/query_builder.dart#L149) |
| `onlyTrashed()` | ✓ | — | [query_builder.dart:157](packages/worm/lib/src/query/query_builder.dart#L157) |
| `SoftDeleteScope` auto-excludes from query | ✓ | — | [soft_delete_scope.dart:19](packages/worm/lib/src/scope/soft_delete_scope.dart#L19) |
| `table.softDeletes()` helper in Blueprint | ✓ | — | [blueprint.dart:180](packages/worm/lib/src/schema/blueprint.dart#L180) |
| Partial unique index `table.unique(['email']).sql((idx) => idx.where('deleted_at IS NULL'))` | ✗ | Low | `IndexDefinition` has no `where` clause; no `.sql()` fluent extension. |
| Soft-delete hook sequence `beforeDelete → [UPDATE deleted_at] → afterDelete → (trashed event)` | ⚠ | Medium | `SoftDeletes.delete()` ([soft_deletes.dart:100-103](packages/worm/lib/src/model/soft_deletes.dart#L100)) calls `save()`, which runs the full UPDATE hook sequence (`beforeSave` / `beforeUpdate` / `afterUpdate` / `afterSave`), not the simpler `beforeDelete` / `afterDelete` chain the spec calls for. The "trashed" event isn't emitted (no such event in the enum). |

**Mixin contract requires manual wiring:**

```dart
mixin SoftDeletes on Model {
  DatabaseAdapter get softDeleteAdapter;  // user must implement
  String get softDeleteTable;             // user must implement
}
```

**Code smells:**

- [soft_deletes.dart:11, :43](packages/worm/lib/src/model/soft_deletes.dart#L11) — `AC-5 / AC-9 / AC-10 of WI-008` comments.

**Test coverage:** [test/src/scope/soft_deletes_test.dart](packages/worm/test/src/scope/soft_deletes_test.dart) (343 lines, contains 4 `AC-`-numbered groups).

---

### Section 17 — Pagination & Chunking

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `Page<T>` with `items`, `total`, `currentPage`, `lastPage`, `perPage`, `hasNextPage`, `hasPrevPage`, `nextPage`, `prevPage` | ✓ | — | [page.dart](packages/worm/lib/src/pagination/page.dart) — fields `data`, `currentPage`, `perPage`, `total`, `lastPage`, `hasMorePages`, `from`, `to`. Spec writes `items`; code writes `data`. Spec writes `hasNextPage`/`hasPrevPage`; code only has `hasMorePages`. |
| `Page.toMap()` returns `{data, meta: {total, perPage, currentPage, lastPage}}` | ⚠ | Low | Method exists; structure may differ slightly. |
| `query.paginate(page:, perPage:)` | ✓ | — | [query_builder.dart:341](packages/worm/lib/src/query/query_builder.dart#L341) |
| `CursorPage<T>` with `items`, `nextCursor`, `prevCursor`, `hasMore` | ✓ | — | [cursor_page.dart](packages/worm/lib/src/pagination/cursor_page.dart) |
| `query.cursorPaginate(perPage:, after:)` | ✓ | — | [query_builder.dart:356](packages/worm/lib/src/query/query_builder.dart#L356) (uses `cursor:` param instead of `after:`) |
| Cursor encoding/decoding | ✓ | — | [cursor.dart](packages/worm/lib/src/pagination/cursor.dart) |
| `query.chunk(500, (batch) async { return true; })` | ✗ | High | |
| `query.streamChunks(500)` async iterable | ✗ | High | |
| `query.stream()` item-by-item async iterable | ✗ | High | |
| Adapter `stream(descriptor)` underneath | ✓ | — | [in_memory_adapter.dart](packages/worm/lib/src/adapter/in_memory_adapter.dart) ships rows as `Stream.fromIterable` — not a true cursor, but the contract is in place. Builder side isn't wired. |

**Code smells:**

- [paginator.dart:5](packages/worm/lib/src/pagination/paginator.dart#L5) — `Per WI-007 they live as ...` comment.

**Test coverage:** [test/src/pagination/paginator_test.dart](packages/worm/test/src/pagination/paginator_test.dart) (270 lines). **Untested:** stream/chunk (missing).

---

### Section 18 — Transactions

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `await Worm.transaction((txn) async { ... })` static | ✗ | Critical | No such static method on `Worm`. |
| Auto-rollback on throw | ✓ at adapter level | — | [in_memory_adapter.dart:176](packages/worm/lib/src/adapter/in_memory_adapter.dart#L176) — snapshot + restore on throw. |
| Return value from transaction | ✓ at adapter level | — | `transaction<T>` is generic. |
| `await user.save(transaction: txn)` propagation | ✗ | Critical | `Model.save()` is `Future<bool> save()` — no `transaction:` parameter. |
| `txn.savepoint(() async { ... })` (Postgres) | ✗ | High | `supportsSavepoints` flag declared; no method. |
| `Worm.transaction(..., connection: 'mongo')` | ✗ | High | No connection override on the (missing) `Worm.transaction`. |
| MongoDB capability gating (replica-set detection) | ✗ | Medium | Mongo adapter doesn't compile. |

**Code smells:** the [TransactionException](packages/worm/lib/src/exception/transaction_exception.dart) class is defined but only thrown by a few adapter pathways — most code paths re-throw the underlying error.

**Test coverage:** [test/src/adapter/in_memory_adapter_txn_test.dart](packages/worm/test/src/adapter/in_memory_adapter_txn_test.dart) — exercises adapter-level transactions. No `Worm.transaction` test (because missing).

---

### Section 19 — CLI Tool

All 15 commands present under [lib/src/cli/commands/](packages/worm/lib/src/cli/commands/):

| Spec command | Code | Status |
|---|---|---|
| `worm init` | `init_command.dart` | ✓ |
| `worm make:model <Name>` | `make_model_command.dart` | ✓ |
| `worm make:model --migration --seeder --factory --all` | ⚠ — flags accepted; `--all` chain may be incomplete | Medium |
| `worm make:migration <name>` | `make_migration_command.dart` | ✓ |
| `worm make:migration --auto [--name X]` | ✗ — no `--auto` flag registered | High |
| `worm make:seeder <Name>` | `make_seeder_command.dart` | ✓ |
| `worm make:factory <Name>` | `make_factory_command.dart` | ✓ |
| `worm make:observer <Name>` | `make_observer_command.dart` | ✓ |
| `worm migrate` | `migrate_command.dart` | ✓ |
| `worm migrate:rollback [--steps=N]` | `migrate_rollback_command.dart` | ✓ |
| `worm migrate:refresh` | `migrate_refresh_command.dart` | ✓ |
| `worm migrate:fresh` | `migrate_fresh_command.dart` | ✓ |
| `worm migrate:status` | `migrate_status_command.dart` | ✓ |
| `worm migrate --pretend` | ✓ | — |
| `worm migrate --force` | ✓ via `force_gate.dart` | — |
| `worm db:seed [--class --env --force]` | `db_seed_command.dart` | ✓ |
| `worm schema:dump [--prune]` | `schema_dump_command.dart` | ⚠ — flag accepted, not honored | Medium |
| `worm gen` | `gen_command.dart` | ✓ — delegates to `dart run build_runner build` |
| `worm model:show <Name>` | `model_show_command.dart` | ⚠ — minimal output (only registered class name) | Low |

**Exit-code contract:** `UsageException` → `2` ([worm_command_runner.dart:174-181](packages/worm/lib/src/cli/worm_command_runner.dart#L174)). Matches spec.

**Test coverage:** [test/src/cli/worm_command_runner_test.dart](packages/worm/test/src/cli/worm_command_runner_test.dart) (1214 lines). **Untested:** `--auto`, `--prune` flag behaviors (because they're not implemented).

---

### Section 20 — Logging & Debugging

| Spec feature | Status | Sev | Evidence |
|---|---|---|---|
| `LogConfig(enabled, level, file, slowQueryThreshold, logQueryParameters, formatQueries)` | ✓ | — | [query_logger.dart:36](packages/worm/lib/src/logging/query_logger.dart#L36) |
| `LogLevel.debug/info/warning/error` | ✓ | — | [query_logger.dart:13](packages/worm/lib/src/logging/query_logger.dart#L13) |
| `[QUERY] ... params: [...] | Xms` format | ✓ | — | [query_logger.dart:275](packages/worm/lib/src/logging/query_logger.dart#L275) |
| `[SLOW QUERY] ... (threshold: 200ms)` | ✓ | — | |
| `[ERROR]` line | ⚠ Low | — | `logError` method exists but isn't consistently emitted by adapter wrappers. |
| `FileLogger` | ✓ | — | [file_logger.dart](packages/worm/lib/src/logging/file_logger.dart) |
| `LoggingAdapter` decorator | ✓ | — | [logging_adapter.dart](packages/worm/lib/src/logging/logging_adapter.dart) |
| `NPlusOneDetector` | ✓ | — | [n_plus_one_detector.dart](packages/worm/lib/src/logging/n_plus_one_detector.dart) |
| `MissingIndexWarner` | ✓ | — | [explain_runner.dart:64](packages/worm/lib/src/logging/explain_runner.dart#L64) |
| `ExplainCapable` mixin | ✓ | — | [explain_runner.dart:15](packages/worm/lib/src/logging/explain_runner.dart#L15) |
| `ExplainResult.usesIndex/indexName/estimatedCost/estimatedRows/raw/scannedTables` | ✓ | — | [explain_runner.dart:25-54](packages/worm/lib/src/logging/explain_runner.dart#L25); only `InMemoryAdapter` populates `usesIndex`. |
| `query.toSql()` | ✗ | Medium | Adapter has `compileToString`; builder doesn't surface it. |
| `query.toMongoFilter()` | ✗ | Medium | |
| `query.explain()` → `ExplainResult` | ✗ | Medium | |
| `query.debug()` chainable | ✗ | Low | |

**Code smells:** [query_logger.dart:34](packages/worm/lib/src/logging/query_logger.dart#L34) — `the WI-001 spec`.

**Test coverage:** [test/src/logging/](packages/worm/test/src/logging/) — 5 test files covering query log, slow query, file logger, N+1, missing index.

---

### Section 21 — Strictness Mode

| Spec flag | Field present | Enforced at runtime |
|---|---|---|
| `preventLazyLoading` | ✓ | ✗ — lazy loading itself isn't implemented; flag is decorative until then. |
| `preventFullTableScans` | ✓ | ⚠ — only enforced on `QueryBuilder.update`/`delete` ([query_builder.dart:315, 329](packages/worm/lib/src/query/query_builder.dart#L315)). A read `.get()` without `.where()` does NOT throw. |
| `preventSilentMassAssign` | ✓ (in code: `preventSilentMassAssignment`) | ⚠ — `Model.fill` throws only when `strictMassAssignment` on the *model* is true; the global config flag is ignored. |
| `warnOnN1Queries` | ✓ (in code: same name) | ✓ — `NPlusOneDetector`. |
| `warnOnMissingIndex` | ✓ | ⚠ — works when adapter supports `ExplainCapable`. |
| `preventDestructiveWithoutWhere` | ✓ | ⚠ — overlaps with `preventFullTableScans` (same code path, both raise `FullTableScanException` with different messages). |
| `slowQueryThreshold: Duration` | ✓ | ✓ — `LoggingAdapter`. |
| `Worm.unsafe(() async { ... })` escape hatch | ✗ | ✗ |

**Code smell:** the dual `preventFullTableScans` / `preventDestructiveWithoutWhere` flags ([query_builder.dart:415-447](packages/worm/lib/src/query/query_builder.dart#L415)) overlap in semantics. Pick one or document the distinction.

**Test coverage:** [test/src/config/strictness_config_extension_test.dart](packages/worm/test/src/config/strictness_config_extension_test.dart). Bulk-op enforcement also covered by [test/src/query/bulk_ops_test.dart](packages/worm/test/src/query/bulk_ops_test.dart). **Untested:** read-side `preventFullTableScans` enforcement, `preventSilentMassAssign` global flag.

---

### Section 22 — Performance

| Spec optimization | Status |
|---|---|
| Dirty tracking → minimal UPDATE | ✓ — [active_record.dart:160-169](packages/worm/lib/src/model/active_record.dart#L160) |
| Batched eager loading (exactly 2 queries) | ✓ — [eager_loader.dart](packages/worm/lib/src/relation/eager_loader.dart) |
| `IN` chunking for >1000 IDs in core | ✗ — no chunking in `InMemoryAdapter`; depends on Postgres adapter (broken). |
| Connection pooling | ⚠ — only in `worm_postgres` (broken). |
| Prepared statement caching | ⚠ — only in `worm_postgres` (broken). |
| Streaming cursors via `query.stream()` | ✗ — builder doesn't expose. |
| Lazy hydration | ✗ — all-or-nothing. |
| Concurrent relation loading via `Future.wait` | ⚠ — `EagerLoader.run` is sequential per-relation. |

**Performance test tier:** no regression suite (spec §24.1 Tier 5).

---

### Section 23 — Error Handling

16 concrete `WormException` subtypes under [lib/src/exception/](packages/worm/lib/src/exception/):

| Spec class | Code |
|---|---|
| `WormException` base | ✓ `worm_exception.dart` |
| `ConnectionException` | ✓ `connection_exception.dart` |
| `ConnectionTimeoutException` | ✗ |
| `AuthenticationException` | ✗ |
| `QueryException` | ✓ `query_exception.dart` |
| `UniqueConstraintException` | ✓ `unique_constraint_exception.dart` |
| `ForeignKeyException` | ✓ `foreign_key_exception.dart` |
| `CheckConstraintException` | ✗ |
| `SyntaxException` | ✗ |
| `ModelException` (umbrella) | ✗ |
| `ModelNotFoundException` | ✓ `model_not_found_exception.dart` |
| `MassAssignmentException` | ✓ `mass_assignment_exception.dart` |
| `ValidationException` | ✓ `validation_exception.dart` |
| `LazyLoadingException` | ✗ |
| `MigrationException` | ✓ `migration_exception.dart` |
| `MigrationLockException` | ✗ |
| `IrreversibleMigrationException` | ✗ |
| `AdapterException` (umbrella) | ✗ |
| `AdapterMismatchException` | ✓ `adapter_mismatch_exception.dart` |
| `UnsupportedOperationException` | ✗ — `ConfigurationException` thrown instead by InMemoryAdapter for unsupported ops. |
| `DangerousQueryException` | ⚠ — named `FullTableScanException` in code. |
| `OperationCancelledException` | ✗ |

**Extras in code, not in spec:**

- `CastException` ([cast_exception.dart](packages/worm/lib/src/exception/cast_exception.dart))
- `ConfigurationException` ([configuration_exception.dart](packages/worm/lib/src/exception/configuration_exception.dart))
- `FactoryException` ([factory_exception.dart](packages/worm/lib/src/exception/factory_exception.dart))
- `RelationNotLoadedException` ([relation_not_loaded_exception.dart](packages/worm/lib/src/exception/relation_not_loaded_exception.dart))
- `TransactionException` ([transaction_exception.dart](packages/worm/lib/src/exception/transaction_exception.dart))
- `UninitializedFieldException` ([uninitialized_field_exception.dart](packages/worm/lib/src/exception/uninitialized_field_exception.dart))

**Error context fields:** `UniqueConstraintException` has `table`, `column`, `query`. Coverage on the other exceptions varies — needs sweep.

**Test coverage:** [test/src/exception/exception_test.dart](packages/worm/test/src/exception/exception_test.dart), [test/src/exception/validation_exception_errors_test.dart](packages/worm/test/src/exception/validation_exception_errors_test.dart).

---

### Section 24 — Testing Strategy

| Spec tier | Code status |
|---|---|
| **Tier 1**: Core unit tests, no DB, every commit | ✓ 722 passing |
| **Tier 2**: Adapter contract tests (same suite run against every adapter) | ⚠ Harness exists ([lib/testing/adapter_contract.dart](packages/worm/lib/testing/adapter_contract.dart)) — 590 lines — but analyzer-excluded because written against pre-EPIC-004 API. Matching test renamed `*.pending_adapter_contract_rewrite`. |
| **Tier 3**: Adapter integration tests (per-DB) | ✗ Adapters don't compile. |
| **Tier 4**: E2E workflow tests (CLI + codegen + migrate + seed + query) | ✗ No harness. CLI commands have unit tests but no end-to-end-from-empty-project flow. |
| **Tier 5**: Performance regression tests | ✗ No nightly suite. |
| `AdapterTestHarness` abstract base | ⚠ Concept exists; no explicit `AdapterTestHarness` class — `runAdapterContractTests` ([adapter_contract.dart:43-77](packages/worm/lib/testing/adapter_contract.dart#L43)) takes a factory and capabilities. |
| `Worm.beginTestTransaction()` / `Worm.rollbackTestTransaction()` | ✗ |
| Factory integration in tests | ✗ (Factory itself is partial; see §10) |

---

### Section 25 — Naming Conventions

[NamingConvention](packages/worm/lib/src/naming/naming_convention.dart) is **104 lines, 4 public static methods**:

| Spec rule | Status |
|---|---|
| Camel ↔ snake conversion | ✓ — `toSnakeCase` handles acronyms (`HTMLContent` → `html_content`), `toCamelCase` handles `_` splits. |
| `User` → `users`, `BlogPost` → `blog_posts` | ✓ — `tableName(input)`. |
| Pluralization | ⚠ — `_pluralize` ([naming_convention.dart:90-98](packages/worm/lib/src/naming/naming_convention.dart#L90)) handles only `+s`, `+es` (words ending `s`), and `+ies` (words ending `y`). No irregular plurals (`person` → `persones`; `child` → `childes`). No `-x`/`-ch`/`-sh`/`-o` handling either. |
| Pivot from `User` + `Role` → `role_user` (alphabetical, singular) | ✗ | High | Not encoded in `NamingConvention`. Pivot tables are user-supplied strings on the `@BelongsToMany` annotation. Documented behavior only. |
| Polymorphic type column stores model class name | ⚠ | The eager loader walks a per-relation map; no central convention enforced. |
| Override conventions via annotation parameters | ✓ — every annotation accepts a `name:` field. |

**Test coverage:** **No dedicated `naming/` test file**. Pluralization edge cases untested.

---

## Cross-cutting Issues

### CC-1: Duplicate `Worm` registry class

Two `final class Worm` declarations:

- [worm.dart:21](packages/worm/lib/src/registry/worm.dart#L21) — 209 lines, `async initialize`, `Map<Type, ModelRegistration>`, `Map<Type, List<Observer<Object>>>` with `observersFor(type)` dispatch. **This is the one re-exported via the registry barrel ([registry.dart](packages/worm/lib/src/registry/registry.dart)).**
- [worm_registry.dart:23](packages/worm/lib/src/registry/worm_registry.dart#L23) — 140 lines, sync `initialize`, `Set<Type>` models, untyped `List<Object>` observers.

The second class is reachable only via a direct `package:worm/src/registry/worm_registry.dart` import. [test/src/registry/worm_registry_test.dart](packages/worm/test/src/registry/worm_registry_test.dart) does exactly that, anchoring the dead-code path in the test suite.

**Recommendation:** delete `worm_registry.dart` + its test. Sweep imports.

---

### CC-2: Public mutable internal model state

Three fields on [Model](packages/worm/lib/src/model/model.dart) are public but conceptually internal:

- `final Map<String, Object?> relations` ([:29](packages/worm/lib/src/model/model.dart#L29))
- `final Map<String, Object?> injectedFields` ([:35](packages/worm/lib/src/model/model.dart#L35))
- `final ModelState state` ([:40](packages/worm/lib/src/model/model.dart#L40))

External code can mutate these directly, breaking dirty tracking, eager-load cache integrity, and aggregate injection invariants. Spec does not mandate they be public.

**Recommendation:** annotate with `@internal` from `package:meta`, or move to a private mixin with package-private accessors.

---

### CC-3: Internal ticket reference comments

27+ occurrences of `WI-001`, `WI-002`, `WI-006`, `WI-007`, `WI-008`, `AC-1`…`AC-10` survive across `lib/` and `test/`:

- [event_dispatcher.dart:15](packages/worm/lib/src/event/event_dispatcher.dart#L15)
- [morph.dart:6](packages/worm/lib/src/relation/morph.dart#L6)
- [soft_deletes.dart:11, :43](packages/worm/lib/src/model/soft_deletes.dart#L11)
- [model_hooks.dart:11](packages/worm/lib/src/model/model_hooks.dart#L11)
- [model_observer.dart:14](packages/worm/lib/src/event/model_observer.dart#L14)
- [paginator.dart:5](packages/worm/lib/src/pagination/paginator.dart#L5)
- [schema_dump_command.dart:19](packages/worm/lib/src/cli/commands/schema_dump_command.dart#L19)
- [model.dart](packages/worm/lib/src/model/model.dart) — 8 occurrences (lines 34, 67, 78, 94, 126, 149, 170, 197)
- [query_logger.dart:34](packages/worm/lib/src/logging/query_logger.dart#L34)
- [query_builder.dart:339-340](packages/worm/lib/src/query/query_builder.dart#L339)
- [relation_definition.dart:144](packages/worm/lib/src/relation/relation_definition.dart#L144)
- [eager_loader.dart:20](packages/worm/lib/src/relation/eager_loader.dart#L20)
- [test/src/query/fluent_qb_goldens_test.dart](packages/worm/test/src/query/fluent_qb_goldens_test.dart) — multiple
- [test/src/scope/soft_deletes_test.dart](packages/worm/test/src/scope/soft_deletes_test.dart) — multiple
- [test/src/serialization/serializer_test.dart](packages/worm/test/src/serialization/serializer_test.dart) — `WI-006 AC literal examples`
- [test/src/relation/morph_to_test.dart](packages/worm/test/src/relation/morph_to_test.dart) — `AC-5`
- [test/src/validation/validation_rules_test.dart](packages/worm/test/src/validation/validation_rules_test.dart) — `WI-001 AC #3`, `WI-002 AC #16`, `WI-002 AC literal examples`

Violates CLAUDE.md "don't reference the current task, fix, or callers — those belong in the PR description and rot as the codebase evolves."

**Recommendation:** `sed`-sweep these references out.

---

### CC-4: Unused annotations

7 annotation classes in [annotations.dart](packages/worm/lib/annotations.dart) are not consumed by any codegen or runtime:

- `@Appended` ([:249](packages/worm/lib/annotations.dart#L249))
- `@Hidden` ([:258](packages/worm/lib/annotations.dart#L258))
- `@Attribute` ([:264](packages/worm/lib/annotations.dart#L264))
- `@CastAs` ([:273](packages/worm/lib/annotations.dart#L273))
- `@Fillable` ([:282](packages/worm/lib/annotations.dart#L282))
- `@Guarded` ([:291](packages/worm/lib/annotations.dart#L291))
- `@Computed` ([:300](packages/worm/lib/annotations.dart#L300))

Verified by `grep -r` for each — only mentioned in their own declaration file and one doc-string-style reference in a test.

The spec describes runtime behavior for each (hidden fields in serialization output, appended virtual attributes, mass-assignment guards). Without codegen processing them, the annotations mislead users into thinking the behaviors work.

**Recommendation:** either wire them through codegen / serializer / Model.fill, or remove until implemented.

---

### CC-5: Spec method-name mismatches (literal-example compilation)

The spec's example code will not compile against the current code:

| Spec | Code | Fix |
|---|---|---|
| `Operator.equals` etc. | `Operator.eq` etc. ([operator.dart](packages/worm/lib/src/query/operator.dart)) | Add aliases or rename. |
| `field.whereIn(values)` | `field.inList(values)` | Add alias. |
| `field.whereNotIn(values)` | `field.notInList(values)` | Add alias. |
| `table.id()` | `table.idUuid()` | Add alias on Blueprint. |
| `table.intId()` | `table.idIncrements()` | Add alias. |
| `Future<void> up(Schema schema) async` | `Future<void> up(DatabaseAdapter adapter) async` | Rename or wrap. |
| `.where(field, value)` 2-arg | `.where(field.eq(value))` | Add overload on QueryBuilder. |
| `.where(field, op, value)` 3-arg | (no equivalent) | Add overload that builds the right `Predicate`. |
| `withoutGlobalScope<ActiveScope>()` typed generic | `.withoutGlobalScope('soft_deletes')` string | Add generic overload that reads `GlobalScope.name`. |
| Migration body uses `await schema.create('users', (table) { ... })` | template emits `await adapter.executeSchema(SchemaDescriptor.createTable(...))` | Update template to use Blueprint via a `Schema` facade. |

---

### CC-6: Dead code under `worm_registry.dart`

`worm_registry.dart` (140 lines) plus its test file (lines unknown) is unused except for the explicit test import. See CC-1.

---

### CC-7: `afterCommit` does not actually wait for transaction commit

[active_record.dart:48-49, :69, :192-198](packages/worm/lib/src/model/active_record.dart#L192) flushes registered `afterCommit` callbacks immediately after the local save/delete operation returns. There is no transaction-context awareness. Spec §12.4 explicitly promises "fires only after the wrapping transaction commits."

Fix requires a transaction-scoped callback queue (per-tx state on the adapter or a `Zone`-based registry).

---

### CC-8: Validation does not auto-fire in `save`

[active_record.dart:32-39](packages/worm/lib/src/model/active_record.dart#L32) fires `beforeValidate` and `afterValidate` hooks but does not invoke `Validator` between them. Spec §13.3 line 1948: "Validation runs automatically before `save()`, in the `beforeValidate` / `afterValidate` lifecycle phase."

Users today must manually call `Validator.validate(...)` before `model.save()`.

---

## Recommended Follow-up Epics (re-scoped)

### EPIC-009: Model finish-out (was: Active Record Model API)
**Scope shrunk** — save/delete/refresh/fill/dirty tracking already exist. New scope:
- `Future<bool> Model.update(Map<String, Object?> data)` (fill + save shortcut).
- `Future<bool> Model.forceDelete()` on the top-level Model (lift from SoftDeletes mixin).
- `Model replicate({List<String> except = const []})` (clone with new ID, unsaved).
- Static `Model.withoutEvents([Type[, types]], callback)`.
- Fix `afterCommit` to actually defer until transaction commit (depends on EPIC-018).
- Wire `Validator` invocation into `ActiveRecord.save` between the two `Validate` hooks.
- Annotate `Model.relations`, `Model.injectedFields`, `Model.state` with `@internal` (or move behind package-private accessors).
- Typed `getOriginal<T>(Field<T> field)` overload.
- Switch validation to a typed `Map<Field, List<ValidationRule>> rules` getter on Model.
- `updateRules` override (dirty-fields-only).
- Add `beforeRestore` / `afterRestore` to `LifecycleEvent` and wire through SoftDeletes.
- Strictness severity: **High**.

### EPIC-010: Adapter API alignment ✓ (delivered 2026-05-24 under EPIC-000)
- ~~Rewrite `worm_postgres` and `worm_mongodb` compilers against post-EPIC-004 query/schema API.~~ ✓ both compile and pass `dart analyze` clean.
- ~~Mix in `ExplainCapable` on both.~~ ✓ Postgres uses `EXPLAIN (FORMAT JSON)`; Mongo uses `runCommand({explain:..., verbosity:"executionStats"})`.
- ~~Rewrite [adapter_contract.dart](packages/worm/lib/testing/adapter_contract.dart) against the new API; run against all three adapters in CI.~~ ✓ Contract suites at `worm_postgres/test/postgres_adapter_contract_test.dart` and `worm_mongodb/test/mongo_adapter_contract_test.dart`, gated by `PG_DB` / `MONGO_URI`.
- Severity (when planned): **Critical**.

### EPIC-011: Factory + Seeder completion
- Factory: `.count(n)`, `.create([overrides:])`, `.has(otherFactory, rel)`, `.for_(parent, rel)`, `.sequence([...])`, expose `faker` on the base class.
- Seeder: create `worm_seeders` tracking table; introduce `SeederRecordStore`; implement idempotency; add `Seeder.order`; introduce `DatabaseSeeder` master pattern.
- `Worm.beginTestTransaction()` / `rollbackTestTransaction()` for test isolation.
- Severity: **High**.

### EPIC-012: QueryBuilder surface completion
- Scalar terminals: `sum`/`avg`/`min`/`max(Field<num>)`.
- Streaming: `stream`, `chunk(size, cb)`, `streamChunks(size)`.
- Boolean composition: `whereGroup`, `whereExists<T>`, `whereColumn`.
- Inspection: `toSql`, `toMongoFilter`, `explain`, `debug`.
- 2-arg `where(field, value)` and 3-arg `where(field, op, value)` overloads.
- `.sql(...)` and `.mongo(...)` adapter-context gates with `AdapterMismatchException`.
- `whereRaw(sql, params, allowRaw: true)`.
- Severity: **High**.

### EPIC-013: Relations runtime
- Typed relation accessors on Model — `user.posts.add(post)`, `user.posts.dissociate()`, `user.roles.attach(...)`, `user.roles.detach(...)`, `user.roles.sync(...)`. The underlying PivotManager already exists; wire it through codegen-generated `User$.posts` etc.
- Constrained eager loading `withRelation(rel, (q) => q.where(...))`.
- Nested eager paths `User$.posts.include([Post$.comments])`.
- `OnDelete.ormCascade` runtime that walks children before parent delete.
- Polymorphic type resolution via a central morph-type registry.
- Severity: **High**.

### EPIC-014 (new): Spec API alias / naming sweep
- Add operator aliases: `Operator.equals/notEquals/greaterThan/lessThan/...` as `static const`s pointing at `eq/neq/gt/lt/...`.
- Add field-method aliases: `whereIn`, `whereNotIn`.
- Add Blueprint method aliases: `table.id()` (UUID), `table.intId()` (auto-incr).
- Rename or wrap `Migration.up(DatabaseAdapter)` to accept a `Schema` facade matching the spec example.
- Add typed-generic `withoutGlobalScope<X extends GlobalScope>()` overload reading `X.name`.
- Severity: **Medium**.

### EPIC-015 (new): Annotation wiring
- Wire `@Hidden`/`@Appended`/`@Computed` into codegen → Serializer.
- Wire `@CastAs(...)` into codegen → `CastManager`.
- Wire `@Fillable`/`@Guarded` into codegen → `Model.fillable`/`guarded` overrides.
- Add `DurationCast`.
- Either remove `@Attribute` (purpose unclear from spec) or document it.
- Severity: **Medium**.

### EPIC-016 (new): `Worm` registry deduplication ✓ (delivered 2026-05-24 under EPIC-000)
- ~~Delete `lib/src/registry/worm_registry.dart`.~~ ✓
- ~~Delete `test/src/registry/worm_registry_test.dart`.~~ ✓
- ~~Migrate any direct imports.~~ ✓ Exactly one `final class Worm` remains, at `lib/src/registry/worm.dart`.
- The 7 unused annotation classes (`Appended`, `Hidden`, `Attribute`, `CastAs`, `Fillable`, `Guarded`, `Computed`) are now marked `@experimental` from `package:meta` so callers see the warning until EPIC-015 wires their codegen.
- Severity (when planned): **Medium**.

### ✓ EPIC-017 (new): Internal ticket reference sweep
- Strip every `WI-XXX` / `AC-N` comment from `lib/` and `test/`.
- Replace with intent-described comments where the original information is load-bearing.
- Add a pre-commit check or lint rule preventing reintroduction.
- Severity: **Low**.
- **Status:** Complete. `grep -rn 'WI-[0-9]\|AC-[0-9]' lib/ test/ --include='*.dart'` returns zero; load-bearing intent rewritten in place; `worm_lints/`'s `no_ticket_reference` rule prevents reintroduction.

### EPIC-023 (new): Codegen foundation ✓ (delivered 2026-05-24 under EPIC-000)
Prerequisite for EPIC-013 (Relations runtime) and EPIC-015 (Annotation wiring) — both depend on the generator emitting relation constants and processing annotations.
- ~~Generator emits typed `RelationField<T>` constants on every companion class (`User$.posts` as `RelationField<List<Post>>`, `User$.profile` as `RelationField<Profile>`).~~ ✓
- ~~Generator output is cast-free (no ` as ` casts).~~ ✓ verified by test in `worm_generator/test/integration/`.
- ~~Annotation-reader infrastructure (`worm_generator/lib/src/relation_annotation_reader.dart`) maps the 9 supported relation annotations to a typed `RelationDescriptor` for codegen consumption.~~ ✓
- Severity (when planned): **High**.

### EPIC-018 (was 014): Scopes + Strictness wiring
- Auto-application of `@GlobalScope` on every `QueryBuilder<T>` (codegen-driven).
- Codegen of typed scope-extension methods (not just `scopeNames` list).
- Lazy-loading enforcement when strict.
- Read-side `preventFullTableScans` enforcement.
- `Worm.unsafe(() async { ... })` escape hatch.
- Severity: **Medium**.

### EPIC-019 (was 015): Auto-migration + schema:dump
- Wire `DiffEngine` into `make:migration --auto`.
- Honor `--prune` in `schema:dump`.
- Migration `dependsOn` enforcement.
- Composite FKs and partial-unique indexes on `IndexDefinition`.
- Severity: **Medium**.

### EPIC-020 (was 016): Transactions top-level
- `Worm.transaction((txn) async {})` with connection override.
- `Model.save(transaction:)` propagation.
- `txn.savepoint(() async {})`.
- Transaction-scoped `afterCommit` queue (needed by EPIC-009 too).
- Severity: **High**.

### ✓ EPIC-021 (was 017): Exception hierarchy completion
- Add `ConnectionTimeoutException`, `AuthenticationException`, `CheckConstraintException`, `SyntaxException`, `LazyLoadingException`, `MigrationLockException`, `IrreversibleMigrationException`, `ModelException` umbrella, `AdapterException` umbrella, `UnsupportedOperationException`, `OperationCancelledException`.
- Alias `FullTableScanException` ↔ `DangerousQueryException`.
- Standardize error-context fields (`table`, `column`, `query`, `migration`) across every exception.
- Severity: **Medium**.
- **Status:** Complete. All listed concrete exceptions exist under `lib/src/exception/`, the umbrella types reparent existing subtypes, `DangerousQueryException` is a typedef alias for `FullTableScanException`, and `ConfigurationException` "feature unsupported" throw sites in `InMemoryAdapter` (`rawQuery` / `rawExecute` / `executeSchema.alter`) and `EagerLoader` (aggregate over non-HasMany/HasOne) now throw `UnsupportedOperationException` instead.

### EPIC-022 (was 018): Performance + E2E test harness
- Lazy hydration.
- Concurrent relation loading (`Future.wait`).
- `IN` chunking in `InMemoryAdapter`.
- E2E CLI workflow tests (empty project → init → make → migrate → seed → query).
- Performance regression tier (10k models, 1k+5k eager-load, 50k stream).
- Severity: **Medium**.

---

## Operational Notes

- **Pre-merge-back tag:** `pre-merge-back-snapshot-2026-05-23` (state before Phase 1 of the merge-back).
- **Pre-restructure tag:** `pre-restructure-snapshot` (state before `git filter-repo`).
- **Backup:** `/tmp/worm-backup-prerestructure/` (Phase-4 state).
- **This audit's baseline:** commit `d6f6796`. Verify with `cd packages/worm && dart format --set-exit-if-changed . && dart analyze && dart test` — must pass before treating the audit as current.
- **Sibling adapter packages** (`worm_postgres`, `worm_mongodb`) are deliberately excluded from the audit's "passes verification" claim — they need EPIC-010.

## How to use this document

1. Pick an EPIC from "Recommended Follow-up Epics" — sort by severity.
2. Open the section(s) it covers and walk the per-feature table.
3. Cross-reference the cited `file:line` to confirm the gap still exists in the current `main` (this audit is point-in-time at `d6f6796`).
4. When done, update the matching row in the Executive Summary table and the per-section feature tables. Move the EPIC entry from "Recommended Follow-up Epics" into a "Completed" section.
