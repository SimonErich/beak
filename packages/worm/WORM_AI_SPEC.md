# WORM_AI_SPEC.md

A single-file, complete specification of the **worm** ORM for server-side Dart.
This file is written for an AI coding agent. If you have this file, you have
everything you need to use worm and build a worm-backed project correctly,
without reading any other documentation.

worm is a type-safe, Eloquent-inspired ORM for server-side Dart (Shelf, Dart
Frog, custom `dart:io` servers, workers). It maps annotated Dart classes to
database tables and gives you typed queries over five backends through one API:
PostgreSQL, MySQL, SQLite, MongoDB, and an in-memory adapter for tests. It is
not designed for Flutter mobile, desktop, or web.

## How to read this spec

- Section 1 is mandatory before writing any code. It contains the **canonical
  model shape** and three rules (`query()`, `tableName`, codegen) that every
  other example depends on. Getting these wrong is the most common failure.
- Sections 2 to 10 are reference. Jump to what you need.
- All code is Dart and copy-paste correct against the current worm API.
- This file has no external links. Everything is inline.

## Read this before you generate any worm code (critical rules)

1. **`SomeModel.query()` is not built in.** A model gets a query entry point
   only if it declares `static QueryBuilder<T> query() => ...` (shown in
   Section 1), or you call the codegen-generated `SomeModelQuery.query()`
   extension static. Never write `User.query()` against a model that does not
   define that static.
2. **`@Table(name: 'x')` is read by the code generator only.** At runtime a
   model resolves its table through `String get tableName` (override it) or a
   `ModelRegistration` passed to `Worm.initialize`. Without one, save and query
   throw `ConfigurationException('model.tableName.missing')`.
3. **Code generation uses build_runner.** The model declares
   `part 'my_model.g.dart';` (the `.g.dart` suffix, never `.worm.dart`), and you
   run `dart run build_runner build --delete-conflicting-outputs` (which
   `dart run worm:worm gen` wraps). There are no Dart macros.
4. **Do not invent features.** worm deliberately does not have: Dart macros,
   working MongoDB multi-document transactions, `Worm.sqlite()` /
   `Worm.postgres()` convenience constructors, eager-load column projection or
   partial models, encryption-at-rest / SQLCipher, an identity map, or lazy
   loading. The full not-implemented list is at the end (Section 10).

## Package family

Install `worm` plus one driver. Add `worm_generator` only if you use codegen.

| Package | What it is | Adapter class |
| --- | --- | --- |
| `worm` | ORM core: models, queries, migrations, seeders, CLI, in-memory adapter | `InMemoryAdapter` |
| `worm_generator` | build_runner code generator (dev dependency) | n/a |
| `worm_lints` | `custom_lint` rules for worm projects (dev dependency) | n/a |
| `worm_sqlite` | SQLite driver, in-process | `SqliteAdapter` |
| `worm_postgres` | PostgreSQL driver, pooled | `PostgresAdapter` |
| `worm_mysql` | MySQL driver | `MysqlAdapter` |
| `worm_mongodb` | MongoDB driver | `MongoAdapter` |

## Table of contents

1. Overview, packages, install, and the canonical model
2. CLI reference and project wiring
3. Migrations, schema builder, and seeding
4. Model lifecycle: CRUD, state, mass assignment, soft deletes, serialization, repositories
5. Casts, validation, factories, and naming
6. Queries: builder, operators, terminals, pagination, scopes
7. Relations
8. Transactions, events and observers, strict mode, and configuration
9. Drivers, adapters, and the DatabaseAdapter contract
10. Logging and debugging, testing, exceptions, security, performance, and the never-list

---

## 1. Overview, packages, install, and the canonical model

Worm is an ORM for server-side Dart (Shelf, Dart Frog, custom `dart:io` servers, background workers). It gives every model a typed field companion (`User$`) so queries read `User$.age.gte(18)` instead of `"age >= 18"`, and a misspelled field or a type-mismatched comparison fails to compile. Worm is descriptor-first: a typed query compiles into an immutable, database-agnostic descriptor (`QueryDescriptor`, `InsertDescriptor`, `SchemaDescriptor`, ...), and the registered `DatabaseAdapter` translates that descriptor into the backend's native form. It speaks to five backends through one API (PostgreSQL, MySQL, SQLite, MongoDB, in-memory) and rebuilds Eloquent's vocabulary (models, scopes, observers, factories, seeders, soft deletes) on Dart's static type system. It has no lazy loading (reading an unloaded relation throws), migrations are never auto-applied, and configuration is Dart code, not YAML. Treat worm as a server-side tool: none of the database drivers run on the web.

### 1.1 The package family

Seven packages. A project installs `worm` plus exactly one driver, and optionally the generator and lints. The in-memory adapter ships inside `worm`, so tests need no extra package.

| Package | What it is | Adapter class | Install it when |
|---|---|---|---|
| `worm` | ORM core: models, queries, migrations, seeders, CLI, in-memory adapter | `InMemoryAdapter` | Always (regular dependency) |
| `worm_sqlite` | SQLite driver | `SqliteAdapter` | Data lives in SQLite |
| `worm_postgres` | PostgreSQL driver with connection pooling | `PostgresAdapter` | Data lives in PostgreSQL |
| `worm_mysql` | MySQL driver | `MysqlAdapter` | Data lives in MySQL |
| `worm_mongodb` | MongoDB driver | `MongoAdapter` | Data lives in MongoDB |
| `worm_generator` | build_runner codegen emitting typed companions from annotations | (none) | You use annotation-driven codegen (dev dependency) |
| `worm_lints` | `custom_lint` plugin with worm's coding-convention rules | (none) | You want the repo lint rules (dev dependency) |

### 1.2 Install

Requirements: Dart SDK `^3.11.0` or newer; a server-side Dart project. The packages are not published to pub.dev (every pubspec says `publish_to: none`); depend on them by path from a beak monorepo checkout, or by git.

Minimum (core + one driver):

```yaml
# pubspec.yaml
environment:
  sdk: ^3.11.0

dependencies:
  worm:
    path: ../beak/packages/worm
  worm_sqlite: # or worm_postgres, worm_mysql, worm_mongodb
    path: ../beak/packages/worm_sqlite
```

Optional codegen (dev dependencies):

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  worm_generator:
    path: ../beak/packages/worm_generator
```

Optional lints. `custom_lint` is pinned exactly to `0.8.1` (`worm_lints` pins `custom_lint_builder` to that version):

```yaml
dev_dependencies:
  custom_lint: 0.8.1
  worm_lints:
    path: ../beak/packages/worm_lints
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

### 1.3 The canonical model

This is the reference shape for a runnable worm model. It uses the attribute store as the source of truth, overrides `tableName` so it runs without a registration, and declares the one-line `static query()` so `User.query()` resolves. Every model a reader is expected to run must include both the `tableName` override and the `static query()`.

```dart
import 'package:worm/worm.dart';

@Table(name: 'users')
final class User extends Model {
  User({required String name, required int age}) {
    setAttribute('id', 'u-$name');
    setAttribute('name', name);
    setAttribute('age', age);
  }
  User._();

  factory User.fromRow(Map<String, Object?> row) {
    final user = User._();
    row.forEach(user.hydrateAttribute);
    return user..markPersisted();
  }

  @override
  String get tableName => User$.tableName;

  @override
  Object get id => getAttribute('id') ?? '';

  String get name => switch (getAttribute('name')) { final String v => v, _ => '' };
  int get age => switch (getAttribute('age')) { final int v => v, _ => 0 };

  @override
  Map<String, Object?> toRow() => {'id': id, 'name': name, 'age': age};

  static QueryBuilder<User> query() => QueryBuilder<User>.from(
        QueryContext<User>(
          adapter: Worm.adapter(),
          table: User$.tableName,
          hydrate: User.fromRow,
        ),
      );
}

abstract final class User$ {
  static const String tableName = 'users';
  static const StringField name = StringField('name');
  static const ComparableField<int> age = ComparableField<int>('age');
}
```

Key mechanics of the shape:
- The attribute store is the per-instance map of column name to value with dirty tracking. `setAttribute(name, value)` writes and marks dirty; `getAttribute(name)` reads the live value; `hydrateAttribute(name, value)` seeds a value without dirtying; `markPersisted()` snapshots current attributes as the originals and flips `exists` to `true` so the next `save()` issues an UPDATE, not an INSERT.
- `Model` has exactly two abstract members you must override: `Object get id` and `Map<String, Object?> toRow()`. Worm never mints primary keys; assign `id` yourself (here `'u-$name'`) or use a database auto-increment column.
- Typed getters read the store through a `switch` so a wrong or missing type yields a fallback instead of throwing.
- The companion `User$` is a plain `abstract final class` of `const` field constants: `StringField` for text columns, `ComparableField<int>` for orderable columns. Operators are gated by field kind (`gte`/ordering exist only on `ComparableField`), so `User$.age.gte('18')` does not compile.

### 1.4 Bootstrap sequence

Connect an adapter, create the table (via `executeSchema` in the quickstart, via migrations in real projects), then call `Worm.initialize` once. Because the model above overrides `tableName`, no `models:` registration is required.

```dart
final adapter = InMemoryAdapter();
await adapter.connect();
await adapter.executeSchema(const SchemaDescriptor.createTable(table: 'users'));
await Worm.initialize(config: const WormConfig(), adapters: {'default': adapter});

await User(name: 'Ada', age: 36).save();
final adults = await User.query().where(User$.age.gte(18)).orderBy(User$.name).get();
// adults: [Ada(36)]
```

`Worm.initialize` signature and rules:
- `Worm.initialize({required WormConfig config, required Map<String, DatabaseAdapter> adapters, List<ModelRegistration> models = const [], List<Observer> observers = const []})`.
- The `adapters` map is keyed by connection name; it must contain an entry for `config.defaultConnection` (default `'default'`) or initialize throws `ConfigurationException` with key `adapter.missing`.
- Initialize must complete before any save or query. Touching the registry earlier throws `ConfigurationException` with key `initialization`.
- Calling `Worm.initialize` twice without a reset throws `ConfigurationException` with key `initialization.duplicate`.
- `Worm.reset()` rolls back any active test transaction, disconnects every adapter, clears all registries, and returns the runtime to uninitialized. Use it in test `tearDown`: `tearDown(Worm.reset);`.
- Safe to call before init: `Worm.strictness` (falls back to all-off), `Worm.environment`, and the event-muting getters. Everything else on `Worm` (including `Worm.adapter()`) throws before init.

`ModelRegistration` (the alternative to overriding `tableName`):

```dart
const ModelRegistration({
  required Type type,
  required String tableName,
  String primaryKeyColumn = 'id',
  PrimaryKeyType primaryKeyType = PrimaryKeyType.uuid,
  String connection = 'default',
  String? morphName, // effectiveMorphName falls back to tableName
});
```

### 1.5 RULES: query(), tableName, and codegen

These three facts govern whether the examples above actually run. Internalize them.

1. `User.query()` does not exist unless the model declares the one-line `static query()` shown in 1.3. It is not inherited from `Model`. Codegen does not put `query()` on the class; it emits `extension UserQuery on User { static QueryBuilder<User> query() ... }`, so the generated entry point is `UserQuery.query()` (an extension static). If you rely on codegen and do not hand-write the static, call `UserQuery.query()`; if you hand-write the static (canonical shape), call `User.query()`.
2. `@Table(name: 'users')` is read by codegen only. It has no runtime effect. At runtime `Model.tableName` returns `null` by default, and save/query throw `ConfigurationException` with key `model.tableName.missing` unless you either (a) override `String get tableName => 'users';` on the model, or (b) register the model with `Worm.initialize(models: [ModelRegistration(type: User, tableName: 'users')])`. Table resolution order: model `tableName` override (when non-null), then the `ModelRegistration` keyed by runtime type, else the `model.tableName.missing` throw.
3. Codegen wiring: the model file must declare `part 'user.g.dart';` (for a file `user.dart`). It is `part 'user.g.dart'`, never `part 'user.worm.dart'` (the `.worm.dart` form makes build_runner warn and emit nothing usable). Generate with `dart run build_runner build --delete-conflicting-outputs`. The worm CLI wraps this as `dart run worm:worm gen` (flags: `--watch`, `--clean`, `--no-delete-conflicting-outputs`; the default forwards `--delete-conflicting-outputs`).

### 1.6 What `worm gen` generates

For every `@Table` class, into `model.g.dart`, from the model's real `@Column` instance fields (not getters):

| Artifact | Shape | Contents |
|---|---|---|
| Companion class | `class User$` | `tableName` constant, one typed field constant per `@Column` (`StringField` / `ComparableField` / `Field`), one `RelationField<User, Post>` per relation annotation |
| Hydration extension | `extension UserHydration on User` | `static User fromRow(Map<String, Object?> row)` built from `switch` pattern matching, plus a `toRow()` projection of the `@Column` fields |
| Query starter | `extension UserQuery on User` | `static QueryBuilder<User> query()` wired with adapter, table, hydrator, and any `@GlobalScope` classes |
| Scope metadata | `extension UserWormScopes on User$` | `scopeNames` and `globalScopes` constants (inert metadata) |
| Accessor extension | `extension UserAccessors on User` | One `posts$`-style relation getter per `@HasMany` / `@HasOne` / `@BelongsToMany`; omitted when the model has none |
| Annotations mixin | `mixin _$UserAnnotations on Model` | Opt-in overrides from `@Hidden` / `@Fillable` / `@Guarded` / `@CastAs` / non-default `@Table(connection:)`; does nothing until you add `with _$UserAnnotations` to the class; omitted when none apply |

Field-kind inference: `String` becomes `StringField`; `int` / `double` / `num` / `DateTime` become `ComparableField<T>`; anything else becomes `Field<T>`. The generated source contains zero `as` casts; hydration throws `FormatException('Expected <type> for User.<field>')` on a wrong-typed row value. The generated `fromRow` constructs a fresh instance without seeding the attribute store or calling `markPersisted()`, so models loaded through the generated starter report `exists == false`; call `markPersisted()` yourself before treating them as persisted.

### 1.7 WormConfig defaults

`const WormConfig()` is shippable as-is. Defaults:
- `primaryKeyType: PrimaryKeyType.uuid` (primary keys default to UUIDs).
- Timestamps on: `created_at` and `updated_at` are written automatically in UTC (`DateTime.now().toUtc()`); every update refreshes `updated_at`.
- `environment: Environment.development`.
- `defaultConnection: 'default'`.
- `strictness`: every guardrail off.

`Worm.environment` resolves in a fixed order: (1) the `WORM_ENV` process variable if it parses case-insensitively to `development` / `staging` / `production` / `testing`; (2) otherwise `WormConfig.environment`; (3) otherwise `Environment.development`. `WORM_ENV` silently overrides the config value. `WormConfig.connections` (`ConnectionConfig` entries) is metadata only; worm core never opens a socket from it, and `port: 0` means "unset" so adapters substitute their protocol default (5432 PostgreSQL, 3306 MySQL).

---

## 2. CLI reference and project wiring

The `worm` CLI scaffolds files, runs migrations/seeders, dumps schema, and shells out to `build_runner`. There are 15 commands. Database commands act only on what your own `bin/worm.dart` registers; the stock CLI registers nothing and uses an in-memory adapter.

### 2.1 Invoking the CLI

```bash
dart run worm:worm <command>        # from a project that depends on worm
dart run worm:worm <command>   # explicit package:executable form (identical)
dart run worm:worm --help           # global usage, exit 0
dart run worm:worm help <command>   # per-command usage, exit 0
dart run bin/worm.dart <command>  # YOUR project-aware entrypoint (see 2.2)
```

- No arguments or `--help`: usage printed to stdout, exit `0`.
- Unknown command or unknown flag: error printed to stderr, exit `2`.
- `dart run worm:worm` always runs the stock CLI with empty registries and a connected `InMemoryAdapter`. Scaffolding (`init`, `make:*`, `gen`) works out of the box; database commands (`migrate*`, `db:seed`, `schema:dump`, `model:show`) only act on what you register, so run your own `bin/worm.dart` for those. Until a real adapter is wired, database commands succeed against RAM, touch no real database, and still exit `0`.

### 2.2 Project wiring: bin/worm.dart

You write this file. It builds a `CliContext` and runs `WormCommandRunner`. Migrations, seeders, and models are registered in code; there is no filesystem scanning. A migration file not present in the `migrations:` list does not exist as far as the CLI is concerned.

```dart title="bin/worm.dart"
import 'dart:io';

import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart'; // or your chosen driver

import '../migrations/20260101_120000_create_users_table.dart';
import '../seeds/user_seeder.dart';

Future<void> main(List<String> args) async {
  final context = CliContext(
    out: stdout,
    err: stderr,
    projectRoot: Directory.current,
    environment: Worm.environment, // resolves WORM_ENV; see 2.5
    now: DateTime.now,
    adapterFactory: () async {
      final adapter = SqliteAdapter.open('app.db'); // swap for your driver
      await adapter.connect();
      return adapter;
    },
    migrations: const <Migration>[CreateUsersTable()],
    seeders: const <Seeder>[UserSeeder()],
    models: const <ModelInfo>[
      ModelInfo(
        name: 'User',
        tableName: 'users',
        fields: <ModelField>[
          ModelField(name: 'id', type: 'uuid'),
          ModelField(name: 'name', type: 'string'),
        ],
        relations: <ModelRelation>[
          ModelRelation(name: 'posts', kind: 'hasMany', target: 'Post'),
        ],
      ),
    ],
  );
  final code = await WormCommandRunner(context).run(args) ?? 0;
  if (code != 0) exit(code);
}
```

`WormCommandRunner(context).run(args)` returns `Future<int?>`; treat `null` as `0`.

#### CliContext fields

| Field | Type | Meaning |
|---|---|---|
| `out` | `IOSink` | stdout sink for command output |
| `err` | `IOSink` | stderr sink for diagnostics |
| `projectRoot` | `Directory` | Root the CLI reads/writes into; `gen` spawns `build_runner` here |
| `environment` | `Environment` | Active env for seeder filtering and force gates; use `Worm.environment` |
| `now` | `DateTime Function()` | Clock for `migrationTimestamp` (make:migration) |
| `adapterFactory` | `Future<DatabaseAdapter> Function()` | Builds and connects the adapter for `migrate*`, `db:seed`, `schema:dump`, `make:migration --auto` |
| `migrations` | `List<Migration>` | Registered migrations, in order |
| `seeders` | `List<Seeder>` | Registered seeders |
| `models` | `List<ModelInfo>` | CLI-side descriptors consumed by `model:show` |

`CliContext` also exposes the directory conventions commands write into: `migrationsDir` (`migrations/`), `seedsDir` (`seeds/`), `modelsDir` (`lib/models/`), `factoriesDir` (`lib/factories/`).

`ModelInfo`, `ModelField`, `ModelRelation` are CLI-side descriptors (not the runtime `Model`). `ModelField.type` and `ModelRelation.kind` are free-form strings you populate from your own model list.

```dart
const ModelInfo({
  required String name,
  required String tableName,
  List<ModelField> fields = const [],
  List<ModelRelation> relations = const [],
});
const ModelField({required String name, required String type});
const ModelRelation({required String name, required String kind, required String target});
```

The default stock `bin/worm.dart` in the package registers empty `migrations`, `seeders`, `models`, and an `adapterFactory` that builds a connected `InMemoryAdapter`.

### 2.3 worm init output

```bash
dart run worm:worm init
```

No flags. Idempotent: existing paths are left untouched and reported `Already exists  <path>`; new items print `created         <path>`. Always exits `0`. Creates:

- 18 `lib/src/` subdirectories: `adapter`, `cast`, `cli`, `config`, `exception`, `factory`, `logging`, `migration`, `model`, `naming`, `observer`, `predicate`, `query`, `registry`, `relation`, `schema`, `seeder`, `validation`.
- Root directories: `migrations/`, `seeds/`, `lib/models/`, `lib/factories/`, `config/`.
- `config/worm_config.dart`: a `WormConfig` template with a commented-out `ConnectionConfig` entry.

The `make:*` commands write only into `migrations/`, `seeds/`, `lib/models/`, `lib/factories/`, and `lib/src/observer/`; you need not keep the whole tree. (`initReadme()` is exported but `init` writes no README.)

### 2.4 Exit codes

| Code | Meaning |
|---|---|
| `0` | Success, including no-op runs (`Nothing to migrate.`, `Already exists`) |
| `1` | Force-gate refusal (`migrate:fresh` / `migrate:refresh` in production, `schema:dump --prune` without `--force`); `model:show` with an unregistered model |
| `2` | Usage error: unknown command or unknown flag |
| `64` | Missing required positional argument (`make:*`, `model:show`) |
| `65` | Refusing to overwrite an existing file (`make:*`) |
| other | `gen` returns the exit code of the `build_runner` child process |

### 2.5 Environment resolution and force gates

`Worm.environment` resolves in order: `WORM_ENV` env var wins (matched case-insensitively against `Environment` enum names `development`, `staging`, `production`, `testing`, `all`), then `WormConfig.environment`, then `Environment.development`.

| Gate | Commands | Semantics |
|---|---|---|
| Production `--force` | `migrate:fresh`, `migrate:refresh` | In production without `--force`: writes `error: refusing to run destructive command in production without --force` to stderr, exits `1`. Outside production `--force` is accepted but unnecessary. |
| Always `--force` | `schema:dump --prune` | Pruning deletes migration files irreversibly, so `--force` is required in EVERY environment, not just production. `--prune` without `--force`: writes error to stderr, exits `1`. |
| Not a safety gate | `db:seed --force` | Bypasses the seeder environment filter (runs every registered seeder). Unrelated to production protection. |

Exported helpers behind the gates: `isProductionWormEnv(String?)` (pure predicate), `ensureForceForProduction({required CliContext context, required bool force})` (returns `false` and writes the diagnostic), and `ProductionGuard` (variant that calls `exit(1)` through an injectable `ExitFn`).

### 2.6 Command reference (all 15)

#### init
`worm init`: no flags. See 2.3. Always exits `0`.

#### make:model
```bash
worm make:model <ClassName> [--all]
```
| Flag | Default | Effect |
|---|---|---|
| `--all`, `-a` | off | Also plan a migration, seeder, and factory |

Writes `lib/models/<snake_case>.dart`: a `@Table(name: '<table>')` class extending `Model` with a `late final String id`. This is a MINIMAL skeleton with no `part` directive and no codegen wiring; flesh it out into a full model (see Models). Table name from `tableNameFor(ClassName)`. With `--all`, three siblings are also planned: `migrations/<timestamp>_create_<table>_table.dart` (class `Create<ClassName>sTable`), `seeds/<snake_case>_seeder.dart` (class `<ClassName>Seeder`), `lib/factories/<snake_case>_factory.dart` (class `<ClassName>Factory`). All-or-nothing: every target is checked first; if any exists, nothing is written and exit `65`. Missing class name exit `64`. Each written file prints `created  <relative path>`.

#### make:migration
```bash
worm make:migration <snake_case_name> [--table <table>] [--auto]
```
| Flag | Default | Effect |
|---|---|---|
| `--table`, `-t` | the migration name | Table the skeleton targets |
| `--auto` | off | Generate body by diffing `schema/schema.json` against the live database schema |

Writes `migrations/<timestamp>_<name>.dart`. Timestamp is `migrationTimestamp(context.now())`, a UTC `YYYYMMDD_HHMMSS` string. Class name is `snakeToPascal(name)`; its `name` getter returns the full file base so the tracking-table entry matches the filename. Skeleton `upSchema` creates the table with `table.idUuid()`; `downSchema` drops with `ifExists: true`. With `--auto`: builds the adapter from `adapterFactory`, introspects the live schema, diffs against `schema/schema.json`, and emits an `upSchema` applying the difference. Missing `schema/schema.json` throws `MigrationException`; malformed JSON throws `FormatException`. Introspection has no type info, so type/nullability changes surface as TODO comments. Missing name exit `64`; existing target file exit `65`.

#### make:seeder
```bash
worm make:seeder <ClassName> [--table <table>]
```
| Flag | Default | Effect |
|---|---|---|
| `--table`, `-t` | `pascalToSnake(ClassName)` | Table named in the skeleton's TODO comment (informational) |

Writes `seeds/<snake_case>.dart` with a `Seeder` subclass whose `name` returns the class name and whose `run(DatabaseAdapter adapter)` body is a TODO. Missing name exit `64`; existing file exit `65`.

#### make:factory
```bash
worm make:factory <ClassName> [--model <ModelClass>]
```
| Flag | Default | Effect |
|---|---|---|
| `--model`, `-m` | class name with a trailing `Factory` stripped (`UserFactory` becomes `User`; no suffix unchanged) | Model the factory builds |

Writes `lib/factories/<snake_case>.dart` with a `Factory<Model>` subclass and a `definition()` stub. Missing name exit `64`; existing file exit `65`.

#### make:observer
```bash
worm make:observer <ClassName> [--model <ModelClass>]
```
| Flag | Default | Effect |
|---|---|---|
| `--model`, `-m` | class name with a trailing `Observer` stripped | Model the observer watches |

Writes `lib/src/observer/<snake_case>.dart` with an empty `Observer<Model>` subclass. Missing name exit `64`; existing file exit `65`.

#### migrate
```bash
worm migrate [--pretend] [--step=N]
```
| Flag | Default | Effect |
|---|---|---|
| `--pretend` | off | Print compiled SQL without executing anything |
| `--step=N` | unset (apply all) | Apply at most N pending migrations |

Builds a `MigrationRunner` from `context.migrations` against `context.adapterFactory()` and applies every pending migration as one batch. Prints `migrated  <name>` per applied migration, or `Nothing to migrate.` Exit `0` either way. With `--pretend`, each pending migration prints a `-- <name>` header then its compiled statements, then a dry-run confirmation line; no database changes, no tracking rows. Raw Dart in a legacy `up(adapter)` migration still executes during pretend; only adapter calls are intercepted.

#### migrate:rollback
```bash
worm migrate:rollback [--steps=N]
```
| Flag | Default | Effect |
|---|---|---|
| `--steps=N` | `1` | Number of batches to roll back |

Reverts the last N batches; within a batch, migrations revert in descending name order. Prints `reverted  <name>` per migration, or `Nothing to roll back.` A recorded migration no longer in the registered list throws `MigrationException`. Exit `0`.

#### migrate:status
```bash
worm migrate:status
```
No flags. Prints a column-aligned table:
```text
Migration                              | Batch | Status
------------------------------------------------------
[x] 20260101_120000_create_users_table | 1     | applied
[ ] 20260102_090000_add_age_to_users   | -     | pending
```
Prints `No migrations registered.` when the context has no migrations. Always exit `0`.

#### migrate:fresh
```bash
worm migrate:fresh [--seed] [--force]
```
| Flag | Default | Effect |
|---|---|---|
| `--seed` | off | Run all registered seeders after migrations re-apply |
| `--force` | off | Required when `WORM_ENV=production` |

Drops the `worm_migrations` tracking table and re-applies every registered migration as batch 1. Prints `migrate:fresh complete (N migration(s) applied).` then one `seeded  <name>` per seeder that ran. Production without `--force`: refusal diagnostic to stderr, exit `1`. `--seed` uses the same environment filter as `db:seed`, keyed on `context.environment`.

#### migrate:refresh
```bash
worm migrate:refresh [--force]
```
| Flag | Default | Effect |
|---|---|---|
| `--force` | off | Required when `WORM_ENV=production` |

Rolls back every applied batch, then re-applies all migrations. Prints `migrate:refresh complete.` Same production gate as `migrate:fresh`: exit `1` without `--force` in production.

#### db:seed
```bash
worm db:seed [--class=<SeederName>] [--env=<name>] [--force] [--only=<SeederName>]
```
| Flag | Default | Effect |
|---|---|---|
| `--class=<SeederName>` | unset | Run only the seeder whose `Seeder.name` matches exactly. Skips the environment filter for that seeder. Unknown name throws `ArgumentError`. |
| `--env=<name>` | `context.environment` | Override the filtering environment. Case-insensitive; an unrecognized value silently falls back to the context environment. |
| `--force` | off | Skip the environment filter and run every registered seeder (env bypass, NOT a production safety gate) |
| `--only=<SeederName>` | unset | Deprecated alias for `--class` (`--class` wins when both given) |

Builds a `SeederRunner` over `context.seeders`, sorted by `Seeder.order` (stable sort; ties keep registration order) and filtered by environment. Prints `seeded  <name>` per seeder that ran, or `No seeders applicable to <env> environment.` The CLI wires no `SeederRecordStore`, so `db:seed` re-runs every applicable seeder on every invocation; idempotent tracking via the `worm_seeders` table is available only when you construct a `SeederRunner` with a store programmatically (see Seeding).

#### schema:dump
```bash
worm schema:dump [--prune] [--force]
```
| Flag | Default | Effect |
|---|---|---|
| `--prune` | off | Delete every `.dart` file directly under `migrations/` after the dump |
| `--force` | off | Acknowledge that `--prune` is irreversible (required in EVERY environment) |

Introspects the live schema through `adapterFactory()` and writes `schema/schema_dump.dart`: a generated `const Map<String, List<String>> schemaDump`, tables sorted alphabetically. The dump file is overwritten without an exists check. Prints `wrote   schema/schema_dump.dart`. `--prune` without `--force`: error to stderr, exit `1` (every environment). With both flags, pruning prints `pruned  N migration file(s).` A missing `migrations/` directory prunes zero files.

#### model:show
```bash
worm model:show <ModelName>
```
No flags. Looks up the name in `context.models` and prints:
```text
Model: User
Table: users
Fields:
  id: uuid
  name: string
Relations:
  posts: hasMany Post
```
Empty field or relation lists print `  (none)`. Missing argument exit `64`. An unregistered model prints `Model not found: <name>` to stderr, exit `1`.

#### gen
```bash
worm gen [--watch] [--clean] [--[no-]delete-conflicting-outputs]
```
| Flag | Default | Effect |
|---|---|---|
| `--watch` | off | Spawn `dart run build_runner watch` with streamed output; replaces the build step |
| `--clean` | off | Run `dart run build_runner clean` first; abort with its exit code if non-zero |
| `--[no-]delete-conflicting-outputs` | on | Forward `--delete-conflicting-outputs` to `build_runner build` |

Default invocation spawns `dart run build_runner build --delete-conflicting-outputs` in `context.projectRoot` and returns the child's exit code (hence "other" exit codes). `--clean` runs before the build and aborts on a non-zero clean step. `--watch` streams output and stays attached, replacing the build step.

### 2.7 Naming helpers and templates

These conversions back the `make:*` commands and are exported from `package:worm/worm.dart`.

| Helper | Example | Notes |
|---|---|---|
| `pascalToSnake(String)` | `'BlogPost'` to `'blog_post'` | |
| `snakeToPascal(String)` | `'blog_post'` to `'BlogPost'` | |
| `tableNameFor(String)` | `'User'` to `'users'`, `'Category'` to `'categories'` | Naive pluralizer: names ending in `s` unchanged (`'Status'` stays `'status'`) |
| `migrationTimestamp(DateTime)` | `'20260101_120000'` | Always UTC; input normalized via `toUtc()` |

Exported string-returning template functions (for building custom scaffolding): `modelTemplate({className, table})`, `migrationTemplate({className, table, fileName})`, `seederTemplate({className, table})`, `factoryTemplate({className, modelClass})`, `observerTemplate({className, modelClass})`, `initReadme()`.

### 2.8 Legacy

`CliRunner` and `CliResult` are an older minimal dispatcher (only `gen` and `--help`) that remain exported for compatibility. They are superseded by `WormCommandRunner`.

---

## 3. Migrations, schema builder, and seeding

Versioned schema evolution: `Migration` classes drive a `Schema` builder (Blueprint DSL) that compiles to a backend-agnostic `SchemaDescriptor`, plus `Seeder` classes for known data. Everything runs through `DatabaseAdapter` (see Adapters). Applied migrations are tracked in `worm_migrations`.

### 3.1 The Migration class

A migration extends `Migration` and overrides `name` + the `upSchema`/`downSchema` pair. `name` is the file name without extension; it is the stored identity in `worm_migrations`, so treat it as immutable once applied (renaming an applied migration makes worm see it as new/pending).

```dart
import 'package:worm/worm.dart';

final class CreateBirdsTable extends Migration {
  const CreateBirdsTable();

  @override
  String get name => '20260702_094946_create_birds_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('birds', (table) {
      table.idUuid();
      table.string('name');
      table.string('species');
      table.timestamps();
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    await schema.drop('birds', ifExists: true);
  }
}
```

Overridable members of `Migration`:

| Member | Default | Meaning |
| --- | --- | --- |
| `String get name` | (abstract) | Stored identity in `worm_migrations`. Must be unique. |
| `Future<void> upSchema(Schema schema)` | forwards to `up(adapter)` | Apply the change. |
| `Future<void> downSchema(Schema schema)` | forwards to `down(adapter)` | Revert the change. |
| `List<String> get dependsOn` | `const []` | Names this migration must run after (toposort; see 3.10). |
| `bool get isDestructive` | `false` | Documentation only; NOT consulted by the runner (see 3.13). |
| `Future<void> up(DatabaseAdapter adapter)` | throws `UnimplementedError` | Legacy surface; the `upSchema` default forwards here. |
| `Future<void> down(DatabaseAdapter adapter)` | throws `UnimplementedError` | Legacy surface. |

- Prefer `upSchema`/`downSchema`. Legacy migrations may override `up`/`down` instead; both styles work because `upSchema`/`downSchema` forward to `up`/`down` by default.
- A migration that overrides NEITHER pair throws `UnimplementedError` when run, which the runner wraps in `MigrationException`.
- You never construct `Schema` yourself; the runner injects it. `schema.adapter` exposes the wrapped `DatabaseAdapter` as a raw escape hatch.
- Scaffold with `dart run worm:worm make:migration create_birds_table`, which writes `migrations/<UTC-timestamp>_create_birds_table.dart` (timestamp `YYYYMMDD_HHMMSS`, so files sort in creation order) and a class named `CreateBirdsTable`.

### 3.2 Registering migrations

Worm does NOT scan `migrations/`. Every migration must be listed explicitly in the `CliContext` your app builds in its own CLI entrypoint (`bin/worm.dart`). Registration order is execution order unless `dependsOn` reorders it.

```dart
final context = CliContext(
  out: stdout,
  err: stderr,
  projectRoot: Directory.current,
  environment: Worm.environment,
  now: DateTime.now,
  adapterFactory: () async {
    final adapter = InMemoryAdapter();
    await adapter.connect();
    return adapter;
  },
  migrations: const [CreateBirdsTable(), CreateSightingsTable()],
  seeders: const [AppSeeder()],
);
```

### 3.3 Running and rolling back (CLI)

| Command | Effect |
| --- | --- |
| `dart run worm:worm migrate` | Apply every pending migration as one batch. Prints `migrated  <name>` per applied migration, or `Nothing to migrate.`. Idempotent: applied names skipped. |
| `dart run worm:worm migrate --step=1` | Apply only the first N pending migrations. |
| `dart run worm:worm migrate --pretend` | Print compiled SQL for each pending migration, change nothing (see 3.11). |
| `dart run worm:worm migrate:status` | Print a `Migration | Batch | Status` table with `[x]` / `[ ]` markers. |
| `dart run worm:worm migrate:rollback` | Revert the last batch. Runs `downSchema` per migration in descending `name` order, deletes rows. |
| `dart run worm:worm migrate:rollback --steps=2` | Revert the last N batches. |
| `dart run worm:worm migrate:refresh` | Roll back every batch (`downSchema` all), then re-apply all. |
| `dart run worm:worm migrate:fresh` | Drop the `worm_migrations` tracking table, re-apply all as batch 1. |
| `dart run worm:worm migrate:fresh --seed` | As above, then run all registered seeders (see 3.16). |

- `migrate:fresh` and `migrate:refresh` refuse to run in production without `--force` (see 3.15). `migrate:rollback` has NO production gate.
- `migrate:fresh` drops ONLY the tracking table, not your data tables. If created tables still exist, re-applying fails on the `CREATE` statements. Drop the schema yourself first, or use `migrate:refresh` (which runs every `downSchema` before re-applying).

### 3.4 Running programmatically: MigrationRunner

The CLI drives `MigrationRunner`. The constructor toposorts by `dependsOn` (see 3.10); dependency errors throw at CONSTRUCTION, before any DB access.

```dart
final runner = MigrationRunner(
  adapter: adapter,                 // required DatabaseAdapter
  migrations: const [CreateBirdsTable(), CreateSightingsTable()],
  seeders: const [],                // default const []
  environment: Environment.development, // default
);

final applied  = await runner.migrate();           // Future<List<String>> newly applied names
await runner.migrate();                            // [] on second call
await runner.run(step: 1);                          // alias for migrate({int? step})
final reverted = await runner.rollback();          // last batch, reverse name order
await runner.rollback(steps: 2);                    // last two batches
await runner.refresh();                             // Future<void>: down all, then up all
final seeded   = await runner.fresh(seed: true);    // Future<List<String>>: drop tracking, up all as batch 1, optionally seed
final captured = await runner.pretend();            // Future<Map<String, List<String>>>
final statuses = await runner.status();             // Future<List<MigrationStatus>>
```

| Method | Signature | Returns |
| --- | --- | --- |
| `migrate` | `Future<List<String>> migrate({int? step})` | Newly applied names (one batch). |
| `run` | `Future<List<String>> run({int? step})` | Alias for `migrate`. |
| `rollback` | `Future<List<String>> rollback({int steps = 1})` | Reverted names; descending name order within a batch. |
| `refresh` | `Future<void> refresh()` | Roll back every batch, re-apply all. |
| `fresh` | `Future<List<String>> fresh({bool seed = false})` | Drop tracking, re-apply all as batch 1; returns seeder names run when `seed: true`. |
| `pretend` | `Future<Map<String, List<String>>> pretend()` | Compiled statements per pending migration; executes nothing. |
| `status` | `Future<List<MigrationStatus>> status()` | Applied/pending report for every registered migration. |

### 3.5 The worm_migrations tracking table and batches

Constant: `migrationsTable == 'worm_migrations'`. Created on demand with `IF NOT EXISTS`; you never migrate it yourself. One row per applied migration:

| Column | Type | Meaning |
| --- | --- | --- |
| `name` | text (primary key) | The migration's `name`. |
| `batch` | integer | Batch it was applied in. |
| `applied_at` | dateTime | ISO 8601 instant of application. |

- One `migrate` call assigns all newly applied migrations the SAME batch = `max(batch) + 1`.
- The tracking row is inserted ONLY after `upSchema` completes successfully.
- `rollback` reads the highest batch, runs `downSchema` for each of its migrations in descending name order, deletes those rows.
- `migrate:fresh` drops the tracking table and re-applies everything as batch 1.

Record/status value types:

| Symbol | Shape | Notes |
| --- | --- | --- |
| `MigrationRecord` | `{name, batch, appliedAt}`; `toMap()` | One tracking-table row. |
| `MigrationStatus` | `{name, state, batch?}`; `toMap()`, `toString()` | One `migrate:status` row; renders `[x] name (batch N)` or `[ ] name`. |
| `MigrationState` | enum `pending`, `applied` | Lifecycle state. |
| `MigrationRecordStore` | `const MigrationRecordStore(adapter)`; `ensureTable`, `dropTable`, `all`, `appliedNames`, `maxBatch`, `namesInBatch`, `insert`, `remove` | Adapter-backed CRUD over `worm_migrations`; the runner always uses this. |
| `MigrationRepository` | abstract; `initialize`, `all`, `record`, `forget`, `latestBatch` | Alternate persistence contract for custom tooling; NOT used by the runner. |
| `InMemoryMigrationRepository` | `InMemoryMigrationRepository()` | In-memory `MigrationRepository`; throws `StateError` if used before `initialize()`. |

### 3.6 The Schema facade

`upSchema`/`downSchema` receive a `Schema` with three operations. `create`/`alter` build a `Blueprint`, convert it to a `SchemaDescriptor`, and reach the adapter via `DatabaseAdapter.executeSchema`; `drop` maps directly to a drop descriptor.

```dart
await schema.create('birds', (table) { /* declare columns */ });
await schema.alter('birds', (table) { /* add or drop columns */ });
await schema.drop('birds', ifExists: true); // ifExists defaults to false
```

`Blueprint` is the full-fidelity form you can render directly (see 3.13, "What reaches your database"):

```dart
final blueprint = Blueprint.create('birds', (table) { /* ... */ });
blueprint.toSql();    // complete PostgreSQL DDL (columns, constraints, FKs, index statements)
blueprint.toMongo();  // MongoDB description document
// also Blueprint.alter('birds', (t) {...}) and Blueprint.drop('birds')
```

`BlueprintOperation` enum: `create`, `alter`, `drop`.

### 3.7 Primary keys

```dart
table.idUuid();        // UUID PRIMARY KEY named "id"
table.idIncrements();  // auto-incrementing INTEGER PRIMARY KEY named "id"
table.id();            // alias for idUuid()
table.intId();         // alias for idIncrements()
table.idUuid(name: 'bird_id'); // all four accept an optional name (default 'id')
```

`idIncrements` marks the column both `primary` and `autoIncrementing` (renders `GENERATED ALWAYS AS IDENTITY` in PostgreSQL). The model-layer mirror is `PrimaryKeyType` enum: `uuid`, `integer` (see Models).

### 3.8 Column types: the complete ColumnType enum

`ColumnType` has 27 values. Each has a `BlueprintTable` method; `TypeMapper` defines the canonical PostgreSQL and MongoDB BSON mapping. Columns are `NOT NULL` unless `..makeNullable()` is called.

| `ColumnType` | Blueprint method | PostgreSQL type | BSON type |
| --- | --- | --- | --- |
| `string` | `string(name, {int length = 255})` | `VARCHAR(length)` | `string` |
| `smallInteger` | `smallInteger(name)` | `SMALLINT` | `int` |
| `integer` | `integer(name)` | `INTEGER` | `int` |
| `bigInteger` | `bigInteger(name)` | `BIGINT` | `long` |
| `decimal` | `decimal(name, {int precision = 10, int scale = 2})` | `NUMERIC(precision,scale)` | `decimal` |
| `boolean` | `boolean(name)` | `BOOLEAN` | `bool` |
| `date` | `date(name)` | `DATE` | `date` |
| `dateTime` | `dateTime(name)` | `TIMESTAMPTZ` | `date` |
| `uuid` | `uuid(name)` | `UUID` | `string` |
| `json` | `json(name)` | `JSON` | `object` |
| `jsonb` | `jsonb(name)` | `JSONB` | `object` |
| `text` | `text(name)` | `TEXT` | `string` |
| `binary` | `binary(name)` | `BYTEA` | `binData` |
| `doublePrecision` | `doublePrecision(name)` | `DOUBLE PRECISION` | `double` |
| `enumType` | `enumColumn(name, List<String> values)` | `TEXT` | `string` |
| `tsvector` | `tsvector(name)` | `TSVECTOR` | `string` |
| `time` | `time(name)` | `TIME` | `date` |
| `interval` | `interval(name)` | `INTERVAL` | `date` |
| `inet` | `inet(name)` | `INET` | `string` |
| `macaddr` | `macaddr(name)` | `MACADDR` | `string` |
| `point` | `point(name)` | `POINT` | `object` |
| `line` | `line(name)` | `LINE` | `object` |
| `box` | `box(name)` | `BOX` | `object` |
| `money` | `money(name)` | `MONEY` | `decimal` |
| `bit` | `bit(name, {int length = 1})` | `BIT(length)` | `string` |
| `xml` | `xml(name)` | `XML` | `string` |
| `array` | `array(name, ColumnType elementType)` | `<element type>[]` | `array` |

Notes:
- `enumColumn('role', ['admin', 'user'])` records allowed values on the `ColumnDefinition` but renders plain `TEXT` with NO `CHECK` constraint. Enforce the value set in the model layer (see Models / validation).
- `array('tags', ColumnType.text)` renders `TEXT[]`; the element type is required.
- `TypeMapper.toSqlType(type, {length, precision, scale, elementType})` and `TypeMapper.toMongoType(type)` are static and public.
- Defaults: `string` length 255; `decimal` precision 10 / scale 2; `bit` length 1.

### 3.9 Column modifiers and convenience columns

Every column method returns a `ColumnDefinition`. Modifiers mutate it IN PLACE and return `void`, so with two or more modifiers use Dart cascades (`..`), not dot chains. A single modifier works with a dot because the column self-registers when its method runs.

```dart
table.string('email')..makeNullable()..makeUnique();
table.integer('score')..withDefault(0);
table.uuid('tenant_id')..primary();
table.string('email').makeUnique(); // single modifier: dot is fine
```

| Modifier | Signature | PostgreSQL rendering |
| --- | --- | --- |
| `makeNullable` | `void makeNullable()` | Removes the default `NOT NULL`. |
| `primary` | `void primary()` | `PRIMARY KEY`. |
| `makeUnique` | `void makeUnique()` | `UNIQUE`. |
| `autoIncrementing` | `void autoIncrementing()` | `GENERATED ALWAYS AS IDENTITY`. |
| `withDefault` | `void withDefault(Object? value)` | `DEFAULT ...` (bools -> `TRUE`/`FALSE`, numbers bare, everything else quoted). |
| `withComment` | `void withComment(String text)` | Recorded on the definition; NOT rendered in DDL yet. |
| `generated` | `void generated(String expression)` | Recorded on the definition; NOT rendered in DDL yet. |
| `toMap` | `Map<String, Object?> toMap()` | Serialize the definition. |

Convenience columns:

```dart
table.timestamps();   // nullable dateTime created_at + updated_at
table.softDeletes();  // nullable dateTime deleted_at (pairs with SoftDeletes mixin; see Models)
```

### 3.10 Indexes

```dart
table.index(['email']);                              // auto-named birds_email_idx
table.index(['a', 'b'], name: 'my_idx');             // explicit name
table.index(['email'], unique: true);                // unique index
table.unique(['email']);                             // shorthand for a unique index
table.index(['payload'], kind: IndexKind.gin);       // index kind
table.index(['email'], where: 'email IS NOT NULL');  // partial index (WHERE clause)
```

- Signatures: `index(List<String> columns, {String? name, bool unique = false, IndexKind kind = IndexKind.btree, String? where})`; `unique(List<String> columns, {String? name})`.
- Omitting `name` auto-names as `<table>_<columns joined by _>_idx`.
- `IndexKind` enum: `btree` (default), `gin`, `gist`, `hash`.
- PostgreSQL rendering: `CREATE [UNIQUE ]INDEX "name" ON "table" USING <kind> (cols)[ WHERE ...];`.
- `IndexDefinition` shape: `{name, columns, unique, kind, partialWhere}`; `toMap()`.
- Cross-adapter runtime index creation: `SchemaIndexDescriptor(collection:, field:, unique:)` is a `SchemaDescriptor` subtype (`SchemaOperation.createIndex`) adapters execute directly (SQL adapters compile it; MongoDB calls `createIndex`; in-memory is a no-op).

### 3.11 Foreign keys and OnDelete

```dart
table.foreign(
  column: 'bird_id',
  references: 'id',
  onTable: 'birds',
  onDelete: OnDelete.cascade,   // defaults to OnDelete.restrict
  // name: optional constraint name
);

table.foreignComposite(
  columns: ['org_id', 'team_id'],           // local and referenced match by index; equal length required
  referencedColumns: ['org_id', 'id'],
  onTable: 'teams',
  onDelete: OnDelete.restrict,
  // name: optional
);
```

`OnDelete` enum (6 values); `onDelete` defaults to `restrict`:

| `OnDelete` | SQL rendering | Behavior |
| --- | --- | --- |
| `cascade` | `CASCADE` | DB engine deletes children silently; NO model hooks fire. |
| `ormCascade` | `NO ACTION` | Worm deletes children at runtime, firing `beforeDelete`/`afterDelete` on each. |
| `restrict` | `RESTRICT` | Delete fails while children exist. |
| `setNull` | `SET NULL` | Child FK column set to NULL. |
| `setDefault` | `SET DEFAULT` | Child FK column set to its default. |
| `noAction` | `NO ACTION` | Database default behavior. |

`OnDelete.ormCascade` deliberately renders `NO ACTION`; the ORM walks every dependent row before the parent delete so observers, soft-delete scopes, and casts all run (see Relations).

`ForeignKeyDefinition`: default ctor (single column) or `.composite(...)`; `toMap()`.

### 3.12 Altering and dropping

Inside `schema.alter`, column methods mean `ADD COLUMN`; `dropColumn(name)` marks a column for removal.

```dart
await schema.alter('birds', (table) {
  table.string('bio').makeNullable();  // ADD COLUMN
  table.dropColumn('legacy_flag');     // DROP COLUMN
});

await schema.drop('birds', ifExists: true); // ifExists defaults to false
```

HONESTY: `schema.alter` currently FAILS at execution time on EVERY shipped adapter. `SchemaOperation.alter` support is uniformly absent:
- In-memory adapter throws `UnsupportedOperationException`.
- PostgreSQL, MySQL, SQLite compilers throw `QueryException` (`compileDdl(SchemaOperation.alter) is not implemented`).
- MongoDB adapter throws `QueryException` (collections are schemaless).

Workaround: express alters as raw DDL via `Blueprint.alter(...).toSql()` plus `schema.adapter.rawExecute(...)`, and keep `schema.alter` calls out of migrations you intend to run.

### 3.13 What reaches your database (fidelity loss)

The `Schema` facade converts each `Blueprint` to a `SchemaDescriptor` before the adapter sees it, keeping only FIVE properties per column: `name`, `type`, `nullable`, `isPrimaryKey`, `defaultValue`. Everything else lives only on the `Blueprint` and is DROPPED by `schema.create`:

- Indexes, `unique(...)`, and single-column `..makeUnique()` constraints.
- Foreign keys (single and composite).
- `..autoIncrementing()`, `length`, `precision`, `scale`.
- `..withComment(...)` and `..generated(...)`.
- `dropColumn(...)` marks (the descriptor has no dropped-columns field).

Full fidelity exists only via direct renderings. To apply the dropped parts, render the blueprint yourself and use the adapter's raw surface:

```dart
final blueprint = Blueprint.create('birds', (table) {
  table.idUuid();
  table.string('name').makeUnique();
  table.uuid('territory_id');
  table.foreign(
    column: 'territory_id',
    references: 'id',
    onTable: 'territories',
    onDelete: OnDelete.cascade,
  );
});
await schema.adapter.rawExecute(blueprint.toSql(), const []);
```

- `toSql()` appends each `CREATE INDEX` as a SEPARATE statement after `CREATE TABLE`. Drivers that reject multi-statement strings need each executed individually; split on statement boundaries or keep index creation in its own blueprint.
- `Blueprint.toSql()` renders `DROP TABLE IF EXISTS` unconditionally, while `schema.drop` defaults to `ifExists: false`. Pass `ifExists: true` explicitly in `downSchema`.

### 3.14 Ordering with dependsOn (toposort)

By default migrations run in registration order. Declare prerequisites by `name` to force ordering (for example an FK whose parent table must exist first):

```dart
final class CreateSightingsTable extends Migration {
  const CreateSightingsTable();

  @override
  String get name => '20260102_000000_create_sightings_table';

  @override
  List<String> get dependsOn => ['20260101_000000_create_birds_table'];

  @override
  Future<void> upSchema(Schema schema) async { /* ... */ }

  @override
  Future<void> downSchema(Schema schema) async { /* ... */ }
}
```

- The `MigrationRunner` constructor runs a stable Kahn topological sort: each migration runs after every entry in its `dependsOn`; migrations with empty `dependsOn` keep exact registration order; ties among ready migrations resolve by registration position (deterministic).
- Errors surface at CONSTRUCTION, before any DB access:
  - Unknown `dependsOn` name -> `MigrationException`, message `declares unknown dependency "<name>"`.
  - Cycle -> `MigrationException`, message `Dependency cycle detected among migrations: '<a>', '<b>'. Break the cycle by removing one of the dependsOn entries.`
- `MigrationDependencySorter` is internal (not exported); reach it through the `MigrationRunner` constructor.

### 3.15 Pretend mode

`worm migrate --pretend` / `runner.pretend()` shows compiled statements per pending migration without executing them.

```dart
final captured = await runner.pretend(); // Map<String, List<String>>
for (final entry in captured.entries) {
  print('-- ${entry.key}');
  entry.value.forEach(print);
}
```

- Maps each pending migration's `name` to the compiled statements in execution order. Already-applied migrations are skipped.
- The runner wraps the real adapter in `PretendAdapter(delegate)` (exposes `List<String> get statements`), recording every descriptor call via the real adapter's `compileToString`, so captured SQL matches the target backend. Reads return empty results; `transaction` just invokes its callback; `rawQuery`/`rawExecute` are recorded as `RAW QUERY: ...` / `RAW EXECUTE: ...`.
- WARNING: pretend intercepts adapter calls ONLY. Your `upSchema` body runs for real, so file writes/HTTP/other side effects happen during a dry run too. Keep migrations free of non-adapter side effects.
- `MigrationPretendLog` (`MigrationPretendLog(entries)`, `.empty()`, `isEmpty`) and `MigrationPretendEntry` (`{migration, sql}`, `toMap()`) are exported typed log types, but `runner.pretend()` returns a plain `Map<String, List<String>>`, NOT a `MigrationPretendLog`.

### 3.16 Auto-generated migrations and diffing

`dart run worm:worm make:migration sync_schema --auto` diffs a declared target schema against the live database and writes `migrations/<timestamp>_sync_schema.dart`. Refuses to overwrite an existing file (exit code 65). Connects via `CliContext.adapterFactory`, builds `MigrationAutoGenerator` (internal, not exported).

Target schema file `schema/schema.json` at project root:

```json
{
  "tables": [
    {
      "name": "birds",
      "columns": [
        { "name": "id", "type": "uuid", "isPrimaryKey": true },
        { "name": "name", "type": "string" },
        { "name": "age", "type": "integer", "nullable": true }
      ]
    }
  ]
}
```

- `type` must be a `ColumnType` enum name. `nullable` and `isPrimaryKey` default to `false`. Missing file -> `MigrationException`; malformed JSON or unknown type name -> `FormatException`.
- Emits: new table -> `schema.create(...)` (one column call each, `..primary()` on PK, `..makeNullable()` on nullable); new column -> `schema.alter(...)` add; removed column -> `schema.alter(...)` with `dropColumn(...)`; removed table -> `schema.drop('<table>');`; type/nullability changes -> `// TODO: ... requires manual review.` comments. Generated `downSchema` drops added tables (`ifExists: true`) with `// TODO:` stubs for dropped tables. Empty diff -> body `// No schema changes detected.`.
- LIMITS: live introspection returns table/column NAMES ONLY, no types; every live column is assumed `ColumnType.text`, so existing tables report spurious type changes (all land as TODO comments) for non-text columns. `enumType`/`array` columns render as `table.text(...)`. Generated `schema.alter` blocks fail at execution time on all shipped adapters (see 3.12); rewrite as raw DDL before running. Structural changes (added/dropped tables and columns) are the reliable part. Review every `--auto` migration before applying.

Diff semantics: `DiffEngine.diff({required List<TableSchema> from, required List<TableSchema> to})` returns a `SchemaDiff`. Each `SchemaChange` carries a `destructive` flag:

| Change | `SchemaChangeKind` | Destructive? |
| --- | --- | --- |
| New table | `addTable` (+ one `addColumn` per column) | No |
| Dropped table | `dropTable` | Yes |
| New nullable column on existing table | `addColumn` | No |
| New NOT NULL column on existing table | `addColumn` | Yes |
| Column type changed | `changeColumnType` | Yes |
| Column nullable -> NOT NULL | `changeColumnNullable` | Yes |
| Column NOT NULL -> nullable | `changeColumnNullable` | No |
| Dropped column | `dropColumn` | Yes |

- `SchemaDiff` exposes `changes`, `hasDestructive`, `isEmpty`, `destructiveChanges`, and `SchemaDiff.empty()`.
- `SchemaDiff.tablesIn(kind)` is a STUB that always returns an empty list. Filter `changes` by `SchemaChangeKind` instead.
- Snapshot types: `TableSchema` (`{name, columns}`; `column(name)`, `toMap()`); `ColumnSnapshot` (`{name, type, nullable, isPrimaryKey}`; `toMap()`).
- `SchemaChange` shape: `{kind, table, column?, previousType?, newType?, previousNullable?, newNullable?, destructive}`; `toMap()`.

### 3.17 Squashing with schema:dump

```bash
dart run worm:worm schema:dump                  # write the snapshot only
dart run worm:worm schema:dump --prune --force  # snapshot, then delete migrations/*.dart
```

- Introspects the live DB and writes `schema/schema_dump.dart`, a generated Dart file with one `const Map<String, List<String>> schemaDump` mapping each table to its column names (tables sorted for reproducible output). Overwritten every run.
- `--prune` deletes every `.dart` file directly under `migrations/`. Because irreversible, `--prune` requires `--force` in EVERY environment (not just production). Without `--force`: writes an explanatory error to stderr, exits code 1. On success prints `pruned  N migration file(s).`.
- `schema_dump.dart` (names-only inspection/squash snapshot) and `schema/schema.json` (the `--auto` target) are DIFFERENT files with different formats. The dump is NOT read back by `make:migration --auto`.

### 3.18 Irreversible migrations, isDestructive, production gating, failure semantics

Irreversible migrations signal failure by throwing from the down path:

```dart
@override
Future<void> downSchema(Schema schema) async {
  throw const IrreversibleMigrationException(
    migration: '20260103_000000_backfill_names',
    message: 'cannot roll back',
    reason: 'source column was dropped after the backfill',
  );
}
```

- `IrreversibleMigrationException({required migration, required message, String? reason})` extends `WormException` directly. The runner wraps EVERY `downSchema` failure in a `MigrationException` (message prefix `down() failed:`), so callers of `runner.rollback()` catch a `MigrationException` embedding the irreversible text, NOT the original type.

`isDestructive` HONESTY: `Migration` declares `bool get isDestructive => false` intending runners to gate destructive migrations behind `--force`, but `MigrationRunner` does NOT read this flag anywhere. Overriding it changes nothing at execution time. Treat it as documentation/forward-compat, not a safety net.

Production gating (at the CLI, not the runner): the active environment is decided from `WORM_ENV` (trimmed, case-insensitive; only the exact word `production` counts). Two commands refuse to run in production without `--force`:
- `worm migrate:fresh`
- `worm migrate:refresh`

On refusal: write `error: refusing to run destructive command in production without --force` to stderr, exit code 1. Implemented by `ensureForceForProduction` (returns `false` on refusal) and `ProductionGuard.enforceForce` (injectable `exit(1)`), both exported; each consults `CliContext.isProduction`. `isProductionWormEnv(String?)` is an exported pure predicate. GAPS: `worm migrate:rollback` has NO production gate (it still runs `downSchema`); `schema:dump --prune`'s `--force` gates file deletion, not the database.

Failure semantics:
- Migrations are NOT wrapped in a transaction; each statement executes individually.
- The tracking row is inserted only after `upSchema` completes. A failure mid-migration leaves NO tracking row, so the next `migrate` retries the whole migration against whatever partial DDL the failure left. Write migrations so a partial re-run can succeed (`ifExists:`/`ifNotExists:` where available), or clean up manually.
- Any exception from `upSchema`/`downSchema` -> `MigrationException` (prefix `up() failed:` or `down() failed:`, migration name attached).
- Rollback resolves recorded names against the registered list. A recorded migration no longer registered -> `MigrationException`, message `Recorded migration not present in registered list`. Never delete an applied migration file.
- A malformed tracking row (wrong column types) -> `MigrationException`, message prefix `Corrupt worm_migrations row:`.

Exceptions summary:

| Symbol | Signature | Wraps / meaning |
| --- | --- | --- |
| `MigrationException` | `MigrationException({required migration, required message})` extends `AdapterException` | Any up/down failure, unknown or cyclic `dependsOn`, unregistered recorded migration, corrupt tracking row, missing `schema/schema.json`. |
| `IrreversibleMigrationException` | `IrreversibleMigrationException({required migration, required message, String? reason})` extends `WormException` | Throw from `downSchema` when a migration cannot be reversed. |

### 3.19 Seeding: the Seeder class

Extend `Seeder`, set `name`, implement `run`. The runner hands you the raw `DatabaseAdapter`; writes go through descriptors (see Adapters for `InsertDescriptor`).

```dart
import 'package:worm/worm.dart';

final class BirdsSeeder extends Seeder {
  const BirdsSeeder();

  @override
  String get name => 'BirdsSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    await adapter.insert(
      const InsertDescriptor(
        table: 'birds',
        values: <String, Object?>{
          'id': 'b-robin',
          'name': 'Robin',
          'species': 'Erithacus rubecula',
        },
      ),
    );
  }
}
```

`worm make:seeder BirdsSeeder` scaffolds this into `seeds/` with a `// TODO` in `run`. `name` has NO default; every seeder must override it (a compile error otherwise). Duplicate names break `--class` targeting and tracking.

Three optional overrides:

| Override | Default | Effect |
| --- | --- | --- |
| `Environment get environment` | `Environment.all` | Restricts where the seeder runs. Exact match, or `all`. |
| `int get order` | `0` | Ascending sort key applied before the run; stable ties keep registration order. |
| `bool get muteEvents` | `false` | Wraps `run` in `Worm.withoutEvents`, so model saves inside skip lifecycle hooks and observers. Validation STILL runs; muting never disables it. |

`Environment` enum: `development`, `staging`, `production`, `testing`, `all`.

### 3.20 DatabaseSeeder (composition)

A master seeder that runs children sequentially in declared order:

```dart
final class AppSeeder extends DatabaseSeeder {
  const AppSeeder();

  @override
  String get name => 'AppSeeder';

  @override
  List<Seeder> get seeders => const <Seeder>[
    BirdsSeeder(),
    SightingsSeeder(),
  ];
}
```

`DatabaseSeeder.run` calls each child's `run` DIRECTLY: it applies NO environment filter, NO `order` sort, and NO event muting to children. Only the master's own `environment`, `order`, `muteEvents` count (the runner only sees the master). It writes no tracking rows of its own.

### 3.21 Running seeders

CLI: `dart run worm:worm db:seed` runs every registered seeder passing the environment filter, printing `seeded  <name>` per run. When nothing applies it prints `No seeders applicable to <env> environment.` and still exits `0`. Reads seeders from `CliContext(seeders: [...])`.

| Flag | Effect |
| --- | --- |
| `--class=<Name>` | Run only the seeder whose `name` matches. Skips the environment filter. Unknown name throws `ArgumentError`. |
| `--force` | Skip the environment filter for every seeder. |
| `--env=<name>` | Override the filtering environment. Case-insensitive parse; an unrecognized value silently falls back to the context environment. |
| `--only=<Name>` | Deprecated alias for `--class`. |

Environment resolution without `--env`: `WORM_ENV`, then `WormConfig.environment`, then `Environment.development`.

`db:seed --force` means "ignore the environment filter", NOT a production gate; it is unrelated to `migrate:fresh --force` / `migrate:refresh --force`. A production-only seeder plus `db:seed --force` runs in development.

Programmatic: `SeederRunner` is the executor behind the CLI.

```dart
final runner = SeederRunner(
  adapter: adapter,
  seeders: const <Seeder>[BirdsSeeder(), DemoAccountsSeeder()],
  environment: Environment.development, // required
  // store: SeederRecordStore(adapter),  // optional; enables idempotent tracking
);
final ran   = await runner.run();                          // names that actually ran
final one   = await runner.run(seederClass: 'BirdsSeeder'); // target one; skips env filter
final all   = await runner.run(force: true);                // ignore env filter
```

| Method | Signature | Notes |
| --- | --- | --- |
| `run` | `Future<List<String>> run({String? seederClass, bool force = false})` | Runs applicable seeders; returns names that ran. |
| `shouldRun` | `bool shouldRun(Seeder seeder)` | Environment check for one seeder. |
| `runOne` | `Future<void> runOne(String name)` | Legacy alias for `run(seederClass: name)`. |

### 3.22 Idempotent tracking with worm_seeders (programmatic only)

By default seeders run every time. Pass a `SeederRecordStore` to make runs idempotent. Store: one row per seeder `name` in `worm_seeders` (`name` text PK, `executed_at` UTC timestamp).

```dart
final store = SeederRecordStore(adapter);
final runner = SeederRunner(
  adapter: adapter,
  seeders: const <Seeder>[BirdsSeeder()],
  environment: Environment.development,
  store: store,
);
final first  = await runner.run(); // ['BirdsSeeder']
final second = await runner.run(); // [] - already recorded, skipped
```

With a store: the runner calls `ensureTable()` first (idempotent `CREATE TABLE IF NOT EXISTS`), skips any seeder whose name already has a record (INCLUDING `--class`/`seederClass:` targeted runs), and inserts a record after each successful run.

STATE REALITY: the CLI does NOT track runs. `worm db:seed` constructs its `SeederRunner` WITHOUT a store, and so does `worm migrate:fresh --seed`. Every CLI invocation re-runs every applicable seeder. Tracking is programmatic ONLY; wire `SeederRecordStore` yourself, or write repeat-safe seeders. `SeederRecordStore` is constructor-injected and never reads `Worm.adapter()`; pass it the same adapter the runner uses.

`worm migrate:fresh --seed` drops the migration log, re-applies every migration, then runs all registered seeders through a `SeederRunner` with the active environment filter (and no tracking store), printing `seeded  <name>` per seeder.

Seeding tracking types:

| Symbol | Signature | Notes |
| --- | --- | --- |
| `SeederRecord` | `const SeederRecord({required String name, required DateTime executedAt})`; `toMap()`, `fromRow()` | `fromRow()` throws `FormatException` on a bad shape. |
| `SeederRecord.tableName` | `static const String tableName = 'worm_seeders'` | Tracking table name. |
| `SeederRecordStore` | `const SeederRecordStore(DatabaseAdapter adapter)` | Adapter-backed CRUD over `worm_seeders`. |
| `SeederRecordStore.ensureTable` | `Future<void> ensureTable()` | Idempotent `CREATE TABLE IF NOT EXISTS`. |
| `SeederRecordStore.hasRun` | `Future<bool> hasRun(String name)` | Whether a name is recorded. |
| `SeederRecordStore.record` | `Future<void> record(String name, {DateTime? executedAt})` | Persist a run record; defaults to UTC now. |
| `SeederRecordStore.all` | `Future<List<SeederRecord>> all()` | Every stored record. |

Seeding with factories: call factories inside `run` for volume (see Models / factories). `Factory.create()` persists through `Model.save()`, so hooks and validation fire and `Worm.initialize` must have run. Call `Worm.seedRandom(42)` first for repeatable fake data.

---

## 4. Model lifecycle: CRUD, state, mass assignment, soft deletes, serialization, repositories

The write path of a worm model: how `save()` picks INSERT vs UPDATE, dirty tracking, mass-assignment guards, soft deletes, serialization, and the optional `Repository<T>` data-mapper. All examples assume the canonical model shape from the Models section (a model extending `Model`, with a `tableName` override and a `static query()`).

### 4.1 save(): insert vs update

`save()` branches on the `exists` flag alone: never persisted -> INSERT, persisted -> UPDATE. It returns a `bool`.

```dart
final user = User(name: 'Alice', age: 34);
await user.save();                 // INSERT (exists was false) -> markPersisted()

user.setAttribute('name', 'Bob');
await user.save();                 // UPDATE, sends only {name: 'Bob'}
```

Save pipeline (in order): `beforeValidate` -> validation rules -> `beforeSave` -> (`beforeCreate` | `beforeUpdate`) -> write -> (`markPersisted` | `syncOriginal`) -> (`afterCreate` | `afterUpdate`) -> `afterSave` -> queued `afterCommit` callbacks.

- **Insert** writes the full `toRow()` map plus `created_at` / `updated_at` (when timestamps on). Values pass through the model's `castManager` first. Then `markPersisted()` flips `exists` to true.
- **Update** writes only dirty attributes when the attribute store is in use and at least one attribute is dirty (minimal-UPDATE guarantee). If the store is untouched (a model that manages its own fields and never called `setAttribute`), worm falls back to `toRow()` minus the primary key column. After the write, `syncOriginal()` clears the dirty set.
- Validation on update runs `updateRules` (defaults to `rules`) and only for dirty fields. An unchanged column never blocks an unrelated edit.

Worm never generates primary key values. Assign `id` before the first save, or use a database auto-increment column.

#### save() returns false vs throws

| Outcome | Cause | Written? |
|---|---|---|
| returns `false` | any `before*` hook (`beforeValidate` / `beforeSave` / `beforeCreate` / `beforeUpdate`) returns `false` | nothing written, no exception |
| throws `ValidationException` | a validation rule fails | nothing written |

Check the `bool` return when hooks can veto. Hook cancellation is a `false`, not an exception. Failed validation is the one save failure that is an exception.

### 4.2 update(map): fill then save

`update(data)` is `fill(data)` then `save()`. Because it goes through `fill`, mass-assignment rules apply (see 4.4): guarded / non-fillable keys are silently skipped in default mode, or throw `MassAssignmentException` in strict mode (before any query runs). The return value is the `save()` result.

```dart
await user.update({'name': 'Carol', 'age': 35});
```

### 4.3 Dirty tracking

Every `setAttribute` call maintains the dirty set:

```dart
user.setAttribute('name', 'Bob');

user.isDirty();                     // true: anything dirty?
user.isDirty('name');               // true: this field dirty?
user.dirtyFields;                   // {'name'} (unmodifiable Set<String>)
user.getOriginal('name');           // 'Alice' (value at last sync, or null)
user.getOriginalValue(User$.name);  // 'Alice', typed via the companion Field<T>
```

Rules:
- Writing a **different** value to an existing key marks it dirty.
- Writing an **equal** value to an existing key does not.
- Writing any value to a **previously absent** key marks it dirty, even if it equals the stored value. Attribute initialization participates in the dirty set on purpose.
- A successful save (`syncOriginal`) or `refresh()` clears the dirty set.
- `getOriginalValue<T>(Field<T>)` returns `null` both for untouched fields and when the stored original is not a `T`.

### 4.4 refresh()

`refresh()` re-reads the row by primary key and reseeds the instance.

```dart
await user.refresh();
```

- Throws `ModelNotFoundException` when the row no longer exists.
- Decodes values through the `castManager`, seeds them via `hydrateAttribute`, calls `markPersisted()` (clears all dirty state), and fires `afterHydrate`.
- Discards local unsaved changes.

### 4.5 delete() and forceDelete()

```dart
await user.delete();       // returns false if beforeDelete cancels
await user.forceDelete();  // identical to delete() on a plain model
```

- `delete()` fires `beforeDelete` (cancelable -> returns `false`), removes the row by primary key, sets `exists` to `false`, fires `afterDelete`.
- On a plain model, `forceDelete()` is the same operation. The distinction only matters with the `SoftDeletes` mixin (see 4.6), where `delete()` trashes and `forceDelete()` hard-deletes.
- When the model declares `ormCascadeSpecs` (emitted for relations marked `OnDelete.ormCascade`), dependent rows are loaded and deleted first, one at a time, firing every child's lifecycle hooks. Any child's `beforeDelete` returning `false` aborts the whole cascade, including the parent's delete.

### 4.6 Timestamps and withoutTimestamps

With `usesTimestamps` on (the default): inserts set `created_at` and `updated_at`, updates refresh `updated_at`, always as `DateTime.now().toUtc()`. Compare in UTC.

```dart
await user.withoutTimestamps(() async {
  user.setAttribute('name', 'migrated');
  await user.save();       // no updated_at change
});
```

The suspension is per instance and restored after the callback, even on error.

### 4.7 afterCommit

`afterCommit(callback)` queues a callback for when the surrounding operation is safely through.

```dart
user.afterCommit(() => log.info('user persisted'));
await user.save();
```

- Outside a transaction: fires immediately after the save or delete completes.
- Inside a `Worm.transaction`: deferred until commit; discarded on rollback.

### 4.8 Hydration, exists, markPersisted

`exists` only becomes `true` through `markPersisted()`. Worm calls it after a successful insert, in `refresh()`, and in repository lookups (`find`, `findOrFail`, `all`). When hydrating rows yourself, do both steps:

```dart
final model = User(name: 'Alice', age: 34);
row.forEach(model.hydrateAttribute); // seed without dirtying
model.markPersisted();               // exists = true, originals snapshotted
```

Caution: the generated `fromRow` hydrator constructs a fresh instance and does **not** call `markPersisted()`. A model loaded through the generated query starter reports `exists == false`, so `save()` on it INSERTS a new row instead of updating. Call `markPersisted()` on query-loaded models before saving, or load through a repository (which calls it for you).

### 4.9 replicate()

`replicate()` builds an unsaved copy (`exists == false`) of every attribute except the primary key, timestamp columns, and anything in `except`. The base implementation throws `UnsupportedOperationException`, and no override is generated. Provide your own using the protected helper `replicatedAttributes`:

```dart
@override
Model replicate({List<String> except = const []}) {
  final copy = User(name: name, age: age);
  replicatedAttributes(except: except).forEach(copy.setAttribute);
  return copy;
}
```

### 4.10 Explicit transactions

Every write method accepts a `transaction:` parameter to enlist in a `TransactionContext`. Without it, writes automatically join any ambient `Worm.transaction` in scope.

```dart
await Worm.transaction(() async {
  await user.save();     // enlisted automatically
  await post.save();     // same transaction
});
```

### 4.11 Write / read-state API (Model)

| Symbol | Signature | Behavior |
|---|---|---|
| `save` | `Future<bool> save({TransactionContext? transaction})` | INSERT when `exists` false, UPDATE otherwise. `false` on hook cancel. |
| `delete` | `Future<bool> delete({TransactionContext? transaction})` | Delete by PK; walks `ormCascadeSpecs` children first. `false` on `beforeDelete` cancel. |
| `forceDelete` | `Future<bool> forceDelete({TransactionContext? transaction})` | Hard delete; same as `delete` on plain models. |
| `update` | `Future<bool> update(Map<String, Object?> data, {TransactionContext? transaction})` | `fill(data)` then `save()`. |
| `refresh` | `Future<void> refresh()` | Re-read by key. Throws `ModelNotFoundException` on missing row. |
| `replicate` | `Model replicate({List<String> except = const []})` | Unsaved copy. Base throws `UnsupportedOperationException`. |
| `replicatedAttributes` | `@protected Map<String, Object?> replicatedAttributes({List<String> except = const []})` | Attributes minus key, timestamps, `except`; for `replicate` overrides. |
| `fill` | `void fill(Map<String, Object?> data)` | Mass-assign honoring `fillable` / `guarded`. |
| `exists` | `bool get exists` | Persisted at least once. |
| `isDirty` | `bool isDirty([String? field])` | Any (or one) attribute dirty. |
| `dirtyFields` | `Set<String> get dirtyFields` | Unmodifiable dirty key set. |
| `setAttribute` | `void setAttribute(String name, Object? value)` | Write and mark dirty (never guarded). |
| `getAttribute` | `Object? getAttribute(String name)` | Live value. |
| `getOriginal` | `Object? getOriginal(String name)` | Value at last sync, or `null`. |
| `getOriginalValue` | `T? getOriginalValue<T>(Field<T> field)` | Typed original; `null` when untouched or not a `T`. |
| `hydrateAttribute` | `void hydrateAttribute(String name, Object? value)` | Seed without dirtying. |
| `markPersisted` | `void markPersisted()` | Snapshot originals; set `exists` true. |
| `withoutTimestamps` | `Future<T> withoutTimestamps<T>(Future<T> Function() callback)` | Suspend timestamp maintenance for the callback. |
| `afterCommit` | `void afterCommit(void Function() callback)` | Queue a post-commit callback. |

`ModelState` is the per-instance container behind these (`attributes`, `original`, `dirty`, `exists`, `withoutTimestamps`, `afterCommitCallbacks`, plus `syncOriginal()`, `setAttribute`, `seedAttribute`). It is exported but owned by its model; mutate through the `Model` API. `ActiveRecord` is the static orchestrator (`ActiveRecord.save`, `.delete`, `.refresh`, `.dispatcherFor`); you rarely call it directly.

### 4.12 Mass assignment: fill / fillable / guarded

`fill(map)` and `update(map)` are the only guarded writes; `setAttribute` is never guarded. Control writable keys with two `Model` overrides.

```dart
final class User extends Model {
  // ... constructor, id, toRow, tableName, static query() ...

  @override
  List<String> get fillable => const ['name', 'email'];

  @override
  List<String> get guarded => const ['role'];
}
```

Per-key decision order inside `fill`:
1. If the key is in `guarded`, reject it. `guarded` always wins.
2. If `fillable` is empty, accept it. An empty whitelist means "everything is fillable".
3. Otherwise the key must appear in `fillable`.

Defaults are empty `fillable` and empty `guarded`, so a fresh model accepts every key. To lock a model down, list its writable fields in `fillable` explicitly.

Note: the `@Fillable` / `@Guarded` annotations are experimental. The generator emits the matching getter overrides only into an opt-in `_$<Model>Annotations` mixin; nothing changes unless you mix that in yourself. The runtime reads the getter overrides. Override the getters directly.

#### Silent skip vs strict throw

By default rejected keys are **silently skipped** (accepted keys in the same map are still applied and marked dirty; a typo vanishes without a trace). Strict mode turns the skip into a `MassAssignmentException`.

Enable per model:

```dart
@override
bool get strictMassAssignment => true;
```

Or globally:

```dart
await Worm.initialize(
  config: const WormConfig(
    strictness: StrictnessConfig(preventSilentMassAssignment: true),
  ),
  adapters: {'default': adapter},
);
```

In strict mode, `fill` applies the permitted keys **first**, then collects **every** offending key and throws one `MassAssignmentException`:

```dart
try {
  user.fill({'name': 'Ada', 'role': 'admin', 'is_admin': true});
} on MassAssignmentException catch (e) {
  print(e.fields); // [role, is_admin]  -- every rejected key
  // e.field holds only the first (legacy); prefer e.fields.
}
```

Because `update(map)` runs `fill` first, it can throw `MassAssignmentException` before any query executes.

#### Worm.unsafe escape hatch

`Worm.unsafe(callback)` disables only the **global** strictness gate for the wrapped region; a model without its own strict flag falls back to silent skipping even when `preventSilentMassAssignment` is on.

```dart
await Worm.unsafe(() async {
  user.fill({'name': 'Ada', 'role': 'admin'}); // 'role' skipped, not thrown
});
```

The flag rides a Dart Zone, so it survives `await`s and resets afterward. Two limits: `unsafe` does not bypass a model's own `strictMassAssignment => true` override, and it never makes `guarded` keys fillable (they are still skipped).

### 4.13 Soft deletes

Soft deletes keep "deleted" rows in the table with a `deleted_at` timestamp. Two independent halves, both wired explicitly; neither activates the other:

- The `SoftDeletes` mixin (`on Model`) provides `delete()`, `restore()`, `forceDelete()`, and `deletedAt` state.
- The `SoftDeleteScope` global scope filters queries to rows where `deleted_at IS NULL`.

#### Mixin contract

The model must implement the required host overrides, and its `toRow()` must include the soft-delete column (or the mixin's UPDATE never writes it).

```dart
final class User extends Model with SoftDeletes {
  User({required this.userId, required this.name, DateTime? deletedAt}) {
    if (deletedAt != null) this.deletedAt = deletedAt;
  }

  factory User.fromRow(Map<String, Object?> row) => User(
    userId: row['id']! as int,
    name: row['name']! as String,
    deletedAt: switch (row[softDeleteColumn]) {
      final DateTime value => value,
      final String value => DateTime.tryParse(value),
      _ => null,
    },
  );

  final int userId;
  final String name;

  @override
  Object get id => userId;

  @override
  String get tableName => 'users';

  // Required host overrides:
  @override
  DatabaseAdapter get softDeleteAdapter => Worm.adapter();

  @override
  String get softDeleteTable => 'users';

  // toRow() MUST include the soft-delete column.
  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': userId,
    'name': name,
    softDeleteColumn: deletedAt?.toIso8601String(),
  };
}
```

| Member | Required | Default | Purpose |
|---|---|---|---|
| `softDeleteAdapter` | yes | none | Adapter the mixin uses for its UPDATE and DELETE. |
| `softDeleteTable` | yes | none | Table the model lives in. |
| `softDeletePrimaryKey` | no | `'id'` | PK column used in the WHERE clause. |
| `softDeleteAtColumn` | no | `softDeleteColumn` (`'deleted_at'`) | Column carrying the timestamp. |
| `toRow()` includes the column | yes | none | The mixin persists via `toRow()`; a missing key means the flag never reaches the database. |

`softDeleteColumn` is the top-level constant `'deleted_at'`. Hydrators seed state through the `deletedAt` setter, as `fromRow` does above.

#### Trash, restore, hard delete

```dart
await user.delete();      // sets deletedAt = DateTime.now(), then UPDATE; always true
user.isTrashed;           // true while deletedAt is non-null
await user.restore();     // fires beforeRestore/afterRestore, clears deletedAt, persists
await user.forceDelete(); // real DELETE by PK, bypasses hooks; always true
```

- `delete()` sets `deletedAt` to `DateTime.now()` (local, not UTC) and calls `save()`. It never issues a real DELETE. Returns `true`.
- `restore()` fires `beforeRestore` (return `false` to cancel -> `restore` returns `false`), clears `deletedAt`, persists, then fires `afterRestore`. This is the **only** hook-firing operation in the mixin.
- `forceDelete()` issues one real DELETE keyed by PK, bypassing hooks. Returns `true`.

#### The mixin replaces save()

Mixing in `SoftDeletes` overrides `Model.save()` with a single targeted UPDATE of the full `toRow()` keyed by `softDeletePrimaryKey`, for **every** save on the model. Consequences:

- No lifecycle hooks fire and no validation runs on `save()` and `delete()` (only `restore()` fires hooks).
- `save()` always returns `true`; there is no hook to cancel it.
- Timestamps (`updated_at`) are not maintained, and dirty tracking is not synced.
- `save()` can never INSERT. Create rows for soft-delete models through another path: the adapter's insert, a seeder, or a migration.
- Writes route through an active transaction when one is in scope (`transaction:` argument wins, else ambient `Worm.transaction` on the same connection).

#### Query side: hiding trashed rows

Register `SoftDeleteScope` on the query context to append `deleted_at IS NULL`:

```dart
final context = QueryContext<User>(
  adapter: Worm.adapter(),
  table: 'users',
  hydrate: User.fromRow,
  globalScopes: const <GlobalScope<Model>>[SoftDeleteScope<User>()],
);

final live = await QueryBuilder<User>.from(context).get(); // only deleted_at IS NULL
```

With code generation, annotate the model `@GlobalScope(SoftDeleteScope)` (from `package:worm/annotations.dart`) and the generated `query()` starter registers the scope.

Bypass methods:

```dart
final everyone = await QueryBuilder<User>.from(context).withTrashed().get();
final trashed  = await QueryBuilder<User>.from(context).onlyTrashed().get();
```

- `withTrashed()` disables `SoftDeleteScope` for this query via `withoutGlobalScope<SoftDeleteScope<Model>>()`. All rows return.
- `onlyTrashed({String column = 'deleted_at'})` calls `withTrashed()` then adds `deleted_at IS NOT NULL`.
- `withoutGlobalScopes()` (plural) also disables `SoftDeleteScope`, along with every other global scope.
- Scope stable name is `softDeleteScopeName` = `'soft_deletes'`; filtered column configurable via `SoftDeleteScope(column: ...)`.

#### Schema side

In a migration, `table.softDeletes()` adds the nullable `deleted_at` column (see the Migrations section).

#### Soft-delete API summary

| Symbol | Signature sketch | Notes |
|---|---|---|
| `softDeleteColumn` | `const String softDeleteColumn = 'deleted_at'` | Default column name. |
| `SoftDeletes` | `mixin SoftDeletes on Model` | Adds soft-delete semantics. |
| `softDeleteAdapter` | `DatabaseAdapter get softDeleteAdapter` | Required host override. |
| `softDeleteTable` | `String get softDeleteTable` | Required host override. |
| `softDeletePrimaryKey` | `String get softDeletePrimaryKey` | Defaults to `'id'`. |
| `softDeleteAtColumn` | `String get softDeleteAtColumn` | Defaults to `softDeleteColumn`. |
| `deletedAt` | `DateTime? get deletedAt; set deletedAt(DateTime?)` | Trash timestamp; setter used by hydrators. |
| `isTrashed` | `bool get isTrashed` | `deletedAt` non-null. |
| `SoftDeletes.save` | `Future<bool> save({TransactionContext? transaction})` | Single UPDATE of `toRow()` by PK; bypasses hooks; always `true`. |
| `SoftDeletes.delete` | `Future<bool> delete({TransactionContext? transaction})` | Sets `deletedAt` and saves; never a real DELETE; always `true`. |
| `SoftDeletes.restore` | `Future<bool> restore({TransactionContext? transaction})` | Fires restore hooks, clears `deletedAt`, saves; `false` when canceled. |
| `SoftDeletes.forceDelete` | `Future<bool> forceDelete({TransactionContext? transaction})` | Real DELETE by PK; bypasses hooks; always `true`. |
| `SoftDeleteScope<T>` | `const SoftDeleteScope({String column = 'deleted_at'})` | Global scope adding `deleted_at IS NULL`; `name` is `'soft_deletes'`. |
| `softDeleteScopeName` | `const String softDeleteScopeName = 'soft_deletes'` | Stable name used for bypassing. |
| `QueryBuilder.withTrashed` | `QueryBuilder<T> withTrashed()` | Disables `SoftDeleteScope`. |
| `QueryBuilder.onlyTrashed` | `QueryBuilder<T> onlyTrashed({String column = 'deleted_at'})` | Only soft-deleted rows. |

### 4.14 Serialization

Every model has `toMap()` and `toJson()`. Both, plus the standalone `Serializer`, consume one thing: the `SerializationDescriptor` returned by `describe()`.

```dart
final map  = user.toMap(); // {'id': 'u-1', 'name': 'Alice', 'created_at': ...}
final json = user.toJson();

user.toMap(
  only: {'id', 'name'},        // whitelist, applied last, top level only
  hidden: {'internal_flag'},   // extra keys to drop for this call
  includeRelations: true,      // walk relations via the cycle-aware Serializer
  maxDepth: 2,                 // nesting budget when relations are included
);
```

- `Model.toMap` signature: `toMap({Set<String>? only, Set<String>? hidden, bool includeRelations = false, int maxDepth = 2})`.
- `toJson()` takes **no parameters**; it is `jsonEncode(toMap())` with defaults, so it never includes relations. For relation JSON: `jsonEncode(toMap(includeRelations: true))`.
- Serialization reads live values through `toRow()`. Casts are **not** re-applied here (a `Decimal` field serializes as whatever the attribute currently holds).
- `only:` and `hidden:` apply after serialization and only to top-level keys; they do not reach into nested relation maps.

#### Customize via describe(), not toMap()

Override `describe()`, never `toMap()`. The `Serializer` pipeline reads `describe()`, so overriding `toMap` diverges the two outputs. Base implementation:

```dart
@override
SerializationDescriptor describe() => SerializationDescriptor(
  fields: toRow(),
  hidden: hiddenFromSerialization,
  appended: computedAttributes,
);
```

Hiding fields and computed attributes are plain `Model` overrides:

```dart
@override
Set<String> get hiddenFromSerialization => const {'password_hash'};

@override
Map<String, Object?> get computedAttributes => {'display_name': '@$name'};
```

Hidden fields still exist on the model and still reach the database via `toRow()`; they never appear in serialized output. Computed attributes appear in `toMap`/`toJson` but never in `toRow()`, so they are never written.

#### Serializing relations

The base `describe()` exposes **no relations**, so `toMap(includeRelations: true)` yields no relation keys until you override `describe()` and list related objects. Each `relations` value must be a `Serializable` or `List<Serializable>` (`Model` implements `Serializable`).

```dart
final class User extends Model {
  // ... constructor, id, toRow, tableName, static query() ...
  List<Post> posts = <Post>[];

  @override
  SerializationDescriptor describe() => SerializationDescriptor(
    fields: toRow(),
    hidden: hiddenFromSerialization,
    appended: computedAttributes,
    relations: {'posts': posts},
  );
}
```

If a relation was populated by eager loading, read it with `getRelation<T>(name)` inside the override. `getRelation` throws `RelationNotLoadedException` (or `LazyLoadingException` under strict mode) when the relation was never loaded, so only expose relations you know are loaded on that code path.

#### Cycles collapse to references

The serializer caches every fully serialized node by `type#id`. On meeting the same node again (a cycle, or a second path), it emits a reference instead of recursing:

```dart
final serialized = user.toMap(includeRelations: true);
// posts[0].author collapses to:
// {'type': 'User', 'id': 'u-1', 'ref': true}
```

Hidden fields never leak through a reference, but `type` and `id` do, by design.

#### Depth budget

`maxDepth` caps nested relation levels. `Model.toMap` defaults to `maxDepth: 2`; the standalone `Serializer` defaults to `maxDepth: 8`. Once the budget is spent, deeper relations are **omitted entirely** (their keys do not appear; they are not truncated to `ref` markers). `maxDepth: 0` walks no relations.

#### Standalone Serializer

```dart
const serializer = Serializer(); // maxDepth defaults to 8
final map  = serializer.toMap(user);
final json = serializer.toJson(user);
```

`Serializable` requires `serializationId` (cycle identity; on `Model` defaults to `'$id'`), `serializationType` (type tag in references; defaults to runtime type name), and `describe()`.

`SerializationDescriptor` also carries a `visible` whitelist: when non-null, only listed keys appear (minus `hidden`), across fields, appended values, and relation keys alike. `Model.describe()` never sets `visible`; set it yourself in a `describe()` override. The model-level whitelist is `toMap(only: ...)`, applied after serialization and only at the top level.

```dart
SerializationDescriptor(
  fields: {'id': id, 'name': name, 'password': password},
  hidden: const {'password'},
  visible: const {'id', 'name', 'display_name'},
  appended: {'display_name': '@$name'},
  relations: {'posts': posts},
);
```

#### Serialization API summary

| Symbol | Signature sketch |
|---|---|
| `Serializable` | `abstract; String get serializationId; String get serializationType; SerializationDescriptor describe()` |
| `SerializationDescriptor` | `const SerializationDescriptor({required Map<String, Object?> fields, Set<String> hidden = {}, Set<String>? visible, Map<String, Object?> appended = {}, Map<String, Object> relations = {}})` |
| `Serializer` | `const Serializer({int maxDepth = 8})` |
| `Serializer.toMap` | `Map<String, Object?> toMap(Serializable root)` |
| `Serializer.toJson` | `String toJson(Serializable root)` |
| `Model.toMap` | `Map<String, Object?> toMap({Set<String>? only, Set<String>? hidden, bool includeRelations = false, int maxDepth = 2})` |
| `Model.toJson` | `String toJson()` (`jsonEncode(toMap())`; no params, no relations) |
| `Model.describe` | `SerializationDescriptor describe()` (supported customization point) |
| `Model.hiddenFromSerialization` | `Set<String> get hiddenFromSerialization` |
| `Model.computedAttributes` | `Map<String, Object?> get computedAttributes` |
| `Model.serializationId` | `String get serializationId` (defaults to `'$id'`) |
| `Model.serializationType` | `String get serializationType` (defaults to runtime type name) |

### 4.15 Repository pattern (Repository<T>)

Active Record puts CRUD on the model (`user.save()`). The data-mapper alternative moves CRUD into a dedicated class: subclass `Repository<T>`. Both sit on the same engine; pick one style per project. `Worm.initialize` is still required because the write methods go through Active Record.

```dart
import 'package:worm/worm.dart';
import 'user.dart';

final class UserRepository extends Repository<User> {
  const UserRepository(super.adapter);

  @override
  String get tableName => 'users';

  @override
  User hydrate(Map<String, Object?> row) => User.fromRow(row);
}
```

`hydrate` reuses the model's `User.fromRow` factory. If the PK column is not `id`, override `primaryKeyColumn`. The repository calls `markPersisted()` on hydrated models for you (after `find` and `all`), so `hydrate` should build, not persist.

Using it (inject the registry adapter so reads and writes agree on one connection):

```dart
final users = UserRepository(Worm.adapter());

final ada = User(name: 'Ada', age: 36);
await users.save(ada);                          // insert or update

final found   = await users.find('u-Ada');      // User?, null when missing
final loaded  = await users.findOrFail('u-Ada');// User, throws ModelNotFoundException when missing
final everyone = await users.all();             // List<User> (whole table)
final removed  = await users.deleteById('u-Ada');// int rows deleted
```

Engine split:
- `save`, `delete`, `refresh` forward to the Active Record orchestrator: they run validation, fire hooks and observers, stamp timestamps, and resolve their adapter from the **model's connection in the Worm registry** (not the injected one).
- Read methods (`find`, `findOrFail`, `all`, `deleteById`) run against the **injected** adapter directly.
- There is no query builder on the repository. For `where` clauses, use `User.query()` (the model's `static query()`) or wrap it in a repository method of your own.

#### Repository API summary

| Member | Signature | Notes |
|---|---|---|
| Constructor | `const Repository(DatabaseAdapter adapter)` | Adapter used by read methods. |
| `tableName` | `String get tableName` | Abstract. Target table. |
| `hydrate` | `T hydrate(Map<String, Object?> row)` | Abstract. Build a typed model from a row. |
| `primaryKeyColumn` | `String get primaryKeyColumn` | Defaults to `'id'`. |
| `save` | `Future<bool> save(T model)` | Insert or update. `false` when a `before` hook cancels. |
| `delete` | `Future<bool> delete(T model)` | Delete through Active Record. |
| `refresh` | `Future<void> refresh(T model)` | Re-read from the database. |
| `find` | `Future<T?> find(Object id)` | Look up by PK, or `null`. |
| `findOrFail` | `Future<T> findOrFail(Object id)` | Look up by PK, or throw `ModelNotFoundException`. |
| `all` | `Future<List<T>> all()` | Load every row as `List<T>`. |
| `deleteById` | `Future<int> deleteById(Object id)` | Delete by PK. Returns affected count. |

### 4.16 Gotchas

- `save()` returns `false` on hook cancellation; it does not throw. Only failed validation throws (`ValidationException`).
- Writing an equal value to a previously absent key still marks the key dirty.
- An UPDATE on a model whose attribute store is unused (or fully clean) sends the entire `toRow()` minus the PK, not a minimal payload.
- `refresh()` discards unsaved local changes and clears the dirty set; throws `ModelNotFoundException` if the row is gone.
- Models loaded via the generated `fromRow` have `exists == false`; saving them INSERTS. Call `markPersisted()` first, or load through a repository.
- `replicate()` throws `UnsupportedOperationException` unless you override it; no override is generated.
- A child's `beforeDelete` returning `false` inside an ORM cascade aborts the parent's delete too.
- `forceDelete()` on a plain model is just `delete()`. The distinction only matters with `SoftDeletes`.
- Timestamps are written in UTC; but `SoftDeletes.delete()` stamps `deletedAt` with local `DateTime.now()`.
- `setAttribute` bypasses mass-assignment protection; guarding applies to `fill` and `update` only. An empty `fillable` means everything is fillable.
- Strict `fill` applies permitted keys **before** it throws; the exception's `fields` list the rejected keys, the accepted ones are already assigned and dirty.
- `Worm.unsafe` relaxes only the global flag; a model's own `strictMassAssignment => true` still throws, and guarded keys are never made fillable.
- The `SoftDeletes` mixin's `save()` writes the full `toRow()`, never INSERTS, always returns `true`, and bypasses hooks/validation/timestamps/dirty-sync. If `toRow()` omits the `deleted_at` key, `delete()` appears to succeed but the flag never reaches the database.
- The mixin and `SoftDeleteScope` are independent: a `SoftDeletes` model still shows trashed rows in queries until the scope is registered on the query context.
- Override `describe()`, never `toMap()`. Base `describe()` exposes no relations, so `toMap(includeRelations: true)` yields no relation keys until you override it.
- Collapsed cycle references leak `type` and `id` even for nodes whose fields are hidden. Relations beyond `maxDepth` are dropped (missing keys), not turned into `ref` markers.

---

## 5. Casts, validation, factories, and naming

Four model-level concerns: type conversion at the storage boundary (casts), declarative per-field rules that auto-run on save (validation), fixture generation (factories), and how Dart identifiers become database names (naming).

### 5.1 Casts

Casts convert a field between its Dart type and the primitive the adapter stores. They run on the storage boundary only:

- Decode on read: hydration runs `castManager.decodeAll(row)`, handing you domain values.
- Encode on write: before insert/update, `castManager.encodeAll(values)` produces storable primitives.
- Never on serialization: `toMap()` / `toJson()` read live attribute values; casts are not re-applied there.
- Fields with no registered cast pass through untouched in both directions.
- Casts do NOT run on query predicates. When filtering a casted column, compare against the STORED form (ISO-8601 string for a `datetime` column, `Decimal.value` for a `decimal` column, `value.name` for an `enum` column).

#### 5.1.1 Attaching casts: castManager override

Override the `castManager` getter. Keys are column names as they appear in the row. This is the recommended mechanism; it is explicit, works for every cast, and needs no code generation. The base `Model.castManager` returns an empty manager, so models without casts pay no per-call cost.

```dart
import 'package:worm/worm.dart';

enum Role { admin, editor, viewer }

@Table(name: 'users')
final class User extends Model {
  User({required String name}) {
    setAttribute('id', 'u-$name');
    setAttribute('name', name);
  }
  User._();

  factory User.fromRow(Map<String, Object?> row) {
    final user = User._();
    row.forEach(user.hydrateAttribute);
    return user..markPersisted();
  }

  @override
  String get tableName => 'users';

  @override
  Object get id => getAttribute('id') ?? '';

  @override
  Map<String, Object?> toRow() => {'id': id};

  @override
  CastManager get castManager => CastManager(<String, AttributeCast>{
        'created_at': const DateTimeCast(),
        'balance': const DecimalCast(),
        'role': const EnumCast<Role>(Role.values),
        'settings': const JsonMapCast(),
      });

  static QueryBuilder<User> query() => QueryBuilder<User>.from(
        QueryContext<User>(
          adapter: Worm.adapter(),
          table: 'users',
          hydrate: User.fromRow,
        ),
      );
}
```

Every built-in cast is `const` and can be used directly and symmetrically:

```dart
const cast = DateTimeCast();
final encoded = cast.encode(DateTime.utc(2026, 5, 22, 12, 30, 45));
// '2026-05-22T12:30:45.000Z'
final decoded = cast.decode(encoded); // DateTime (UTC)
cast.decode('not-a-date');            // throws CastException
```

Decode is lenient, encode is strict: decode accepts several raw forms (adapters surface values differently), encode mostly accepts only the domain type (a wrong write type is a bug, not a storage quirk). Unusable input throws `CastException` in both directions; the exception carries `field`, `fromType`, `toType`.

```dart
const cast = BoolCast();
cast.decode('true'); // true
cast.encode('true'); // throws CastException: encode wants a bool
```

#### 5.1.2 The 14 built-in casts

Verified against `lib/src/cast/casts/`.

| Cast | `name` | Dart type | Stored form | Decode also accepts |
| --- | --- | --- | --- | --- |
| `IntCast` | `int` | `int` | `int` | numeric `String`, whole `double` |
| `DoubleCast` | `double` | `double` | `double` (encode converts `int`) | `int`, numeric `String` |
| `BoolCast` | `bool` | `bool` | `bool` | `int` (0 false, nonzero true), `'true'`/`'t'`/`'1'`, `'false'`/`'f'`/`'0'` (case-insensitive) |
| `StringCast` | `string` | `String` | `String` | `num`, `bool`, `BigInt`, `Uri` via `toString()` |
| `DateTimeCast` | `datetime` | `DateTime` (UTC) | ISO-8601 `String` | epoch-milliseconds `int` (as UTC), parseable `String`, `DateTime` |
| `DurationCast` | `duration` | `Duration` | `int` milliseconds | `int`, `BigInt`, whole `double`, numeric `String` |
| `BigIntCast` | `bigint` | `BigInt` | canonical decimal `String` | `int`, parseable `String` |
| `DecimalCast` | `decimal` | `Decimal` | canonical `String` (`.value`) | `String`, `int`, `Decimal` |
| `EnumCast<T>` | `enum` | `T extends Enum` | `value.name` `String` | name `String`, index `int`, `T` |
| `UriCast` | `uri` | `Uri` | `uri.toString()` | parseable `String` |
| `JsonMapCast` | `json-map` | `Map<String, Object?>` | JSON-encoded `String` | already-decoded `Map` (keys must be `String`) |
| `JsonListCast` | `json-list` | `List<Object?>` | JSON-encoded `String` | already-decoded `List` |
| `CustomCast<T>` | `custom` (configurable) | `T` | whatever your `toDb` returns | whatever your `fromDb` handles |
| `EncryptedCast` | `encrypted` | `String` plaintext | subclass-defined ciphertext | whatever your `decryptString` handles |

Constructors:

```dart
const IntCast({String field = 'value'});
const DoubleCast({String field = 'value'});      // encode converts int
const BoolCast({String field = 'value'});
const StringCast({String field = 'value'});
const DateTimeCast({String field = 'value'});     // UTC on both directions
const DurationCast({String field = 'duration'});  // note different default field
const BigIntCast({String field = 'value'});
const DecimalCast({String field = 'value'});
const EnumCast<T extends Enum>(List<T> values, {String field = 'value'});
const UriCast({String field = 'value'});
const JsonMapCast({String field = 'value'});
const JsonListCast({String field = 'value'});
const CustomCast<T>({
  required T Function(Object?) fromDb,
  required Object? Function(T) toDb,
  String name = 'custom',
});
// EncryptedCast: abstract; const EncryptedCast({String field = 'value'});
```

The `field` parameter (default `'value'`, `'duration'` for `DurationCast`) is used ONLY for error reporting in `CastException`. `CustomCast` reports its `name` instead.

#### 5.1.3 DateTimeCast (UTC) and Decimal (lossless)

`DateTimeCast` calls `toUtc()` on both decode and encode. A local-time value round-trips as the same instant but returns as UTC. Epoch integers are milliseconds since epoch, in UTC (not seconds).

`Decimal` is arbitrary-precision, backed by its canonical string, so `0.10000000000000001` survives a round trip without float drift. Accepted grammar: `sign? digits ('.' digits)? exponent?`.

```dart
final price = Decimal.parse('19.99');   // throws FormatException on bad input
final maybe = Decimal.tryParse('oops'); // null
final whole = Decimal.fromInt(42);
Decimal.zero;                            // const zero
price.value;                             // '19.99', the canonical string
```

Decimal hazards:
- Equality is string-based: `Decimal.parse('1.10') != Decimal.parse('1.1')`. Canonicalization only strips a leading `+`.
- `compareTo` parses through `double`, so ordering can lose precision beyond roughly 15 to 17 significant digits.
- `Decimal.parse` throws `FormatException`, not `CastException`. Only `DecimalCast` wraps failures in `CastException`.

#### 5.1.4 EnumCast hazards

`EnumCast` needs the enum's `values` list (Dart cannot enumerate an enum from a type parameter alone).

```dart
const roleCast = EnumCast<Role>(Role.values);
roleCast.encode(Role.editor); // 'editor'
roleCast.decode('editor');    // Role.editor
roleCast.decode(0);           // Role.admin (index fallback)
```

Decode matches by `name` first, then falls back to the integer index. The index fallback means reordering enum members silently changes the meaning of stored integers. Store names, not indexes, when you control the column.

#### 5.1.5 CustomCast

Closure-based cast for one-off conversions (for example a `Duration` stored as whole seconds rather than the `DurationCast` default of milliseconds):

```dart
final secondsCast = CustomCast<Duration>(
  fromDb: (raw) => Duration(seconds: raw! as int),
  toDb: (duration) => duration.inSeconds,
  name: 'duration-seconds',
);
```

`null` short-circuits in both directions, so your closures only see non-null values. Encode throws `CastException` when the value is not a `T`. Register it in a `castManager` override. Because `CustomCast` takes constructor arguments, it cannot be used with `@CastAs`.

#### 5.1.6 EncryptedCast: bring your own crypto

`EncryptedCast` is an abstract skeleton. Worm ships NO cipher, NO key handling, and NO encryption-at-rest. The base class provides only: `null` passthrough both directions; an encode type check (`String` plaintext only, else `CastException`); and wrapping of any `FormatException` your `decryptString` throws into a `CastException`. The ciphertext format is entirely your subclass's contract.

```dart
final class MyEncryptedCast extends EncryptedCast {
  const MyEncryptedCast();

  @override
  Object encryptString(String plaintext) {
    // Call a maintained crypto library (AES-GCM, libsodium, a KMS).
    // Return ciphertext in the exact shape decryptString expects.
    throw UnimplementedError('bring your own cipher');
  }

  @override
  String decryptString(Object ciphertext) {
    // Reverse encryptString. Throw FormatException on malformed input;
    // the base class wraps it in a CastException.
    throw UnimplementedError('bring your own cipher');
  }
}
```

Encrypted columns cannot be filtered by plaintext; the database only ever sees ciphertext. Keep key material out of the source tree.

#### 5.1.7 @CastAs annotation (experimental, avoid)

`@CastAs(SomeCast)` exists in `package:worm/annotations.dart` but its wiring is experimental. The generator emits it into an opt-in `_$YourModelAnnotations` mixin that you must mix in manually, and it renders the cast as `const SomeCast()`, so the cast needs a const NO-ARGUMENT constructor. `EnumCast` and `CustomCast` take constructor arguments and do NOT qualify. Prefer the `castManager` override for all casts.

#### 5.1.8 CastManager and CastException API

```dart
CastManager([Map<String, AttributeCast>? casts]);
bool hasCast(String field);
Iterable<String> get registeredFields;
void register(String field, AttributeCast cast);
void unregister(String field);
Map<String, Object?> decodeAll(Map<String, Object?> row);
Map<String, Object?> encodeAll(Map<String, Object?> values);
Object? decodeOne(String field, Object? raw);
Object? encodeOne(String field, Object? value);
```

`AttributeCast` base contract: `abstract class`; `String get name`; `Object? decode(Object? raw)`; `Object? encode(Object? value)`; `castError({field, source, reason, targetType})`. `null` passes through; bad input throws `CastException`.

`CastException({field, fromType, toType, message, model})` is thrown by casts in both directions on unusable input.

#### 5.1.9 Cast gotchas

- Encode throws where decode succeeds. `BoolCast().encode('true')` throws though `decode('true')` returns `true`.
- `DateTimeCast` always returns UTC; epoch integers are milliseconds, not seconds.
- `Decimal.parse` throws `FormatException`, not `CastException`. `'1.10'` and `'1.1'` are not equal.
- `JsonMapCast` / `JsonListCast` accept an already-encoded JSON `String` on encode but validate it with `jsonDecode` first; invalid JSON throws a raw `FormatException` there, NOT a `CastException`.
- `JsonMapCast` throws `CastException` when a decoded map has a non-`String` key.
- `CastManager` treats unregistered fields as pass-through: a typo in the field key silently skips the cast.
- `@CastAs` takes effect only through the opt-in generated mixin and requires a const no-argument cast constructor.

### 5.2 Validation

Rules are attached to fields and run automatically inside every `save()`, before anything reaches the database.

#### 5.2.1 Declaring rules

Override the `rules` getter. Keys are typed `Field` references; values are lists of `ValidationRule`. The default `rules` is empty (empty rules skip validation entirely).

```dart
@override
Map<Field<Object?>, List<ValidationRule>> get rules => {
      User$.email: const [Required(), Email()],
      User$.name: const [Required(), MinLength(2)],
    };
```

`User$.email` is a generated companion constant. Hand-written models construct keys directly:

```dart
@override
Map<Field<Object?>, List<ValidationRule>> get rules => {
      const Field<Object?>('name'): const [Required(), MinLength(2)],
    };
```

The `rules` map literal itself CANNOT be `const`: `Field` overrides `==`, and Dart forbids such types as const map keys. Keep the getter body a plain map literal; the keys and rule lists themselves can be const.

#### 5.2.2 When rules run

Validation runs inside `save()`, between the `beforeValidate` and `afterValidate` lifecycle events:

- Insert path (model not yet persisted): every field in `rules` is validated.
- Update path (model exists): `updateRules` applies instead, and only for DIRTY fields. An unchanged column never blocks an unrelated edit, even if its current value would fail its rules.

Any failure throws `ValidationException` and cancels the write: nothing is inserted or updated, `afterValidate` and all later hooks are skipped, and the model's `exists` flag is unchanged. Two distinct signals: validation failure THROWS, while hook cancellation makes `save()` return `false`. `Worm.withoutEvents` mutes lifecycle hooks but never validation; there is no switch that skips rules on `save()`. Bulk query-builder writes (`update`/`delete` on a query) bypass validation entirely.

`updateRules` defaults to `rules`. Override it to run a different set on edits, for example a uniqueness check that excludes the current row:

```dart
@override
Map<Field<Object?>, List<ValidationRule>> get updateRules => {
      User$.email: [
        const Required(),
        const Email(),
        Unique(
          adapter: Worm.adapter(),
          table: 'users',
          column: 'email',
          exceptId: id,
        ),
      ],
    };
```

Because the update path only validates dirty fields, this `Unique` check runs only when the email actually changed.

#### 5.2.3 The 16 built-in rules

All are `const`, and every rule accepts an optional `message` parameter that replaces the default text. One doctrine: EVERY RULE EXCEPT `Required` TREATS `null` AS VALID. Chain `Required()` first to make a field mandatory.

| Rule | Constructor | Valid when | Notes |
| --- | --- | --- | --- |
| `Required` | `const Required({String message})` | Value is non-null and not an empty `String`, `Iterable`, or `Map` | The only rule that rejects `null` |
| `Email` | `const Email({String message})` | `String` matching a pragmatic, RFC 5321-inspired pattern | Non-strings fail |
| `Min` | `const Min(num bound, {String? message})` | `num` >= `bound` | Inclusive; non-numeric values fail |
| `Max` | `const Max(num bound, {String? message})` | `num` <= `bound` | Inclusive; non-numeric values fail |
| `MinLength` | `const MinLength(int length, {String? message})` | `String`/`Iterable` length >= `length` | Inclusive; asserts `length >= 0`; other types fail |
| `MaxLength` | `const MaxLength(int length, {String? message})` | `String`/`Iterable` length <= `length` | Inclusive; asserts `length >= 0`; other types fail |
| `In` | `const In(List<Object?> allowed, {String? message})` | Value contained in `allowed` | Whitelist membership |
| `NotIn` | `const NotIn(List<Object?> forbidden, {String? message})` | Value not contained in `forbidden` | Blacklist exclusion |
| `Regex` | `const Regex(RegExp pattern, {String? message})` | `String` matching `pattern` | Non-strings fail |
| `Url` | `const Url({String message})` | `String` parsing to an absolute URL with scheme and host | `mailto:`, opaque URIs, relative paths fail |
| `Uuid` | `const Uuid({String message})` | Canonical UUID string, versions 1 through 8, 8-4-4-4-12 hex | Non-strings fail |
| `DateRule` | `const DateRule({String message})` | A `DateTime`, or a `String` that `DateTime.tryParse` accepts | Rule id is `date` |
| `After` | `const After(DateTime bound, {String? message})` | Date strictly after `bound` | Strict: equal timestamps fail; ISO-8601 strings coerced |
| `Before` | `const Before(DateTime bound, {String? message})` | Date strictly before `bound` | Strict: equal timestamps fail; ISO-8601 strings coerced |
| `Confirmed` | `const Confirmed(Object? other, {String? message})` | Value equals `other` | Password-confirmation style equality |
| `Unique` | `const Unique({required DatabaseAdapter adapter, required String table, required String column, Object? exceptId, String primaryKey = 'id', String? message})` | No existing row has the same value in `table.column` | The only async built-in |

Bounds convention: `Min`, `Max`, `MinLength`, `MaxLength` are INCLUSIVE; `After`, `Before` are STRICT. Type mismatches fail rather than pass (a `String` under `Max`, or an `int` under `MinLength`, produces the rule's error message).

Stable `name` ids used in diagnostics: `required`, `email`, `min`, `max`, `minLength`, `maxLength`, `in`, `notIn`, `regex`, `url`, `uuid`, `date`, `after`, `before`, `confirmed`, `unique`.

#### 5.2.4 Unique (the only async rule)

`Unique` runs a `count` query for rows where `column` equals the value. When `exceptId` is set, the row whose `primaryKey` matches `exceptId` is excluded, so an update never collides with the row being updated.

```dart
final rule = Unique(
  adapter: Worm.adapter(),
  table: 'users',
  column: 'email',
  exceptId: user.id, // on updates: ignore this row
);
```

Default failure message: `The email has already been taken.` (with your column name substituted). It is a pre-check, not a lock: two concurrent saves can both pass before either row lands. Keep a unique index on the column as the database-level backstop and translate the driver error:

```dart
try {
  await user.save();
} on UniqueConstraintException catch (e) {
  throw ValidationException.fromUniqueConstraint(e);
}
```

#### 5.2.5 ValidationException.errors shape

`save()` throws `ValidationException` when any rule fails. The `errors` getter always yields an unmodifiable `Map<String, List<String>>` keyed by field name, ready for a JSON API. The engine runs EVERY rule for EVERY field with no short-circuiting, so `errors` is the complete picture, not just the first failure.

```dart
try {
  await user.save();
} on ValidationException catch (e) {
  print(e.errors);
  // {email: [Must be a valid email address.], name: [This field is required.]}
}
```

Constructors: `const ValidationException({field, rule, message, value, model})`; `ValidationException.fromMap(Map<String, List<String>> errors)`; `ValidationException.fromUniqueConstraint(violation)`. Single-field constructions expose the same `{field: [message]}` shape.

#### 5.2.6 Standalone Validator

The same engine works outside models. `Validator` takes rules keyed by plain field-name strings.

```dart
const validator = Validator({
  'email': [Required(), Email()],
  'name': [Required(), MinLength(2)],
});

final errors = await validator.validate({'name': '', 'email': 'nope'});
// {email: [Must be a valid email address.],
//  name: [This field is required., Must be at least 2 characters long.]}

await validator.validateOrThrow({'name': 'Ada', 'email': 'ada@example.com'});
// passes; throws ValidationException.fromMap on failure
```

`validateSync(values)` is the synchronous variant for rule sets you know contain no async rules; if any rule returns a `Future` (which `Unique` always does) it throws a `StateError` telling you to use `validate`.

For objects implementing the `Validatable` interface (`validationRules()`, `validationValues()`, `primaryKeyValue`, `tableName`), the top-level `validateModel(Validatable validatable)` helper composes a `Validator` and throws on failure.

Engine surface:

```dart
// ValidationRule: abstract; String get name; FutureOr<ValidationResult> validate(Object? value)
// ValidationResult: const ValidationResult.valid() / const ValidationResult.invalid(String message);
//                   getters isValid, isInvalid, message
const Validator(Map<String, List<ValidationRule>> rules);
//   validate(values), validateOrThrow(values), validateSync(values)
Future<void> validateModel(Validatable validatable);
```

#### 5.2.7 Validation gotchas

- Every rule except `Required` passes `null`. A lone `Email()` on a null field validates fine.
- `Min`/`Max`/`MinLength`/`MaxLength` inclusive; `After`/`Before` strict (equal timestamps fail).
- Type mismatches fail rather than pass.
- Update path validates dirty fields only; a stored value predating a new rule is not re-checked until that field changes.
- The `rules` map literal cannot be `const` because `Field` overrides `==`.
- `validateSync` throws `StateError` on any async rule; `Unique` is always async.
- Validation failure throws; hook cancellation returns `false` from `save()`.
- Bulk query-builder `update`/`delete` bypass validation.

### 5.3 Factories

Factories produce typed model instances on demand for tests and seeders.

#### 5.3.1 Defining a factory

Extend `Factory<T extends Model>` and override `definition()`, which returns one fresh blueprint per call. The `faker` getter gives deterministic fake data. `stateVariations` declares named transforms (defaults to empty).

```dart
final _ids = Sequence();

final class UserFactory extends Factory<User> {
  @override
  User definition() =>
      User(name: faker.firstName())..setAttribute('id', _ids.next());

  @override
  Map<String, FactoryState<User>> get stateVariations => {
        'admin': (user) => user..setAttribute('role', 'admin'),
      };
}
```

`FactoryState<T>` is `typedef FactoryState<T> = T Function(T base)`. `Sequence` is a monotonic counter that keeps generated ids unique across calls.

#### 5.3.2 Building vs creating

`make()` / `makeMany(n)` build in memory. `create()` builds, applies overrides, and persists through `Model.save()`, so validation and lifecycle hooks run exactly as for any save.

```dart
final draft  = UserFactory().make();          // built, not saved
final drafts = UserFactory().makeMany(3);     // three unsaved instances

final user = await UserFactory().create();    // built, saved, returned
final alice = await UserFactory().create(
  overrides: {'name': 'Alice'},               // overrides win over definition()
);
```

`create()` requires `Worm.initialize` to have run, or the underlying `save()` throws `ConfigurationException`. Overrides are applied with `fill()`, so mass-assignment rules apply: guarded or non-fillable keys are silently skipped, or throw `MassAssignmentException` in strict mode. `make()` NEVER applies overrides or persists; overrides exist only on `create()`.

Signatures:

```dart
abstract base class Factory<T extends Model> { const Factory(); }
T definition();                                    // only required override
Map<String, FactoryState<T>> get stateVariations;  // defaults to empty
T make();
List<T> makeMany(int count);
Future<T> create({Map<String, Object?> overrides = const {}});
FakerService get faker;
```

#### 5.3.3 States and inline transforms

Select a named variation with `state(name)`; it returns a DERIVED factory (state calls compose, the original factory stays untouched). An unknown name throws `FactoryException(factoryState:, message:)` naming the missing state. For an inline, unnamed variation use `withTransform`. Derived factories share the parent's `stateVariations`, so you can chain further `state()` calls.

```dart
final admin  = UserFactory().state('admin').make();
final admins = await UserFactory().state('admin').count(3).create();

final banned = UserFactory()
    .withTransform((user) => user..setAttribute('banned', true))
    .make();
```

```dart
Factory<T> state(String name);                       // throws FactoryException on unknown
Factory<T> withTransform(FactoryState<T> transform);
```

#### 5.3.4 Batches, sequences, and relation graphs

`count(n)`, `sequence(patterns)`, `has(...)`, `for_(...)` each return an internal PLAN object (type is private; interact only through the fluent chain). The plan chains the same four methods and finishes with `create({overrides})`, which returns `Future<List<T>>` (even for a single instance). Nothing touches the database until `create()`.

```dart
final five = await UserFactory().count(5).create();

// sequence cycles override patterns, one per instance, wrapping modulo count:
final users = await UserFactory()
    .sequence([{'name': 'a'}, {'name': 'b'}])
    .count(4)
    .create();
// names: a, b, a, b

// One user, plus three posts whose user_id points at it:
final withPosts = await UserFactory()
    .has(PostFactory().count(3), User$.posts)
    .create();

// Three posts for an existing parent, user_id pre-filled:
final posts = await PostFactory()
    .for_(author, User$.posts)
    .count(3)
    .create();
```

- `has(childFactory, relation)` persists the parent first, then runs the child factory once per parent with the parent's primary key bound to `relation.foreignKey`. The child can be a plain factory or a planned chain (`PostFactory().count(3)`). Multiple `has()` calls compose into independent child batches.
- `for_(parent, relation)` pre-fills `relation.foreignKey` with `parent.id` on every produced instance. Multiple `for_()` calls do NOT compose; the last one wins.

`has`/`for_` wire foreign keys through a typed `RelationField`, the same generated companions eager loading uses. Without code generation, declare it by hand:

```dart
const posts = RelationField<User, Post>('posts', foreignKey: 'user_id');
```

Signatures:

```dart
count(int n);
sequence(List<Map<String, Object?>> patterns);
has<R extends Model>(childFactory, RelationField<T, R> relation);
for_<P extends Model>(P parent, RelationField<P, T> relation);
// plan terminal:
Future<List<T>> create({Map<String, Object?> overrides = const {}});
```

#### 5.3.5 Override precedence

When a plan merges values for one instance, LATER sources win:

1. `for_` foreign-key binding (weakest)
2. the cycled `sequence` pattern
3. explicit `create(overrides: ...)` (strongest)

#### 5.3.6 Deterministic fake data and Sequence

`FakerService` is a singleton wrapper around `faker_dart`. Once seeded, the built-in helpers draw from small bundled datasets with an internal seeded `Random`, so the same seed produces the same sequence across runs and upstream upgrades (stable enough for snapshot tests).

```dart
Worm.seedRandom(42); // forwards to FakerService.instance.seed(42)

final faker = FakerService.instance;
faker.name();        // 'Alice Carter'
faker.firstName();   // 'Alice'
faker.lastName();    // 'Carter'
faker.email();       // 'alice.carter@example.org'
faker.phoneNumber(); // '(415) 555-0134' style
```

For the full `faker_dart` surface use `faker.raw`; values from `raw` are NOT covered by the determinism guarantee. `setLocale(FakerLocaleType)` forwards to `faker_dart` and affects non-seeded delegations only.

```dart
static final FakerService instance;
void seed(int value);
void setLocale(FakerLocaleType locale);
String name(); String firstName(); String lastName();
String email(); String phoneNumber();
Faker get raw;
static void Worm.seedRandom(int seed); // forwards to FakerService.instance.seed

// Sequence (typedef FactorySequence = Sequence):
Sequence({int start = 1});
int next();       // return current value and advance
void reset();     // return to starting value
int get peek;     // value the next next() will return
int get start;    // configured starting value
```

#### 5.3.7 Factory gotchas

- `create()` needs a running worm (`Worm.initialize`) or `save()` throws `ConfigurationException`.
- `make()` never applies overrides or persists.
- Overrides pass through `fill()`, so mass-assignment protection applies.
- `sequence` patterns cycle modulo pattern count.
- Multiple `has()` compose; multiple `for_()` do not (last wins).
- `state('nope')` throws `FactoryException`.
- `Factory.create()` returns `Future<T>`, but after `count`/`sequence`/`has`/`for_` the plan's `create()` returns `Future<List<T>>`.
- `has()` children are created once per parent instance.

### 5.4 Naming conventions

`NamingConvention` is a `final class` with a private constructor; all methods are static, you never instantiate it. It and `worm_generator` derive database names from Dart identifiers.

#### 5.4.1 Core static methods

```dart
static String toSnakeCase(String input); // camelCase/PascalCase -> snake_case, acronym-aware, idempotent
static String toCamelCase(String input); // snake_case -> camelCase, empty segments skipped
static String tableName(String input);   // PascalCase class -> plural snake_case table
static String pivotTableName(String a, String b); // singular snake of both, alphabetical, joined '_'
```

```dart
NamingConvention.toSnakeCase('userId');           // 'user_id'
NamingConvention.toSnakeCase('HTMLContent');      // 'html_content'
NamingConvention.toSnakeCase('parseHTMLContent'); // 'parse_html_content'
NamingConvention.toSnakeCase('URLParser');        // 'url_parser'
NamingConvention.toSnakeCase('URL');              // 'url'
NamingConvention.toCamelCase('created_at');       // 'createdAt'
NamingConvention.tableName('User');               // 'users'
NamingConvention.tableName('BlogPost');           // 'blog_posts'
NamingConvention.tableName('BlogCategory');       // 'blog_categories'
NamingConvention.pivotTableName('User', 'Role');  // 'role_user' (order-independent)
NamingConvention.pivotTableName('BlogPost', 'Tag'); // 'blog_post_tag'
```

`toSnakeCase` inserts a boundary before the last uppercase letter when a lowercase letter follows it; consecutive uppercase letters are kept together as an acronym. It recognizes only ASCII letters (`A-Z`, `a-z`) for case boundaries. This is what codegen uses to turn a `@Column` field name into its column name when you do not pass `@Column(name:)`.

`tableName` runs `toSnakeCase` then pluralizes the LAST snake segment only (`BlogCategory` -> `blog_categories`, never `blogs_categories`). `pivotTableName` NEVER pluralizes (`role_user`, not `roles_users`).

#### 5.4.2 Pluralizer rules

Applied in order:

| Rule | Example |
| --- | --- |
| Uncountable words stay unchanged | `Series` -> `series`, `Sheep` -> `sheep` |
| Irregular forms map directly | `Person` -> `people`, `Child` -> `children` |
| `-y` after a consonant -> `-ies` | `Category` -> `categories` |
| `-y` after a vowel adds `-s` | `Day` -> `days` |
| `-s`, `-x`, `-z`, `-ch`, `-sh` add `-es` | `Box` -> `boxes`, `Match` -> `matches` |
| `-f` or `-fe` -> `-ves` | `Wolf` -> `wolves`, `Knife` -> `knives` |
| Everything else adds `-s` | `User` -> `users` |

Complete irregulars (singular/plural): person/people, child/children, man/men, woman/women, tooth/teeth, foot/feet, mouse/mice, goose/geese, index/indices, matrix/matrices, vertex/vertices.

Complete uncountables set: data, equipment, information, series, species, fish, sheep, deer.

The pluralizer is English-only. Use `@Table(name:)` for anything it gets wrong.

#### 5.4.3 Derived column names

| Name | Default derivation | Example |
| --- | --- | --- |
| Table name | `NamingConvention.tableName(className)` unless `@Table(name:)` set | `User` -> `users` |
| Column name | `NamingConvention.toSnakeCase(fieldName)` unless `@Column(name:)` set | `createdAt` -> `created_at` |
| Foreign key (has-one / has-many) | `toSnakeCase(parentClassName) + '_id'` | `User` has many `Post`: `user_id` on `posts` |
| Pivot table (belongs-to-many) | `pivotTableName(a, b)` | `User` and `Role`: `role_user` |
| Pivot keys (belongs-to-many) | `toSnakeCase(className) + '_id'` per side | `user_id` and `role_id` on `role_user` |
| Morph columns | `<morphName>_type` and `<morphName>_id` | `commentable`: `commentable_type`, `commentable_id` |
| Morph name | `ModelRegistration.effectiveMorphName` = `morphName ?? tableName` | `User` defaults to `users` |

Runtime table-name resolution for a model instance follows a chain: the model's own `tableName` override wins, then `ModelRegistration.tableName` from the registry; if neither resolves, worm throws `ConfigurationException` with key `model.tableName.missing`.

#### 5.4.4 Escape hatches

Every derived name can be overridden where it is declared:

- `@Table(name:, connection:)` overrides table name and target connection.
- `@Column(name:)` overrides a single column name.
- `@HasOne` / `@HasMany` take `foreignKey:` and `localKey:`; `@BelongsTo` takes `foreignKey:` and `ownerKey:`.
- `@BelongsToMany` takes `pivotTable:`, `foreignPivotKey:`, `relatedPivotKey:`.
- `@MorphToMany` takes `morphName:` and `pivotTable:`.
- `ModelRegistration(tableName:, primaryKeyColumn:, morphName:)` sets the same facts for the runtime registry via `Worm.initialize`.

#### 5.4.5 CLI naming helpers

The `make:*` CLI commands use their own lightweight helpers (exported from `package:worm/worm.dart`) to render scaffolding templates. These DIVERGE from `NamingConvention` and are deliberately naive.

| Function | Signature | Behavior |
| --- | --- | --- |
| `pascalToSnake` | `String pascalToSnake(String input)` | `BlogPost` -> `blog_post`. Inserts `_` before EVERY uppercase letter; not acronym-aware |
| `tableNameFor` | `String tableNameFor(String className)` | `BlogPost` -> `blog_posts`. Naive: names ending in `s` pass through, `-y` always -> `-ies`, else add `-s` |
| `snakeToPascal` | `String snakeToPascal(String input)` | `blog_post` -> `BlogPost` |
| `migrationTimestamp` | `String migrationTimestamp(DateTime now)` | `YYYYMMDD_HHMMSS` migration filename prefix, always normalized to UTC |

#### 5.4.6 Naming gotchas

- CLI `tableNameFor` is naive: no irregulars/uncountables, every trailing `-y` -> `-ies` even after a vowel. `Person` scaffolds `persons`, while codegen resolves `people`. Check scaffolded names before you migrate.
- CLI `pascalToSnake` is not acronym-aware; `NamingConvention.toSnakeCase` is. `HTMLContent` -> `h_t_m_l_content` (CLI) vs `html_content` (NamingConvention).
- `pivotTableName` never pluralizes.
- Only the last snake segment of a class name is pluralized.
- `toSnakeCase` recognizes only ASCII letters for case boundaries.

---

## 6. Queries: builder, operators, terminals, pagination, scopes

The query builder accumulates an immutable `QueryDescriptor` via chainable methods; nothing touches the database until a terminal method runs. All symbols are exported from `package:worm/worm.dart`.

Every example below assumes the canonical model shape from the Models section. A model is queryable only if it declares the one-line `static query()` starter (it is NOT inherited from `Model`; codegen instead emits `extension UserQuery on User { static QueryBuilder<User> query() ... }`, and the static forwards it to `User.query()`). The typed field companion `User$` is emitted by codegen or hand-written as `const` fields:

```dart
@Table(name: 'users')
final class User extends Model {
  // ... constructors, id, tableName override, toRow (see Models) ...
  static QueryBuilder<User> query() => QueryBuilder<User>.from(
        QueryContext<User>(
          adapter: Worm.adapter(),
          table: User$.tableName,
          hydrate: User.fromRow,
        ),
      );
}

abstract final class User$ {
  static const String tableName = 'users';
  static const StringField name = StringField('name');
  static const ComparableField<int> age = ComparableField<int>('age');
}
```

`QueryContext<T>({required adapter, required table, required hydrate, primaryKey = 'id', globalScopes})` wires the adapter (from `Worm.adapter()`), table name, row hydrator, and registered global scopes. Build one by hand only when skipping codegen.

### 6.1 Entry, immutability

```dart
final users = await User.query().get();
```

Every chainable returns a FRESH `QueryBuilder<T>`; the receiver is untouched. You must use the return value:

```dart
final base = User.query().where(User$.age.gte(18));
final sorted = base.orderBy(User$.age, descending: true); // base unchanged

// BUG: result discarded, no WHERE applied
final q = User.query();
q.where(User$.age.gte(18));   // return value thrown away
await q.get();                // scans everything
```

### 6.2 where(), orWhere(): three shapes

`where()` AND-combines onto the existing WHERE tree; `orWhere()` OR-combines. Both accept the same three shapes:

```dart
// 1. Composed predicate tree (typed, recommended)
await User.query().where(User$.age.gte(18)).get();
// 2. (field, value): sugar for equality
await User.query().where(User$.name, 'Alice').first();
// 3. (field, Operator, value): explicit operator
await User.query().where(User$.age, Operator.gte, 65).get();

// orWhere, same three shapes
await User.query()
    .where(User$.name.eq('Alice'))
    .orWhere(User$.name.eq('Bob'))
    .get();
```

Fail-fast rules:
- Extra arguments after a predicate tree, or an unrecognized first argument: throws `ConfigurationException`.
- A non-`Operator` in the operator slot, or a non-`Field` in the field slot: throws `ArgumentError`.

### 6.3 Typed field classes

Codegen emits one `const` field companion per column, typed by capability. The field class gates which operators compile (invalid combinations are compile errors, not runtime errors). Hand-written `const` fields behave identically.

```dart
final class Field<T> {              // any column
  const Field(String name, {String? tableName});
  final String name;                // DB column name (snake_case), not Dart property
  final String? tableName;          // optional qualifier for joins/multi-table
}
final class ComparableField<T> extends Field<T> {   // numeric + DateTime columns
  const ComparableField(String name, {String? tableName});
}
final class StringField extends Field<String> {     // text columns; T fixed to String
  const StringField(String name, {String? tableName});
}
```

Codegen infers `ComparableField` for `int`, `double`, `num`, `DateTime`; `StringField` for `String`; plain `Field<T>` for everything else. Field equality/`hashCode` compare `name` + `tableName`.

| Field class | Operators unlocked |
| --- | --- |
| `Field<T>` | `eq`, `neq`, `isNull()`, `isNotNull()`, `inList`, `notInList`, `whereIn`, `whereNotIn` |
| `ComparableField<T>` | all `Field<T>` operators plus `gt`, `gte`, `lt`, `lte`, `between`, `notBetween` |
| `StringField` | all `Field<String>` operators plus `like`, `notLike`, `ilike`, `contains`, `startsWith`, `endsWith` |

```dart
User$.age.gte(18);        // OK: ComparableField<int>
User$.name.gte('Alice');  // compile error: gte undefined on StringField
User$.age.gte('18');      // compile error: String is not int
```

### 6.4 Operators (every method)

Each returns a `PredicateTree` (a `LeafNode`) ready for `where(...)` or boolean composition.

`extension FieldOperators<T> on Field<T>`:

| Method | Signature | Compiles to |
| --- | --- | --- |
| `eq` | `PredicateTree eq(T value)` | `Operator.eq` (`=`) |
| `neq` | `PredicateTree neq(T value)` | `Operator.neq` (`!=`) |
| `isNull` | `PredicateTree isNull()` | `Operator.isNull` (`IS NULL`) |
| `isNotNull` | `PredicateTree isNotNull()` | `Operator.isNotNull` (`IS NOT NULL`) |
| `inList` | `PredicateTree inList(List<T> values)` | `Operator.inList` (`IN (...)`) |
| `notInList` | `PredicateTree notInList(List<T> values)` | `Operator.notInList` (`NOT IN (...)`) |
| `whereIn` | `PredicateTree whereIn(List<T> values)` | alias; forwards to `inList` |
| `whereNotIn` | `PredicateTree whereNotIn(List<T> values)` | alias; forwards to `notInList` |

`extension ComparableFieldOperators<T> on ComparableField<T>`:

| Method | Signature | Compiles to |
| --- | --- | --- |
| `gt` | `PredicateTree gt(T value)` | `Operator.gt` (`>`) |
| `gte` | `PredicateTree gte(T value)` | `Operator.gte` (`>=`) |
| `lt` | `PredicateTree lt(T value)` | `Operator.lt` (`<`) |
| `lte` | `PredicateTree lte(T value)` | `Operator.lte` (`<=`) |
| `between` | `PredicateTree between(T lower, T upper)` | `Operator.between` (inclusive both bounds) |
| `notBetween` | `PredicateTree notBetween(T lower, T upper)` | `Operator.notBetween` |

`extension StringFieldOperators on StringField`:

| Method | Signature | Compiles to |
| --- | --- | --- |
| `like` | `PredicateTree like(String pattern)` | `Operator.like` (pattern verbatim) |
| `notLike` | `PredicateTree notLike(String pattern)` | `Operator.notLike` |
| `ilike` | `PredicateTree ilike(String pattern)` | `Operator.ilike` (case-insensitive) |
| `contains` | `PredicateTree contains(String substring)` | `Operator.like` with `'%substring%'` |
| `startsWith` | `PredicateTree startsWith(String prefix)` | `Operator.like` with `'prefix%'` |
| `endsWith` | `PredicateTree endsWith(String suffix)` | `Operator.like` with `'%suffix'` |

```dart
User$.name.inList(['Alice', 'Bob']);
User$.name.notInList(['Mallory']);
User$.age.between(18, 65);            // inclusive
User$.age.notBetween(0, 17);
User$.name.like('A%');
User$.name.ilike('a%');
User$.name.contains('li');           // LIKE '%li%'
User$.name.startsWith('Al');         // LIKE 'Al%'
User$.name.endsWith('ce');           // LIKE '%ce'
```

Notes:
- `whereIn`/`whereNotIn` are the only long-form extension aliases; byte-identical trees to `inList`/`notInList`.
- `isNull()`/`isNotNull()` take no arguments and carry a `null` operand.
- `contains`/`startsWith`/`endsWith` wrap input in `%`; literal `%` or `_` in the input are NOT escaped and keep LIKE-wildcard meaning. `like`/`notLike`/`ilike` pass the pattern verbatim. A hand-built `Predicate(..., escape: r'\')` makes `\%`, `\_` and `\\` literal in a `like`/`notLike`/`ilike` pattern on every adapter (`ESCAPE '\'` in SQL).

### 6.5 Operator enum

```dart
enum Operator {
  eq, neq, gt, gte, lt, lte,
  like, notLike, ilike,
  isNull, isNotNull,
  inList, notInList,
  between, notBetween;
}
```

`Operator.values.length` is 15. A `switch` over `Operator` needs only these 15 canonical cases. Six long-form aliases are `static const` references to the identical instance (NOT extra enum values):

| Alias | Canonical |
| --- | --- |
| `Operator.equals` | `Operator.eq` |
| `Operator.notEquals` | `Operator.neq` |
| `Operator.greaterThan` | `Operator.gt` |
| `Operator.greaterThanOrEqualTo` | `Operator.gte` |
| `Operator.lessThan` | `Operator.lt` |
| `Operator.lessThanOrEqualTo` | `Operator.lte` |

```dart
assert(identical(Operator.equals, Operator.eq)); // true
```

There is no `Operator.notIn` or similar; only the six comparison operators have aliases.

### 6.6 Shaping: orderBy, limit, offset, select, distinct

```dart
final rows = await User.query()
    .where(User$.age.gte(18))
    .orderBy(User$.age, descending: true) // ascending is the default
    .limit(10)
    .offset(20)
    .get();
```

- `orderBy(Field field, {bool descending = false})`: appends a sort clause; call repeatedly for multi-column sorts (applied in call order). Accepts any `Field`.
- `limit(int value)` / `offset(int value)`: set LIMIT / OFFSET.
- `distinct()`: return only distinct rows.
- `select(List<Field> fields)`: restrict projected columns; an empty list means `SELECT *`.

`select()` gotcha: it narrows the row map handed to your hydrator. Generated `fromRow` expects the full column set, so use `select()` only when the hydrator tolerates missing keys. For single-column reads use `pluck()` (projects internally, never hydrates).

### 6.7 Terminal methods (execute)

```dart
final all     = await User.query().get();                        // List<User>
final one     = await User.query().where(User$.name, 'Alice').first(); // User?
final must    = await User.query().firstOrFail();                // User, or throws
final byId    = await User.query().find(42);                     // User? by primary key
final mustId  = await User.query().findOrFail(42);               // User, or throws
final has     = await User.query().where(User$.age.gte(18)).exists(); // bool
final n       = await User.query().where(User$.age.gte(18)).count();  // int
final names   = await User.query().pluck(User$.name);            // List<String>
```

| Terminal | Signature | Behavior |
| --- | --- | --- |
| `get` | `Future<List<T>> get()` | hydrate all matching rows |
| `first` | `Future<T?> first()` | first row or `null` (adds LIMIT 1) |
| `firstOrFail` | `Future<T> firstOrFail()` | first row or throws `ModelNotFoundException` |
| `find` | `Future<T?> find(Object id)` | by primary key, or `null` |
| `findOrFail` | `Future<T> findOrFail(Object id)` | by primary key or throws `ModelNotFoundException` |
| `exists` | `Future<bool> exists()` | LIMIT 1 probe via adapter `selectOne`; short-circuits at first match (cheaper than count) |
| `count` | `Future<int> count()` | real COUNT over every match; returns `0` on empty |
| `pluck` | `Future<List<V>> pluck<V>(Field<V> field)` | single-column raw values, no hydration; rows whose value is null or not a `V` are silently dropped |

### 6.8 Scalar aggregates

Aggregates push down to the adapter; worm never fetches rows to compute them in Dart.

```dart
final total   = await User.query().count();            // int, 0 on empty
final ageSum  = await User.query().sum(User$.age);      // num?
final ageAvg  = await User.query().avg(User$.age);      // double?
final young   = await User.query().min<int>(User$.age); // int?
final old     = await User.query().max<int>(User$.age); // int?
```

| Terminal | Signature | Empty result |
| --- | --- | --- |
| `count` | `Future<int> count()` | `0` |
| `sum` | `Future<num?> sum(Field<num> field)` | `null` |
| `avg` | `Future<double?> avg(Field<num> field)` | `null` |
| `min` | `Future<V?> min<V>(Field<V> field)` | `null` |
| `max` | `Future<V?> max<V>(Field<V> field)` | `null` |

`min<V>`/`max<V>` narrow the adapter return to `V`; on an incompatible runtime type they throw `CastException` rather than coercing.

Strict-mode note: any query without a WHERE clause can throw `FullTableScanException` under strict mode (see the strict-mode part of the spec; `Worm.unsafe` is the escape hatch).

### 6.9 Predicate combinators and grouping

Field operators return `PredicateTree`; compose directly without a builder. Combinators return new immutable nodes:

```dart
sealed class PredicateTree {
  PredicateTree and(PredicateTree other);
  PredicateTree or(PredicateTree other);
  PredicateTree not();
  PredicateTree group();   // adds explicit parentheses
  Map<String, Object?> toMap();
}
```

```dart
final tree = User$.age.gte(18)
    .and(User$.name.startsWith('A'))
    .or(User$.age.isNull())
    .group();
await User.query().where(tree.not()).get();

// (name = 'Alice' OR name = 'Bob') AND age >= 18
final t2 = User$.name.eq('Alice').or(User$.name.eq('Bob')).group().and(User$.age.gte(18));
await User.query().where(t2).get();
```

`whereGroup((q) => ...)` is the fluent equivalent of `.group()`: it wraps a sub-builder's WHERE tree in parentheses and ANDs it onto the outer query. The inner builder runs with global scopes DISABLED (scope predicates cannot leak into your parentheses); the outer builder still applies them once at execution:

```dart
// WHERE (name = 'Alice' OR name = 'Bob') AND age >= 18
await User.query()
    .whereGroup((q) => q.where(User$.name.eq('Alice')).orWhere(User$.name.eq('Bob')))
    .where(User$.age.gte(18))
    .get();
```

Sealed tree subtypes (adapters pattern-match over the 8): `LeafNode(Predicate)`, `AndNode(left, right)`, `OrNode(left, right)`, `NotNode(child)`, `GroupNode(child)`, `ExistsNode(QueryDescriptor, {negated})`, `ColumnNode({leftField, rightField, operator, leftTable, rightTable})`, `RawNode(sql, {parameters})`. Chained `where(...)` calls AND their trees; you rarely build `AndNode` by hand. On MongoDB, NOT compiles to `$nor`.

`Predicate` is the immutable value object inside every `LeafNode`:

```dart
final class Predicate {
  const Predicate({required String fieldName, required Operator operator, String? tableName, Object? value});
  String get qualifiedName;   // 'age' or 'users.age' with tableName
  Map<String, Object?> toMap();
}
```

`value` shape varies by operator: a `(lower, upper)` record for `between`/`notBetween`, a `List` for `inList`/`notInList`, `null` for `isNull`/`isNotNull`, the right-hand scalar otherwise. `toMap()` omits the `value` key for null checks and encodes records as `{'lower': ..., 'upper': ...}`.

### 6.10 Subqueries and column comparisons

```dart
final postsByOne = Post.query().where(Post$.userId.eq(1));

await User.query().whereExists(postsByOne).get();     // EXISTS (...)
await User.query().whereNotExists(postsByOne).get();  // NOT EXISTS (...)
```

`whereExists<X>(QueryBuilder<X> sub)` / `whereNotExists<X>(...)` embed the subquery's descriptor as an `ExistsNode`; the subquery never executes on its own.

```dart
// WHERE users.updated_at > users.created_at
await User.query()
    .whereColumn(User$.updatedAt, User$.createdAt, operator: Operator.gt)
    .get();
```

`whereColumn(Field left, Field right, {Operator operator = Operator.eq})` compares two columns. The in-memory evaluator rejects column-to-column `like`, `inList`, `between`, and null-check operators with `UnsupportedOperationException`; stick to the six comparison operators for portability.

### 6.11 Bulk writes: update, delete, insertMany

Bulk operations translate to one adapter call. WARNING: bulk `update()`, `delete()`, and `insertMany()` skip lifecycle hooks and validation ENTIRELY. No `saving`/`deleting`/observer events fire and no validators run. Use `Model.save()` / `Model.delete()` when per-row events matter. Global scopes still constrain the WHERE clause of bulk `update()` and `delete()` (a soft-delete scope keeps trashed rows out unless you add `withTrashed()`).

```dart
final updated = await User.query()
    .where(User$.age.lt(18))
    .update({'is_active': false});     // Future<int> affected count

final deleted = await User.query().where(User$.age.gt(120)).delete(); // Future<int>

final users = await User.query().insertMany([   // Future<List<T>> hydrated
  {'id': 1, 'name': 'Alice', 'age': 30},
  {'id': 2, 'name': 'Bob', 'age': 25},
]);
```

- `update(Map<String, Object?> values)` / `delete()`: return affected count.
- `insertMany(List<Map<String, Object?>> rows)`: one INSERT for all rows, returns hydrated models. `insertMany([])` returns `[]` without touching the adapter.
- Under strict mode, `update()` / `delete()` without a WHERE clause throws `FullTableScanException`.

### 6.12 Streaming and chunking

For result sets too large for memory:

```dart
await for (final user in User.query().where(User$.age.gte(18)).stream()) {
  process(user);                                  // Stream<T>, one model at a time
}
await User.query().chunk(500, (batch) async {     // Future<void>, callback per batch
  await exportBatch(batch);
});
await for (final batch in User.query().streamChunks(500)) { // Stream<List<T>>
  await exportBatch(batch);
}
```

- `stream()` -> `Stream<T>`; `chunk(int size, callback)` -> `Future<void>`; `streamChunks(int size)` -> `Stream<List<T>>` (batches of at most `size`).
- `chunk()` and `streamChunks()` throw `ConfigurationException` when `size <= 0`.
- Streaming always bounds Dart-side hydration memory. Only the MongoDB adapter streams from a live DB cursor; SQLite/PostgreSQL/MySQL materialize the full result set in the driver first, then emit row by row (driver-side memory is not bounded).

### 6.13 Raw SQL: whereRaw

```dart
final evens = await User.query()
    .whereRaw('age % 2 = 0', allowRaw: true)
    .get();
```

`whereRaw(String sql, {List<Object?> parameters = const [], bool allowRaw = false})` emits a fragment verbatim as a `RawNode`. Omitting `allowRaw: true` throws `ConfigurationException` (the flag makes raw SQL visible at every call site). Never interpolate untrusted input; pass values via `parameters`. A query containing a `RawNode` throws `UnsupportedOperationException` at execution time on the Mongo and in-memory adapters (they cannot compile raw SQL).

### 6.14 Dialect gates: .sql() and .mongo()

The portable builder surface is backend-neutral. Backend-only constructs live behind gates that check `DatabaseAdapter.adapterType` and throw `AdapterMismatchException` (carrying `expectedAdapter` and `actualAdapter`) on the wrong family. The in-memory adapter rejects both gates.

```dart
R sql<R>(R Function(SqlQueryContext<T>) build);     // SQL-capable adapters only
R mongo<R>(R Function(MongoQueryContext<T>) build);  // Mongo adapters only
```

`.sql()` hands a `SqlQueryContext<T>` with SQL-only chainables: `join`, `leftJoin`, `groupBy`, `having`, and its own `whereRaw(sql, {parameters})` (no `allowRaw` flag; entering the gate states intent). `.builder` exits back to the portable builder:

```dart
final builder = User.query().sql((q) => q
    .join(
      'posts',
      const Field<Object?>('user_id', tableName: 'posts'),
      const Field<Object?>('id', tableName: 'users'),
    )
    .groupBy(const [Field<Object?>('id', tableName: 'users')])
    .having('COUNT(*)', Operator.gt, 5)
    .builder);
final prolific = await builder.get();
```

`having` takes a raw aggregate expression (`'COUNT(*)'`, `'SUM(views)'`); same injection caution as `whereRaw`. A `join` without `select([...])` compiles to `SELECT *`, flattening both tables and colliding same-named columns; pair joins with an explicit projection (or prefer eager loading, see Relations).

`.mongo()` hands a `MongoQueryContext<T>` whose fragments accumulate on the CONTEXT, not the builder:

```dart
final ctx = User.query().mongo((m) => m
    .withRawFilter({'meta.flag': true})
    .withPipeline([{r'$sort': {'age': -1}}]));
ctx.rawFilter; // {'meta.flag': true}
ctx.pipeline;  // [{'$sort': {'age': -1}}]
```

`withRawFilter` merges extra `find()` filters; `withPipeline` appends aggregation stages. Read them back via `rawFilter`/`pipeline` getters. Returning `.builder` from the callback discards them. On MongoDB, multi-document `transaction()` throws `TransactionException` by design.

On a non-matching adapter:

```dart
User.query().sql((q) => q.builder);
// throws AdapterMismatchException: .sql(...) requires a SQL-capable adapter
```

### 6.15 Inspecting: toSql, toMongoFilter

Both compile the current builder (INCLUDING global scopes) without executing:

```dart
User.query().where(User$.name, 'Alice').toSql();
// SELECT * FROM users WHERE name = 'Alice'
User.query().where(User$.name, 'Alice').toMongoFilter();
// {"name":"Alice"}
```

- `toSql()` -> `String`: inlines literal values for deterministic, snapshot-friendly output. NOT executable; adapters parameterize their real queries separately. Never feed `toSql()` output back into a database.
- `toMongoFilter()` -> `String`: compiles the WHERE tree to canonical Mongo filter JSON.
- `debug()` logs a one-line summary via `dart:developer` and returns `this` (never throws). `explain()` -> `Future<ExplainResult>` asks the adapter for a plan; throws `UnsupportedOperationException` unless the adapter mixes in `ExplainCapable`.

### 6.16 Pagination

Two strategies. Both also exist as top-level functions (`paginate<T>({context, descriptor, ...})`, `cursorPaginate<T>({context, descriptor, ...})`) for callers without a builder; the builder methods are thin wrappers with the same defaults.

#### Offset: paginate

`paginate({int page = 1, int perPage = 15})` runs two queries (one SELECT with LIMIT/OFFSET, one COUNT); both share the WHERE clause including global scopes.

```dart
final page = await User.query()
    .where(User$.age.gte(18))
    .orderBy(User$.name)
    .paginate(page: 2, perPage: 10);

page.data;         // List<User>, up to 10 rows
page.currentPage;  // 2
page.perPage;      // 10
page.total;        // total matching rows across all pages
page.lastPage;     // int get, total pages, always >= 1
page.hasMorePages; // bool get, currentPage < lastPage
page.from;         // int get, 1-based index of first row; 0 when empty
page.to;           // int get, 1-based index of last row; 0 when empty
```

`Page<T>({required data, required currentPage, required perPage, required total})`. Asking for a page past the end does not throw: `data` is empty, `from`/`to` are `0`, and `lastPage` is still `1` (so "page X of Y" never renders "page 1 of 0"). `paginate()` issues a COUNT on every call.

#### Cursor: cursorPaginate

```dart
Future<CursorPage<T>> cursorPaginate({
  int perPage = 15,
  Cursor? cursor,
  String? after,
})
```

Runs a single SELECT requesting `perPage + 1` rows, ordered ascending by the cursor field (primary key by default); the extra row is never returned and only signals another page exists.

```dart
final first = await User.query().cursorPaginate(perPage: 10);
first.data;          // List<User>, up to 10 rows
first.hasMorePages;  // bool get, nextCursor != null
first.nextCursor;    // Cursor?, null on last page
final token = first.nextToken; // String? get, opaque URL-safe, null on last page

final next = await User.query().cursorPaginate(perPage: 10, after: token);
```

Pass EITHER a decoded `Cursor` via `cursor:` OR the encoded token via `after:`; the two are equivalent. Passing BOTH throws `ArgumentError`.

`CursorPage<T>({required data, required perPage, required nextCursor})`. A `Cursor({required field, required value, required id})` is a `(field, value, id)` anchor from the last visible row (ordered column name, its value, the row's primary key as tiebreaker). `encode()` -> URL-safe base64 JSON; `static Cursor? decode(String? token)` reverses it and returns `null` (never throws) for null, empty, or malformed tokens (a garbled token restarts from the beginning). Tokens are base64 JSON, readable by anyone: opaque, not secret.

Each follow-up appends `WHERE <field> > <value>` to the existing WHERE clause. The advance is always `>` against ascending order: a custom `orderBy` is kept, but the walk still moves forward by `field > value`, so descending cursor walks are not supported. If the cursor field is `null` on the last visible row, no `nextCursor` is emitted and iteration stops early (cursor-paginate on non-nullable columns).

| | `paginate()` | `cursorPaginate()` |
| --- | --- | --- |
| Queries per page | 2 (SELECT + COUNT) | 1 (SELECT of `perPage + 1`) |
| Jump to page N | yes | no, forward-only |
| Total / "page X of Y" | yes | no |
| Stable under concurrent inserts | no | yes |
| Deep-page cost | grows with OFFSET | constant with an index on the cursor field |

### 6.17 Scopes

Reusable query transformers. Global scopes apply to every query automatically; local scopes apply on demand.

#### Global scopes

```dart
final class ActiveScope extends GlobalScope<Model> {
  const ActiveScope();
  @override
  String get name => 'active';
  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) =>
      builder.where(const Field<bool>('is_active').eq(true));
}
```

Global scopes live on `QueryContext.globalScopes` (`List<GlobalScope<Model>>`). With codegen, annotate the model with `@GlobalScope(ActiveScope)` and the generated `query()` registers it. Two properties:
- Applied at EXECUTION time (and inside `toSql()`), in registration order. The builder's own `descriptor.where` stays scope-free until then.
- They constrain writes too: bulk `update()`/`delete()` run their WHERE through the same scopes.

Bypass:

```dart
await User.query().withoutGlobalScope<ActiveScope>().get(); // drop one by type
await User.query().withoutGlobalScopes().get();             // drop all
```

`withoutGlobalScope<X extends GlobalScope>()` resolves `X` against registered scopes via an `is X` check and records the matched scope's `name`. GOTCHA: when no registered scope satisfies `is X` it returns the builder UNCHANGED. That silent no-op is the classic scope bug: a typo'd or unregistered type parameter disables nothing and throws nothing.

#### Local scopes

Opt-in predicate fragments; never auto-apply. Attach with `scope(LocalScope<T> scope)`:

```dart
final class PublishedScope extends LocalScope<Post> {
  const PublishedScope();
  @override
  QueryBuilder<Post> apply(QueryBuilder<Post> builder) =>
      builder.where(Post$.published.eq(true));
}
final posts = await Post.query().scope(const PublishedScope()).get();

// Ad-hoc closure fragment:
final adults = await User.query()
    .scope(CallableLocalScope((q) => q.where(User$.age.gte(18))))
    .get();
```

Typed scope methods (`Post.query().published()`) are HAND-WRITTEN extensions:

```dart
extension PostQueryScopes on QueryBuilder<Post> {
  QueryBuilder<Post> published() => scope(const PublishedScope());
}
```

There is NO string-based `applyScope(name)` on the builder. The `@Scope('published')` annotation on a model method currently records the name only, in the generated `scopeNames` metadata list; it does NOT emit a callable query method. Write the extension above by hand. `@GlobalScope(...)` registration, by contrast, is fully wired into the generated `query()`.

#### Soft deletes: a bundled global scope

There is no special soft-delete engine. The `SoftDeletes` mixin registers a bundled `SoftDeleteScope`, a plain `GlobalScope` filtering `deleted_at IS NULL`:

```dart
final live = await User.query().get();               // scope applied
final all  = await User.query().withTrashed().get();  // scope bypassed
final gone = await User.query().onlyTrashed().get();  // bypassed + deleted_at IS NOT NULL
```

`SoftDeleteScope<T>({String column = 'deleted_at'})`; its `name` is the `softDeleteScopeName` constant (`'soft_deletes'`). `withTrashed()` is literally `withoutGlobalScope<SoftDeleteScope<Model>>()`; `onlyTrashed({String column = 'deleted_at'})` is `withTrashed()` plus an `isNotNull()` predicate on the column. Because global scopes run through `find()`/`findOrFail()` too, a soft-deleted row is not findable without `withTrashed()`.

#### Scope API summary

| Symbol | Signature | Note |
| --- | --- | --- |
| `GlobalScope<T>` | `abstract; String get name; QueryBuilder<T> apply(builder)` | auto-applied at execution time |
| `LocalScope<T>` | `abstract; QueryBuilder<T> apply(builder)` | opt-in via `scope()` |
| `CallableLocalScope<T>` | `CallableLocalScope((q) => ...)` | closure-backed local scope |
| `SoftDeleteScope<T>` | `SoftDeleteScope({column: 'deleted_at'})` | bundled global scope, `deleted_at IS NULL` |
| `softDeleteScopeName` | `const String` | `'soft_deletes'` |
| `scope` | `scope(LocalScope<T> scope)` | apply a local scope |
| `withoutGlobalScope` | `withoutGlobalScope<X extends GlobalScope>()` | bypass one; silent no-op when unregistered |
| `withoutGlobalScopes` | `withoutGlobalScopes()` | bypass all |
| `withTrashed` | `withTrashed()` | include soft-deleted rows |
| `onlyTrashed` | `onlyTrashed({column: 'deleted_at'})` | only soft-deleted rows |

---

## 7. Relations

Relations are metadata plus a batched loader, not live collections. A relation records table names, key columns, and a hydrator; eager loading takes all parent rows at once, issues one IN-clause SELECT against the related table, and installs results into each parent's `relations` map. Two hard rules follow: there is NO lazy loading (reading an unloaded relation throws; see 7.6), and there is a fixed query budget per relation path (see 7.5). Model call sites below (`User.query()`, `Post.query()`) require the `static query()` and `String get tableName` override shown in Models; the relation annotations here sit on the same model class.

### 7.1 Choosing a shape (decision table)

| You need | Annotation | Class |
| --- | --- | --- |
| One child row holding a FK back to this model | `@HasOne(Type)` | `HasOneRelation` |
| Many child rows holding a FK back to this model | `@HasMany(Type)` | `HasManyRelation` |
| Inverse: this row holds the FK to its parent | `@BelongsTo(Type)` | `BelongsToRelation` |
| Many-to-many through a pivot table | `@BelongsToMany(Type)` | `BelongsToManyRelation` |
| One distant row through an intermediate table | `@HasOneThrough(Type, through: Type)` | `HasOneThroughRelation` |
| Many distant rows through an intermediate table | `@HasManyThrough(Type, through: Type)` | `HasManyThroughRelation` |
| One child that can belong to several parent types | `@MorphOne(Type)` | `MorphOneRelation` |
| Many children that can belong to several parent types | `@MorphMany(Type)` | `MorphManyRelation` |
| Inverse: child pointing at one of several parent types | `@MorphTo()` | `MorphToRelation` / `MorphToDefinition` |
| Many-to-many where the owning side is polymorphic | `@MorphToMany(Type)` | `MorphToManyRelation` |

### 7.2 Declaring relations

Annotations sit on model fields; `worm gen` reads them. Import `package:worm/annotations.dart` for the annotations and `package:worm/worm.dart` for the rest. The model file declares `part 'MODEL.g.dart';` (never `.worm.dart`).

```dart
import 'package:worm/annotations.dart';
import 'package:worm/worm.dart';

part 'user.g.dart';

@Table(name: 'users')
final class User extends Model {
  // Columns, constructor, toRow(), tableName override, and static query() elided.
  // See Models for the full runnable model shape.

  @HasMany(Post, onDelete: OnDelete.ormCascade)
  final List<Post> posts;

  @HasOne(Profile)
  final Profile? profile;

  @BelongsToMany(Role)
  final List<Role> roles;
}

@Table(name: 'posts')
final class Post extends Model {
  @BelongsTo(User)
  final User? user;
}
```

`worm gen` emits per model:
- Typed `RelationField` constants on the companion: `User$.posts`, `User$.profile`. Pass these to `withRelations` and friends.
- Runtime accessors ONLY for `@HasOne`, `@HasMany`, `@BelongsToMany` fields: `user.posts$`, `user.profile$`, `user.roles$` (see 7.8). Through and morph relations get no accessor; they are read via eager loading only.
- `OrmCascadeSpec` entries wired into `Model.ormCascadeSpecs` for any relation declaring `onDelete: OnDelete.ormCascade`.

#### Annotation parameters

| Annotation | Parameters (defaults shown) | Meaning |
| --- | --- | --- |
| `@HasOne(Type)` | `foreignKey`, `localKey`, `onDelete: OnDelete.restrict` | Parent owns one child |
| `@HasMany(Type)` | `foreignKey`, `localKey`, `onDelete: OnDelete.restrict` | Parent owns many children |
| `@BelongsTo(Type)` | `foreignKey`, `ownerKey` | Child points at its parent |
| `@BelongsToMany(Type)` | `pivotTable`, `foreignPivotKey`, `relatedPivotKey`, `onDelete: OnDelete.restrict` | Many-to-many via pivot |
| `@HasOneThrough(Type, through: Type)` | `firstKey`, `secondKey` | One distant row via intermediate |
| `@HasManyThrough(Type, through: Type)` | `firstKey`, `secondKey` | Many distant rows via intermediate |
| `@MorphOne(Type)` | `morphName` | One polymorphic child |
| `@MorphMany(Type)` | `morphName` | Many polymorphic children |
| `@MorphTo()` | `types: Map<String, Type>` | Inverse polymorphic pointer |
| `@MorphToMany(Type)` | `morphName`, `pivotTable` | Polymorphic many-to-many |

#### Naming defaults

Every key parameter is optional; omitted ones fill from convention.

| Convention | Default | Example |
| --- | --- | --- |
| Local, owner, parent, related, through keys | `'id'` | `users.id` |
| Foreign key column | snake_case parent class + `_id` | `User.posts` uses `posts.user_id` |
| Pivot table | singular snake_case of both class names, alphabetical, joined `_` | `User` + `Role` = `role_user` |
| Pivot key columns | snake_case class + `_id` | `user_id`, `role_id` |
| Morph columns | `<morphName>_type` and `<morphName>_id` | `commentable_type`, `commentable_id` |
| `onDelete` | `OnDelete.restrict` | |

The FK always lives on the child table for HasOne/HasMany/BelongsTo. Through relations hop an intermediate with two FKs: `firstKey` on the through table points at the parent, `secondKey` on the final table points at the through row. Example: `@HasManyThrough(Post, through: User)` on `Country` reaches every post written from that country via `users.country_id` (firstKey) and `posts.user_id` (secondKey).

### 7.3 Manual wiring (relation classes on QueryContext)

Every relation class is const-constructible; you can wire relations by hand into a `QueryContext.relations` map. The map key is the relation name that every `with*` call resolves against. An unknown name throws `ConfigurationException` (key `relation.unknown`) at query execution, not compile time.

```dart
final context = QueryContext<User>(
  adapter: Worm.adapter(),
  table: 'users',
  hydrate: UserHydration.fromRow,
  relations: {
    'posts': const HasManyRelation<Model, Model>(
      name: 'posts',
      childTable: 'posts',
      foreignKey: 'user_id',
      hydrateChild: PostHydration.fromRow,
    ),
  },
);

final users = await QueryBuilder<User>.from(context)
    .withRelationPaths(['posts'])
    .get();
```

#### Relation class constructors

| Class | Constructor sketch | Queries | Sets on parent |
| --- | --- | --- | --- |
| `HasOneRelation<Parent, Child>` | `(name:, childTable:, foreignKey:, hydrateChild:, localKey: 'id')` | 1 | `Child?` |
| `HasManyRelation<Parent, Child>` | `(name:, childTable:, foreignKey:, hydrateChild:, localKey: 'id')` | 1 | `List<Child>` |
| `BelongsToRelation<Child, Parent>` | `(name:, parentTable:, foreignKey:, hydrateParent:, ownerKey: 'id')` | 1 | `Parent?` |
| `BelongsToManyRelation<Parent, Related>` | `(name:, relatedTable:, pivotTable:, parentPivotKey:, relatedPivotKey:, hydrateRelated:, parentKey: 'id', relatedKey: 'id')` | 2 | `List<Related>` |
| `HasOneThroughRelation<Parent, Child>` | `(name:, throughTable:, childTable:, firstKey:, secondKey:, hydrateChild:, localKey: 'id', throughKey: 'id')` | 2 | `Child?` |
| `HasManyThroughRelation<Parent, Child>` | `(name:, throughTable:, childTable:, firstKey:, secondKey:, hydrateChild:, localKey: 'id', throughKey: 'id')` | 2 | `List<Child>` |
| `MorphOneRelation<Parent, Child>` | `(name:, childTable:, morphType:, parentMorphName:, hydrateChild:, localKey: 'id')` | 1 | `Child?` |
| `MorphManyRelation<Parent, Child>` | `(name:, childTable:, morphType:, parentMorphName:, hydrateChild:, localKey: 'id')` | 1 | `List<Child>` |
| `MorphToRelation<Child, Target>` | `(name:, morphTypeColumn:, morphIdColumn:, types: Map<String, MorphTypeMapping<Target>>)` | 1 per morph type | `Target?` |
| `MorphToManyRelation<Parent, Related>` | `(name:, relatedTable:, pivotTable:, parentMorphName:, morphType:, relatedPivotKey:, hydrateRelated:, parentKey: 'id', relatedKey: 'id')` | 2 | `List<Related>` |

Support types: `Relation<Parent, Child>` (abstract base; `load(adapter, parents)`, `loadWithFilter(..., {extraFilter})`); `RelationLoadResult<Parent>` (`setOnParent(parent)`, `stats`); `LoadStats` (`queriesExecuted`); `RelationField<Parent, Related>` (`(name, foreignKey:, localKey: 'id')`, `include(children)` builds a `RelationPath`); `RelationPath` (`(path)`); `RelationLoadSpec` (typedef of `RelationPath`); `OrmCascadeSpec` (`(childTable:, foreignKey:, hydrate:)`).

### 7.4 Delete behavior: OnDelete

Each `@HasOne`, `@HasMany`, `@BelongsToMany` carries an `onDelete` from the six-value `OnDelete` enum: `cascade, ormCascade, restrict, setNull, setDefault, noAction`.

| Value | Who acts | Effect on dependents | Child hooks fire |
| --- | --- | --- | --- |
| `cascade` | Database engine | Engine FK cascade removes them | No |
| `ormCascade` | Worm, at `model.delete()` time | Each child deleted through the ORM, one at a time | Yes (`beforeDelete`/`afterDelete`) |
| `restrict` (default) | Database engine | Delete fails while dependents exist | No |
| `setNull` | Database engine | FK set to `NULL` | No |
| `setDefault` | Database engine | FK set to its column default | No |
| `noAction` | Nobody | Engine default behavior | No |

`cascade` vs `ormCascade` differ only in who walks: `cascade` is a silent, fast engine FK cascade with no Dart code run. `ormCascade` walks every dependent row through the ORM so observers and lifecycle hooks run and nested cascades recurse; any child's `beforeDelete` returning `false` aborts the whole delete and the parent survives. In generated SQL an `ormCascade` FK renders as `ON DELETE NO ACTION`, because the ORM handles the cascade before the parent row is deleted. See 7.10 for the walk.

### 7.5 Eager loading API

Declare loads on the builder before the terminal (`get()` etc.). One query per relation path regardless of parent count.

```dart
// Typed companions (preferred, compile-checked):
final users = await User.query()
    .withRelations([User$.posts, User$.profile])
    .get();

// Raw string paths (same load, no compile check):
final same = await User.query()
    .withRelationPaths(['posts', 'profile'])
    .get();
```

Each name must be registered on the model's relation map (codegen does this). An unknown name throws `ConfigurationException` with key `relation.unknown` at execution.

#### Nested paths

Dot notation descends; each segment is one more query.

```dart
// users -> posts -> comments: three SELECTs total.
final a = await User.query()
    .withNested(User$.posts.include([Post$.comments]))
    .get();

// Identical load with a raw string path:
final b = await User.query()
    .withRelationPaths(['posts.comments'])
    .get();
```

`RelationField.include` builds a `RelationPath`. `withPath` and `withNested` are the same method under two names. The loader recurses with loaded children as the new parents.

#### Constrained loads

`withRelation` takes an optional `PredicateTree` AND-merged into the child SELECT.

```dart
final users = await User.query()
    .withRelation(User$.posts, Post$.published.eq(true))
    .get();
```

Omitting the constraint makes `withRelation(User$.posts)` an unconstrained load. Constraints are honored ONLY by HasOne, HasMany, BelongsToMany. BelongsTo, through, and every morph shape silently ignore the filter and load everything. Constraints do not cascade to a nested tail: `withRelation(User$.posts, ...)` filters posts only, never `posts.comments`.

#### Batching invariant (queries per relation path)

| Shape | Queries per load |
| --- | --- |
| HasOne, HasMany, BelongsTo, MorphOne, MorphMany | 1 |
| BelongsToMany, HasOneThrough, HasManyThrough, MorphToMany | 2 |
| MorphTo | 1 per distinct morph type observed |

An empty parent list short-circuits with zero queries. Missing rows are quiet: list-valued relations get `[]`, single-valued relations get `null`; dangling pivot or morph references are skipped. Per terminal, total queries = one parent query + per-path count from the table above + one query per aggregate. Multiple top-level loads/aggregates run concurrently via `Future.wait` outside a transaction; inside a transaction they run serially (one connection).

There is no `whereHas` and no filtering of parents by relation existence in the database. To filter in Dart, inject an existence flag:

```dart
final users = await User.query().withExists('posts').get();
final authors = users.where((u) => u.getInjected<bool>('postsExists')).toList();
```

#### QueryBuilder eager-load methods

| Symbol | Signature |
| --- | --- |
| `withRelationPaths` | `(List<String> paths)` |
| `withRelations` | `(List<RelationField> relations)` |
| `withRelation` | `(RelationField field, [PredicateTree? constraint])` |
| `withPath` | `(RelationPath path)` |
| `withNested` | `(RelationLoadSpec spec)` (alias of `withPath`) |
| `withCount` | `(String relation, {String? injectKey, PredicateTree? filter})` |
| `withSum` | `(String relation, String column, {String? injectKey})` |
| `withExists` | `(String relation, {String? injectKey})` |

Support: `EagerLoader.run({context, parents, loads, aggregates}) -> Future<int>`; `EagerLoad(path, {constrain})`; `AggregateInjection(relationName:, kind:, injectionKey:, ...)`; `AggregateKind { count, sum, exists }`.

### 7.6 Reading what you loaded (NO lazy loading)

Loaded values land in `Model.relations` (a `Map<String, Object?>`). Read via the typed accessor `getRelation<T>`.

```dart
final posts = user.getRelation<List<Post>>('posts');
final profile = user.getRelation<Profile>('profile');
```

| State | Result |
| --- | --- |
| Loaded, value matches `T` | The value |
| Loaded, value does not match `T` | `null`, silently |
| Not loaded | Throws `RelationNotLoadedException` |
| Not loaded, strict mode (`preventLazyLoading: true`) | Throws `LazyLoadingException` |
| Not loaded, inside `Worm.unsafe(() async { ... })` | `null` |

Reading a relation you never eager-loaded is the design point: worm never runs a query behind a property access. `getRelation<List<Post>>` and `getRelation<Post>` are not interchangeable; the wrong `T` on a loaded relation returns `null` silently. Raw `user.relations['posts']` returns `Object?` with none of these protections; prefer `getRelation`.

### 7.7 Relation aggregates

`withCount`, `withSum`, `withExists` push a rollup into the database as one `GROUP BY` query per aggregate and inject a virtual field per model, read via `getInjected<T>`.

```dart
final users = await User.query()
    .withCount('posts')
    .withSum('posts', 'views')
    .withExists('posts')
    .get();

final count = users.first.getInjected<int>('postsCount');
final views = users.first.getInjected<num>('postsSum');
final active = users.first.getInjected<bool>('postsExists');

// Filtered count and custom inject key:
final published = await User.query()
    .withCount('posts', filter: Post$.published.eq(true), injectKey: 'pubCount')
    .get();
```

Injection keys default to `<relation>Count`, `<relation>Sum`, `<relation>Exists`; override with `injectKey:`. `withCount` also takes a `filter:` predicate.

Rules:
- Aggregates support HasMany and HasOne ONLY. Any other shape (including all morph shapes) throws `UnsupportedOperationException` (operation `aggregate.<injectKey>`).
- Aggregate methods take the relation name as a `String`, not a `RelationField`. Use `User$.posts.name` to stay typed.
- Parents with no matching children get `0` from `withCount`, `0` (not `null`) from `withSum`, `false` from `withExists`.
- `withSum` injects `num`; read with `getInjected<num>`. `getInjected<int>` can throw depending on the adapter's return type.
- `getInjected<T>` throws `UninitializedFieldException` when the key was never populated AND when the stored value does not match `T`. It never returns a silent `null`.

Model accessors: `Model.relations` (`Map<String, Object?>`); `Model.getRelation<T>(String name) -> T?`; `Model.injectedFields` (`Map<String, Object?>`); `Model.getInjected<T>(String name) -> T`.

### 7.8 Runtime accessors (generated write side)

For every `@HasMany`, `@HasOne`, `@BelongsToMany` field, `worm gen` emits a getter named `<field>$`:

```dart
final HasManyAccessor<User, Post> posts = user.posts$;
final HasOneAccessor<User, Profile> profile = user.profile$;
final BelongsToManyAccessor<User, Role> roles = user.roles$;
```

Accessor classes are public API; construct by hand around any relation instance if needed:

```dart
final accessor = HasManyAccessor<User, Post>(
  parent: user,
  relation: const HasManyRelation<User, Post>(
    name: 'posts',
    childTable: 'posts',
    foreignKey: 'user_id',
    hydrateChild: PostHydration.fromRow,
  ),
);
```

#### HasManyAccessor<Parent, Child> (operates on the child FK)

```dart
await user.posts$.add(post);          // set post.user_id, save post, drop cache
await user.posts$.addAll([a, b, c]);  // add each, one save per child
final posts = await user.posts$.get(); // reload from DB, refresh cache (alias: list())
await user.posts$.dissociate(post);   // null post.user_id, re-save; row stays
```

| Method | Signature | Effect |
| --- | --- | --- |
| constructor | `({parent:, relation:, resolveAdapter?})` | Wraps a `HasManyRelation` |
| `add` | `(Child child) -> Future<void>` | Set FK, save child via `Model.save()`, drop cache |
| `addAll` | `(Iterable<Child>) -> Future<void>` | `add` for each, one cache drop |
| `get` | `() -> Future<List<Child>>` | Reload from DB, refresh cache |
| `list` | `() -> Future<List<Child>>` | Alias of `get` |
| `dissociate` | `(Child child) -> Future<void>` | Null FK, keep row |

`add`/`addAll` persist each child through `Model.save()`, so validation and lifecycle hooks run per row.

#### HasOneAccessor<Parent, Child>

```dart
await user.profile$.associate(profile); // set profile.user_id, save (alias: set)
final current = await user.profile$.get(); // Profile? from DB
await user.profile$.clear();            // load current child, null its FK via its save hooks
```

| Method | Signature | Effect |
| --- | --- | --- |
| constructor | `({parent:, relation:, resolveAdapter?})` | Wraps a `HasOneRelation` |
| `associate` | `(Child child) -> Future<void>` | Set FK, save child |
| `set` | `(Child child) -> Future<void>` | Alias of `associate` |
| `get` | `() -> Future<Child?>` | Reload from DB, refresh cache |
| `clear` | `() -> Future<void>` | Null FK on current child (via its `beforeSave`/`afterSave`); no-op when none associated |

#### BelongsToManyAccessor<Parent, Related> (manipulates the pivot table)

```dart
await user.roles$.attach(adminRoleId);
await user.roles$.attach(editorRoleId, pivotData: {'assigned_at': '2026-07-02'});
await user.roles$.attachAll([1, 2, 4]);

final removed = await user.roles$.detach(4);      // -> int rows removed
final removedAll = await user.roles$.detachAll([1, 2]);

final result = await user.roles$.sync([2, 3]);    // -> PivotSyncResult
print(result.attached); // [3]
print(result.detached); // [1]
```

| Method | Signature | Effect |
| --- | --- | --- |
| constructor | `({parent:, relation:})` | Wraps a `BelongsToManyRelation` |
| `attach` | `(Object relatedId, {Map pivotData}) -> Future<void>` | Plain INSERT pivot row, NO dedup |
| `attachAll` | `(Iterable<Object> ids) -> Future<void>` | `attach` per id, NO `pivotData` param |
| `detach` | `(Object relatedId) -> Future<int>` | Delete pivot rows, return count |
| `detachAll` | `(Iterable<Object> ids) -> Future<int>` | `detach` per id, summed count |
| `sync` | `(List<Object> ids) -> Future<PivotSyncResult>` | Diff to exactly these ids |

`attach` never deduplicates: two `attach(3)` calls create two pivot rows. Use `sync` for idempotent attachment. `sync` reads current pivot rows once, then issues one DELETE per detached id and one INSERT per attached id (correct but not batched: one query per change). `attachAll` cannot write `pivotData`; loop over `attach` when each row needs pivot columns. `PivotSyncResult` exposes `attached: List<Object>` and `detached: List<Object>`.

`HasManyAccessor` and `HasOneAccessor` accept an optional `resolveAdapter` callback; `BelongsToManyAccessor` always resolves through `Worm.adapter(parent.connectionName)`.

#### Cache invalidation

Every accessor mutation (`add`, `addAll`, `associate`, `dissociate`, `clear`, `attach`, `attachAll`, `detach`, `detachAll`, `sync`) removes the cached entry from `parent.relations`. After a mutation, `getRelation` throws `RelationNotLoadedException` until you reload via `accessor.get()` or a fresh eager-loaded query. `dissociate`/`clear` null the FK but never delete the child row.

### 7.9 Manual pivot wiring: PivotManager

`PivotManager` is the primitive underneath `BelongsToManyAccessor`. Use it when no accessor is at hand. It does NOT touch the relation cache (that layer belongs to the accessor).

```dart
final manager = PivotManager(
  adapter: Worm.adapter(),
  pivotTable: 'role_user',
  parentPivotKey: 'user_id',
  relatedPivotKey: 'role_id',
  parentId: user.id,
);

await manager.attach(3, pivotData: {'assigned_at': '2026-07-02'});
final removed = await manager.detach(3);       // -> int
final result = await manager.sync([1, 2]);     // -> PivotSyncResult
```

| Symbol | Signature |
| --- | --- |
| `PivotManager` | `({adapter:, pivotTable:, parentPivotKey:, relatedPivotKey:, parentId:})` |
| `PivotManager.attach` | `(Object relatedId, {Map pivotData})` INSERT pivot row |
| `PivotManager.detach` | `(Object relatedId) -> Future<int>` DELETE matching rows |
| `PivotManager.sync` | `(List<Object> ids) -> Future<PivotSyncResult>` set-diff attach/detach |

### 7.10 Cascade deletes through the ORM

`onDelete: OnDelete.ormCascade` wires an `OrmCascadeSpec` into `Model.ormCascadeSpecs`. `parent.delete()` walks the specs before deleting the parent row:

1. Run `beforeDelete` on the parent; if it returns `false`, abort (nothing deleted).
2. Walk `ormCascadeSpecs`: SELECT children by `foreignKey`, then call `child.delete()` per row so every child's `beforeDelete`/`afterDelete` hooks fire, observers run, and nested cascades recurse.
3. If any child's `beforeDelete` returns `false`, the whole delete aborts and the parent survives.
4. Otherwise DELETE the parent row and run `afterDelete` on the parent.

Compare `OnDelete.cascade`: one DELETE, the engine removes dependents, no Dart code runs for any child.

Declare specs by hand on any model:

```dart
@override
List<OrmCascadeSpec> get ormCascadeSpecs => const [
  OrmCascadeSpec(
    childTable: 'posts',
    foreignKey: 'user_id',
    hydrate: PostHydration.fromRow,
  ),
];
```

`Model.ormCascadeSpecs` defaults to `const []`. Aborts are NOT rollbacks: a child's `beforeDelete` returning `false` aborts the walk, but children deleted earlier in that same walk stay deleted unless the operation runs inside a transaction. Bulk `QueryBuilder.delete()` skips hydration, hooks, and `ormCascadeSpecs` entirely; ONLY `model.delete()` cascades through the ORM.

### 7.11 Polymorphic relations

A polymorphic child replaces one FK with a column pair derived from the morph name: `<morphName>_type` stores a type string, `<morphName>_id` stores the parent id. One `comments` table can point at `posts` and `videos` at once. The type string (`'post'`, `'video'`) is data stored in every row, decoupled from Dart class names so renaming a class never corrupts stored associations. The `MorphRegistry` owns that mapping.

#### MorphOne / MorphMany (owning side, 1 query)

Load children whose morph columns match the parent's ids AND type string. `morphTypeColumn`/`morphIdColumn` are derived getters (here `imageable_type`/`imageable_id`). `MorphOne` sets a `Child?`; `MorphMany` sets a `List<Child>`. Declaratively `@MorphOne(Image)` / `@MorphMany(Image)` with optional `morphName:`.

```dart
const images = MorphManyRelation<Model, Model>(
  name: 'images',
  childTable: 'images',
  morphType: 'post',            // this parent's type string
  parentMorphName: 'imageable', // derives imageable_type / imageable_id
  hydrateChild: ImageHydration.fromRow,
);
```

#### MorphToMany (polymorphic many-to-many, 2 queries)

The pivot carries the morph pair plus a related key (tags on posts and videos through one `taggables` pivot). Loads in two queries (pivot rows filtered by ids and type string, then related rows by id), sets a `List<Related>`. Declaratively `@MorphToMany(Tag, morphName: 'taggable', pivotTable: 'taggables')`.

#### MorphTo without dynamic (inverse)

A child points at one of several parent types. Supply a sealed hierarchy with one case per parent type plus a `wrap` function per type, then pattern-match exhaustively (no `dynamic`, no default arm).

```dart
sealed class Commentable {
  const Commentable();
}
final class PostCommentable extends Commentable {
  const PostCommentable(this.post);
  final Post post;
}
final class VideoCommentable extends Commentable {
  const VideoCommentable(this.video);
  final Video video;
}
```

Two parallel surfaces exist. Prefer the definition flavor; it is the shape codegen targets.

`MorphToDefinition` is pure metadata with one `MorphBinding` per type string; `EagerLoader.loadMorphTo` batches (one SELECT per distinct type observed):

```dart
final commentable = MorphToDefinition<Comment, Commentable>(
  name: 'commentable',
  morphTypeColumn: 'commentable_type',
  morphIdColumn: 'commentable_id',
  hydrateMap: {
    'post': MorphBinding<Commentable>(
      table: 'posts',
      hydrate: PostHydration.fromRow,
      wrap: (model) {
        if (model case final Post post) return PostCommentable(post);
        throw StateError('Expected Post');
      },
    ),
    'video': MorphBinding<Commentable>(
      table: 'videos',
      hydrate: VideoHydration.fromRow,
      wrap: (model) {
        if (model case final Video video) return VideoCommentable(video);
        throw StateError('Expected Video');
      },
    ),
  },
);

final queries = await EagerLoader.loadMorphTo(
  adapter: Worm.adapter(),
  children: comments,
  definition: commentable,
);

for (final comment in comments) {
  final target = comment.getRelation<Commentable>('commentable');
  final label = switch (target) {
    PostCommentable(:final post) => 'on post ${post.id}',
    VideoCommentable(:final video) => 'on video ${video.id}',
    null => 'orphaned',
  };
  print(label);
}
```

Per-child load when you hold a single model: `final Commentable? target = await commentable.load(Worm.adapter(), comment);`. `load` returns `null` in four cases: type column null or absent, type string not in `hydrateMap`, id column null, or the referenced parent row does not exist.

`MorphToRelation` is the same idea packaged as a `Relation` so it sits in a `QueryContext.relations` map and loads through the standard `with*` pipeline. Its per-type entries are `MorphTypeMapping` objects, structurally identical to `MorphBinding` (`table`, `hydrate`, `wrap`, `ownerKey: 'id'`):

```dart
final relation = MorphToRelation<Model, Commentable>(
  name: 'commentable',
  morphTypeColumn: 'commentable_type',
  morphIdColumn: 'commentable_id',
  types: {
    'post': MorphTypeMapping<Commentable>(
      table: 'posts',
      hydrate: PostHydration.fromRow,
      wrap: (model) {
        if (model case final Post post) return PostCommentable(post);
        throw StateError('Expected Post');
      },
    ),
  },
);
```

Both flavors share the budget: one SELECT per distinct morph type observed across the loaded children (the documented exception to one-query-per-path).

#### Typed raw rows: MorphTarget

Below the model layer, the `toMorphTarget` extension gives raw rows the same sealed treatment. It reads canonical row keys `morphTypeKey` (`'_morphType'`) and `morphIdKey` (`'_morphId'`) and discriminates against an allowed-types map (same shape as `Worm.morphRegistry.tableMap`):

```dart
final target = row.toMorphTarget({'post': 'posts', 'video': 'videos'});
switch (target) {
  case GenericMorph(:final table, :final id):
    // Resolved: row points at `table`, primary key `id`.
  case UnresolvedMorph(:final rawType):
    // Missing type, unknown type, or missing id. rawType is the observed
    // string, or null when absent.
}
```

`toMorphTarget` never returns `null` and never throws; every failure collapses into `UnresolvedMorph`. Column names derive from the morph name (`commentable_type`/`commentable_id`), but `toMorphTarget` reads `_morphType`/`_morphId`; map your columns onto those keys first.

#### MorphRegistry

Multiple polymorphic relations sharing type strings register each participating model once in the process-wide registry at `Worm.morphRegistry`:

```dart
Worm.morphRegistry.register<Post>(
  const MorphRegistration<Post>(
    morphType: 'post',
    type: Post,
    table: 'posts',
    hydrate: PostHydration.fromRow, // optional
  ),
);

Worm.morphRegistry.typeFor('post');          // Post, or null when unknown
Worm.morphRegistry.morphTypeFor(Post);       // 'post', or null when unknown
Worm.morphRegistry.morphNameFor(Post);       // 'post', THROWS on unknown
Worm.morphRegistry.registrationFor('post');  // full binding, or null
Worm.morphRegistry.tableMap;                 // {'post': 'posts', ...}
```

Duplicate rules (loud, never silent shadowing):
- Registering an already-taken morph string throws `ConfigurationException` with key `morph.duplicate.type`.
- Registering an already-registered Dart type throws `ConfigurationException` with key `morph.duplicate.dart`.
- `morphNameFor` on an unknown type throws `ConfigurationException` with key `morph.unknown`; `morphTypeFor` and `typeFor` return `null` for unknowns instead.
- Accessing `Worm.morphRegistry` before `Worm.initialize` throws `ConfigurationException` with key `initialization`. `Worm.reset()` clears the registry.

Registry API: `register<M>(MorphRegistration<M>)`; `morphTypeFor(Type) -> String?`; `morphNameFor(Type) -> String`; `typeFor(String) -> Type?`; `registrationFor(String) -> MorphRegistration<Model>?`; `registrationForType(Type) -> MorphRegistration<Model>?`; `registrations -> List<MorphRegistration<Model>>` (registration order); `tableMap -> Map<String, String>`; `clear() -> void`. `MorphRegistration<M>(morphType:, type:, table:, hydrate?)`.

#### Polymorphic gotchas

- Unresolvable children get `null` under the relation name, not an exception; both MorphTo flavors set the key on every child, so `getRelation<Commentable>('commentable')` returns `null` for orphans.
- Unknown type strings are skipped quietly during batch loads; a typo in a `hydrateMap` key loads those children as `null`.
- `withRelation` constraints are ignored by every morph shape.
- Aggregates (`withCount`/`withSum`/`withExists`) do not support morph shapes and throw `UnsupportedOperationException`.
- MorphTo runs one query per distinct morph type observed; ten types in one result set means ten SELECTs.

Related definition-only descriptors (metadata, no load logic): `MorphOneDefinition`, `MorphManyDefinition`, `MorphToManyDefinition`; the sealed base `RelationDefinition` (`name`) enables exhaustive matching over morph shapes.

---

## 8. Transactions, events and observers, strict mode, and configuration

Runtime facts for grouping writes atomically, hooking the write pipeline, gating unsafe queries, and configuring the engine. All examples that call `User.query()` / `Post.query()` assume the model declares the one-line `static QueryBuilder<T> query()` starter shown in the Models section; without it, `User.query()` does not exist (codegen instead emits `UserQuery.query()`).

### 8.1 Transactions

Orientation: `Worm.transaction` runs a callback inside one database transaction. Returning from the callback commits; throwing rolls back and rethrows.

```dart
static Future<T> transaction<T>(
  Future<T> Function(TransactionContext txn) action, {
  String? connection, // defaults to WormConfig.defaultConnection
})
```

```dart
final result = await Worm.transaction((txn) async {
  await user.save();
  await post.save();
  return 'created'; // returning commits both writes
});

try {
  await Worm.transaction((txn) async {
    await user.save();
    throw StateError('boom'); // rolls back the save, then rethrows
  });
} on StateError {
  // user row was never committed
}
```

`TransactionContext` carries `adapter` (the transactional handle), `connectionName`, and the `savepoint` method.

#### Ambient enlistment (Zone-based)

`Worm.transaction` propagates its context through a Dart `Zone`, so it survives `await`s. Any `save()`, `delete()`, or `update()` inside the callback (including in helper functions it calls) enlists automatically because `Worm.adapter(connection)` returns the transactional handle while inside the matching transaction. `Worm.currentTransaction` returns the ambient `TransactionContext` or `null`.

```dart
Future<void> registerUser(User u) => u.save(); // no transaction parameter

await Worm.transaction((txn) async {
  await registerUser(user);          // still inside the transaction
  await user.save(transaction: txn); // equivalent explicit form
});
```

`save`, `delete`, and `update` accept an explicit `transaction:` parameter; both forms route to the same place. Enlistment matches by connection: a model whose `connectionName` differs from the transaction's connection saves outside the transaction and commits independently.

#### Nesting joins vs savepoint (capability-gated)

A nested `Worm.transaction` on the **same** connection joins the enclosing one. There is no second `BEGIN`; only the outermost commit or rollback counts. For a real inner rollback boundary use `txn.savepoint(body)`.

```dart
await Worm.transaction((txn) async {
  await a.save();
  try {
    await txn.savepoint(() async {
      await b.save();
      throw StateError('undo b only'); // ROLLBACK TO SAVEPOINT, then rethrows
    });
  } on StateError {
    // b rolled back; a still pending in the outer transaction
  }
}); // commits: a persists, b does not
```

- On success the savepoint is released and its work stays part of the transaction.
- On throw, only the savepoint's own work rolls back; the exception rethrows into the outer callback; catch it there for the outer transaction to survive and commit.
- `savepoint` throws `UnsupportedOperationException` when `adapter.capabilities.supportsSavepoints` is `false`, even where the outer transaction works (the two capability flags are independent).
- SQL drivers name savepoints `worm_sp_1`, `worm_sp_2`, and so on.
- A nested `Worm.transaction` on a **different** connection opens its own independent transaction; nothing coordinates the two (no two-phase commit).

#### afterCommit queue and discard

`model.afterCommit(void Function() callback)` defers side effects until the data is durable.

- Outside a transaction: the callback fires immediately after the save or delete completes.
- Inside a transaction: callbacks queue on the `TransactionContext` (not on the model) and drain in registration order only after the outermost transaction commits. Callbacks from every model saved in the transaction drain together after the single commit.
- On rollback: queued callbacks are discarded without firing.
- Callbacks registered inside a savepoint that rolls back are discarded too; the rest of the queue survives.

```dart
await Worm.transaction((txn) async {
  user.afterCommit(() => notifySignup(user));
  await user.save(); // notifySignup has not run yet
});
// committed: notifySignup runs now
```

#### Capability gating and adapter matrix

`Worm.transaction` checks `adapter.capabilities.supportsTransactions` before opening anything and throws `UnsupportedOperationException` when it is `false`. `TransactionContext.savepoint` checks `supportsSavepoints`.

| Adapter | Transactions | Savepoints | Notes |
| --- | --- | --- | --- |
| `InMemoryAdapter` | yes | yes | Snapshot/restore of the whole store; nested calls act as savepoints. |
| `SqliteAdapter` | yes | yes | `SAVEPOINT` statements; single connection, no overlapping queries inside a transaction. |
| `PostgresAdapter` | yes | yes | Native transactions; savepoints named `worm_sp_N`. |
| `MysqlAdapter` | yes | yes | Native transactions; savepoints named `worm_sp_N`. |
| `MongoAdapter` | no | no | See below. |

#### MongoDB: TransactionException by design

`MongoAdapter.capabilities` reports `supportsTransactions: false`, so `Worm.transaction` on a Mongo connection throws `UnsupportedOperationException` at the capability gate. Calling `MongoAdapter.transaction()` directly throws `TransactionException`. This is deliberate: the underlying `mongo_dart` driver exposes no client-session/transaction API, so atomic multi-document commit and rollback cannot be guaranteed. Working Mongo multi-document transactions are not available; perform Mongo writes individually or design them to be independently valid.

#### Test transactions

For test isolation, `Worm.beginTestTransaction()` opens a transaction on the default connection and holds it open across the test; `Worm.rollbackTestTransaction()` unwinds it, discarding every write and every queued `afterCommit` callback. While active, `Worm.adapter()` returns the transactional handle for the default connection, so code under test participates automatically.

```dart
setUp(Worm.beginTestTransaction);
tearDown(Worm.rollbackTestTransaction);
```

- A second `beginTestTransaction` without a rollback throws `ConfigurationException` (key `test_transaction.duplicate`).
- `Worm.reset()` rolls back any active test transaction automatically.
- Test transactions cover the default connection only; writes on named connections during a test persist unless cleaned up manually.

### 8.2 Multiple named adapters and Worm.adapter() resolution

Orientation: adapters are registered under connection names in `Worm.initialize`; models, queries, and transactions each target one connection.

```dart
await Worm.initialize(
  config: const WormConfig(), // defaultConnection defaults to 'default'
  adapters: <String, DatabaseAdapter>{
    'default': primary,     // one key MUST match config.defaultConnection
    'analytics': analytics, // or initialize throws ConfigurationException('adapter.missing')
  },
);
```

`initialize` connects every adapter (in map iteration order; a failing `connect()` propagates). `Worm.registeredConnections` lists registered names.

#### Worm.adapter([name]) resolution order

```dart
static DatabaseAdapter adapter([String? connection]) // defaults to config.defaultConnection
```

1. **Active test transaction.** While `beginTestTransaction()` is open, requests for the default connection return the test transaction's handle. Other connections are unaffected.
2. **Ambient transaction.** Inside a `Worm.transaction` whose `connectionName` matches the requested name, the transactional handle is returned (this is what makes saves auto-enlist).
3. **The registry.** Otherwise the adapter registered under that name. Unknown name throws `ConfigurationException('adapter.unknown')`; calling before `initialize` throws `ConfigurationException('initialization')`.

#### Routing a model to a connection

The write path reads the model's `connectionName` getter (default `'default'`). `save`, `delete`, and `refresh` resolve `Worm.adapter(model.connectionName)`.

```dart
final class AuditLog extends Model {
  @override
  String get connectionName => 'analytics';
  // id, tableName, toRow ...
}
```

With codegen, `@Table(name: 'audit_logs', connection: 'analytics')` makes the generator emit a `_$AuditLogAnnotations` mixin containing exactly that `connectionName` override. The mixin is opt-in: you must add `with _$AuditLogAnnotations` yourself, or the annotation has no runtime effect. `ModelRegistration(type: AuditLog, tableName: 'audit_logs', connection: 'analytics')` records the same fact in the registry, but the persistence path reads the getter, not the registration; keep them in sync.

Asymmetry: the generated static `query()` starter calls `Worm.adapter()` with no argument, so it always targets the default connection, even for a model annotated with another connection. To query a model on a non-default connection, build the builder with an explicit `QueryContext`:

```dart
final logs = await QueryBuilder<AuditLog>.from(
  QueryContext<AuditLog>(
    adapter: Worm.adapter('analytics'),
    table: 'audit_logs',
    hydrate: AuditLog.fromRow,
  ),
).get();
```

#### Transactions and pooling across connections

- Transactions are per connection: `Worm.transaction((txn) async {...}, connection: 'analytics')`.
- Cross-connection transactions are independent; a rollback on one never undoes commits on another.
- `ConnectionConfig` pool parameters: `poolSize` (default 10) connections per isolate, `connectionTimeout` (default 5 s) bounds acquisition, `idleTimeout` (default 300 s) retires idle connections.
- `maxTotalConnections` (default `null`, no cap) limits combined pool size across every connection in the current isolate. The Postgres pool enforces it with an isolate-wide reservation counter: later pools get their `poolSize` clamped to remaining headroom; when nothing remains, `PostgresConnectionPool.fromConfig` throws `ConfigurationException('maxTotalConnections')`.

### 8.3 Lifecycle events and observers

Orientation: every save, delete, and restore passes through a fixed sequence of lifecycle events. Hook them on the model (`ModelHooks`) or in registered observers (`ModelObserver<T>`).

#### The 13 events

The `LifecycleEvent` enum has exactly these 13 values. `bool isCancelable(LifecycleEvent event)` returns `true` for exactly the six `before*` events.

| Event | Fires | Cancelable |
| --- | --- | --- |
| `beforeValidate` | Before validation runs | Yes |
| `afterValidate` | After validation succeeds | No |
| `beforeSave` | Before any save, insert or update | Yes |
| `beforeCreate` | Immediately before an INSERT | Yes |
| `afterCreate` | Immediately after an INSERT | No |
| `beforeUpdate` | Immediately before an UPDATE | Yes |
| `afterUpdate` | Immediately after an UPDATE | No |
| `afterSave` | After any save, insert or update | No |
| `beforeDelete` | Immediately before a DELETE | Yes |
| `afterDelete` | Immediately after a DELETE | No |
| `afterHydrate` | After a model is hydrated from a row | No |
| `beforeRestore` | Before a soft-deleted model is restored | Yes |
| `afterRestore` | After a soft-deleted model is restored | No |

Cancelable (`before*`) hooks return `Future<bool>`; returning `false` aborts. Non-cancelable (`after*`) hooks return `Future<void>`.

Events per operation, in order:

| Operation | Events fired, in order |
| --- | --- |
| Insert | `beforeValidate`, `afterValidate`, `beforeSave`, `beforeCreate`, `afterCreate`, `afterSave` |
| Update | `beforeValidate`, `afterValidate`, `beforeSave`, `beforeUpdate`, `afterUpdate`, `afterSave` |
| Delete | `beforeDelete`, `afterDelete` (ORM-cascade children each run their own full delete sequence) |
| Restore (`SoftDeletes`) | `beforeRestore`, `afterRestore` |
| Refresh | `afterHydrate` |

Validation runs between `beforeValidate` and `afterValidate` (updates validate dirty fields only). Validation is not an event: it cannot be muted, and its failure throws `ValidationException` instead of returning `false`. `afterCommit` callbacks settle at the end of the insert/update/delete sequence.

#### Model hooks vs observers

`Model` mixes in `ModelHooks`, giving no-op defaults for all 13 hooks. Override only what you need; hooks take no arguments (you are inside the instance):

```dart
final class Post extends Model {
  // constructor, id, tableName, toRow ...

  @override
  Future<bool> beforeCreate() async {
    if (getAttribute('published_at') == null) {
      setAttribute('published_at', DateTime.now().toUtc().toIso8601String());
    }
    return true; // false cancels the INSERT
  }

  @override
  Future<void> afterSave() async { /* invalidate a cache entry */ }
}
```

An observer moves the same hooks out of the model. Extend `ModelObserver<T>`; each hook receives the model instance:

```dart
final class UserObserver extends ModelObserver<User> {
  const UserObserver();

  @override
  Future<bool> beforeDelete(User model) async =>
      model.getAttribute('role') != 'admin'; // admins not deletable

  @override
  Future<void> afterCreate(User model) async { /* send welcome email */ }
}
```

Observers register once, at startup, and only through `initialize`; there is no runtime add/remove API (use `Worm.reset()` plus a fresh `initialize` in tests):

```dart
await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': adapter},
  observers: const [UserObserver()],
);
```

Observer lookup is keyed by the **exact runtime type** of the model: `Worm.observersFor(model.runtimeType)` matches the observer's `T` exactly, so an observer declared on a base class never fires for subclasses. Register one observer per concrete model type.

#### Dispatch order (model hook, then observers)

For each event, the model's own hook runs first, then every observer in registration order. Interleaving is per event, not per phase. An insert with one observer traces: `beforeValidate` (model), `beforeValidate` (observer), `afterValidate` (model), `afterValidate` (observer), `beforeSave` (model/observer), `beforeCreate` (model/observer), INSERT, `afterCreate` (model/observer), `afterSave` (model/observer).

#### Cancellation returns false (no exception thrown)

Any `before*` hook that returns `false` cancels: remaining handlers for that event are skipped, the database call never happens, all later hooks for the operation are skipped, and `save()` / `delete()` returns `false`. No exception is thrown.

```dart
final saved = await user.save();
if (!saved) {
  // a beforeValidate / beforeSave / beforeCreate hook returned false
}
```

`OperationCancelledException` exists in the exception catalog but the runtime does **not** currently throw it. Check the bool return; do not write a `catch` for it. During an ORM-cascade delete, a child's `beforeDelete` returning `false` aborts the whole cascade, parent included. An `after*` hook that throws propagates the exception (skipping the remaining handlers for that event) but the row stays written.

#### Worm.withoutEvents (never mutes validation)

```dart
static Future<T> withoutEvents<T>(
  Future<T> Function() body, {
  List<LifecycleEvent>? events, // null = mute all; a list mutes only those, unioned with enclosing mutes
})
```

```dart
await Worm.withoutEvents(() async => user.save());            // no hooks, no observers
await Worm.withoutEvents(() async => user.save(),
    events: [LifecycleEvent.afterCreate]);                    // mute only this event
```

- Zone-based: survives `await`s inside `body`, resets on return/throw.
- Nested selective calls **union** their event lists; nesting inside a mute-all region stays mute-all.
- A muted `before*` hook cannot cancel: the operation proceeds as if the hook returned `true`.
- Muting suppresses model hooks and observers only. Muting **never** disables validation; rules run on every `save()`, muted or not.
- Inspect the current region: `Worm.mutedEvents` (`Set<LifecycleEvent>?`), `Worm.isMutingAll` (`bool`), `Worm.isEventMuted(event)` (`bool`). `mutedEvents` returns `null` both when nothing is muted and when everything is muted; use `isMutingAll` to distinguish.
- A `Seeder` may override `bool get muteEvents => true` to run its whole `run` inside `withoutEvents`.

Bulk query-builder `update` / `delete` bypass hooks and observers entirely. `SoftDeletes` bypasses hooks on its `save`, `delete`, and `forceDelete`; only `restore()` fires events (`beforeRestore` / `afterRestore`). `afterHydrate` currently fires from `refresh()`.

#### Custom handlers and dispatcher

| Symbol | Signature / shape | Purpose |
| --- | --- | --- |
| `LifecycleHandler` | `abstract interface`; `dispatchBefore(event, model)`, `dispatchAfter(event, model)` | Type-erased handler for cross-cutting pipelines (metrics, audit). Return `true` from `dispatchBefore` for models it ignores. |
| `Observer<T>` | `abstract class Observer<T>`; `Type get modelType` | Marker base that `initialize(observers:)` accepts. |
| `ModelObserver<T>` | `abstract class ModelObserver<T extends Model> extends Observer<T> implements LifecycleHandler`; 13 typed hooks receiving `T model` | Canonical external observer for one model type. |
| `EventDispatcher` | `const EventDispatcher(List<LifecycleHandler> handlers)`; `dispatchBefore`, `dispatchAfter` | Fans one event to the model hook, then handlers in order. |
| `ActiveRecord.dispatcherFor` | `static EventDispatcher dispatcherFor(Model model)` | Builds the dispatcher from registered observers. |
| `Model.afterCommit` | `void afterCommit(void Function() callback)` | Queue work for after the surrounding operation commits. |

`dispatchBefore` with an `after*` event, or `dispatchAfter` with a `before*` event, throws `ArgumentError`.

### 8.4 Strict mode

Orientation: independent guardrails on `StrictnessConfig`, all defaulting to `false`, enabled per flag on the config passed to `initialize`. Flags are orthogonal; flipping one never flips another.

```dart
await Worm.initialize(
  config: const WormConfig(
    strictness: StrictnessConfig(
      preventLazyLoading: true,
      preventFullTableScans: true,
      preventSilentMassAssignment: true,
      preventDestructiveWithoutWhere: true,
    ),
  ),
  adapters: {'default': adapter},
);
```

#### Flag to exact exception

| Flag | Enforced by | Effect |
| --- | --- | --- |
| `preventLazyLoading` | `Model.getRelation` | Accessing an unloaded relation throws `LazyLoadingException` instead of the default `RelationNotLoadedException`. |
| `preventFullTableScans` | `QueryBuilder` | WHERE-less query (read or destructive write) throws `FullTableScanException`. Umbrella flag: also gates WHERE-less `update()`/`delete()` even when `preventDestructiveWithoutWhere` is off. |
| `preventDestructiveWithoutWhere` | `QueryBuilder` | WHERE-less bulk `update()`/`delete()` throws `FullTableScanException`. Reads stay unrestricted. |
| `preventSilentMassAssignment` | `Model.fill` | `fill()` (and `update()`, which fills first) throws `MassAssignmentException` when the data map has guarded or non-fillable keys; every offending key is collected in `.fields`. Without the flag those keys are silently skipped. |
| `warnOnN1Queries` | `LoggingAdapter` | Logs a `[WARNING]` line when the detector sees 5+ single-row lookups against the same table within 100 ms. Warning only. |
| `throwOnN1Queries` | `LoggingAdapter` | Escalates the same detection to a thrown `DangerousQueryException` (carrying the offending table name); no warning line is emitted first. |
| `warnOnMissingIndex` | `LoggingAdapter` | Logs a structured `missing-index` warning when a filtered query's EXPLAIN plan shows no index use. Only for adapters that declare `supportsExplain` and mix in `ExplainCapable`; otherwise a silent no-op. Warning only. |
| `slowQueryThreshold` | `LoggingAdapter` | `Duration`, default 500 ms. Queries at or above it trigger the `QueryLogger.slowQuery` callback. |

`DangerousQueryException` is a `typedef` of `FullTableScanException`; a `catch` on either name catches both. Either N+1 flag alone arms the detector. The four `LoggingAdapter`-enforced knobs (`warnOnN1Queries`, `throwOnN1Queries`, `warnOnMissingIndex`, `slowQueryThreshold`) do nothing unless the adapter is wrapped in a `LoggingAdapter`, and that wrapper's own `strictness` argument is what those checks read.

Two independent slow-query thresholds, both active: `StrictnessConfig.slowQueryThreshold` (500 ms, drives the callback) and `LogConfig.slowQueryThreshold` (200 ms, drives whether a log line gets the `[SLOW QUERY]` prefix instead of `[QUERY]`).

#### Worm.unsafe zone

```dart
static Future<T> unsafe<T>(Future<T> Function() body)
```

```dart
final removed = await Worm.unsafe(() async {
  return Post.query().delete(); // deliberate full-table delete; strict mode would block this
});
```

Runs `body` with global query/model gates disabled; the flag propagates via a Dart `Zone`, surviving `await`s and restoring on return/throw. Check state with `Worm.isUnsafe`.

Relaxes: `preventFullTableScans`, `preventDestructiveWithoutWhere` (`QueryBuilder` checks `Worm.isUnsafe` before throwing), unloaded-relation access (`getRelation` returns `null` instead of throwing), and the global `preventSilentMassAssignment` policy (`fill()` falls back to silent skipping).

Does **not** relax: a model's own `strictMassAssignment` override (per-model opt-in throws even inside `unsafe`), validation, and the `LoggingAdapter` checks (N+1 warnings/throws, missing-index warnings, slow-query callbacks fire regardless). A bulk job that trips the N+1 throw fails even inside `unsafe`; turn `throwOnN1Queries` off for that workload. Nested `unsafe` is idempotent (a no-op).

#### Per-builder vs global

Global level is `WormConfig.strictness`, read through `Worm.strictness` (safe before `initialize`; falls back to all-off defaults). Local level is the `StrictnessConfig` a builder carries: `QueryBuilder.from(context, strictness: ...)`. The effective gate is an OR: a check runs when either the builder's local config or the live global config enables it, merged at execution time. Generated `query()` starters pass no local config, so the global config governs in practice; the local parameter matters for hand-built builders and tests.

### 8.5 Configuration types

All types are exported from `package:worm/worm.dart`, are `const`-constructible, and provide `copyWith`.

#### WormConfig

```dart
const WormConfig({
  String defaultConnection = 'default',
  Map<String, ConnectionConfig> connections = const {},
  int poolSize = 10,
  PrimaryKeyType primaryKeyType = PrimaryKeyType.uuid,
  bool timestamps = true,
  bool softDeletes = false,
  StrictnessConfig strictness = const StrictnessConfig(),
  Environment environment = Environment.development,
})
```

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `defaultConnection` | `String` | `'default'` | `initialize` throws `ConfigurationException('adapter.missing')` if no adapter is registered under this name. |
| `connections` | `Map<String, ConnectionConfig>` | `{}` | Metadata only; adapters are supplied separately to `initialize`. |
| `poolSize` | `int` | `10` | Default pool size for connections that do not declare their own. |
| `primaryKeyType` | `PrimaryKeyType` | `PrimaryKeyType.uuid` | Values: `uuid`, `integer`. |
| `timestamps` | `bool` | `true` | Whether `created_at` / `updated_at` are managed automatically. |
| `softDeletes` | `bool` | `false` | Default soft-delete on; still opt-in per model via the `SoftDeletes` mixin. |
| `strictness` | `StrictnessConfig` | all flags off | See below. |
| `environment` | `Environment` | `Environment.development` | Overridden at runtime by `WORM_ENV` in `Worm.environment`. |

Double `initialize` throws `ConfigurationException('initialization.duplicate')`; call `Worm.reset()` first.

#### ConnectionConfig

```dart
const ConnectionConfig({
  String driver = 'inMemory',
  String host = 'localhost',
  int port = 0,
  String database = '',
  String? username,
  String? password,
  bool useSsl = false,
  int poolSize = 10,
  int? maxTotalConnections,
  Duration connectionTimeout = const Duration(seconds: 5),
  Duration idleTimeout = const Duration(seconds: 300),
})
```

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `driver` | `String` | `'inMemory'` | Adapter packages match it to claim a connection. Known ids: `'postgres'`, `'mongodb'`, `'inMemory'`. |
| `host` | `String` | `'localhost'` | Hostname or socket path. |
| `port` | `int` | `0` | Sentinel: `0` means "unset"; adapters substitute their protocol default (5432 Postgres, 3306 MySQL). Not an error. |
| `database` | `String` | `''` | Database, keyspace, or namespace. |
| `username` | `String?` | `null` | `null` means unauthenticated. |
| `password` | `String?` | `null` | `null` means unauthenticated. |
| `useSsl` | `bool` | `false` | Negotiate TLS on the wire. |
| `poolSize` | `int` | `10` | Connections held open per isolate. |
| `maxTotalConnections` | `int?` | `null` | Cap on total connections across the isolate; `null` disables the cap. Enforced by reservation at pool construction time. |
| `connectionTimeout` | `Duration` | 5 seconds | Max wait when acquiring a connection. |
| `idleTimeout` | `Duration` | 300 seconds | Time a connection may idle before being closed. |

`ConnectionConfig` is metadata only; worm core never opens sockets from it. Adapter packages consume the subset they need.

#### StrictnessConfig

```dart
const StrictnessConfig({
  bool preventLazyLoading = false,
  bool preventFullTableScans = false,
  bool preventSilentMassAssignment = false,
  bool warnOnN1Queries = false,
  bool throwOnN1Queries = false,
  bool warnOnMissingIndex = false,
  bool preventDestructiveWithoutWhere = false,
  Duration slowQueryThreshold = const Duration(milliseconds: 500),
})
```

Exact per-flag exceptions and enforcement are in section 8.4. `slowQueryThreshold` default is 500 ms (distinct from `LogConfig.slowQueryThreshold` at 200 ms).

#### LogConfig

```dart
const LogConfig({
  bool enabled = true,
  LogLevel level = LogLevel.debug,
  String? file,
  Duration slowQueryThreshold = const Duration(milliseconds: 200),
  bool logQueryParameters = true,
  bool formatQueries = true,
})
```

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Master switch. When `false`, every log method is a no-op. |
| `level` | `LogLevel` | `LogLevel.debug` | **Reserved**: the current logger does not yet drop sub-threshold entries. |
| `file` | `String?` | `null` | Consumed by `QueryLogger.fromConfig`: non-null returns a `FileLogger` appending to that path; `null` returns a `ConsoleQueryLogger` writing to stdout. Directly constructed loggers ignore it. |
| `slowQueryThreshold` | `Duration` | 200 ms | Queries at or above this are formatted with the `[SLOW QUERY]` prefix instead of `[QUERY]`. |
| `logQueryParameters` | `bool` | `true` | When `false`, the params section reads `params: [REDACTED]`. |
| `formatQueries` | `bool` | `true` | **Reserved** for future SQL pretty-printing; not acted on yet. |

`level` and `formatQueries` are reserved fields: they exist on the config but the current implementation does not act on them.

#### LogLevel

```dart
enum LogLevel { debug, info, warning, error }
```

Ordered least to most severe. `severity` getter returns an `int` (the enum index) for comparison. Filtering by level is not implemented yet (see `LogConfig.level`).

#### Environment

```dart
enum Environment { development, staging, production, testing, all }
```

| Value | Meaning |
| --- | --- |
| `development` | Local development; the fallback when nothing else is set. |
| `staging` | Pre-production staging. |
| `production` | Live production. Destructive CLI commands require force gates here. |
| `testing` | Automated test runs. |
| `all` | Seeder-only marker meaning "run in every environment". Not a deployment target. |

`Worm.environment` precedence: (1) `WORM_ENV` process variable, trimmed and matched case-insensitively against value names; (2) `WormConfig.environment`; (3) `Environment.development`. An unparseable `WORM_ENV` falls through to the config.

### 8.6 Worm static members

`Worm` is a `final` class with a private constructor: it cannot be instantiated or subclassed; all access is through statics. (An older unexported `Worm` under `worm_registry.dart` is not this class.) Pre-init column shows behavior when called before `initialize`.

| Member | Signature | Pre-init |
| --- | --- | --- |
| `initialize` | `Future<void> initialize({required WormConfig config, required Map<String, DatabaseAdapter> adapters, List<ModelRegistration> models = const [], List<Observer<Object>> observers = const []})` | n/a; second call throws `ConfigurationException('initialization.duplicate')` |
| `reset` | `Future<void> reset()` | Safe (no-op); rolls back active test txn, disconnects adapters, clears models/observers/morph/config |
| `isInitialized` | `bool get isInitialized` | Safe -> `false` |
| `config` | `WormConfig get config` | Throws `ConfigurationException('initialization')` |
| `adapter` | `DatabaseAdapter adapter([String? connection])` | Throws `initialization`; unknown name throws `adapter.unknown` |
| `registrationOf` | `ModelRegistration registrationOf<T>()` | Throws `initialization`; unknown `T` throws `model.unknown` |
| `registrationForType` | `ModelRegistration registrationForType(Type type)` | Throws `initialization`; unknown type throws `model.unknown` |
| `models` | `List<ModelRegistration> get models` | Throws `initialization` (unmodifiable view) |
| `registeredConnections` | `List<String> get registeredConnections` | Safe -> empty list |
| `observers` | `List<Observer<Object>> get observers` | Throws `initialization` (registration order) |
| `observersFor` | `List<Observer<Object>> observersFor(Type type)` | Safe -> empty list; matches exact runtime type |
| `morphRegistry` | `MorphRegistry get morphRegistry` | Throws `initialization` |
| `strictness` | `StrictnessConfig get strictness` | Safe -> all-off defaults |
| `isUnsafe` | `bool get isUnsafe` | Safe -> reads Zone state |
| `unsafe` | `Future<T> unsafe<T>(Future<T> Function() body)` | Safe (acts normally) |
| `transaction` | `Future<T> transaction<T>(Future<T> Function(TransactionContext txn) action, {String? connection})` | Throws `initialization` |
| `currentTransaction` | `TransactionContext? get currentTransaction` | Safe -> `null` |
| `beginTestTransaction` | `Future<void> beginTestTransaction()` | Throws `initialization`; second active throws `test_transaction.duplicate` |
| `rollbackTestTransaction` | `Future<void> rollbackTestTransaction()` | Safe (no-op) |
| `withoutEvents` | `Future<T> withoutEvents<T>(Future<T> Function() body, {List<LifecycleEvent>? events})` | Safe (acts normally) |
| `mutedEvents` | `Set<LifecycleEvent>? get mutedEvents` | Safe -> `null` |
| `isMutingAll` | `bool get isMutingAll` | Safe -> `false` |
| `isEventMuted` | `bool isEventMuted(LifecycleEvent event)` | Safe -> reads Zone state |
| `seedRandom` | `void seedRandom(int seed)` | Safe; forwards to `FakerService.seed` for reproducible factories |
| `environment` | `Environment get environment` | Safe -> `WORM_ENV` or `Environment.development` |

`morphRegistry` extras: `register(MorphRegistration<T>(...))`; duplicate morph string/Dart type throws `ConfigurationException('morph.duplicate.type')` / `('morph.duplicate.dart')`; `morphNameFor(Type)` throws `ConfigurationException('morph.unknown')` for unregistered types, while `morphTypeFor(Type)` and `typeFor(String)` return `null`. `reset()` clears it.

---

## 9. Drivers, adapters, and the DatabaseAdapter contract

Worm core never writes SQL. The query builder compiles everything into immutable descriptor objects and hands them to a `DatabaseAdapter`. The adapter translates each descriptor into a native operation and returns plain `Map<String, Object?>` rows; the model layer hydrates those maps. Descriptors go down, maps come up. Queries never change when you swap adapters, only construction code does. Five backends ship: the bundled `InMemoryAdapter` (in `worm` core) plus four driver packages (`worm_sqlite`, `worm_postgres`, `worm_mysql`, `worm_mongodb`).

### 9.1 Backend comparison

All types below are exported from `package:worm/worm.dart`. Each driver adds its own package barrel (`package:worm_sqlite/worm_sqlite.dart`, etc.). The 11 `AdapterCapabilities` flags all default `false`; "yes" means the flag is set `true` in that adapter's declared const.

| | InMemory | SQLite | PostgreSQL | MySQL | MongoDB |
| --- | --- | --- | --- | --- | --- |
| Backing package | none (in `worm`) | `sqlite3 ^2.4.0` | `postgres ^3.0.0` | `mysql_client_plus ^0.1.3` | `mongo_dart ^0.9.0` |
| `AdapterType` | `inMemory` | `sql` | `sql` | `sql` | `custom` (see 9.7) |
| Pooling | none, single object | none, single connection | `poolSize` -> `maxConnectionCount`, `maxTotalConnections` cap | same as Postgres | none, one `Db` handle |
| `supportsTransactions` | yes | yes | yes | yes | no |
| `supportsSavepoints` | yes | yes | yes | yes | no |
| `supportsStreaming` | yes | yes | yes | yes | yes |
| `supportsRawQuery` | no | yes | yes | yes | no |
| `supportsReturning` | yes | no | yes | no | yes |
| `supportsJoins` | no | yes | yes | yes | no |
| `supportsPreparedStatements` | no | no | yes | yes | no |
| `supportsPartialIndexes` | no | no | yes | no | no |
| `supportsAggregations` | yes | yes | yes | yes | yes |
| `supportsSchemaIntrospection` | yes | yes | yes | yes | yes |
| `supportsExplain` | yes | yes | yes | yes | yes |
| EXPLAIN source | synthetic (always indexed) | `EXPLAIN QUERY PLAN` | `EXPLAIN (FORMAT JSON)` | `EXPLAIN FORMAT=JSON` | `explain` command |
| Streaming behavior | materialized rows | buffered | buffered | buffered | live cursor (only true stream) |
| Insert returns | full row echo | echo of supplied values | native `RETURNING *` | echo + `id` from `LAST_INSERT_ID()` | stored document |
| `IN` list chunk size | n/a | 900 | 1000 | 1000 | n/a |
| Raw pass-through | throws `UnsupportedOperationException` | yes | yes | yes | throws `AdapterMismatchException` |
| `SchemaOperation.alter` | `UnsupportedOperationException` | `QueryException` | `QueryException` | `QueryException` | `QueryException` |
| Platform | server + Flutter native | server + Flutter native (ffi) | server (`dart:io` sockets) | server (`dart:io` sockets) | server (`dart:io` sockets) |

Flag nuances (declared support, not raw behavior): SQLite keeps a real prepared-statement LRU cache yet declares `supportsPreparedStatements: false`; MySQL echoes inserted rows yet declares `supportsReturning: false`. The flag answers capability queries only, it does not change execution.

`AdapterType` values: `enum AdapterType { sql, mongodb, inMemory, custom }`. `custom` is the base default for third-party adapters. `.sql()` query gates require `adapterType == AdapterType.sql`; `.mongo()` gates require `AdapterType.mongodb`; a mismatch throws `AdapterMismatchException`.

### 9.2 Platform: no database driver on Flutter Web

No worm database driver runs on Flutter Web. Plan around it.
- `InMemoryAdapter`: pure Dart, but `worm` core imports `dart:io` (CLI, file logging), so in practice it runs on server-side Dart and Flutter native.
- SQLite: ffi-backed `sqlite3`, server-side Dart and Flutter native (mobile/desktop). The main `SqliteAdapter(CommonDatabase, ...)` constructor accepts any `CommonDatabase` (a WASM-backed DB could be injected), but the shipped `.memory()` / `.open()` factories are native-only.
- PostgreSQL, MySQL, MongoDB: `dart:io` sockets, server-side Dart and Flutter native only.

### 9.3 Per-driver construction

`Worm.initialize(adapters: {...})` calls `connect()` on every registered adapter, so you do not connect by hand except where noted (Mongo). There are no `Worm.sqlite()` / `Worm.postgres()` convenience constructors; the adapter map is the only registration path.

#### In-memory

```dart
import 'package:worm/worm.dart';

final adapter = InMemoryAdapter();
// Override the declared capability matrix (for testing gate behavior):
final gated = InMemoryAdapter(
  capabilities: const AdapterCapabilities(supportsTransactions: true),
);

await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': adapter},
);
```

Fresh empty store per instance; two instances share nothing (per-isolate). `ConnectionConfig.driver` defaults to `'inMemory'`. Lifecycle: `connect()` sets `isConnected` true; `disconnect()` sets it false and keeps data; `close()` sets it false and wipes every table and schema. Diagnostics: `adapter.store` (an `InMemoryStore`) exposes `tableNames`, `schemas`, `hasTable`, `columnsOf`, `rowsOf`, `truncate`, `clear`, `snapshot()`/`restore()`. Transactions snapshot the whole store (deep clone) and restore on throw; nested `transaction()` calls snapshot again for savepoint semantics.

#### SQLite (`worm_sqlite`)

```dart
import 'package:worm_sqlite/worm_sqlite.dart';

final adapter = SqliteAdapter.memory();                 // fresh in-RAM DB, ideal for tests
final adapter = SqliteAdapter.open('app.db');           // open/create file-backed DB
final adapter = SqliteAdapter(database, compiler: const SqliteCompiler()); // wrap open CommonDatabase
```

`connect()` applies three pragmas: `journal_mode = WAL`, `foreign_keys = ON`, `synchronous = NORMAL`. `disconnect()` clears the statement cache and disposes the database. Single connection, no pool; keep transaction callbacks sequential. Prepared-statement LRU: `adapter.preparedStatementCache` (`SqlitePreparedCache`, `maxSize` 128, keyed by SQL text) exposes `hitCount`, `missCount`, `missRate`, `length`, `clear()`; `rawQuery`/`rawExecute` bypass it; DDL and `disconnect()` clear it. Nested transactions open savepoints `worm_sp_1`, `worm_sp_2`, ... `insert()`/`insertMany()` echo supplied values projected to `returning` columns; database-computed defaults are not read back.

#### PostgreSQL (`worm_postgres`)

```dart
import 'package:worm_postgres/worm_postgres.dart';

final pool = PostgresConnectionPool.fromConfig(const ConnectionConfig(
  driver: 'postgres',
  host: 'localhost',
  port: 5432,        // port 0 (worm's "unset" sentinel) resolves to 5432
  database: 'app',
  username: 'app',
  password: 'secret',
  poolSize: 4,       // becomes the pool's maxConnectionCount
  useSsl: true,      // true -> SslMode.require, false -> SslMode.disable
));

final adapter = PostgresAdapter(pool: pool);
// Inject a raw driver pool directly (tests):
final pool2 = PostgresConnectionPool(
  pool: Pool<Object?>.withUrl(url),
  maxConnectionCount: 4,
);
```

`PostgresAdapter({required PostgresConnectionPool pool, PostgresCompiler compiler = const PostgresCompiler(), preparedStatementCache})`. `connect()` is a no-op (the pool opens lazily); `disconnect()` closes the pool. Each method acquires, uses, and releases its own pooled connection, so one adapter is safe to share across concurrent callers. Inserts emit `RETURNING *` (or `RETURNING <columns>`); an INSERT producing no row throws `QueryException`. Nested transactions run inside `Pool.runTx` with savepoints `worm_sp_1`, ... `preparedStatementCache` (default `maxSize: 100`) is observability only; the `postgres` driver caches per connection.

Pooling / `maxTotalConnections`: an isolate-wide reservation counter caps the sum of every named pool's size in the current isolate. A `poolSize` that only partially fits is silently clamped to remaining slots; when none remain, `fromConfig` throws `ConfigurationException` with key `maxTotalConnections`. Slots return on `close()` (which `disconnect()` calls). Diagnostics: `PostgresConnectionPool.isolateReservedSlots`, `resetIsolateReservationForTesting()`. The cap is per isolate, not per process.

#### MySQL / MariaDB (`worm_mysql`)

```dart
import 'package:worm_mysql/worm_mysql.dart';

final pool = MysqlConnectionPool.fromConfig(const ConnectionConfig(
  driver: 'mysql',
  host: 'localhost',
  port: 3306,        // port 0 resolves to 3306
  database: 'app',
  username: 'app',
  password: 'secret',
  poolSize: 4,
));

final pool = MysqlConnectionPool.fromUri(
  'mysql://app:secret@localhost:3306/app',
  maxConnections: 5,
);

final adapter = MysqlAdapter(pool: pool);
```

`MysqlAdapter({required MysqlConnectionPool pool, MysqlCompiler compiler = const MysqlCompiler(), preparedStatementCache})`. `connect()` is a no-op; `disconnect()` closes the pool. Both factories set collation `utf8mb4_general_ci`; diagnostics `pool.activeConnections`, `pool.idleConnections`. Only `fromConfig` participates in the isolate-wide `maxTotalConnections` reservation (clamps, then throws `ConfigurationException` key `maxTotalConnections` when none remain, returns slots on `close()`); `fromUri` pools live outside the cap.

TLS bad-cert caveat: `fromUri` enables TLS when the URL carries `?ssl=true` or `?secure=true` (also `1`). When `fromUri` enables TLS and you pass no `onBadCertificate` callback, it installs a permissive one that accepts any certificate including self-signed. Convenient for dev, unsafe for production. Always pass your own for production endpoints:

```dart
final pool = MysqlConnectionPool.fromUri(
  'mysql://app:secret@db.example.com:3306/app?ssl=true',
  onBadCertificate: (certificate) => false, // reject unverifiable certs
);
```

`fromConfig` installs no permissive default; it forwards exactly the callback you give it. Inserts: no `RETURNING`; `insert()` echoes supplied values, and when you supply no `id` and set no `returning` list, injects `id` from `LAST_INSERT_ID()` if the table generated one (skipped if you pass a `returning` list or your own `id`). Nested transactions issue `START TRANSACTION` on one pinned connection with savepoints `worm_sp_1`, ... `ILIKE` is emulated as `LOWER(column) LIKE LOWER(?)`. `preparedStatementCache` (default `maxSize: 100`) is observability only.

#### MongoDB (`worm_mongodb`)

```dart
import 'package:worm_mongodb/worm_mongodb.dart';

final connection = MongoConnection.fromUri('mongodb://app:secret@localhost:27017/app');
// Equivalent: MongoConnection(uri: '...').
final connection = MongoConnection.fromDb(db); // adopt a pre-built mongo_dart Db (tests)

final adapter = MongoAdapter(connection: connection);
await adapter.connect(); // REQUIRED before use; the Db does not open lazily
```

`MongoAdapter({required MongoConnection connection, MongoFilterCompiler compiler = const MongoFilterCompiler()})`. `MongoConnection` owns a single `mongo_dart` `Db`; no pool. `connect()` does real work (opens the `Db`); `open()`/`close()` are idempotent; `connection.isOpen` reports state. Unlike the lazy SQL pools, you must `connect()` (or let `Worm.initialize` do it) before use. Reach `adapter.connection.db` for driver APIs worm does not wrap.

id / `_id` aliasing: worm's canonical primary key is `id`; MongoDB stores it as `_id`. The adapter and compiler translate on every boundary: `id` in written values becomes `_id`; `_id` in read documents comes back as `id`; filters, sort keys, projections, and `groupBy` map `id` to `_id`. Insert without an `id` returns the driver-generated `ObjectId` under `id`.

Mongo transaction throws: `MongoAdapter.transaction()` always throws `TransactionException`, by design. `mongo_dart` 0.9 exposes no client-session/transaction API, so atomic multi-document commit/rollback cannot be guaranteed even against a replica set; the adapter refuses rather than run writes without isolation and declares `supportsTransactions: false`. Single-document writes remain atomic. Do not pick MongoDB when you need `Worm.transaction`. `rawQuery`/`rawExecute` throw `AdapterMismatchException` (no SQL surface). `whereExists` and `whereRaw` predicates throw `UnsupportedOperationException` in the filter compiler. `stream()` iterates the live driver cursor (the only true streaming driver).

### 9.4 The DatabaseAdapter contract

```dart
abstract class DatabaseAdapter {
  const DatabaseAdapter({
    AdapterCapabilities capabilities = const AdapterCapabilities(),
  });
}
```

`abstract` (not `sealed`), so third-party packages can implement it. The base constructor stores the declared matrix; `capabilities` is a getter, overridable for runtime-computed support. Rows cross the boundary in both directions as `Map<String, Object?>`.

Getters:

```dart
AdapterCapabilities get capabilities; // declared matrix; overridable
AdapterType get adapterType;          // defaults to AdapterType.custom
```

Every method below is abstract and must be implemented, except `aggregateGrouped`, which ships a concrete default (fetch and roll up in memory); SQL and document drivers override it to push `GROUP BY` down.

```dart
// Lifecycle
Future<void> connect();     // open/init; safe to call multiple times
Future<void> disconnect();  // close connections, release resources

// Reads
Future<List<Map<String, Object?>>> select(QueryDescriptor descriptor);
Future<Map<String, Object?>?>       selectOne(QueryDescriptor descriptor); // null on no match, never throws
Stream<Map<String, Object?>>        stream(QueryDescriptor descriptor);    // bounded memory

// Writes
Future<Map<String, Object?>>       insert(InsertDescriptor descriptor);        // inserts one, returns it
Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor descriptor);// inserts many, returns them
Future<int>                        update(UpdateDescriptor descriptor);        // affected row count
Future<int>                        delete(DeleteDescriptor descriptor);        // affected row count

// Aggregates
Future<int>              count(AggregateDescriptor descriptor);          // 0 on no match
Future<num?>             sum(AggregateDescriptor descriptor);            // null on no match
Future<double?>          avg(AggregateDescriptor descriptor);            // null on no match
Future<Object?>          min(AggregateDescriptor descriptor);
Future<Object?>          max(AggregateDescriptor descriptor);
Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor descriptor); // has a default; empty map when groupBy == null

// Raw access
Future<List<Map<String, Object?>>> rawQuery(String query, List<Object?> parameters);
Future<int>                        rawExecute(String statement, List<Object?> parameters); // affected count

// Transactions
Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action); // tx = transactional context; throw rolls back

// Schema
Future<void>                     executeSchema(SchemaDescriptor descriptor);
Future<Map<String, List<String>>> introspectSchema(); // table name -> declared columns ([] if none persisted)

// Debugging
String compileToString(Object descriptor); // native string form; synchronous; never executes
```

`explain` is NOT on the contract. It lives on the `ExplainCapable` mixin (see 9.6). Parameter binding is always positional and value-safe (`$1, $2, ...` for Postgres, `?` for SQLite/MySQL); user values never get interpolated into statement text.

### 9.5 AdapterCapabilities

```dart
const AdapterCapabilities({
  bool supportsTransactions = false,
  bool supportsSavepoints = false,
  bool supportsStreaming = false,
  bool supportsRawQuery = false,
  bool supportsReturning = false,
  bool supportsJoins = false,
  bool supportsPreparedStatements = false,
  bool supportsPartialIndexes = false,
  bool supportsAggregations = false,
  bool supportsSchemaIntrospection = false,
  bool supportsExplain = false,
})
```

All 11 flags default `false`; adapters opt in explicitly. The type only describes; enforcement is each adapter's job. Members:

```dart
bool supports(String capability);       // safe string lookup; false for unknown keys; never throws
AdapterCapabilities copyWith({...});    // copy with any subset overridden
```

`supports()` keys: `'transactions'`, `'savepoints'`, `'streaming'`, `'rawQuery'`, `'returning'`, `'joins'`, `'preparedStatements'`, `'partialIndexes'`, `'aggregations'`, `'schemaIntrospection'`, `'explain'`.

Two rules: (1) Capabilities describe. The runtime consults flags before acting: `Worm.transaction` checks `supportsTransactions`, `TransactionContext.savepoint` checks `supportsSavepoints`, `MissingIndexWarner` checks `supportsExplain`. (2) Adapters enforce. Flags stop nothing; if a caller invokes an unsupported method anyway, the adapter throws `UnsupportedOperationException`, naming the operation and adapter. Declaring `supportsTransactions: false` makes `Worm.transaction` throw `UnsupportedOperationException` before the adapter is called, but the adapter must still throw from `transaction()` for direct callers (`TransactionException` for the Mongo backend).

### 9.6 Error mapping and EXPLAIN

Drivers never let native error types leak. Every executor call is wrapped through a stateless mapper's `wrap` helper. A value already a `WormException` passes through unwrapped (no double-wrapping). Backend-agnostic mapping:

| Native condition | Worm exception |
| --- | --- |
| Unique or primary key violation | `UniqueConstraintException` |
| Foreign key violation | `ForeignKeyException` |
| Deadlock or serialization failure | `TransactionException` |
| Connection refused, dropped, or timed out | `ConnectionException` |
| Anything else the database rejects | `QueryException` |

Per-driver native codes: SQLite extended result codes `2067` (UNIQUE) and `1555` (PRIMARY KEY) -> `UniqueConstraintException`, `787` (FOREIGN KEY) -> `ForeignKeyException`, else `QueryException`. Postgres SQLSTATE `23505` -> `UniqueConstraintException`, `23503` -> `ForeignKeyException`, `40001`/`40P01` -> `TransactionException`, `08xxx` family -> `ConnectionException`, else `QueryException`. MySQL error numbers `1062`/`1169` -> `UniqueConstraintException`, `1451`/`1452`/`1216`/`1217` -> `ForeignKeyException`, `1205`/`1213` -> `TransactionException`, `1042`/`1043`/`1045`/`2002`/`2003`/`2006`/`2013` -> `ConnectionException`, else `QueryException`. Mongo code `11000` (duplicate key) -> `UniqueConstraintException`, else `QueryException`; write-command failures on a `WriteResult` map through the same path.

EXPLAIN is opt-in via a mixin, not on the contract:

```dart
abstract mixin class ExplainCapable {
  Future<ExplainResult> explain(QueryDescriptor descriptor);
}

const ExplainResult({
  required bool usesIndex,
  String raw = '',
  String? indexName,
  double estimatedCost = 0, // 0 means unknown
  int estimatedRows = 0,    // 0 means unknown
  List<String> scannedTables = const [],
})
```

Consumers gate access with `capabilities.supportsExplain` plus `is ExplainCapable`. `MissingIndexWarner.checkAfterQuery` is a hard no-op unless both are true, so it can be wired unconditionally. All five shipped adapters mix it in. `PredicateEvaluator` (`const PredicateEvaluator()`, `bool matches(Map<String, Object?> row, PredicateTree? tree, {bool Function(ExistsNode)? existsResolver})`, `int compareValues(Object? a, Object? b)`) is the shared in-memory predicate semantics (LIKE-to-regex, inclusive BETWEEN, NULLS-first). A `null` tree matches every row. `RawNode` (from `whereRaw`), column-to-column LIKE/IN/BETWEEN/NULL, and an `ExistsNode` without an `existsResolver` throw `UnsupportedOperationException`; comparing non-`Comparable` values throws `StateError`.

### 9.7 Writing a new driver

Split the package into three pieces, mirroring the shipped drivers:
- Compiler: a `const`, I/O-free class turning a descriptor into dialect output (SQL text + positional params, or a filter document). Unit-testable with golden strings.
- Executor: the `DatabaseAdapter` subclass. Runs compiled statements on the native client, manages connection/pool, implements `transaction()`.
- Error mapper: a stateless class whose `wrap` helper catches native errors and rethrows typed `WormException`s.

```dart
final class MyAdapter extends DatabaseAdapter with ExplainCapable {
  MyAdapter(this._client) : super(capabilities: _capabilities);

  final MyClient _client;
  static const MyCompiler _compiler = MyCompiler();
  static const AdapterCapabilities _capabilities = AdapterCapabilities(
    supportsTransactions: true,
    supportsStreaming: true,
    supportsAggregations: true,
    supportsSchemaIntrospection: true,
  );

  @override
  AdapterType get adapterType => AdapterType.sql; // unlocks .sql(); default is custom

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      MyErrorMapper.wrap(() async {
        final compiled = _compiler.compileSelect(d);
        return _client.query(compiled.sql, compiled.parameters);
      }, table: d.table);
  // ... every other abstract method delegates the same way.
}
```

Rules: declare only the flags you truly deliver (a flipped-on flag you cannot honor fails the contract suite). Bind values positionally, never interpolate. Map every native error through `wrap`; let existing `WormException`s pass through. `transaction()` commits on return, rolls back and rethrows the original on throw, or throws `TransactionException` when the backend has no atomic transactions (do not fake them). Keep `aggregateGrouped`'s default only if a Dart-side rollup is acceptable. If your backend holds rows in Dart, delegate `WHERE` semantics to `const PredicateEvaluator()` instead of hand-rolling them. Register through `Worm.initialize(adapters: {'default': adapter})` (there is no `Worm.sqlite()` shortcut); `Worm.initialize` connects every adapter and throws `ConfigurationException` if none matches the default connection.

Contract test entry point:

```dart
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:worm/testing/adapter_contract.dart'; // NOT exported from package:worm/worm.dart
import 'package:worm/worm.dart';
import 'package:worm_my/worm_my.dart';

void main() {
  runAdapterContractTests(
    name: 'MyAdapter contract',                 // optional group label
    capabilities: const AdapterCapabilities(    // must match the adapter's real profile
      supportsTransactions: true,
      supportsStreaming: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
    ),
    adapterFactory: () => MyAdapter(MyClient()), // fresh, UNCONNECTED adapter per test; the suite calls connect()
  );
}
```

`runAdapterContractTests` takes `adapterFactory` (returns a fresh unconnected adapter each test; a `const` tear-off like `SqliteAdapter.memory` or an `async` closure both work), `capabilities` (the exercised profile, must match), and optional `name`. Import `package:worm/testing/adapter_contract.dart` directly; it is deliberately not exported from the main barrel so it never leaks into production builds.

Fixture: around each test the suite drops, recreates, and reseeds a `users` table with schema `id` integer primary key, `name` text, `age` integer, `email` nullable text, `score` integer, and these rows:

| id | name | age | email | score |
| --- | --- | --- | --- | --- |
| 1 | Alice | 30 | `alice@example.com` | 100 |
| 2 | Bob | 25 | `bob@example.com` | 200 |
| 3 | Carol | 40 | `carol@example.com` | 150 |
| 4 | Dave | 35 | `null` | 200 |
| 5 | Eve | 28 | `eve@example.com` | 50 |

Dave's null `email` drives `isNull`/`isNotNull`; the repeated `score` of `200` drives `aggregateGrouped`. Your `executeSchema` must create it, writes must persist against it, `introspectSchema` must report it. Groups run: CRUD; every operator (`eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `like`, `isNull`, `isNotNull`, `inList`, `notInList`, `between`, `notBetween`); `AND`/`OR`/`NOT` composition; sorting and pagination; aggregations including `aggregateGrouped`; schema create/drop plus introspection; streaming parity with `select`; `compileToString`; capability gating; and raw query (asserts a `WormException` when `supportsRawQuery` is false). The transaction-rollback group runs only when `supportsTransactions` is true, and the capability-gating test asserts `transaction()` throws `TransactionException` whenever `supportsTransactions` is false.

Server-driver suites gate on an environment variable and skip with a placeholder test when unset, so `dart test` stays green offline. SQLite runs in-process, unconditionally. Postgres gates on `PG_DB`, MySQL on `MYSQL_URL`, Mongo on `MONGO_URI`:

```dart
final url = Platform.environment['PG_DB'];
if (url == null || url.isEmpty) {
  test('Postgres contract suite skipped', () {}, skip: 'Set PG_DB to run it.');
  return;
}
runAdapterContractTests(/* build the adapter from url in adapterFactory */);
```

---

## 10. Logging and debugging, testing, exceptions, security, performance, and the never-list

Operational surface of worm: how to observe queries, test against it, catch and classify failures, secure it, keep it fast, and which plausible APIs do not exist.

### 10.1 Logging and debugging

Logging is an explicit decorator, never a config flag. Wrap your real adapter in `LoggingAdapter` and pass the wrapped adapter to `Worm.initialize`. If you do not wrap, nothing is logged. `LogConfig` alone does nothing.

```dart
final logger = ConsoleQueryLogger();
final adapter = LoggingAdapter(
  inner: InMemoryAdapter(),          // any DatabaseAdapter works here
  logger: logger,
  strictness: const StrictnessConfig(
    warnOnN1Queries: true,
    warnOnMissingIndex: true,
  ),
  adapterName: 'InMemory',
);

await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': adapter},
);
```

`LoggingAdapter` is itself a `DatabaseAdapter`. It times every call with a stopwatch, delegates to `inner`, and emits one `QueryLog` per operation. Inside `transaction()` callbacks it wraps the transactional adapter in a new decorator sharing the same logger, detector, and warner, so queries inside transactions are logged too.

#### Sinks

Three `QueryLogger` implementations ship, plus a config factory:

```dart
final console = ConsoleQueryLogger();                 // stdout
final memory  = InMemoryQueryLogger();                // tests and diagnostics
final file    = FileLogger('/var/log/worm.log');      // appends to a file

// file != null -> FileLogger, file == null -> ConsoleQueryLogger
final fromConfig = QueryLogger.fromConfig(const LogConfig(file: 'worm.log'));
```

- `FileLogger` holds an open `IOSink`. Call `await fileLogger.close()` on shutdown or trailing lines are lost.
- `InMemoryQueryLogger` retains everything forever; keep it out of long-running processes.
- Custom sink: extend `QueryLogger` and implement the single primitive `emitLine(String line)`. The base class formats and enforces `LogConfig.enabled` before your sink sees a line.

#### Line format and param redaction

Every line starts with a UTC timestamp `[yyyy-MM-dd HH:mm:ss.SSS]` then a tag:

```text
[2026-07-02 10:15:42.123] [QUERY] SELECT * FROM users WHERE name = ? | params: [Alice] | 3ms
[2026-07-02 10:15:42.512] [SLOW QUERY] SELECT * FROM posts | params: [] | 240ms (threshold: 200ms)
[2026-07-02 10:15:43.007] [WARNING] N+1: 5+ same-table queries on "posts" within 100ms. Consider eager loading.
[2026-07-02 10:15:43.442] [ERROR] connection lost :: SocketException
```

Set `LogConfig(logQueryParameters: false)` to redact; the params section then reads `params: [REDACTED]`. Timestamps are UTC, not local.

#### Two slow-query thresholds (independent)

| Setting | Default | Consumed by | Effect |
| --- | --- | --- | --- |
| `LogConfig.slowQueryThreshold` | 200 ms | `QueryLogger.log` formatting | Line rendered with `[SLOW QUERY]` prefix + `(threshold: Nms)` suffix instead of `[QUERY]`. |
| `StrictnessConfig.slowQueryThreshold` | 500 ms | `LoggingAdapter` | Fires `QueryLogger.slowQuery(entry, threshold)`. `InMemoryQueryLogger` collects these into `slowQueries`; console and file loggers ignore the callback. |

A 300 ms query at defaults gets a `[SLOW QUERY]` line (over 200 ms) but does NOT land in `InMemoryQueryLogger.slowQueries` (under 500 ms). Set both for one consistent definition.

#### N+1 detection

`NPlusOneDetector` is a sliding-window counter consulted after each `select`/`selectOne`:

1. Armed when either `warnOnN1Queries` or `throwOnN1Queries` is set on the `LoggingAdapter`'s `StrictnessConfig`.
2. Only single-row lookups count: `limit == 1`, or a query that returned at most one row and filters on `id` or any column ending in `_id`. Multi-row selects never contribute.
3. Entries older than `window` are evicted before every check, so memory stays bounded.
4. When one table hits `threshold` lookups (default 5) within `window` (default 100 ms), the detector fires and resets that table's counter, giving one diagnostic per burst.
5. `warnOnN1Queries` writes a `[WARNING]` line; `throwOnN1Queries` throws `DangerousQueryException` from inside the query call WITHOUT emitting a warning line first. Orthogonal flags; the throw wins when both are set.

The detector itself never throws; escalation is `LoggingAdapter`'s job. Tune it:

```dart
LoggingAdapter(
  inner: adapter,
  logger: logger,
  strictness: const StrictnessConfig(warnOnN1Queries: true),
  detector: NPlusOneDetector(threshold: 10, window: Duration(milliseconds: 250)),
);
```

The fix for every N+1 warning is eager loading (see Relations): `.withRelationPaths([...])` / `.withRelations(...)`.

#### Missing-index warnings

With `warnOnMissingIndex: true`, `MissingIndexWarner` runs after each select, asks the adapter for an EXPLAIN plan, and writes a `[WARNING]` line when a filtered query uses no index:

```text
[WARNING] missing-index: query on "users" filters by (email) without an index. Plan: SCAN users
```

Hard no-op (safe to enable unconditionally) unless all hold: adapter's `AdapterCapabilities.supportsExplain` is `true`; adapter mixes in `ExplainCapable` (Postgres, SQLite, in-memory do); the query has a `where` clause. `InMemoryAdapter` always reports `usesIndex: true`, so run staging against Postgres or SQLite for real plans.

#### Inspecting a query without running it

```dart
final query = User.query().where(User$.age.gte(18));

query.toSql();          // "SELECT * FROM users WHERE age >= 18"  -- inspection only
query.toMongoFilter();  // '{"age":{"$gte":18}}'                  -- inspection only
query.debug().get();    // logs a builder summary via dart:developer, then runs
final plan = await query.explain();  // ExplainResult from the adapter
```

- `toSql()` / `toMongoFilter()` compile with literals inlined: deterministic and golden-test friendly, but NOT executable. Adapters parameterize their real statements.
- `debug()` is a pure observer: logs builder state (table, where tree, sort, limit, eager loads) under logger name `worm.query` and returns the same builder for chaining. Never throws.
- `explain()` returns the adapter's `ExplainResult` (index use, estimated cost/rows, raw plan). Throws `UnsupportedOperationException` when the adapter does not mix in `ExplainCapable`.
- Every adapter exposes `compileToString(descriptor)`, a synchronous render hook that never executes.

#### What escapes logging

- `stream()` and `introspectSchema()` pass straight through, unlogged.
- `rawQuery` / `rawExecute` are logged but carry no `table`, so they bypass N+1 and missing-index checks.
- `connect()`, `disconnect()`, `compileToString()` are pass-through and produce no entries.
- N+1 and missing-index diagnostics go through `logWarning`, so on `InMemoryQueryLogger` they appear in `lines`, NOT in the structured `warnings` list (that list is filled only by direct `warning(code: ...)` calls).
- `LogConfig.level` and `LogConfig.formatQueries` are reserved and currently have no effect.

#### Logging API summary

| Symbol | Signature sketch |
| --- | --- |
| `LogLevel` | enum `debug, info, warning, error`; `int get severity` (filtering reserved) |
| `LogConfig` | `const LogConfig({enabled = true, level = LogLevel.debug, file, slowQueryThreshold = 200ms, logQueryParameters = true, formatQueries = true})` + `copyWith` |
| `QueryLogger` | abstract; `factory QueryLogger.fromConfig(LogConfig)`; `log`, `warning({code, message, entry})`, `logWarning`, `logError`, `slowQuery`; primitive `emitLine(String)` |
| `ConsoleQueryLogger` | `ConsoleQueryLogger({config, StringSink? sink})` |
| `InMemoryQueryLogger` | fields `entries`, `slowQueries`, `warnings`, `lines`; `clear()` |
| `FileLogger` | `FileLogger(String path, {config})`; `Future<void> close()` |
| `LoggedWarning` | `{String code, String message, QueryLog? entry}` |
| `QueryLog` | `const QueryLog({statement, parameters, duration, rowCount, adapter, table})` |
| `LoggingAdapter` | `LoggingAdapter({required inner, required logger, required strictness, adapterName = 'DatabaseAdapter', detector, missingIndexWarner})` |
| `NPlusOneDetector` | `NPlusOneDetector({threshold = 5, window = 100ms, clock})`; `recordQuery(table)`, `shouldWarn(table, {threshold, window})`, `resetTable(table)`, `reset()` |
| `ExplainCapable` | mixin; `Future<ExplainResult> explain(QueryDescriptor)` |
| `ExplainResult` | `const ExplainResult({required usesIndex, raw = '', indexName, estimatedCost = 0, estimatedRows = 0, scannedTables = []})` |
| `MissingIndexWarner` | `const MissingIndexWarner()`; `checkAfterQuery({descriptor, capabilities, adapter, logger})` |
| `formatQueryLine` | `String formatQueryLine(QueryLog, LogConfig)` |
| `formatWarningLine` | `String formatWarningLine(String message)` |
| `formatErrorLine` | `String formatErrorLine(String message, [Object? error])` |
| `formatStructuredWarning` | `String formatStructuredWarning(String code, String message, QueryLog? entry)` |
| `formatTimestamp` | `String formatTimestamp()` (UTC `[yyyy-MM-dd HH:mm:ss.SSS]`) |
| `QueryBuilder.debug` | `QueryBuilder<T> debug()` |
| `QueryBuilder.toSql` / `.toMongoFilter` | `String toSql()` / `String toMongoFilter()` |
| `QueryBuilder.explain` | `Future<ExplainResult> explain()` |
| `DatabaseAdapter.compileToString` | `String compileToString(Object descriptor)` |

### 10.2 Testing

Default recipe: one fresh `InMemoryAdapter` per test, schema created up front, `Worm.reset` in `tearDown`. Every test starts empty and leaves nothing behind.

```dart
// test/support/test_database.dart
import 'package:worm/worm.dart';

Future<InMemoryAdapter> createTestDatabase() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
        SchemaColumn(name: 'name', type: ColumnType.text),
        SchemaColumn(name: 'email', type: ColumnType.text),
      ],
    ),
  );
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
    models: const <ModelRegistration>[
      ModelRegistration(type: User, tableName: 'users'),
    ],
  );
  return adapter;
}
```

```dart
// test/user_test.dart
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'support/test_database.dart';
import 'support/user_factory.dart';

void main() {
  setUp(() async {
    Worm.seedRandom(42);
    await createTestDatabase();
  });

  tearDown(Worm.reset);

  test('finds a user by name', () async {
    await UserFactory().create(overrides: {'name': 'Alice'});
    final found = await User.query().where(User$.name.eq('Alice')).first();
    expect(found, isNotNull);
  });
}
```

`Worm.reset()` rolls back any active test transaction, disconnects every registered adapter, and clears the model, observer, and morph registries. `Worm` is then uninitialized, so the next `setUp` can call `Worm.initialize` without hitting the double-init guard. `tearDown(Worm.reset)` is not optional: a second `Worm.initialize` without a reset throws `ConfigurationException` (key `initialization.duplicate`).

Prefer `executeSchema` with a `SchemaDescriptor.createTable` over migrations in tests (fastest path to a schema). To exercise the real migration path, build a `MigrationRunner` with your migration list and call `migrate()` against the test adapter (see Migrations).

#### Which adapter to test against

- `InMemoryAdapter` (default): no I/O; capabilities cover transactions, savepoints, streaming, aggregations, explain. `close()` wipes data; `disconnect()` keeps it (`Worm.reset()` calls `disconnect()`, fine because the playbook discards the adapter).
- `InMemoryAdapter` throws `UnsupportedOperationException` for `rawQuery` / `rawExecute` (`supportsRawQuery: false`). Use `SqliteAdapter.memory()` from `worm_sqlite` when code under test issues raw SQL or needs real SQL semantics (SQL types, constraint errors). Harness is identical; only adapter construction changes.

#### Test transactions for shared databases

For a shared DB (SQLite file, Postgres in CI), wrap each test in a rollback-only transaction:

```dart
setUp(Worm.beginTestTransaction);
tearDown(Worm.rollbackTestTransaction);
```

- `beginTestTransaction()` opens a transaction on the DEFAULT connection only. While active, `Worm.adapter()` returns the transactional handle; writes on other connections are not isolated.
- Calling `beginTestTransaction()` while one is active throws `ConfigurationException` (key `test_transaction.duplicate`).
- `rollbackTestTransaction()` completes only once fully rolled back, so the next line observes pre-test state. No-op when none is active.
- `afterCommit` callbacks queued during the test are discarded on rollback; they never fire. Do not assert on their side effects there.
- `Worm.reset()` calls `rollbackTestTransaction()` first, so `tearDown(Worm.reset)` alone covers both. Test transactions mutate global static state on `Worm`; not safe for concurrent production use.

#### Factories + seedRandom

Factories build in memory (`make`, `makeMany`) or persist (`create`). Combine with `Worm.seedRandom` so faker output is identical every run.

```dart
// test/support/user_factory.dart
import 'package:worm/worm.dart';
int _nextId = 0;

final class UserFactory extends Factory<User> {
  @override
  User definition() => User()
    ..setAttribute('id', ++_nextId)
    ..setAttribute('name', faker.name())
    ..setAttribute('email', faker.email());
}
```

```dart
Worm.seedRandom(42);                                    // reproducible faker stream
final users = await UserFactory().count(5).create();    // five persisted rows
final draft = UserFactory().make();                     // built, not saved
```

`create(overrides: {...})` applies overrides through `fill()`, so guarded fields obey mass-assignment rules (see Models). `Worm.seedRandom` seeds the shared `FakerService` singleton; call it in `setUp` (not once per suite) if tests must be order-independent.

#### Asserting on the queries your code runs

Wrap the test adapter in `LoggingAdapter` + `InMemoryQueryLogger` to assert on every statement, its parameters, and the table hit. This is the regression test for an N+1 fix.

```dart
final logger = InMemoryQueryLogger();
final adapter = LoggingAdapter(
  inner: InMemoryAdapter(),
  logger: logger,
  strictness: const StrictnessConfig(),
  adapterName: 'InMemory',
);
// connect, executeSchema, and Worm.initialize with `adapter` as usual
logger.clear(); // setup queries (like executeSchema) are logged too

await User.query().where(User$.name.eq('Alice')).get();

expect(logger.entries, hasLength(1));
final entry = logger.entries.single;
expect(entry.table, 'users');
expect(entry.parameters, ['Alice']);
```

`InMemoryQueryLogger` also exposes `slowQueries` (entries at or over `StrictnessConfig.slowQueryThreshold`), `lines`, and `clear()`. To assert "at most N queries", check `logger.entries.length`. It grows unboundedly; fine in tests, do not ship it.

#### Golden testing queries and descriptors

No database needed:

```dart
test('adult users query compiles as expected', () {
  final sql = User.query()
      .where(User$.age.gte(18))
      .orderBy(User$.age, descending: true)
      .limit(10)
      .toSql();
  expect(sql, 'SELECT * FROM users WHERE age >= 18 ORDER BY age DESC LIMIT 10');
});
```

`toSql()` is inspection/goldens only, not executable. Every descriptor has `toMap()` for structured snapshots.

#### Testing a custom driver

worm ships a conformance suite (CRUD, all operators, sorting, pagination, aggregations, streaming, schema ops, capability gating). Not exported from `package:worm/worm.dart`; import directly:

```dart
import 'package:worm/testing/adapter_contract.dart';

runAdapterContractTests(
  name: 'MyAdapter contract',
  capabilities: const AdapterCapabilities(supportsTransactions: true),
  adapterFactory: () async => MyAdapter(),
);
```

#### Testing gotchas

- Bulk `update()` / `delete()` / `insertMany()` on the query builder skip lifecycle hooks and validation, so observer-based test doubles will not see them.
- `InMemoryAdapter` `rawQuery`/`rawExecute` throw; use `SqliteAdapter.memory()` for raw-SQL paths.

#### Testing API summary

| Symbol | Signature sketch |
| --- | --- |
| `InMemoryAdapter` | `InMemoryAdapter({AdapterCapabilities? capabilities})`; `close()` wipes, `disconnect()` keeps |
| `Worm.reset` | `static Future<void> reset()` |
| `Worm.beginTestTransaction` | `static Future<void> beginTestTransaction()` |
| `Worm.rollbackTestTransaction` | `static Future<void> rollbackTestTransaction()` |
| `Worm.seedRandom` | `static void seedRandom(int seed)` |
| `Factory<T>.make` / `.makeMany` | `T make()` / `List<T> makeMany(int count)` |
| `Factory<T>.create` | `Future<T> create({Map<String, Object?> overrides})` |
| `Factory<T>.count(n).create()` | `Future<List<T>> create({...})` |
| `runAdapterContractTests` | `void runAdapterContractTests({required adapterFactory, required capabilities, String name})` |

### 10.3 Exceptions

Every failure surfaces as a typed exception rooted at `WormException`. All types are exported from `package:worm/worm.dart`. `WormException` IMPLEMENTS `Exception` (does not extend it). Three catch levels: concrete types, the two abstract umbrellas (`AdapterException`, `ModelException`), and the abstract root `WormException`.

```dart
abstract class WormException implements Exception {
  const WormException(String message);
  final String message;
  Map<String, Object?> get context; // overridden by subtypes
}
```

Every concrete exception exposes typed fields plus a `context` map. `toString()` renders `TypeName: message (field: value, ...)` and omits `null`-valued entries.

Hierarchy (indented = extends parent):

```text
WormException (implements Exception)
├─ AdapterException
│  ├─ ConnectionException
│  │  └─ ConnectionTimeoutException
│  ├─ AuthenticationException
│  ├─ QueryException
│  │  └─ SyntaxException
│  ├─ UniqueConstraintException
│  ├─ ForeignKeyException
│  ├─ CheckConstraintException
│  ├─ DataException
│  ├─ TransactionException
│  ├─ MigrationException
│  └─ AdapterMismatchException
├─ ModelException
│  ├─ ValidationException
│  ├─ MassAssignmentException
│  ├─ ModelNotFoundException
│  ├─ RelationNotLoadedException
│  ├─ LazyLoadingException
│  ├─ CastException
│  └─ UninitializedFieldException
├─ FullTableScanException      (DangerousQueryException is a typedef alias of this)
├─ ConfigurationException
├─ OperationCancelledException
├─ UnsupportedOperationException
├─ FactoryException
├─ IrreversibleMigrationException
└─ MigrationLockException
```

#### Adapter-layer catalog

| Exception | Extends | Typed fields | Thrown when |
| --- | --- | --- | --- |
| `ConnectionException` | `AdapterException` | `host: String`, `port: int` | A DB connection cannot be established or is lost. |
| `ConnectionTimeoutException` | `ConnectionException` | + `timeoutMs: int` | Establishing a connection exceeds the configured timeout. Catchable as `ConnectionException`. |
| `AuthenticationException` | `AdapterException` | `host: String`, `username: String?` | DB refuses authentication (wrong user/password, missing role, expired creds). |
| `QueryException` | `AdapterException` | `query: String`, `nativeError: String?`, `table: String?` | A query fails to execute for any reason the driver reports. |
| `SyntaxException` | `QueryException` | + `position: int?` (byte offset in `query`) | Driver reports a syntax error. Catchable as `QueryException`. |
| `UniqueConstraintException` | `AdapterException` | `table: String`, `column: String` | A UNIQUE constraint is violated. Convert via `ValidationException.fromUniqueConstraint`. |
| `ForeignKeyException` | `AdapterException` | `table: String`, `column: String` | A foreign key constraint is violated. |
| `CheckConstraintException` | `AdapterException` | `table: String`, `column: String?`, `constraintName: String?` | A CHECK or NOT NULL constraint is violated. |
| `DataException` | `AdapterException` | `table: String`, `column: String?` | The database refuses a value for its size, range or format (a string longer than its column, a number outside its type's range, text that is not a valid value of the type). |
| `TransactionException` | `AdapterException` | `savepointName: String?` | A transaction or savepoint fails. MongoDB's `transaction()` throws it by design: multi-document transactions unsupported. |
| `MigrationException` | `AdapterException` | `migration: String` | A migration fails to apply. |
| `AdapterMismatchException` | `AdapterException` | `expectedAdapter: String`, `actualAdapter: String` | `QueryBuilder.sql(...)` runs on a non-SQL adapter, or `.mongo(...)` on a non-Mongo adapter. |

All adapter-exception constructors are `const` and take `message` as a required named parameter alongside the fields.

#### Model-layer catalog

| Exception | Extends | Typed fields | Thrown when |
| --- | --- | --- | --- |
| `ValidationException` | `ModelException` | `field: String`, `rule: String`, `value: Object?`, `model: String?`, `errors` getter | One or more fields fail validation, during `save()` or via `Validator.validateOrThrow` / `validateModel`. |
| `MassAssignmentException` | `ModelException` | `model: String`, `field: String`, `extraFields: List<String>`, `fields` getter | `fill()` targets guarded/non-fillable keys while strict mass assignment is on. |
| `ModelNotFoundException` | `ModelException` | `model: String`, `id: Object` | `findOrFail` / `firstOrFail` lookups find no row. |
| `RelationNotLoadedException` | `ModelException` | `model: String`, `relationName: String` | A relation is accessed before eager load, OUTSIDE strict mode. |
| `LazyLoadingException` | `ModelException` | `modelName: String`, `relationName: String` | Same access WITH `StrictnessConfig.preventLazyLoading: true`. |
| `CastException` | `ModelException` | `field: String`, `fromType: String`, `toType: String`, `model: String?` | An attribute cast fails, or a typed aggregate (`min<V>` / `max<V>`) receives a mismatching value. |
| `UninitializedFieldException` | `ModelException` | `model: String`, `field: String` | A model field is read before it was initialized or hydrated. |

`ValidationException` is a `final class` with three construction paths. `errors` always returns an unmodifiable `Map<String, List<String>>` (inner lists too); single-field form yields `{field: [message]}`.

| Constructor | Signature |
| --- | --- |
| default | `const ValidationException({required String field, required String rule, required String message, Object? value, String? model})` |
| `fromMap` | `ValidationException.fromMap(Map<String, List<String>> errors, {String? model})` (`field`/`rule` become empty strings) |
| `fromUniqueConstraint` | `factory ValidationException.fromUniqueConstraint(UniqueConstraintException violation, {String? message, String? model})` (default message `'The <column> has already been taken.'`) |

`MassAssignmentException.field` holds only the FIRST offending key (backwards compat); `fields` returns the complete list (`field` + `extraFields`). Factory: `MassAssignmentException.forFields({required String model, required List<String> fields, required String message})` (asserts non-empty).

#### Direct WormException subtypes (NOT caught by `AdapterException` or `ModelException`)

| Exception | Extends | Typed fields | Thrown when |
| --- | --- | --- | --- |
| `FullTableScanException` | `WormException` | `table: String`, `queryHint: String?` | A guarded query would scan or mutate a whole table. |
| `DangerousQueryException` | typedef alias of `FullTableScanException` | same | Same class, second name; a `catch` on either catches both. |
| `ConfigurationException` | `WormException` | `key: String` | ORM configuration invalid or incomplete (see key table). |
| `OperationCancelledException` | `WormException` | `operation: String`, `hook: String?` | Reserved for hook cancellation. Current runtime NEVER throws it: a `before*` hook cancel makes `save()` / `delete()` return `false`. Do not build control flow on catching it. |
| `UnsupportedOperationException` | `WormException` | `operation: String`, `adapter: String?` | Operation genuinely unavailable: `Worm.transaction` on an adapter without `supportsTransactions`, `savepoint` without `supportsSavepoints`, `rawQuery`/`rawExecute`/`alter` on `InMemoryAdapter`, `RawNode` in `PredicateEvaluator`. Worm's own type, unrelated to `dart:core` `UnsupportedError`. |
| `FactoryException` | `WormException` | `factoryState: String` | A factory is misused, commonly requesting an undeclared named state. `factoryState` empty when unrelated to a specific state. |
| `IrreversibleMigrationException` | `WormException` | `migration: String`, `reason: String?` | A migration's `down` is invoked but it cannot be rolled back. Authors throw it from `down` for one-way changes. |
| `MigrationLockException` | `WormException` | `migration: String`, `lockHolder: String?` | The migration advisory lock is held by another process. |

`DangerousQueryException` / `FullTableScanException` is the workhorse of three strictness gates: `preventFullTableScans` (reads with no `where`, thrown by `QueryBuilder` before the adapter runs), `preventDestructiveWithoutWhere` (updates/deletes with no `where`, same mechanism), `throwOnN1Queries` (escalated from the N+1 detector inside `LoggingAdapter`). Wrap a deliberate full-table op in `Worm.unsafe(() async { ... })` to bypass these gates for that zone.

#### ConfigurationException key catalog (complete)

| Key | Thrown from | Meaning |
| --- | --- | --- |
| `initialization` | `Worm` statics, active record | Registry accessed before `Worm.initialize` completed. |
| `initialization.duplicate` | `Worm.initialize` | `initialize` called twice without `Worm.reset()`. |
| `adapter.missing` | `Worm.initialize` | No adapter registered for `config.defaultConnection`. |
| `adapter.unknown` | `Worm.adapter`, `Worm.transaction` | Named connection has no registered adapter. |
| `model.unknown` | `Worm.registrationOf`, `Worm.registrationForType` | Model type never registered. |
| `model.tableName.missing` | model lookup | No `tableName` override and no registration resolve a table name. |
| `test_transaction.duplicate` | `Worm.beginTestTransaction` | A test transaction is already active. |
| `morph.duplicate.type` | `MorphRegistry.register` | Morph type key already registered. |
| `morph.duplicate.dart` | `MorphRegistry.register` | Dart type already registered under another morph key. |
| `morph.unknown` | `MorphRegistry` | Resolving a morph type never registered. |
| `relation.unknown` | eager loader | Eager-load path names a relation the model never declared. |
| `where.shape` | `QueryBuilder.where` | `where()` received an unsupported argument shape. |
| `relationQuery.where.shape` | relation subqueries | Same, inside relation queries. |
| `whereRaw.allowRaw` | `QueryBuilder.whereRaw` | `whereRaw` called without `allowRaw: true`. |
| `chunk.size` | `QueryBuilder.chunk` | Chunk size not greater than zero. |
| `streamChunks.size` | `QueryBuilder.streamChunks` | Chunk size not greater than zero. |
| `maxTotalConnections` | pool construction | A new pool would exceed the per-isolate `maxTotalConnections` cap with nothing available. |
| `scope.shim` | internal scope shim | Internal invariant; should never surface in user code. |

#### Strictness guardrail map (each flag maps to exactly one exception; all default `false`)

| Flag | Exception thrown | Thrown by |
| --- | --- | --- |
| `preventSilentMassAssignment` | `MassAssignmentException` | `Model.fill` |
| `preventLazyLoading` | `LazyLoadingException` | relation accessors |
| `preventFullTableScans` | `FullTableScanException` | `QueryBuilder` (reads) |
| `preventDestructiveWithoutWhere` | `FullTableScanException` | `QueryBuilder` (updates, deletes) |
| `throwOnN1Queries` | `DangerousQueryException` | `LoggingAdapter` |

Without `preventLazyLoading`, unloaded relation access throws `RelationNotLoadedException`. `warnOnN1Queries` and `warnOnMissingIndex` log warnings and never throw. `IrreversibleMigrationException` and `MigrationLockException` extend `WormException` directly; a catch on `AdapterException` will NOT see them, even though `MigrationException` (a failed apply) is under `AdapterException`.

#### Umbrella catch example

```dart
try {
  await user.save();
} on ValidationException catch (e) {
  final errors = e.errors;         // Map<String, List<String>>, JSON-API shaped
} on ModelException {              // mass assignment, missing model, cast, relation, uninitialized
} on AdapterException {            // connection, auth, constraint, query, transaction, migration apply, mismatch
} on WormException {               // catch-all; also the only umbrella that sees FullTableScan/Configuration/etc.
}
```

### 10.4 Security

#### Parameterization everywhere

Typed queries cannot inject. Every typed-field query compiles to an immutable descriptor; the driver's compiler renders SQL with positional placeholders + a separate parameter list. Postgres binds `$1, $2, ...`; MySQL and SQLite bind `?`; MongoDB receives structured filter maps, never concatenated strings. Values never become statement text. Holds for `where` predicates, `insert`/`update` values, `inList` items, `between` bounds. `orderBy` and `select` accept typed fields (identifiers only), not strings.

```dart
final users = await User.query().where(User$.email.eq(userInput)).get(); // userInput bound, never spliced
```

`toSql()` inlines literals for readability. That string is for your eyes only; worm never executes it and neither should you.

#### Raw escape hatches: the only developer-trusted (verbatim) surfaces

Four surfaces pass text/maps through verbatim. These are the only places injection is possible; each treats the string as code you wrote, not data:

| Surface | What is trusted (verbatim) | What is still bound |
| --- | --- | --- |
| `whereRaw(sql, parameters:, allowRaw: true)` | the SQL fragment | every value in `parameters` |
| `.sql((q) => q.having(expression, operator, value))` | the aggregate expression string | the comparison `value` |
| `.mongo((m) => m.withRawFilter(...))` and `withPipeline(...)` | the whole filter map / pipeline stages | nothing |
| `adapter.rawQuery(sql, params)` / `rawExecute(sql, params)` | the SQL statement | every value in `params` |

`whereRaw` refuses to run without `allowRaw: true` and otherwise throws `ConfigurationException` (key `whereRaw.allowRaw`). The flag makes the trust decision visible at the call site.

```dart
// Correct: fragment is a constant you wrote; value travels as a bound parameter.
final rows = await User.query()
    .whereRaw('LOWER(email) = ?', parameters: [input.toLowerCase()], allowRaw: true)
    .get();

// NEVER: input becomes SQL text and can rewrite the query.
final bad = await User.query()
    .whereRaw("email = '$input'", allowRaw: true)
    .get();
```

Rule: raw strings must be constants or come from your own code. Anything a user typed goes through `parameters` or a typed predicate.

#### Mass-assignment strict mode

`fill()` and `update()` apply request-shaped maps. Declare assignability on the model with `fillable` / `guarded` overrides (see Models). By default offending keys are silently skipped, which hides bugs and probing. Turn on strict mode in production:

```dart
await Worm.initialize(
  config: const WormConfig(
    strictness: StrictnessConfig(preventSilentMassAssignment: true),
  ),
  adapters: {'default': adapter},
);
```

With the flag on, `fill()` throws `MassAssignmentException` listing every offending key in `.fields` (`.field` holds only the first). A single model can opt in by overriding `strictMassAssignment` to `true`. `Worm.unsafe` bypasses the global flag inside its zone; audit every `unsafe` block. Guarded attributes are still writable through `setAttribute` and direct field assignment; `fillable`/`guarded` only govern `fill()` and `update()` maps.

Validation rules run automatically on `save()` and throw `ValidationException` before anything reaches the DB. `ValidationException.errors` (`Map<String, List<String>>`) is safe to return to clients. Use `Unique(exceptId: id)` on update paths so they do not collide with the row being updated. DB-level `UniqueConstraintException` converts to the same shape via `ValidationException.fromUniqueConstraint`.

#### Serialization is not a redaction boundary

`hiddenFromSerialization` removes keys from `toMap()` / `toJson()`:

```dart
@override
Set<String> get hiddenFromSerialization => const {'password_hash'};
```

Caveats: not a redaction boundary for identifiers. The cycle-aware serializer emits `{type, id, ref: true}` stubs when it collapses a repeated node, so primary keys appear by design. Per-call `toMap(hidden: ...)` / `toMap(only: ...)` refine one call; they do not change the model's default shape.

#### Field-level encryption and its limits

`EncryptedCast` is an abstract skeleton: it handles null passthrough and type checks; you implement `encryptString` and `decryptString` with your own primitive (AES-GCM, libsodium, a KMS call). worm ships no cipher, no key management, no default format. There is NO encryption-at-rest, NO SQLCipher, and no encrypted database file support in any shipped driver. Encrypted columns are opaque to the database: you cannot filter, sort, or index on their plaintext. For whole-database encryption solve it at the infrastructure layer (encrypted volumes, managed DB encryption).

#### Query log redaction

Query logs include bound parameters by default, so user data lands in log files. Redact in production:

```dart
final logger = QueryLogger.fromConfig(
  const LogConfig(file: '/var/log/worm.log', logQueryParameters: false),
);
```

Every line then prints `params: [REDACTED]`.

#### Transport security

- MySQL: `MysqlConnectionPool.fromUri` with `?ssl=true` installs a PERMISSIVE certificate callback that accepts any certificate (including a man-in-the-middle's). In production pass your own `onBadCertificate`, or use `fromConfig` (installs no permissive default) and verify the chain.
- PostgreSQL: `ConnectionConfig(useSsl: true)` maps to the driver's `SslMode.require`; `false` disables TLS entirely.

#### Credentials

`ConnectionConfig` carries `username`/`password` as plain metadata; worm never persists or logs them, but the config is only as safe as its source. Read from the environment at startup; never commit:

```dart
final config = ConnectionConfig(
  driver: 'postgres',
  host: Platform.environment['DB_HOST'] ?? 'localhost',
  database: 'app',
  username: Platform.environment['DB_USER'],
  password: Platform.environment['DB_PASSWORD'],
  useSsl: true,
);
```

#### Destructive operation gates

The CLI refuses `migrate:fresh` and `migrate:refresh` in production without `--force` (writes `error: refusing to run destructive command in production without --force` to stderr, exits code 1). `schema:dump --prune` requires `--force` in EVERY environment (it deletes every migration file under `migrations/`). `db:seed --force` is NOT a production gate: it bypasses the seeder environment filter, making it more dangerous in production, not less. Never put it in a deploy script.

### 10.5 Performance

#### Fix N+1 first

worm never lazy-loads, so an N+1 is always explicit code (a query in a loop). Replace with eager loading (see Relations):

```dart
// N+1: one query for users, one per user for posts
final users = await User.query().get();
// Eager: exactly one extra query per relation path
final users = await User.query().withRelationPaths(['posts']).get();
```

Turn on `warnOnN1Queries` (or `throwOnN1Queries` in CI) to surface loops. If you only need a number or flag per parent, do not load the relation: `withCount`, `withSum`, `withExists` inject aggregates in bulk, pushed to the DB.

#### Let the database count

Aggregate terminals (`count`, `sum`, `avg`, `min`, `max`) compile to aggregate queries; they never pull rows into Dart. Use `exists()` instead of `count() > 0`: `exists()` is a `LIMIT 1` probe that stops at the first match; `count()` counts every match. Use `pluck()` when you need a single column (projects just that column instead of hydrating full models).

#### Stream large result sets

`get()` materializes every row. For exports/backfills/batch jobs use `stream()`, `chunk(size, callback)`, or `streamChunks(size)` for bounded memory (`chunk`/`streamChunks` throw `ConfigurationException` if size is not greater than zero). How bounded depends on the driver: some stream from a live cursor, others buffer per page.

#### Paginate deep lists with cursors

Offset `paginate` runs two queries (page select + count) and gets slower the deeper the page. Cursor `cursorPaginate` runs one query with a `perPage + 1` probe and stays flat at any depth (ascending order only). Offset for page-numbered UIs, cursors for infinite scroll and APIs.

#### Index what you filter

Every column in a hot `where`, `orderBy`, or join should be indexed. Declare indexes in migrations with the blueprint's `index()` / `unique()` (see Migrations). Verify with `query.explain()` on an `ExplainCapable` adapter (Postgres, SQLite, in-memory). Enable `warnOnMissingIndex` in staging. The in-memory adapter always reports an index hit, so verify against a real database.

#### Write less, batch more

- Updates are already minimal: worm tracks dirty fields and `save()` on an existing model sends only changed columns in the `UPDATE`.
- Batch inserts with `insertMany` (one statement for many rows). Trade-off: bulk `insertMany`, `update`, `delete` skip lifecycle hooks and validation.
- Wrap multi-write jobs in one `Worm.transaction` (one commit instead of one per row; large win on drivers that fsync per commit).
- Keep pivot syncs small: `sync()` on a many-to-many issues one query per attached id and one per detached id (a 500-id sync is ~500 queries plus a diff read). Prefer small incremental `attach`/`detach`.

#### Mute events for bulk jobs

Every `save()` dispatches up to six lifecycle events through hooks and observers. For seeding/backfills that is overhead. `Worm.withoutEvents(body)` mutes dispatch for a region (validation still runs); seeders can opt in per class with `muteEvents`.

#### Driver knobs

- PostgreSQL: real connection pool (`poolSize`, `maxTotalConnections` with per-isolate reservation), native `RETURNING`, partial indexes, JSON-format EXPLAIN.
- SQLite: single connection with WAL, 128-entry LRU prepared-statement cache (cleared by DDL), automatic chunking of `IN` lists past 900 parameters.
- MySQL: server-side prepared statements per call; its statement cache is for observability, not reuse.
- In-memory: everything is a Dart map operation; the ORM-layer baseline.

`poolSize` defaults to 10; raising it helps concurrent handling until the DB's own connection limit is the bottleneck.

#### Strictness as tripwires

`warnOnN1Queries` and `warnOnMissingIndex` surface the two most common silent slowdowns. `preventFullTableScans` and `preventDestructiveWithoutWhere` stop accidental whole-table work. `slowQueryThreshold` (500 ms default on `StrictnessConfig`) feeds slow-query capture. Keep `throwOnN1Queries` OFF in bulk-write and benchmark suites: rapid single-row writes can look like N+1 and abort the job with `DangerousQueryException`. Warn there instead.

#### Honest non-features (design)

- No identity map. Two queries for the same row give two independent instances; mutating one does not update the other. Fetch once and pass it along if you need one authoritative instance.
- No partial-model projection. worm hydrates whole rows into whole models. For a slice use `pluck()` (one column) or the adapter raw layer; do not hydrate models with holes.
- No lazy loading. Accessing an unloaded relation throws (`RelationNotLoadedException`, or `LazyLoadingException` under `preventLazyLoading`). Always eager load.
- No query cache. Every terminal hits the database. Cache at the application layer where you can invalidate it.

### 10.6 Glossary

- **Adapter vs driver**: an adapter is a class implementing `DatabaseAdapter`, compiling descriptors into native operations for one backend; a driver is the package shipping an adapter (for example `worm_postgres`).
- **Batch**: the group of migrations applied together by one `migrate` run; each batch gets a number in `worm_migrations`, and rollback reverts the most recent batch as a unit.
- **Capability**: one flag on `AdapterCapabilities` declaring what an adapter can do (`supportsTransactions`, `supportsJoins`, and more). Capabilities describe; enforcement is the adapter's job. All flags default to `false`.
- **Cast**: a bidirectional conversion between a Dart field type and its stored form, defined by an `AttributeCast` (`DateTimeCast`, `EnumCast`, `JsonMapCast`). Decodes on hydration, encodes on insert/update.
- **Chainable vs terminal**: a chainable `QueryBuilder` method returns a new builder without touching the DB (`where`, `orderBy`, `limit`); a terminal executes and produces a result (`get`, `first`, `count`, `paginate`). Nothing runs until a terminal.
- **Companion class**: the generated `User$` class (model name + `$`) holding one typed `Field` constant per column and one `RelationField` per relation. Makes `User$.age.gte(18)` compile-checked.
- **Descriptor**: an immutable, database-agnostic description of one operation (`QueryDescriptor`, `InsertDescriptor`, `SchemaDescriptor`). The builder produces descriptors; adapters compile them to native queries.
- **Dirty**: a field changed since hydration or the last save (`isDirty`, `dirtyFields`). worm writes only dirty fields on update.
- **Eager loading**: loading related models in batches up front alongside the parent query. worm's only relation-loading strategy; there is no lazy loading.
- **Factory state**: a named variation of a factory's base definition, applied with `state('name')`. Requesting an undeclared state throws `FactoryException`.
- **Hydration**: turning a raw `Map<String, Object?>` row into a typed model via the generated `fromRow`; reverse is `toRow`.
- **Morph**: a polymorphic relation; one child table pointing at parents of several types through `<name>_type` + `<name>_id`. Types registered in `MorphRegistry`.
- **Pivot**: the join table of a many-to-many relation. Conventional name is the two singular snake_case class names joined alphabetically (`role_user`).
- **Savepoint**: a nested rollback boundary inside an open transaction, created with `txn.savepoint(() async { ... })`. A throw inside undoes only the savepoint; the outer transaction survives.
- **Scope**: a reusable named query constraint. Local scopes are methods annotated `@Scope()` applied per query; global scopes (`GlobalScope<T>`) apply to every query for a model unless removed.
- **Seeder**: a class inserting baseline/demo rows, tagged with a target `Environment` and order. Runs can be tracked in `worm_seeders` for idempotence.
- **Soft delete**: marking a row deleted by setting `deleted_at` instead of removing it. Soft-deleted rows are hidden from queries by default and can be restored.
- **Strictness**: the opt-in guardrail flags on `StrictnessConfig`. All default off; each maps to one typed exception.

### 10.7 NEVER DO / NOT IMPLEMENTED

These are features agents commonly invent. In worm they do NOT exist. Generate the stated alternative.

- **Dart macros codegen.** worm's codegen is `build_runner` based via `worm_generator`; run `worm gen`. There is no macro path.
- **MongoDB multi-document transactions.** `MongoAdapter.transaction()` throws `TransactionException` by design (the `mongo_dart` driver exposes no session API). Never wrap Mongo writes in `Worm.transaction`.
- **`Worm.sqlite(path)` / `Worm.postgres(url)` convenience constructors.** They do not exist. Construct an adapter (`SqliteAdapter`, `PostgresAdapter`, ...) and pass it: `Worm.initialize(adapters: {'default': adapter})`.
- **Lazy loading.** None, by design. Accessing an unloaded relation throws `RelationNotLoadedException` (or `LazyLoadingException` under `preventLazyLoading`). Eager load with `withRelations` / `withRelationPaths`.
- **Identity map / second-level cache.** Two queries for the same row return two distinct instances.
- **Column projection on eager loads / partial models.** Relations always hydrate full models. No `select` on an eager-load constraint produces a partial model.
- **SQLCipher / encryption-at-rest.** No shipped driver encrypts database files. `EncryptedCast` is a field-level, bring-your-own-crypto abstract class.
- **`whereHas`.** Not part of the API. Use `withExists` or SQL joins via `.sql()`.
- **The annotations `@Hidden`, `@Appended`, `@Attribute`, `@CastAs`, `@Fillable`, `@Guarded`, `@Computed` as working features.** They are experimental and not wired (they only feed an opt-in `_$XAnnotations` mixin). Use the `Model` overrides: `fillable`, `guarded`, `strictMassAssignment`, `hiddenFromSerialization`, `computedAttributes`.
- **`Model.query()` as an inherited/generated method.** It is NOT inherited from `Model` and codegen does NOT put a `query()` on the class. Codegen emits `extension UserQuery on User { static QueryBuilder<User> query() ... }`, so the generated entry point is `UserQuery.query()`. To write `User.query()` the model must declare the one-line `static QueryBuilder<User> query() => ...` shown in the canonical model (see Models).

Canonical spellings (code-true; aliases from other ORMs are wrong): operators `Operator.eq, neq, gt, gte, lt, lte`, list membership `field.inList(...)` / `field.notInList(...)`; blueprint primary keys `idUuid()` / `idIncrements()`; pagination `paginate(...)` returns a `Page` with rows in `Page.data`, cursor `cursorPaginate(cursor: ...)` (passing both `cursor:` and `after:` throws `ArgumentError`); uniqueness rule `Unique(exceptId: ...)`; eager by string path `withRelationPaths(['author'])`; migration tracking table `worm_migrations`, seeder tracking table `worm_seeders`; `DangerousQueryException` is a typedef of `FullTableScanException` (both catch the same class).
