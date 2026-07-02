---
title: Soft deletes
description: Trash rows with a deleted_at timestamp instead of removing them, and restore them later.
---

Soft deletes keep "deleted" rows in the table with a `deleted_at` timestamp, so queries can skip them and you can restore them later. This page documents the `SoftDeletes` mixin contract and the query side that hides trashed rows. It builds on [defining models](./defining-models.md) and [saving and updating](./saving-and-updating.md).

Soft-deleted rows aren't gone. They've gone underground. `withTrashed()` digs them up.

## Two halves, one feature

Worm splits soft deletes in two:

- **The `SoftDeletes` mixin** on your model provides `delete()`, `restore()`, `forceDelete()`, and the `deletedAt` state.
- **The `SoftDeleteScope` global scope** on your queries filters out rows where `deleted_at` is not null.

You wire both explicitly. Neither half activates the other.

## The mixin contract

`SoftDeletes` is a mixin `on Model`. Your model must implement two members, and its `toRow()` must include the soft-delete column:

```dart title="user.dart"
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

  // Required by the mixin:
  @override
  DatabaseAdapter get softDeleteAdapter => Worm.adapter();

  @override
  String get softDeleteTable => 'users';

  // toRow() must include the soft-delete column, or the
  // mixin's UPDATE never writes it.
  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': userId,
    'name': name,
    softDeleteColumn: deletedAt?.toIso8601String(),
  };
}
```

The contract in full:

| Member | Required | Default | Purpose |
| --- | --- | --- | --- |
| `softDeleteAdapter` | yes | none | Adapter the mixin uses for its `UPDATE` and `DELETE`. |
| `softDeleteTable` | yes | none | Table the model lives in. |
| `softDeletePrimaryKey` | no | `'id'` | Primary-key column used in the `WHERE` clause. |
| `softDeleteAtColumn` | no | `softDeleteColumn` (`'deleted_at'`) | Column carrying the timestamp. |
| `toRow()` includes the column | yes | none | The mixin persists via `toRow()`; a missing key means the flag never reaches the database. |

Hydrators seed the state through the `deletedAt` setter, as `fromRow` does above.

## Trashing, restoring, and hard deletes

```dart
await user.delete();      // sets deletedAt = DateTime.now(), then UPDATE
user.isTrashed;           // true
await user.restore();     // clears deletedAt, fires restore hooks
await user.forceDelete(); // real DELETE; gone even from withTrashed()
```

What each call does:

- `delete()` sets `deletedAt` to `DateTime.now()` and calls `save()`. It never issues a real `DELETE`. Always returns `true`.
- `restore()` fires `beforeRestore` (return `false` from your hook to cancel; `restore` then returns `false`), clears `deletedAt`, persists, then fires `afterRestore`. This is the **only** hook-firing operation in the mixin.
- `forceDelete()` issues one real `DELETE` keyed by the primary key, bypassing hooks. Returns `true`.
- `isTrashed` is `true` while `deletedAt` is non-null.

## The mixin replaces save()

Mixing in `SoftDeletes` overrides `Model.save()` with a single targeted `UPDATE` of the full `toRow()`, keyed by `softDeletePrimaryKey`. That override applies to every save on the model, not just deletes. Consequences:

- No lifecycle hooks fire, and no validation runs, on `save()` and `delete()`.
- `save()` always returns `true`.
- Timestamps (`updated_at`) are not maintained, and dirty tracking is not synced.
- A `save()` can never `INSERT`. Create rows for soft-delete models through another path, such as the adapter's insert, a [seeder](../database/seeding.md), or a migration.

All writes route through an active transaction when one is in scope: an explicit `transaction:` argument wins, otherwise an ambient `Worm.transaction` on the same connection is joined. See [transactions](../database/transactions.md).

## The query side

`SoftDeleteScope` is a [global scope](../queries/scopes.md) that appends `deleted_at IS NULL` to every query it is registered on:

```dart
final context = QueryContext<User>(
  adapter: Worm.adapter(),
  table: 'users',
  hydrate: User.fromRow,
  globalScopes: const <GlobalScope<Model>>[SoftDeleteScope<User>()],
);

final live = await QueryBuilder<User>.from(context).get();
// Only rows where deleted_at IS NULL.
```

If you use code generation, annotate the model with `@GlobalScope(SoftDeleteScope)` from `package:worm/annotations.dart` and the generated `query()` starter registers the scope for you.

Two builder methods bypass the scope:

```dart
final everyone = await QueryBuilder<User>.from(context).withTrashed().get();
final trashed = await QueryBuilder<User>.from(context).onlyTrashed().get();
```

- `withTrashed()` disables `SoftDeleteScope` for this query via the typed `withoutGlobalScope<SoftDeleteScope<Model>>()` bypass. All rows come back.
- `onlyTrashed({String column = 'deleted_at'})` calls `withTrashed()` and adds `deleted_at IS NOT NULL`. Only trashed rows come back.

The scope's stable name is the `softDeleteScopeName` constant, `'soft_deletes'`. Its filtered column defaults to `'deleted_at'` and is configurable via `SoftDeleteScope(column: ...)`.

## The schema side

The table needs a nullable timestamp column. In a migration, `softDeletes()` adds it:

```dart title="migrations/2026_07_02_000001_create_users.dart"
@override
Future<void> upSchema(Schema schema) => schema.create('users', (table) {
  table.idIncrements();
  table.string('name');
  table.softDeletes(); // nullable deleted_at
});
```

See [schema builder](../database/schema-builder.md) for the full Blueprint surface.

## Gotchas

- `save()`, `delete()`, and `forceDelete()` bypass lifecycle hooks and validation. Only `restore()` fires hooks (`beforeRestore`, cancelable, and `afterRestore`).
- The mixin's `save()` always returns `true`; there is no hook to cancel it.
- `delete()` stamps `deletedAt` with local `DateTime.now()`, not UTC.
- The mixin's `save()` writes the full `toRow()`, not just dirty fields, and never inserts. New rows need another write path.
- Timestamps and dirty tracking are untouched by the mixin's writes: `updated_at` stays stale and `dirtyFields` is not cleared.
- If `toRow()` omits the `deleted_at` key, `delete()` appears to succeed but the flag never reaches the database.
- The mixin and the scope are independent. A model with `SoftDeletes` still shows trashed rows in queries until `SoftDeleteScope` is registered on the query context.
- On a plain model without the mixin, `forceDelete()` is identical to `delete()`.
- `withoutGlobalScopes()` (plural) also disables `SoftDeleteScope`, along with every other global scope.

## API summary

| Symbol | Signature sketch | Description |
| --- | --- | --- |
| `softDeleteColumn` | `const String softDeleteColumn = 'deleted_at'` | Default soft-delete column name. |
| `SoftDeletes` | `mixin SoftDeletes on Model` | Adds soft-delete semantics to a model. |
| `SoftDeletes.softDeleteAdapter` | `DatabaseAdapter get softDeleteAdapter` | Required host override; adapter for the mixin's writes. |
| `SoftDeletes.softDeleteTable` | `String get softDeleteTable` | Required host override; target table. |
| `SoftDeletes.softDeletePrimaryKey` | `String get softDeletePrimaryKey` | Primary-key column; defaults to `'id'`. |
| `SoftDeletes.softDeleteAtColumn` | `String get softDeleteAtColumn` | Timestamp column; defaults to `softDeleteColumn`. |
| `SoftDeletes.deletedAt` | `DateTime? get deletedAt; set deletedAt(DateTime?)` | Current trash timestamp; setter used by hydrators. |
| `SoftDeletes.isTrashed` | `bool get isTrashed` | Whether `deletedAt` is non-null. |
| `SoftDeletes.save` | `Future<bool> save({TransactionContext? transaction})` | Single `UPDATE` of `toRow()` by primary key; bypasses hooks; always `true`. |
| `SoftDeletes.delete` | `Future<bool> delete({TransactionContext? transaction})` | Sets `deletedAt` and saves; never a real `DELETE`; always `true`. |
| `SoftDeletes.restore` | `Future<bool> restore({TransactionContext? transaction})` | Fires restore hooks, clears `deletedAt`, saves; `false` when canceled. |
| `SoftDeletes.forceDelete` | `Future<bool> forceDelete({TransactionContext? transaction})` | Real `DELETE` by primary key; bypasses hooks; always `true`. |
| `SoftDeleteScope<T>` | `const SoftDeleteScope({String column = 'deleted_at'})` | Global scope adding `deleted_at IS NULL`; `name` is `'soft_deletes'`. |
| `softDeleteScopeName` | `const String softDeleteScopeName = 'soft_deletes'` | Stable scope name used for bypassing. |
| `QueryBuilder.withTrashed` | `QueryBuilder<T> withTrashed()` | Disables `SoftDeleteScope` for this query. |
| `QueryBuilder.onlyTrashed` | `QueryBuilder<T> onlyTrashed({String column = 'deleted_at'})` | Only soft-deleted rows. |

## Continue reading

- [Scopes](../queries/scopes.md): global scopes in general; soft deletes are one bundled instance.
- [Schema builder](../database/schema-builder.md): `softDeletes()` and the rest of the Blueprint surface.
- [Lifecycle hooks and observers](./lifecycle-hooks-and-observers.md): what the mixin bypasses, and the restore hooks it fires.
