---
title: Worm for AI agents
description: How coding agents should navigate these docs, plus the list of features that do not exist.
---

This page tells coding agents (and the humans configuring them) how to get correct worm answers fast, and which plausible-sounding APIs to never generate.

## Navigation strategy

1. Start at the [cheatsheet](../reference/cheatsheet.md). It holds copy-paste blocks for every common task and a table of all CLI commands.
2. For exact signatures, defaults, and flags, go to the [reference section](../reference/cheatsheet.md) pages listed in the task map below. Reference pages state every default and name every throwable exception inline.
3. For semantics and edge cases, read the owning guide page. Each guide ends with a Gotchas section and, where it owns an API surface, an API summary table.

Every runnable code block on this site is complete and copy-pasteable against the current API. There is no pseudo-code. If a block does not compile against your installed version, the versions differ; trust the code in your environment over any cached knowledge.

## Machine-readable exports

The site publishes two plain-text exports:

- `/llms.txt`: an index of every page with descriptions.
- `/llms-full.txt`: the full documentation corpus in one file.

Prefer `/llms-full.txt` when you can afford the context; it contains every API summary table and every code block.

## Task to page map

| Task | Page |
| --- | --- |
| Install packages, wire the CLI | [Installation](../start-here/installation.md) |
| Bootstrap the runtime (`Worm.initialize`) | [Configuration](../start-here/configuration.md) |
| Define a model | [Defining models](../models/defining-models.md) |
| Run code generation (`worm gen`) | [Code generation](../models/code-generation.md) |
| Create, save, update, delete rows | [Saving and updating](../models/saving-and-updating.md) |
| Validate before save | [Validation](../models/validation.md) |
| Guard request-shaped input (`fill`) | [Mass assignment](../models/mass-assignment.md) |
| Write a migration | [Migrations](../database/migrations.md) |
| Build or alter tables (Blueprint) | [Schema builder](../database/schema-builder.md) |
| Run, roll back, or inspect migrations | [CLI commands](../reference/cli-commands.md) |
| Seed data | [Seeding](../database/seeding.md) |
| Generate fake data (factories) | [Factories](../models/factories.md) |
| Query rows | [Query basics](../queries/query-basics.md) |
| Grouped predicates, raw SQL, bulk writes | [Advanced queries](../queries/advanced-queries.md) |
| Paginate | [Pagination](../queries/pagination.md) |
| Define relations | [Defining relations](../relations/defining-relations.md) |
| Eager load relations | [Eager loading](../relations/eager-loading.md) |
| Attach, detach, sync pivot rows | [Working with relations](../relations/working-with-relations.md) |
| Transactions and savepoints | [Transactions](../database/transactions.md) |
| Serialize to JSON | [Serialization](../models/serialization.md) |
| Soft delete and restore | [Soft deletes](../models/soft-deletes.md) |
| Write tests | [Testing](./testing.md) |
| Log and debug queries | [Logging and debugging](./logging-and-debugging.md) |
| Pick a database driver | [Choosing a database](../drivers/choosing-a-database.mdx) |
| Look up an operator or field type | [Operators and fields](../reference/operators-and-fields.md) |
| Look up an exception | [Exceptions](../reference/exceptions.md) |
| Look up a `Worm.*` static | [Worm runtime](../reference/worm-runtime.md) |
| Write a new database driver | [Writing a database driver](../contributing/writing-a-database-driver.md) |

## Do not hallucinate these

Each item below is a feature agents commonly invent for ORMs. In worm, they do not exist. Generate the stated alternative instead.

- **Dart macros code generation.** Worm's codegen is `build_runner` based, via `worm_generator`. Run it with `worm gen`. There is no macro path.
- **MongoDB multi-document transactions.** `MongoAdapter.transaction()` throws `TransactionException` by design; the underlying `mongo_dart` driver exposes no session API. Never wrap Mongo writes in `Worm.transaction`. See [MongoDB](../drivers/mongodb.md).
- **`Worm.sqlite(path)` / `Worm.postgres(url)` convenience constructors.** They do not exist. Construct an adapter (`SqliteAdapter`, `PostgresAdapter`, ...) and pass it to `Worm.initialize(adapters: {'default': adapter})`.
- **Lazy loading.** Worm has none, by design. Accessing an unloaded relation throws `RelationNotLoadedException` (or `LazyLoadingException` under strict mode). Always eager load with `withRelations` or `withRelationPaths`. See [eager loading](../relations/eager-loading.md).
- **Identity map or second-level cache.** Two queries for the same row return two distinct model instances.
- **Column projection on eager loads / partial models.** Relations always hydrate full models. There is no `select` on an eager-load constraint that produces a partial model.
- **SQLCipher or encryption-at-rest.** No shipped driver encrypts database files. `EncryptedCast` is a field-level, bring-your-own-crypto abstract class. See [security](./security.md).
- **`whereHas`.** Not part of the API. Use `withExists` or SQL joins via `.sql()`.
- **The annotations `@Hidden`, `@Appended`, `@Attribute`, `@CastAs`, `@Fillable`, `@Guarded`, `@Computed` as working features.** They are experimental and not wired. Use the `Model` overrides instead: `fillable`, `guarded`, `strictMassAssignment`, `hiddenFromSerialization`, `computedAttributes`. See [annotations](../reference/annotations.md).

## Canonical spellings

These are the code-true names. Aliases you remember from other ORMs or from spec drafts are wrong unless a reference page lists them:

- Operators: `Operator.eq`, `neq`, `gt`, `gte`, `lt`, `lte`; list membership via `field.inList(...)` / `field.notInList(...)`.
- Schema: `Blueprint` methods `idUuid()` and `idIncrements()` declare primary keys.
- Pagination: `paginate(...)` returns a `Page` whose rows are `Page.data`; cursor pagination is `cursorPaginate(cursor: ...)`, and passing both `cursor:` and `after:` throws an `ArgumentError`.
- Validation: the uniqueness rule takes `Unique(exceptId: ...)` to exclude the current row.
- Eager loading by string path: `withRelationPaths(['author'])`.
- Migration tracking table: `worm_migrations`. Seeder tracking table: `worm_seeders`.
- Exceptions: `DangerousQueryException` is a typedef of `FullTableScanException`; both names catch the same class.

When in doubt, check [operators and fields](../reference/operators-and-fields.md), [naming conventions](../reference/naming-conventions.md), and [exceptions](../reference/exceptions.md).

## Continue reading

- [Cheatsheet](../reference/cheatsheet.md) for every common snippet on one page.
- [CLI commands](../reference/cli-commands.md) for exact flags and exit codes.
- [Exceptions](../reference/exceptions.md) for the full typed hierarchy.
