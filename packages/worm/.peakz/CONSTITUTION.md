<!-- SECTION_START id="metadata" owner="constitution_synthesizer" -->
# Metadata
**Project:** Worm ORM
**Version:** 0.x pre-release (no stability guarantees; breaking renames permitted)
**Scope:** All packages in the `packages/` monorepo — `worm`, `worm_generator`, `worm_postgres`, `worm_mongodb` — share this constitution.
**Authoritative sources:**
1. `worm_concept.md` is authoritative for the public API surface (names, signatures, semantics).
2. Well-tested internal implementations may diverge from the spec only when explicitly recorded in the audit; otherwise the spec wins on rename, signature, and behavior conflicts.
3. `CLAUDE.md` rules and the audit (`packages/worm/audit/SPEC_GAP_ANALYSIS.md`) are authoritative for code quality and gap tracking.

**Audit baseline:** commit `d6f6796`, `dart test` 722/722 in `worm/`, 9/9 in `worm_generator/`. Adapter packages must reach the same bar.

---

<!-- SECTION_END id="metadata" owner="constitution_synthesizer" -->

<!-- SECTION_START id="principles" owner="constitution_synthesizer" -->
# Principles

- **Type safety is absolute.** No `dynamic` outside documented interop; no `Object`/`Object?` when a concrete type, generic, enum, or sealed class fits; no `Map<String, dynamic>` as a domain type; no `as` casts in hand-written code; `!` only when non-nullness is proven by the surrounding code.
- **Spec compliance over local convenience.** When the spec's example would not compile against the code, add the alias, overload, or rename to make the spec example literal. Examples: `Operator.equals`/`eq`, `field.whereIn`/`inList`, `table.id()`/`idUuid()`, `Migration.up(Schema)`/`up(DatabaseAdapter)`.
- **No dead code.** Duplicate classes (e.g. two `final class Worm`), unused annotations (`@Hidden`, `@Appended`, `@Computed`, `@CastAs`, `@Fillable`, `@Guarded`, `@Attribute`), and dead tracking types (`SeederRecord` without a tracking table) must be either wired up or deleted.
- **No internal ticket references in code.** `WI-001`…`WI-008` and `AC-1`…`AC-10` comments are forbidden in `lib/` and `test/`. Intent comments only when removing them would confuse a future reader.
- **Public API surface is intentional.** Conceptually internal model state (`Model.relations`, `Model.injectedFields`, `Model.state`) must be `@internal` from `package:meta` or moved behind package-private accessors.
- **Active Record is the default; Data Mapper is opt-in.** `Repository<T>` exists; do not collapse the two paths or invert the default.
- **One ORM, multiple adapters.** Adapter-specific surface (`.sql()`, `.mongo()`) must be gated behind context closures that throw `AdapterMismatchException` when used against the wrong adapter.
- **No string-keyed escape hatches where a type fits.** `withoutGlobalScope<X>()` over `withoutGlobalScope('name')`; typed `Field` keys for validation rules over `Map<String, …>`.

---

<!-- SECTION_END id="principles" owner="constitution_synthesizer" -->

<!-- SECTION_START id="architecture" owner="constitution_synthesizer" -->
# Architecture

- **Project shape: Dart ORM library + CLI + sibling adapter and generator packages.** Not a framework, not a runtime application. No global mutable singletons except the explicit `Worm` registry.
- **Package layout (fixed):**
  - `packages/worm/` — core library, in-memory adapter, CLI binary (`bin/worm.dart`), codegen sources under `lib/src/codegen/`, public test harness under `lib/testing/`.
  - `packages/worm_generator/` — `build_runner` + `source_gen` wrapper around the in-package generators.
  - `packages/worm_postgres/`, `packages/worm_mongodb/` — adapter implementations; must compile against the current `worm` API at all times.
- **Barrel exports:** `lib/worm.dart` is the single public entry point. New public symbols must be exported from the barrel or live behind `lib/testing/`.
- **Registry:** exactly one `final class Worm`. Delete `lib/src/registry/worm_registry.dart` and its test; the registry barrel re-exports `worm.dart` only.
- **Connection routing:** `@Table(connection: 'mongo')` is honored at runtime via `Model.connectionName`, not hard-coded to `'default'`.
- **Codegen contract:** generated companions (`User$`), hydration extensions, query starters, typed scope extension methods, and typed relation field constants (`User$.posts`). Generator output must be cast-free.
- **Adapter contract:** every adapter implements the full `DatabaseAdapter` interface, declares its `AdapterCapabilities`, mixes in `ExplainCapable`, and passes the contract harness in `lib/testing/adapter_contract.dart`.
- **CLI exit codes:** `UsageException` → `2`; uncaught exception → `1`; success → `0`. Match `package:args` conventions.

---

<!-- SECTION_END id="architecture" owner="constitution_synthesizer" -->

<!-- SECTION_START id="testing" owner="constitution_synthesizer" -->
# Testing

- **Five tiers, every tier owned:**
  1. Unit tests with `InMemoryAdapter` — run on every commit; must pass cleanly (`dart test`).
  2. Adapter contract tests — `runAdapterContractTests(factory, capabilities)` executed against `InMemoryAdapter`, `worm_postgres`, `worm_mongodb`.
  3. Adapter integration tests — real Postgres and real Mongo, run in CI against ephemeral containers.
  4. End-to-end CLI workflows — empty project → `init` → `make:*` → `migrate` → `db:seed` → query.
  5. Performance regression — 10k inserts, 1k+5k batched eager-load, 50k streamed rows; thresholds tracked over time.
- **Behavior over existence.** A test that only asserts a method exists or that a mock returned a literal is not a test. Assert the observable effect (row count, row contents, hook order, exception type and fields).
- **Fakes and stubs over mocks.** Mock libraries are reserved for cases where a fake is genuinely impractical.
- **Mandatory test categories:**
  - Every public terminal on `QueryBuilder` has at least one execution test against `InMemoryAdapter`.
  - Every lifecycle hook has an ordering test and a cancellation test.
  - Every exception subtype has a construction-and-context test.
  - Every cast has a roundtrip test (DB ↔ model) with edge cases (null, max, min, malformed).
  - `afterCommit` has a transaction-wrapped test proving it does not fire until commit.
  - `Validator.validate` auto-fires inside `Model.save` between `beforeValidate` and `afterValidate`; tested end-to-end.
- **Regression test for every bug fix.** Reproducer first, fix second, regression test stays.
- **Pluralizer:** edge-case test file required (`person`, `child`, `box`, `church`, `bus`, `hero`, `query`).
- **Test isolation:** `Worm.beginTestTransaction()` + `Worm.rollbackTestTransaction()` must exist and be used in adapter integration suites.
- **Pre-merge gate:** `dart format --set-exit-if-changed .`, `dart analyze`, and `dart test` all clean in every package — including `worm_postgres` and `worm_mongodb`.

---

<!-- SECTION_END id="testing" owner="constitution_synthesizer" -->

<!-- SECTION_START id="ux" owner="constitution_synthesizer" -->
# UX

- **Public API examples in the spec must compile.** If a renamed alias is needed, add it; do not ask the user to rewrite.
- **Naming conventions:**
  - Dart camelCase ↔ DB snake_case bidirectional, acronym-aware (`HTMLContent` ↔ `html_content`).
  - Pluralization handles `-s`, `-es` (`-s/-x/-ch/-sh/-o` stems), `-ies` (consonant + `y`), and a documented irregular list (`person/people`, `child/children`, `man/men`, `woman/women`, `mouse/mice`, `goose/geese`).
  - Pivot table name = alphabetical singular join (`Role` + `User` → `role_user`); encoded in `NamingConvention`, not left to the user.
- **Error messages name the offender.** Every exception carries the relevant context (`table`, `column`, `query`, `migration`, `model`, `field`); generic "validation failed" is not acceptable.
- **CLI output is structured.** Each command prints one human-readable line per action plus a final summary; `--pretend` prints the planned SQL without executing; `--force` is required for destructive commands in non-development environments.
- **No silent data loss.** Mass assignment skips disallowed fields unless `strictMassAssignment` is true, in which case it throws `MassAssignmentException` with the offending keys listed.
- **Strictness escape hatch:** `Worm.unsafe(() async { … })` is the documented way to bypass strict checks for one block; using it outside that block is forbidden.
- **Documentation gating:** an annotation is only documented as functional once its codegen or runtime consumer ships and is tested. Until then it is either removed or marked `@experimental`.

---

<!-- SECTION_END id="ux" owner="constitution_synthesizer" -->

<!-- SECTION_START id="performance" owner="constitution_synthesizer" -->
# Performance

- **Hard targets (in-memory adapter, single isolate, M-class laptop):**
  - 10k single-row inserts: < 5s wall-clock.
  - Eager load 1k parents + 5k children: exactly 2 queries, < 500ms.
  - Streaming 50k rows via `query.stream()`: constant memory (< 50MB resident growth).
  - Single-row dirty UPDATE: emits SQL touching only dirty columns, verified by adapter trace.
- **Required optimizations:**
  - Dirty-only UPDATE (already in place; do not regress).
  - Batched eager loading (`IN`-based, single child query per relation).
  - `IN` chunking at 1000 IDs for adapters that need it.
  - Streaming terminals (`stream`, `chunk`, `streamChunks`) on `QueryBuilder`.
  - Concurrent relation loading via `Future.wait` when independent.
- **Forbidden patterns:**
  - Loading all rows into memory to count, sum, or check existence — `.count`, `.exists`, `.sum`, etc. must push down to the adapter.
  - Per-row N+1 queries when eager loading is available; the `NPlusOneDetector` warning is a CI failure in strict mode.
  - Full-table scan on `update`/`delete` without `where` unless inside `Worm.unsafe(...)`.
- **Slow-query budget:** default `slowQueryThreshold` of 200ms; queries exceeding this are logged at WARN with the rendered SQL and parameters.

---

<!-- SECTION_END id="performance" owner="constitution_synthesizer" -->

<!-- SECTION_START id="governance" owner="constitution_synthesizer" -->
# Governance

- **Source of truth precedence:** Spec > Constitution > Audit > Code. When spec and well-tested code disagree on internals (not public API), document the divergence in the audit and proceed; on public API the spec wins and the code is changed.
- **Change classification:**
  - **Public API change** (signature, name, behavior of an exported symbol): requires a spec update in the same PR, an audit row flip, and a regression test. Allowed freely while at 0.x.
  - **Internal refactor:** requires existing tests to remain green, no public surface drift, and `dart format`/`dart analyze`/`dart test` clean.
  - **Bug fix:** requires a regression test that fails before the fix and passes after.
- **Epic discipline:** new work is scoped under an EPIC entry in the audit's "Recommended Follow-up Epics." A PR that closes an audit gap updates the matching audit row and Executive Summary table in the same PR.
- **No partial implementations on `main`.** A feature ships fully wired (annotation → codegen → runtime → test) or not at all. Half-finished branches stay on feature branches.
- **No skipped hooks.** `--no-verify`, `--no-gpg-sign`, and analyzer exclusion of test files are forbidden unless the constitution is amended.
- **Adapter packages are first-class.** A PR that lands a `worm` change which breaks `worm_postgres` or `worm_mongodb` is not mergeable until both adapters compile and pass the contract harness.
- **Internal references decay.** Any PR introducing `WI-XXX` or `AC-N` comments in `lib/` or `test/` is blocked by a lint rule (to be added under the cleanup epic).
- **Audit currency:** the audit (`SPEC_GAP_ANALYSIS.md`) is re-verified against `main` at the start of every epic and at every minor version bump.
- **Constitution amendments:** require a dedicated PR titled `chore(constitution): …`, reference the principle changed, and link the audit rows that justify the change.
<!-- SECTION_END id="governance" owner="constitution_synthesizer" -->
