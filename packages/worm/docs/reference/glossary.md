---
title: Glossary
description: Short definitions of the terms worm's documentation uses, each with a pointer to the page that explains it in full.
---

Every term the docs lean on, defined in two or three lines. Follow the link on each entry for the full treatment.

### Adapter (vs driver)

An adapter is a class implementing the `DatabaseAdapter` contract; it compiles descriptors into native operations for one backend. A driver is the package that ships an adapter (for example `worm_postgres`). The docs use "driver" for the package and "adapter" for the class. See [how drivers work](../drivers/how-drivers-work.md).

### Batch

The group of migrations applied together by one `migrate` run. Each batch gets a number in the `worm_migrations` tracking table, and `rollback` reverts the most recent batch as a unit. See [migrations](../database/migrations.md).

### Capability

One flag on `AdapterCapabilities` declaring what an adapter can do (`supportsTransactions`, `supportsJoins`, and nine more). Capabilities describe; enforcement is the adapter's job. All flags default to `false`. See [adapter API](./adapter-api.md#adaptercapabilities).

### Cast

A bidirectional conversion between a Dart field type and its stored form, defined by an `AttributeCast` (for example `DateTimeCast`, `EnumCast`, `JsonMapCast`). Casts decode on hydration and encode on insert or update. See [casts](../models/casts.md).

### Chainable vs terminal

A chainable is a `QueryBuilder` method that returns a new builder without touching the database (`where`, `orderBy`, `limit`). A terminal executes the query and produces a result (`get`, `first`, `count`, `paginate`). Nothing runs until a terminal. See [query basics](../queries/query-basics.md).

### Companion class

The generated `User$` class (model name plus `$`) holding one typed `Field` constant per column and one `RelationField` per relation. Companions are what make `User$.age.gte(18)` compile-checked. See [code generation](../models/code-generation.md).

### Descriptor

An immutable, database-agnostic description of one operation (`QueryDescriptor`, `InsertDescriptor`, `SchemaDescriptor`, and friends). The query builder produces descriptors; adapters compile them into native queries. See [how drivers work](../drivers/how-drivers-work.md).

### Dirty

A field is dirty when its value changed since hydration or the last save. Worm tracks dirty fields per model (`isDirty`, `dirtyFields`) and writes only dirty fields on update. See [saving and updating](../models/saving-and-updating.md).

### Eager loading

Loading related models in batches up front, alongside the parent query, instead of one query per parent. It is worm's only relation-loading strategy: there is no lazy loading by design. See [eager loading](../relations/eager-loading.md).

### Factory state

A named variation of a model factory's base definition, applied with `state('name')`. Requesting an undeclared state throws `FactoryException`. See [factories](../models/factories.md).

### Hydration

Turning a raw `Map<String, Object?>` row into a typed model instance, via the generated `fromRow`. The reverse direction is `toRow`. See [code generation](../models/code-generation.md).

### Morph

Shorthand for a polymorphic relation: one child table pointing at parents of several types through a `<name>_type` and `<name>_id` column pair. Morph types are registered in the `MorphRegistry`. See [polymorphic relations](../relations/polymorphic-relations.md).

### Pivot

The join table of a many-to-many relation, holding one foreign key per side. The conventional name is the two singular snake_case class names joined alphabetically (`role_user`). See [working with relations](../relations/working-with-relations.md).

### Savepoint

A nested rollback boundary inside an open transaction, created with `txn.savepoint(() async { ... })`. A throw inside the body undoes only the savepoint's work; the outer transaction survives. See [transactions](../database/transactions.md).

### Scope

A reusable, named query constraint. Local scopes are methods annotated with `@Scope()` and applied per query; global scopes (`GlobalScope<T>`) apply to every query for a model unless removed. See [scopes](../queries/scopes.md).

### Seeder

A class that inserts baseline or demo rows, tagged with a target `Environment` and an execution order. Runs can be tracked in the `worm_seeders` table to keep seeding idempotent. See [seeding](../database/seeding.md).

### Soft delete

Marking a row as deleted by setting its `deleted_at` timestamp instead of removing it. Soft-deleted rows are hidden from queries by default and can be restored. See [soft deletes](../models/soft-deletes.md).

### Strictness

The set of opt-in guardrail flags on `StrictnessConfig` (`preventLazyLoading`, `preventFullTableScans`, `throwOnN1Queries`, and more). All default to off; each maps to one typed exception. See [strict mode](../guides/strict-mode.md).

## Continue reading

- [Cheatsheet](./cheatsheet.md): the one-page syntax reference for everything defined above.
- [What is worm](../start-here/what-is-worm.md): the big-picture tour that puts these terms in order.
- [Exceptions](./exceptions.md): the typed exceptions several of these terms reference.
