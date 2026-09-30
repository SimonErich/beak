# An existing backend

> Keep your REST or RPC backend and let the Beak panel talk to it through model-owned transports, with your own permissions, error mapping and a contract suite.

You have a backend that already owns its models, authorization and business operations, and you want Beak's panel in front of it. After this page you know which of the three ways to connect fits, what the panel does and does not do on top of your API, and how to prove your adapter behaves.

Beak's default backend is a Shelf server over the worm ORM, and none of it is needed here. The panel talks to a `BeakDataSource`, an interface in `beak_core`, and a source is whatever you write behind it.

## At a glance

| Way | Beak runs | Your backend stays | Pick it when |
| --- | --- | --- | --- |
| Model-owned transport | The panel only | The API, its auth and its rules | You have a REST or RPC API and will not move the data |
| Beak server over your database | The whole stack | Only the database | You own the database and would rather not maintain the API ([An existing database](existing-database.md)) |
| A custom source on Beak's server | The panel and the generated routes | Your storage | The storage is not SQL. Saves are limited today, see below |

This page is about the first row. You bind a transport to a `BeakModel` once, register the resource once, and the panel finds the transport by itself. There is no second list mapping resources to sources.

```dart title="packages/beak_frontend/test/src/panel/model_configuration_test.dart"
final class _BoundModel extends BeakModel {
  const _BoundModel({
    this.dataSource,
    this.permissions = const BeakPermissions.allowAll(),
    this.capabilities = const {BeakOperation.read},
  });

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const NoteModel().columns;

  @override
  final BeakDataSource? dataSource;

  @override
  final BeakPermissions permissions;

  @override
  final Set<BeakOperation> capabilities;
}
```

A `BeakModel` is metadata plus five optional hooks (`dataSource`, `capabilities`, `permissions`, `createModel`, `editModel`). These are the ones to know first:

| Hook | Default | What the panel does with it |
| --- | --- | --- |
| `dataSource` | `null` | Routes every query and write for `table` to it. Return a stable instance. |
| `capabilities` | read, create, update, delete | Hides what the transport cannot do. An API without an update endpoint drops `update`, and the edit action disappears. |
| `permissions` | `BeakPermissions.allowAll()` | Live yes-or-no callbacks per operation, read each time, so a refresh changes access without rebuilding anything. |
| `createModel`, `editModel` | `null` | Separate column sets for the create and edit forms, when your write commands differ from your read DTOs. |

## Build it

1. **Write the model by hand.** A `@Resource` schema class forwards only `permissions` and `capabilities`, and reserves the names `dataSource`, `createModel` and `editModel`. For a foreign API, subclass `BeakModel` directly: a `const` class with a zero-argument constructor anywhere under `lib/` is picked up by `beak prepare` and listed in the generated registry.
2. **Write the data source.** Implement `BeakDataSource`: `query`, `getOne`, `create`, `update`, `delete`, `restore`, `batchGet`, `attach`, `detach`, `aggregate`. Your adapter converts DTOs to `BeakRecord`, translates the query operations it supports, and calls your existing commands. What it must not do is ignore a filter or a sort it cannot honour: throw a typed exception, or the panel shows an unfiltered list as if it were the answer. [Custom data sources](../../extending/custom-data-sources.md) has the contract per method.
3. **Implement `BeakCommitDataSource` if your API can save a graph atomically.** Then a form save is one `commit(plan)` and a crashed save can be resumed with `recover(saveId)`. Without it the panel runs a staged save: one `create` or `update` per operation, in dependency order, stopping at the first failure.
4. **Prove it with the contract suite.** `runBeakDataSourceContract` is the executable specification, and every source Beak ships runs it. It checks the edges that only bite in production: `getOne` returning `null` instead of throwing, `update` throwing when the row is gone, `aggregate` returning `0` over an empty set.
5. **Register the resource and mount the panel.** A `BeakResource` selects the model and adds presentation. If sign-in belongs to your backend, give the panel a `BeakAuthConfig(adapter: ...)`, and bind every model or pass one `dataSource:` to the panel, because with external authentication no HTTP source exists.

```dart title="packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart"
runBeakDataSourceContract(
  'WormDataSource',
  registry: _contractRegistry(),
  model: const NoteModel(),
  create: () async {
    adapter = await createApiTestDatabase();
    return WormDataSource(_contractRegistry(), adapter: adapter);
  },
  seed: (source, model, records) async {
    for (final record in records) {
      await adapter.insert(
        InsertDescriptor(table: model.table, values: record.toRow()),
      );
    }
  },
  sortableTextColumn: NoteColumns.title,
  numericColumn: NoteColumns.rating,
  relationModels: const [NoteModel(), _AuthorWithNotesModel()],
  seedLinks: (source, relation, ownerId, relatedIds) async {
    for (final relatedId in relatedIds) {
      await adapter.insert(
        InsertDescriptor(
          table: relation.pivotTable,
          values: {
            relation.foreignPivotKey: ownerId,
            relation.relatedPivotKey: relatedId,
          },
        ),
      );
    }
  },
);
```

That is the shape of the suite call for `WormDataSource`; yours passes your own `create` and `seed`. [Custom data sources](../../extending/custom-data-sources.md#prove-it-with-the-contract-suite) explains each argument.

## Which source method the panel calls

| Panel action | Source implements `BeakCommitDataSource` | Otherwise |
| --- | --- | --- |
| Form save (create or edit) | `commit(plan)`, resumed with `recover(saveId)` | A staged save, in dependency order, stopping at the first failed or uncertain write |
| Delete and archive | A one-operation `commit` that keeps the model's soft delete | `delete(table, id)` |
| Record page (show, edit) | One `query` filtered on the primary key, with the relations the layout needs | The same |
| Edit page of a model with `editModel` | `loadEditValues(table, id)` when the source implements `BeakEditDataSource` | `getOne`, then the form prefills from the read record |

## Map your errors

Every panel call passes through one wrapper. A `BeakException` goes through untouched. Any other `Exception` goes to `BeakPanelConfig.mapException`, which returns a localized `BeakException` for the failures it recognises and `null` for the rest, so a programming error stays loud. The wrapper covers record reads, mutations, aggregates, uploads and edit-command loading.

`BeakPanel(mapException: ...)` takes the mapper directly. A panel built from a `BeakPanelConfig` sets it there instead, because `config:` together with another everyday option throws.

## Rules and limits

- The panel checks are presentation. `capabilities` and `permissions` hide controls. Your backend has to authorize every call again.
- No Beak validation on your server. Beak's rules run in the panel's forms. Your API stays the authority on what is valid, and the panel shows whatever error you map.
- A custom source on Beak's own server saves staged, not atomic. `POST /api/commits` is mounted for every source, and the panel's HTTP source always saves through it. Over a source that is not a `WormDataSource` on a transactional adapter, the route authorizes every operation first, then writes them through your `create`, `update`, `delete`, `attach` and `detach` in dependency order. There is no rollback, and the receipts live in the server's memory (the newest 1024), so a restart forgets them. Prefer the transport route above, where the panel calls your API directly.
- Serving a custom source takes one argument. `defaults.build(dataSource: MyDataSource())` in `lib/server.dart` replaces the worm source (and `storage:` replaces the resolved storage driver). See [Custom data sources](../../extending/custom-data-sources.md).
- Filters you cannot honour are errors. A bridge-style source that supports only equality filters must throw on the rest; the query spec is Beak's full vocabulary.
- A staged save is not atomic. It stops at the first failed or uncertain write, and the operations before it stay written. A save that touches models bound to different sources is staged too, even when each source could commit on its own.
- The Serverpod bridge is this pattern, generated. `ServerpodResource` is a `BeakModel` that sets all five hooks from a Serverpod client. If your backend is Serverpod, start at [An existing Serverpod project](existing-serverpod-project.md).

## Verify it

Run the contract suite against your source, then boot the panel against it in a widget test:

```console
$ dart test test/my_data_source_contract_test.dart
MyDataSource satisfies the BeakDataSource contract ...
All tests passed!
```

The test count depends on the columns you pass: without a numeric column the sum and average tests are skipped. Then `flutter test`, with your model and a fake transport behind a `BeakPanel`, checks the wiring end to end. [Testing](../../shipping/testing.md) has the harness.

## Reference

| Piece | Where it lives |
| --- | --- |
| `BeakDataSource`, `BeakCommitDataSource`, `BeakEditDataSource` | `package:beak/beak.dart` |
| `BeakModel`, `BeakPermissions`, `BeakOperation` | `package:beak/beak.dart` |
| `BeakPanel`, `BeakPanelConfig(mapException:)`, `BeakAuthConfig` | `package:beak/panel.dart` |
| `runBeakDataSourceContract`, `InMemoryBeakDataSource` | `package:beak/testing.dart` |

## Continue reading

- [Model-owned transports](../../extending/model-transports.md): the hooks, capabilities, permissions and the command models in full.
- [Custom data sources](../../extending/custom-data-sources.md): the interface, its contract per method and the suite.
- [Client bridge](../../serverpod/bridge/index.md): a finished example of the same pattern.
- [Choose your path](index.md): the other starting points.
