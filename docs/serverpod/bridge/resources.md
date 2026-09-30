---
title: Bridge resources
description: Bind typed Serverpod client calls to a Beak resource with ServerpodResource, and learn exactly which queries, writes and features the bridge refuses.
type: guide
audience: [expert]
status: stable
---

# Bridge resources

After this page you can bind the endpoints you already have to a Beak resource by hand, mount it in a panel, and predict which requests the bridge will refuse before a user finds out. Generating the binding is on [Generating bridge resources](generator.md); this page is the runtime it generates against.

## At a glance

A `ServerpodResource<T, Id, Create, Update>` is a `BeakModel` that carries its own data source. You hand it typed callbacks over your generated client, one per operation. Beak stays out of your database: it calls the callbacks, converts the results to `BeakRecord`s, and refuses anything you did not bind.

The examples on this page use the bookshop's `Book`, the class `serverpod generate` writes into `bookshop_client`. The `BookEndpoint` in the test is a stand-in for the `client.books` endpoint a real project would expose; it holds rows in a map so the test runs without a server. The same code compiles unchanged against the generated `Book` in `examples/serverpod/bookshop_client`.

```dart title="packages/beak_serverpod/test/src/bookshop_resource_test.dart"
--8<-- "packages/beak_serverpod/test/src/bookshop_resource_test.dart:bookModel"
```

`ServerpodModel` holds the presentation: which columns exist and which is the display column. `resource` is a logical key you choose, not a table name; Beak never sends it to a server. The codec turns a `Book` into a `BeakRecord` and back, field by field, with the value codecs from `ServerpodCodecs`:

```dart title="packages/beak_serverpod/test/src/bookshop_resource_test.dart"
--8<-- "packages/beak_serverpod/test/src/bookshop_resource_test.dart:bookCodec"
```

With the model and codec in hand, bind the operations. This one binds all nine:

```dart title="packages/beak_serverpod/test/src/bookshop_resource_test.dart"
--8<-- "packages/beak_serverpod/test/src/bookshop_resource_test.dart:bookResource"
```

The `query` callback runs the request through `ServerpodQueryReader` first, so a filter or sort the endpoint cannot answer is refused before any call goes out. `reader.page(0)` translates Beak's 1-based page to the endpoint's origin. The test beside it drives every operation through a `ServerpodDataSource` and checks that a range filter throws.

Only `query` and `get` are required. `create` needs its `createCodec`, `update` its `updateCodec`; without both halves the operation stays unbound. The resource's `capabilities` follow: `read` always, `create`, `update` and `delete` only when bound, so the panel does not offer what would fail.

Mount it like any resource. Because the model brings its data source, the panel needs no `dataSource:`:

```dart
// Illustrative: real class names, assembled for this page.
BeakPanel(
  title: 'Bookshop',
  resources: [BeakResource(model: bookResource(client.books), title: 'Books')],
  auth: BeakAuthConfig(adapter: auth),
)
```

`ServerpodDataSource` is the piece that routes by resource key, and a `ServerpodResource` builds one for itself. To turn your domain exceptions into Beak's typed errors, set `mapException` once on the panel, as `BeakPanel(mapException: ...)` or on the `BeakPanelConfig` you pass as `config:`; it applies to every bound resource.

## Rules and limits

The query rows are the rules of `ServerpodQueryReader`. Generated resources use it, and a hand-written `query:` callback can too; a callback that reads the `BeakQuerySpec` itself accepts whatever you write. The other rows come from `ServerpodResource` and `ServerpodDataSource`. The package's tests cover the query rules and the unbound operations.

| Area | The bridge accepts | Everything else |
| --- | --- | --- |
| Filters | An AND of equality filters on fields you allowlisted, each field at most once | `BeakConfigurationException`: `Unsupported query for resource "<key>".` Ranges, `or`, `not`, contains: all refused |
| Sort | At most one, on a `sortable` column that maps to a value of the endpoint's sort enum | The same exception |
| Search | One term, only if the endpoint takes `search`, only across `searchable` columns | The same exception |
| Paging | `page` and `perPage` of 1 or more, translated to the endpoint's page origin, 0 or 1 | The same exception. A `firstPage` other than 0 or 1 is a `BeakConfigurationException`: `The endpoint page origin must be configured as zero or one.` |
| Relations | Nothing is loaded with the rows. `ServerpodRelationField` reads a nested object from a complete DTO for display | A query with relation loads is refused; attach and detach say `Resource "<key>" does not support attach.` |
| Archived rows | Only if the endpoint takes `includeArchived` | The same exception |
| Count (generated resources) | `count` with no column, computed from the list query's total | `Unsupported aggregate.` |
| Delete | The `archive` callback. `forceDelete` and `restore` only when bound, never inferred | `BeakValidationException`: `Resource "<key>" does not support delete.` |
| Ids | UUID strings and integers, decoded strictly. `42` decodes, `42.5` does not | `BeakValidationException` |
| Form saves | Staged: the panel sends each operation of the save as its own create or update call | No single transaction; the result says `staged`, not `atomic`, and atomicity is your endpoint's |
| Summaries, CSV export | Not implemented | `BeakConfigurationException`: `This data source does not support summaries.` and `This data source does not support CSV exports.` |
| Server-side field permissions | Not implemented; the panel then treats every field as allowed | Your endpoints must enforce, always |
| Errors | A `BeakException` passes through untouched. Another `Exception` goes through `mapException`, and propagates unchanged when that returns `null` | An `Error` is never caught |

Two rules cut across the table:

- `BeakPermissions` on a resource hides controls, nothing else. Every endpoint has to authorize its own operation, because the panel can be bypassed.
- A `BeakPanel` given `dataSource:` replaces every model's own source. Do not set it on a bridge panel, and do not mix bridge resources with tunnel resources in one panel ([the admin app](../admin-app/index.md) sets `dataSource:` on purpose).

If the panel has an authentication adapter and any resource has neither its own source nor a panel `dataSource:`, startup fails with `External authentication requires bound models or a data source.`

Columns default to detail-only. `ServerpodColumnOptions` starts at `visibleOn: {BeakContext.detail}`, so a column that should appear in the table says `BeakContext.table` explicitly. That is deliberate: a bridge exposes what you name.

## Verify it

The runtime is covered by the package's own tests, which run without a server:

```console
$ cd packages/beak_serverpod && dart test
00:00 +30: All tests passed!
```

In your own project, write one test per resource before the first user does. Build the `ServerpodDataSource` with a fake client, call `query` with a spec that uses a range filter and expect the `BeakConfigurationException`. That test documents the limit and fails loudly the day someone adds a range filter to a screen.

## Reference

The constructor, verbatim:

```dart title="packages/beak_serverpod/lib/src/resource.dart"
ServerpodResource({
  required this.model,
  required this.codec,
  required this.idCodec,
  required this.identify,
  BeakPermissions? permissions,
  this.createModel,
  this.editModel,
  this.onChanged,
  required Future<BeakPage<T>> Function(BeakQuerySpec spec) query,
  required Future<T?> Function(Id id) get,
  this.createCodec,
  this.updateCodec,
  this.editValues,
  Future<T> Function(Create input)? create,
  Future<T> Function(Id id, Update input)? update,
  Future<void> Function(Id id)? archive,
  Future<void> Function(Id id)? forceDelete,
  Future<T> Function(Id id)? restore,
  Future<List<T>> Function(List<Id> ids)? batchGet,
  Future<num> Function(BeakAggregateSpec spec)? aggregate,
}) : _permissions = permissions,
// ...
```

`onChanged` runs after a successful write so the host can refresh. It is not part of any server transaction. `createModel` and `editModel` describe the write shape when it differs from the read shape.

The query reader, which turns a `BeakQuerySpec` into the endpoint's own vocabulary and refuses what does not fit:

```dart title="packages/beak_serverpod/lib/src/query.dart"
ServerpodQueryReader({
  required this.spec,
  required this.model,
  required this.fields,
  Set<String> filters = const {},
  bool supportsSearch = false,
  bool supportsSort = true,
  bool supportsArchived = false,
}) {
// ...
```

Its members are `page(firstPage)`, `perPage`, `search`, `descending(fallback)`, `resolveField(name)`, `sort(values, fallback, overrides:)` and `equal(name, codec)`. `fields` maps a property's leaf name to its full paths, and `filters` is the allowlist of names that may arrive as equality filters.

Presentation options per column:

```dart title="packages/beak_serverpod/lib/src/field.dart"
const ServerpodColumnOptions({
  this.visibleOn = const {BeakContext.detail},
  this.sortable = false,
  this.searchable = false,
  this.filterable = false,
  this.rules = const [],
  this.enumLabels = const {},
});
```

Value codecs, all on `ServerpodCodecs`: `string`, `integer`, `decimal`, `boolean`, `dateTime`, `uuid`, `uri` and `enumeration(values)`. Each has `.nullable`, `.list` and `.set`. They never coerce: `false` stays distinct from `null`, a fractional number is not truncated to an integer, and a number is not turned into a string.

The operations a resource can bind, as `ServerpodOperation`: `query`, `get`, `create`, `update`, `delete`, `restore`, `forceDelete`, `batchGet`, `aggregate`.

## Continue reading

- [Generating bridge resources](generator.md): have this binding written from your generated client.
- [Endpoint conventions](endpoint-conventions.md): the endpoint shapes the generator recognizes.
- [Model-owned transports](../../extending/model-transports.md): the mechanism behind a resource that brings its own source.
