---
title: Cheatsheet
description: Copy-paste worm, bootstrap to exceptions, verified against the current API on one page.
---

*Everything a hungry bird needs, on one page.* Every block below is verified against the current API. For per-flag CLI detail see [CLI commands](./cli-commands.md).

## Bootstrap

Initialize once before any persistence; reset in test teardown.

```dart
import 'package:worm/worm.dart';

Future<void> main() async {
  final adapter = InMemoryAdapter(); // or a driver adapter from worm_sqlite, worm_postgres, ...
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  ); // in-memory needs the table up front; SQL drivers run migrations instead
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
    models: const <ModelRegistration>[
      ModelRegistration(type: User, tableName: 'users'),
    ],
  );
}
```

```dart
await Worm.reset(); // back to uninitialized (tests: tearDown(Worm.reset))
```

## Model skeleton

Annotated model (codegen input; `worm gen` writes `user.g.dart` with `User$` typed fields, `UserHydration.fromRow`/`toRow`, and the `UserQuery.query()` starter):

```dart title="lib/models/user.dart"
import 'package:worm/worm.dart';

part 'user.g.dart';

@Table(name: 'users')
final class User extends Model {
  User({required this.id, required this.name, this.age});

  @PrimaryKey()
  @Column()
  @override
  final String id;

  @Column()
  final String name;

  @Column()
  final int? age;

  @override
  String get tableName => User$.tableName;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': id,
    'name': name,
    'age': age,
  };

  // One-line forwarder so call sites read `User.query()`.
  static QueryBuilder<User> query() => UserQuery.query();
}
```

Hand-written model (no codegen; attribute store):

```dart
final class User extends Model {
  User({required String id, required String name}) {
    setAttribute('id', id);
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
  Map<String, Object?> toRow() => <String, Object?>{
    'id': getAttribute('id'),
    'name': getAttribute('name'),
  };

  static QueryBuilder<User> query() => QueryBuilder<User>.from(
        QueryContext<User>(
          adapter: Worm.adapter(),
          table: 'users',
          hydrate: User.fromRow,
        ),
      );
}
```

## CRUD one-liners

`User.query()` is the model's one-line static forwarding to the generated `UserQuery.query()` starter in `user.g.dart`.

```dart
final user = User(id: 'u1', name: 'Alice', age: 34);
await user.save();                    // INSERT when new, UPDATE (dirty columns only) when persisted
await user.update({'name': 'Bob'});   // fill(...) + save() in one call
await user.refresh();                 // re-read; throws ModelNotFoundException if the row is gone
await user.delete();                  // delete (fires hooks; walks ormCascadeSpecs children first)

final all    = await User.query().get();
final first  = await User.query().first();       // null when empty
final one    = await User.query().firstOrFail(); // throws ModelNotFoundException
final byId   = await User.query().find('u1');    // null when missing
final strict = await User.query().findOrFail('u1');
final n      = await User.query().where(User$.age.gte(18)).count();
final any    = await User.query().where(User$.age.gte(65)).exists(); // LIMIT 1 probe
final names  = await User.query().pluck<String>(User$.name);
final total  = await User.query().sum(User$.age);   // num?
final mean   = await User.query().avg(User$.age);   // double?
final oldest = await User.query().max<int>(User$.age);

// Bulk (no hooks, no validation; global scopes still apply)
final updated  = await User.query().where(User$.age.lt(18)).update({'active': false});
final deleted  = await User.query().where(User$.age.isNull()).delete();
final inserted = await User.query().insertMany([
  {'id': 'u2', 'name': 'Carol'},
  {'id': 'u3', 'name': 'Dave'},
]);
```

## Where and operators

Three `where()` shapes, grouping, subqueries, raw:

```dart
final q = User.query();

await q.where(User$.age.gte(18)).get();            // PredicateTree from typed fields
await q.where(User$.name, 'Alice').first();        // (field, value) sugar for eq
await q.where(User$.age, Operator.gte, 65).get();  // explicit operator

await q
    .whereGroup((g) => g.where(User$.name.eq('Alice')).orWhere(User$.name.eq('Bob')))
    .where(User$.age.gte(18))
    .orderBy(User$.age, descending: true)
    .limit(10)
    .offset(20)
    .distinct()
    .get();

final published = Post.query().where(Post$.published.eq(true));
await q.whereExists(published).get();
await q.whereNotExists(published).get();
await q.whereColumn(User$.age, const ComparableField<int>('login_count')).get();
await q.whereRaw('age % 2 = 0', allowRaw: true).get(); // opt-in, never from user input
```

Operators by field class (wrong combinations are compile errors):

| Field class | Operators |
|---|---|
| `Field<T>` (every field) | `eq`, `neq`, `isNull()`, `isNotNull()`, `inList`, `notInList` (aliases `whereIn`, `whereNotIn`) |
| `ComparableField<T>` | all of the above plus `gt`, `gte`, `lt`, `lte`, `between(lo, hi)`, `notBetween(lo, hi)` |
| `StringField` | all `Field<T>` operators plus `like`, `notLike`, `ilike`, `contains`, `startsWith`, `endsWith` |

| `Operator` enum values | Long-form aliases (identical constants) |
|---|---|
| `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `like`, `notLike`, `ilike`, `isNull`, `isNotNull`, `inList`, `notInList`, `between`, `notBetween` | `Operator.equals`, `notEquals`, `greaterThan`, `greaterThanOrEqualTo`, `lessThan`, `lessThanOrEqualTo` |

Predicate combinators: `a.and(b)`, `a.or(b)`, `a.not()`, `a.group()`.

## Scopes

```dart
final class TenantScope extends GlobalScope<Model> {
  const TenantScope();

  @override
  String get name => 'tenant';

  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) =>
      builder.where(const Field<String>('tenant_id').eq('acme'));
}

await q.withoutGlobalScope<TenantScope>().get(); // bypass one (silent no-op when unregistered)
await q.withoutGlobalScopes().get();             // bypass all
await q.scope(CallableLocalScope((b) => b.where(User$.age.gte(18)))).get(); // ad hoc local scope
await q.withTrashed().get();                     // include soft-deleted rows
await q.onlyTrashed().get();                     // only soft-deleted rows
```

## Eager loading and aggregates

No lazy loading exists; load relations up front or `getRelation` throws.

```dart
final users = await q.withRelationPaths(['posts', 'posts.comments']).get(); // string paths
final u2 = await q.withRelation(User$.posts, Post$.published.eq(true)).get(); // typed + constraint
final u3 = await q.withPath(User$.posts.include([Post$.comments])).get();     // typed nested

final posts = users.first.getRelation<List<Post>>('posts'); // throws RelationNotLoadedException if unloaded

final counted = await q.withCount('posts').withSum('posts', 'views').withExists('posts').get();
final count  = counted.first.getInjected<int>('postsCount');
final sum    = counted.first.getInjected<num>('postsSum');    // 0 when no children
final has    = counted.first.getInjected<bool>('postsExists');
```

## Pagination

```dart
final page = await q.orderBy(User$.name).paginate(page: 2, perPage: 25); // defaults: page 1, perPage 15
// page.data, page.total, page.currentPage, page.perPage,
// page.lastPage (always >= 1), page.hasMorePages, page.from, page.to

final c1 = await q.cursorPaginate(perPage: 50);                    // default perPage 15
final c2 = await q.cursorPaginate(perPage: 50, after: c1.nextToken); // opaque token round-trip
// c1.data, c1.nextCursor, c1.nextToken, c1.hasMorePages
// passing both cursor: and after: throws ArgumentError
```

## Transactions

```dart
await Worm.transaction((txn) async {
  await user.save(); // ambient: enlists automatically, no txn parameter needed

  await Worm.transaction((inner) async {
    // same connection: joins the outer transaction, no second BEGIN
  });

  await txn.savepoint(() async {
    // on throw, rolls back to the savepoint; the outer transaction survives
  });

  user.afterCommit(() {
    // runs once after COMMIT; discarded on rollback
  });
});
```

## CLI commands

Full detail on [CLI commands](./cli-commands.md).

| Command | Flags | What it does |
|---|---|---|
| `worm init` | (none) | Scaffold project layout and `config/worm_config.dart`; idempotent |
| `worm make:model <ClassName>` | `--all` / `-a` | Model under `lib/models/`; `--all` adds migration, seeder, factory |
| `worm make:migration <snake_name>` | `--table` / `-t <table>`, `--auto` | Timestamped migration under `migrations/`; `--auto` diffs `schema/schema.json` against the live schema |
| `worm make:seeder <ClassName>` | `--table` / `-t <table>` | Seeder skeleton under `seeds/` |
| `worm make:factory <ClassName>` | `--model` / `-m <ModelClass>` | Factory skeleton under `lib/factories/` |
| `worm make:observer <ClassName>` | `--model` / `-m <ModelClass>` | Observer skeleton under `lib/src/observer/` |
| `worm migrate` | `--pretend`, `--step=N` | Apply pending migrations as one batch |
| `worm migrate:rollback` | `--steps=N` (default 1) | Revert the last N batches |
| `worm migrate:status` | (none) | Applied/pending table with batch numbers |
| `worm migrate:fresh` | `--seed`, `--force` | Drop the tracking table, re-apply everything; `--force` required in production |
| `worm migrate:refresh` | `--force` | Roll back everything, then re-apply; `--force` required in production |
| `worm db:seed` | `--class=<Name>`, `--env=<name>`, `--force`, `--only=<Name>` (deprecated) | Run seeders; `--force` bypasses the environment filter |
| `worm schema:dump` | `--prune`, `--force` | Write `schema/schema_dump.dart`; `--prune` deletes migration files and requires `--force` in every environment |
| `worm model:show <ModelName>` | (none) | Print table name, fields, and relations of a registered model |
| `worm gen` | `--watch`, `--clean`, `--[no-]delete-conflicting-outputs` (default on) | Run build_runner code generation |

Exit codes: `0` success, `1` force-gate refusal or model not found, `2` usage error, `64` missing required argument, `65` refusing to overwrite an existing file.

## Migration skeleton

Register every migration in your `CliContext(migrations: [...])`.

```dart title="migrations/20260101_120000_create_users_table.dart"
import 'package:worm/worm.dart';

final class CreateUsersTable extends Migration {
  const CreateUsersTable();

  @override
  String get name => '20260101_120000_create_users_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('users', (table) {
      table.idUuid();                       // or table.idIncrements()
      table.string('email').makeUnique();   // VARCHAR(255)
      table.string('name');
      table.integer('age').makeNullable();  // columns are NOT NULL by default
      table.boolean('active').withDefault(true);
      table.uuid('team_id');
      table.timestamps();                   // nullable created_at / updated_at
      table.softDeletes();                  // nullable deleted_at
      table.index(['email']);
      table.foreign(
        column: 'team_id',
        references: 'id',
        onTable: 'teams',
        onDelete: OnDelete.cascade,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    await schema.drop('users', ifExists: true);
  }
}
```

## Seeder skeleton

Register in `CliContext(seeders: [...])`; run with `worm db:seed`.

```dart title="seeds/user_seeder.dart"
import 'package:worm/worm.dart';

final class UserSeeder extends Seeder {
  const UserSeeder();

  @override
  String get name => 'UserSeeder';

  @override
  Environment get environment => Environment.development; // default: Environment.all

  @override
  int get order => 1; // lower runs first; default 0

  @override
  bool get muteEvents => true; // wraps run() in Worm.withoutEvents; default false

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    await adapter.insert(
      const InsertDescriptor(
        table: 'users',
        values: <String, Object?>{'id': 'u1', 'name': 'Alice'},
      ),
    );
  }
}
```

## Factory skeleton

```dart title="lib/factories/user_factory.dart"
import 'package:worm/worm.dart';

final class UserFactory extends Factory<User> {
  static final Sequence _ids = Sequence();

  @override
  User definition() =>
      User(id: 'u${_ids.next()}', name: faker.firstName(), age: 30);

  @override
  Map<String, FactoryState<User>> get stateVariations =>
      <String, FactoryState<User>>{
        'senior': (base) => base..setAttribute('age', 70),
      };
}
```

```dart
final built = UserFactory().make();                              // build only, no persist
final saved = await UserFactory().create();                      // save (hooks + validation run)
final named = await UserFactory().create(overrides: {'name': 'Zed'});
final five  = await UserFactory().count(5).create();
final ab    = await UserFactory().sequence([{'name': 'a'}, {'name': 'b'}]).count(4).create();
final old   = await UserFactory().state('senior').create();      // unknown name throws FactoryException
await UserFactory().has(PostFactory().count(3), User$.posts).create(); // parent plus 3 linked children
await PostFactory().for_(saved, User$.posts).count(3).create();        // children with FK pre-filled
Worm.seedRandom(42); // deterministic faker output
```

## Test setup

```dart title="test/user_test.dart"
import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'users'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, DatabaseAdapter>{'default': adapter},
      models: const <ModelRegistration>[
        ModelRegistration(type: User, tableName: 'users'),
      ],
    );
  });

  tearDown(Worm.reset);

  test('writes roll back per test', () async {
    await Worm.beginTestTransaction();
    addTearDown(Worm.rollbackTestTransaction);
    // every save in here is rolled back after the test
  });
}
```

## Strictness flags

All flags default to `false`; enable per deployment via `WormConfig(strictness: ...)`.

```dart
const strict = StrictnessConfig(
  preventLazyLoading: true,             // unloaded relation access throws LazyLoadingException
  preventFullTableScans: true,          // no-WHERE reads throw FullTableScanException
  preventSilentMassAssignment: true,    // guarded fill() throws MassAssignmentException
  warnOnN1Queries: true,                // log detected N+1 patterns
  throwOnN1Queries: true,               // escalate N+1 to a thrown exception
  warnOnMissingIndex: true,             // log when EXPLAIN shows no index use
  preventDestructiveWithoutWhere: true, // UPDATE/DELETE without WHERE throws
  slowQueryThreshold: Duration(milliseconds: 500), // slow-query warning threshold
);

await Worm.initialize(
  config: const WormConfig(strictness: strict),
  adapters: <String, DatabaseAdapter>{'default': adapter},
);

final rows = await Worm.unsafe(() => User.query().get()); // zone-scoped bypass of all guards
```

## Top exceptions

| Exception | Thrown when |
|---|---|
| `ConfigurationException` | ORM use before `Worm.initialize`, duplicate initialize, missing adapter or table name, invalid `where(...)` shape, `whereRaw` without `allowRaw: true`, `chunk`/`streamChunks` size of zero or less |
| `ModelNotFoundException` | `firstOrFail`, `findOrFail`, `refresh()` on a deleted row, `Repository.findOrFail` |
| `ValidationException` | `rules`/`updateRules` fail during `save()` |
| `MassAssignmentException` | `fill()` hits guarded or non-fillable keys under strict mass assignment |
| `RelationNotLoadedException` | `getRelation` on a relation that was never eager loaded |
| `LazyLoadingException` | The same access with `preventLazyLoading: true` |
| `UninitializedFieldException` | `getInjected` without a matching `withCount`/`withSum`/`withExists` |
| `FullTableScanException` | Scan or no-WHERE write blocked by a strict flag (`DangerousQueryException` is a typedef alias) |
| `AdapterMismatchException` | `.sql()` against a Mongo adapter, or `.mongo()` against a SQL adapter |
| `CastException` | `min<V>`/`max<V>` result does not match `V`; cast decode failures |
| `UnsupportedOperationException` | `explain()` on a non-`ExplainCapable` adapter, `replicate()` without generated code, transactions or savepoints the adapter cannot provide |
| `TransactionException` | Transaction failures; the MongoDB adapter throws it for multi-document transactions by design |
| `MigrationException` | Migration up/down failure, unknown or cyclic `dependsOn`, recorded migration missing from the registered list |
| `IrreversibleMigrationException` | Thrown from your own `downSchema` to mark a migration irreversible |
| `FactoryException` | `Factory.state(...)` with an unknown state name |
| `WormException` / `AdapterException` / `ModelException` | Abstract bases for catching whole categories |

## Continue reading

- [CLI commands](./cli-commands.md): every command, flag, default, and exit code in full detail.
- [Exceptions](./exceptions.md): the complete exception hierarchy and every throw site.
- [AI agents](../guides/ai-agents.md): how to navigate these docs programmatically.
- [Quickstart](../start-here/quickstart.md): the guided zero-to-first-query path.
