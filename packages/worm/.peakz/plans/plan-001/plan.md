# Worm Development Plan

## Overview

**Plan ID:** plan-001

**Total Epics:** 8 epics across Foundation, Feature, Quality, and Performance tiers

**Critical Path:** EPIC-000 → EPIC-006 → [EPIC-001, EPIC-002, EPIC-004] → EPIC-003 → EPIC-005 → EPIC-007

---

## Execution Order & Dependencies

### Phase 1: Foundation & Groundwork (Must Complete First)

#### EPIC-000: Foundation — Adapter Alignment, Codegen Foundation, and Dead Code Removal
**Status:** Foundation (unblocks all downstream)  
**Dependencies:** None  
**Scope:** 6 major workflows
- Rewrite PostgreSQL adapter compiler against new query/schema API (~120 errors)
- Rewrite MongoDB adapter compiler against new API (~77 errors)
- Restore and wire adapter contract harness in CI
- Extend code generator to emit typed RelationField constants
- Extend generator to surface annotation metadata (@Hidden, @Appended, etc.)
- Delete duplicate worm_registry.dart; audit and clean all references

**Key Risks:** Adapter rewrites have high regression surface; mitigate via contract harness gate

**Completion Criteria:** dart analyze clean, contract harness passes all adapters, zero casts in generated code, only one Worm class remains

---

#### EPIC-006: Exception Hierarchy Completion and Internal Reference Cleanup
**Status:** Quality/Groundwork (required before feature epics throw exceptions)  
**Dependencies:** EPIC-000  
**Scope:** 8 workflows, split delivery
- **W1–W4 + W7 (Ship Early):** Add 9 missing exception types (ConnectionTimeout, Authentication, CheckConstraint, etc.), introduce ModelException/AdapterException umbrellas, create FullTableScanException alias, standardize context fields, add construction tests
- **W5–W6 + W8 (Ship Last):** Sweep WI-*/AC-* comments, add lint rule preventing reintroduction, migrate ConfigurationException → UnsupportedOperationException

**Key Risks:** Umbrella types may shadow existing catch ordering; lint may bounce on existing files until cleanup completes

**Completion Criteria:** Every exception has typed context, ModelException/AdapterException inheritance tree correct, zero WI-/AC- comments in lib/test, lint rule enforces rule in CI

---

### Phase 2: Core Features (Parallel After Foundation)

#### EPIC-001: Model Lifecycle Finish-Out and Top-Level Transactions
**Status:** Feature  
**Dependencies:** EPIC-000, EPIC-006  
**Scope:** 7 major workflows
- Add Model.update/forceDelete/replicate convenience methods and withoutEvents callback muting
- Wire validation into save() between beforeValidate/afterValidate hooks; migrate to typed Map<Field, List<ValidationRule>>
- Implement beforeRestore/afterRestore lifecycle hooks
- Seal internal state (relations, injectedFields, state) as @internal
- Implement Worm.transaction<T> with adapter-state callback queue
- Deploy afterCommit queue that drains only on outermost transaction commit

**Key Risks:** Validation API migration is large blast radius; afterCommit queue must handle nesting, parallelism, and rollback correctly

**Completion Criteria:** Model.update persists and fires hooks, forceDelete on every model, replicate returns unsaved copy, withoutEvents suppresses hooks correctly, Worm.transaction commits/rolls-back with nested support, afterCommit drains only on outermost commit

---

#### EPIC-002: QueryBuilder Surface Completion
**Status:** Feature  
**Dependencies:** EPIC-000, EPIC-006  
**Scope:** 8 major workflows
- Add scalar aggregates (sum/avg/min/max) as adapter-pushed terminals
- Implement streaming terminals (stream, chunk, streamChunks) with constant memory on 50k rows
- Support boolean composition (whereGroup, whereExists, whereColumn)
- Add query inspection (toSql, toMongoFilter, explain, debug)
- Extend where() overloads (2-arg implicit eq, 3-arg with operator)
- Implement withoutGlobalScope<X> reading scope name at compile time
- Add adapter gates (.sql / .mongo closures throwing AdapterMismatchException)
- Provide whereRaw escape hatch with allowRaw guard

**Key Risks:** Streaming requires adapter cursor semantics that may differ per adapter; adapter gates risk feature drift

**Completion Criteria:** Aggregates never materialize rows, 50k stream < 50MB memory, whereExists compiles to EXISTS/\$exists, where(field, value) equiv to where(field, Operator.eq, value), .sql() gate throws AdapterMismatchException on wrong adapter

---

#### EPIC-004: Factory, Seeder, and CLI/Migration Enhancements
**Status:** Feature  
**Dependencies:** EPIC-000, EPIC-001, EPIC-006  
**Scope:** 8 major workflows
- Add faker getter on Factory; implement count/create/has/for_/sequence chainable methods
- Implement seeder tracking via worm_seeders table; add Seeder.order for explicit ordering
- Wire Worm.beginTestTransaction / rollbackTestTransaction for test isolation
- Integrate DiffEngine into worm make:migration --auto with pretend mode
- Implement schema:dump --prune to squash old migrations
- Enforce Migration.dependsOn topological sort with cycle detection
- Extend IndexDefinition with composite FKs and partial-unique indexes
- Introduce user-facing Schema facade (Migration.up(Schema) overload)

**Key Risks:** Test transaction binding affects parallel test isolation; schema:dump --prune is destructive; composite FK syntax must work for both SQL and Mongo

**Completion Criteria:** Factory.count(5).create() persists 5 rows, seeder tracking in worm_seeders, test transaction rolls back database state, make:migration --auto generates matching diff, dependsOn cycle rejected with both migration names, composite FK in DDL

---

### Phase 3: Advanced Features (Depend on Phase 2)

#### EPIC-003: Relations Runtime and Annotation Wiring
**Status:** Feature  
**Dependencies:** EPIC-000, EPIC-001, EPIC-006  
**Scope:** 10 major workflows
- Emit per-relation accessor methods (BelongsToAccessor, HasManyAccessor, BelongsToManyAccessor) with add/attach/sync/detach operations
- Support constrained eager loading via withRelation(RelationField, (q) => q.where(...))
- Implement nested paths (User$.posts.include([Post$.comments])) with breadth-first batching
- Deploy OnDelete.ormCascade runtime behavior (fires ORM hooks, not DB-level CASCADE)
- Build central Worm.morphRegistry for polymorphic type resolution
- Wire @Hidden field skipping in Serializer
- Wire @Appended (DB-derived) and @Computed (transient) getter stubs
- Wire @CastAs into CastManager at bootstrap
- Wire @Fillable/@Guarded into mass-assignment enforcement
- Ship DurationCast as default cast

**Key Risks:** Relation accessor signatures must sync with EPIC-000 codegen; ormCascade hook ordering interacts with EPIC-001 transactions; annotation wiring is a large surface

**Completion Criteria:** user.posts.add persists with FK, sync results in exact 3 pivot rows, nested eager-load uses exactly 3 queries, ormCascade fires beforeDelete/afterDelete on children, @Hidden absent from toMap, @CastAs round-trips Duration ↔ ms

---

#### EPIC-005: Strictness, Scopes, and Spec API Aliases
**Status:** Feature  
**Dependencies:** EPIC-000, EPIC-002, EPIC-004, EPIC-006  
**Scope:** 9 major workflows
- Auto-apply @GlobalScope scopes to every QueryBuilder via codegen; add withoutGlobalScope<X> bypass
- Generate typed scope extension methods (not just string lists)
- Throw LazyLoadingException in strict mode on unloaded relation access; bypass via Worm.unsafe
- Enforce preventFullTableScans on .get() without .where() in strict mode
- Unify preventFullTableScans/preventDestructiveWithoutWhere overlap
- Add Operator aliases (equals, notEquals, greaterThan, etc.) as static const pointers
- Add FieldOperators aliases (whereIn, whereNotIn, whereBetween, etc.)
- Add Blueprint helpers (table.id(), table.intId(), table.uuid())
- Support cursorPaginate(perPage:, after:) parameter names; rename Page.data → items, add hasNextPage/hasPrevPage

**Key Risks:** Auto-applied scopes can mask data; strict-mode enforcement may break existing tests; renaming Page.data is breaking change at 0.x

**Completion Criteria:** QueryBuilder auto-applies scopes, scope extension methods callable, unloaded relation throws in strict mode, .get() without .where() throws in strict mode, Operator.equals === Operator.eq (compile-time alias), cursorPaginate parameter names compatible

---

### Phase 4: Performance & E2E (All Previous Epics Must Complete)

#### EPIC-007: Performance Optimizations, Adapter Integration, and E2E Testing
**Status:** Performance (final validation)  
**Dependencies:** EPIC-000, EPIC-001, EPIC-002, EPIC-003, EPIC-004, EPIC-005, EPIC-006  
**Scope:** 10 major workflows
- Deploy lazy column hydration scoped to select([...]) columns; mark unselected as 'not loaded'
- Enable concurrent eager-load relation fetching via Future.wait on independent relations
- Implement IN-clause chunking at 1000 IDs in all adapters
- Build E2E CLI workflow tests: empty project → init → make:model → migrate → db:seed → query
- Enforce performance tier: 10k inserts < 5s
- Enforce performance tier: 1k+5k batched eager-load < 500ms, exactly 2 queries
- Enforce performance tier: 50k streamed rows < 50MB resident growth
- Enforce performance tier: dirty UPDATE touches only dirty columns
- Deploy slow-query logger (default 200ms threshold, emit WARN)
- Promote NPlusOneDetector warnings to exceptions in strict mode

**Key Risks:** Lazy hydration interacts subtly with serialization; perf thresholds vary by CI machine (use relative regression detection); memory measurement is approximate; E2E subprocess spawning can be flaky

**Completion Criteria:** select([...]) only hydrates specified columns, eager-loader concurrent on independent relations, IN-chunking verified at 1000-ID boundary, E2E test runs full workflow end-to-end, all perf tiers met, dirty UPDATE emits optimized SQL, slow-query threshold enforced, NPlusOne escalated in strict mode

---

## Dependency Graph Summary

```
EPIC-000 (Foundation)
  ├─→ EPIC-006 (Exception Hierarchy)
  │     ├─→ EPIC-001 (Model Lifecycle)
  │     │     └─→ EPIC-003 (Relations)
  │     │           └─→ EPIC-007 (Performance)
  │     ├─→ EPIC-002 (QueryBuilder)
  │     │     └─→ EPIC-005 (Strictness)
  │     │           └─→ EPIC-007
  │     └─→ EPIC-004 (Factory/Seeder/CLI)
  │           └─→ EPIC-005
  │                 └─→ EPIC-007
```

---

## Key Milestones

| Phase | Epics | Outcome |
|-------|-------|---------|
| **1** | EPIC-000, EPIC-006 | Clean foundation: aligned adapters, complete exception hierarchy, no duplicate registry |
| **2** | EPIC-001, EPIC-002, EPIC-004 | Core runtime: transactions, queries, factories—all ready for features |
| **3** | EPIC-003, EPIC-005 | Advanced features: relations, strictness, scopes—near-complete API surface |
| **4** | EPIC-007 | Performance validated: perf tiers met, E2E tests passing, regression suite in place |

---

## Cross-Epic Success Criteria

- **dart analyze** clean in all 4 packages (worm, worm_postgres, worm_mongodb, worm_generator)
- **dart test** passes 722+ tests, including unit, E2E, and performance regression suites
- **Adapter contract harness** passes against InMemoryAdapter, worm_postgres, worm_mongodb in CI
- **Zero breaking changes** between epics; overloads/deprecation warnings used for transitions
- **Zero casts** in generated code (' as ' pattern scan in generator test)
- **Split delivery** honored for EPIC-006: W1–W4 + W7 before EPIC-001..005; W5–W6 + W8 after all features ship