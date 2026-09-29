# beak_serverpod_generator

Writes the Beak side of a Serverpod client you already have. It reads your
generated `Client` class and its model classes with the Dart analyzer, finds the
endpoint that lists each model, and writes one Dart file: a ready-made
`ServerpodResource` per model, a typed field descriptor per property, and the
codecs between them. Serverpod keeps owning the models, the endpoints, the
authorization and the database. The generator never writes to your server, never
writes a migration and never opens a database.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter.

## When you need it

This is for the client bridge: a Beak panel over endpoints that already return
DTOs, check permissions and hold the business rules, with no change on the
server. Writing the binding by hand is possible
([`beak_serverpod`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod)
documents it), and the generator writes the same thing from the client's Dart
types.

It is not part of the admin app path. There the Beak schema classes mirror your
`.spy.yaml` models by hand, and `beak prepare` generates their parts. Nothing
generates a Beak schema class from a `.spy.yaml` file yet.
[Choosing an integration](https://simonerich.github.io/beak/serverpod/choosing-an-integration/)
says which path fits.

## Install and run

Add the generator as a dev dependency of the package that holds your panel, and
`beak_serverpod` and `beak_core` as runtime dependencies, because the generated
file imports both. If a model has a `UuidValue`, add `uuid` too. Generate
Serverpod's client first, resolve packages, then run the generator.

The config sits next to your `pubspec.yaml`. `library` is the library that
exports `Client` and the models, and the value below is a placeholder for yours:

```yaml
# beak_serverpod.yaml (illustrative: the library URI is a placeholder)
library: package:example_client/example_client.dart
models:
  - EntryView
output: lib/beak/entry_resources.g.dart
```

```console
$ dart run beak_serverpod_generator:generate --config beak_serverpod.yaml
Generated /home/me/consumer/lib/beak/entry_resources.g.dart
```

| Config key | Meaning |
| --- | --- |
| `library` | The library URI that exports `Client` and the models. |
| `models` | Read models. Each gets a `<Model>Resource` and endpoint discovery. |
| `types` | Types that get descriptors and codecs only, with no endpoint discovery. |
| `output` | The file to write, relative to the root. |

At least one of `models` and `types` is required. Command and nested DTO types
are collected on their own, so do not list them again.

| Option | Default | Meaning |
| --- | --- | --- |
| `--config` | `beak_serverpod.yaml` | The config file. |
| `--root` | The directory of the config file | The consumer package, when you run from elsewhere. |

Only the configured output is written, and an unchanged file is left untouched.
Regenerate after every model or endpoint change, and never edit the file: it is a
function of the client's types and drifts silently when they change.

## What you get

For each model in `models`, the generated file has:

- `<Model>Resource`, a `ServerpodResource` that binds the endpoint's `list`,
  `getById`, `create`, `update`, `archive` and `getMany` where they exist, and
  derives `count` from the list query's total.
- `<Model>Fields`, a typed descriptor per scalar or collection property. Nested
  `entry.title` becomes `entryTitle`; a colliding path uses `__`.
- `<Model>FormSlot`, an enum pool sized to the model's scalar fields, so commands
  wider than a default pool work.
- `<Model>Relations`, typed references to nested objects and lists, for custom
  presentation from complete loaded records. They do not enable relation writes.
- `<Model>Codec`, typed record encoding and constructor-based command decoding.
- A static `editInput(read, ...)` on the resource, which projects the read model
  onto the edit command. A value that cannot be derived (a nullable read value
  for a required input, a domain conversion) becomes a required typed parameter.

Using a resource takes the client, a logical key, the primary-key descriptor and
the columns you want to show. This compiles against the file the generator wrote
for the test fixture below:

```dart
// Illustrative: compiled against the generator's own test fixture.
EntryViewResource(
  client: client,
  resource: 'entries',
  primaryKey: EntryViewFields.entryId,
  locale: currentLocale,
  columns: [
    EntryViewFields.entryTitle.column(
      'Title',
      options: const ServerpodColumnOptions(
        visibleOn: {BeakContext.table, BeakContext.detail},
        sortable: true,
        searchable: true,
      ),
    ),
    EntryViewFields.entryStatus.column(
      'Status',
      options: const ServerpodColumnOptions(
        visibleOn: {BeakContext.table, BeakContext.detail},
        filterable: true,
        enumLabels: {
          ResourceStatus.active: 'Active',
          ResourceStatus.paused: 'Paused',
        },
      ),
    ),
  ],
  permissions: BeakPermissions({
    BeakOperation.read: () => true,
    BeakOperation.update: () => false,
  }),
);
```

The panel discovers the resource's data source, so the resource needs no
repository, no registry entry and no `dataSource:` on the panel.
`locale` appears only because the fixture's endpoint methods take a `locale`
string. It is a required callback when they do. Labels for command-only fields
come from a matching read column; give `createLabels` and `editLabels` for the
rest. `firstPage` overrides the page origin, and, when the query has a sort enum,
`sortFields` maps ambiguous enum values to fields.

## What your endpoints must look like

The generator binds by name and by type, and it fails with a specific message
instead of guessing.

The client and the endpoint methods, from the generator's own test fixture:

```dart title="packages/beak_serverpod_generator/test/fixtures/resources.dart"
class Client {
  Client(this.entry);
  final EntryEndpoint entry;
}
// ...
Future<EntryPage> list({
  required EntryQuery query,
  required String locale,
}) async {
// ...
Future<EntryView> getById(UuidValue id) async => value;
Future<EntryView> create(EntryInput input) async {
// ...
Future<EntryView> update({
  required UuidValue id,
  required EntryInput input,
}) => create(input);
Future<void> archive(UuidValue id) async {
// ...
Future<List<EntryView>> getMany({required List<UuidValue> ids}) async => [
```

| Rule | Detail |
| --- | --- |
| List endpoint | Exactly one field of `Client` whose type has `list(query)` returning a page with exactly one `List<Model>` and an integer `totalCount`. |
| Query DTO | Constructible without required named arguments, with integer `page` and `pageSize`. Its defaults decide whether paging is zero- or one-based. |
| Query vocabulary | `search: String?`, `sort` (an enum matched to field names), `descending: bool`, `includeArchived: bool`. A nullable scalar or enum property that matches a read field becomes an equality filter. |
| Read | `get` or `getById` returning `Model` or `Model?`, taking one non-null scalar id. |
| Write | `create(Input)` and `update(Id, Input)` or `edit(Id, Input)` bind the generic forms only when they return the read model. |
| Delete | A `delete` or `archive` returning `void` binds ordinary delete. |
| Types | `String`, `int`, `double`, `bool`, `DateTime`, `Uri`, `UuidValue` and enums, nullable or not, plus lists and sets of those. Nested objects and lists of non-nullable objects. |

Arbitrary maps, nullable elements in an object list, duplicate class names in the
selected graph and constructors that are private, named or positional fail
generation.
[Endpoint conventions](https://simonerich.github.io/beak/serverpod/bridge/endpoint-conventions/)
lists every signature and every message.

## Limits

- The client class must be named `Client`. The command line has no option for
  another name (the function `generateServerpodCompanions` takes `client:`, the
  command does not pass it).
- The command prints `Generated <path>` on every run, changed or not.
- It is structural generation. Table names, authorization, validation,
  transactions and cleanup stay in Serverpod, and the generated resource inherits
  the bridge's limits: an AND of equality filters, one sort, one search, no
  relation loads, staged form saves, no summaries or CSV export.
- Commands whose result is not the read model stay available to custom screens
  and workflows. Restore, force delete and relation attach and detach are never
  inferred.
- The generator is tested against hand-written fixtures and the analyzer, not
  against a running Serverpod server, and no test mounts a generated resource
  inside a `BeakPanel`.
- Run `dart test` and `dart analyze` in this package.

## Continue reading

- [Generating bridge resources](https://simonerich.github.io/beak/serverpod/bridge/generator/): the loop, and how to verify that a second run changes nothing.
- [Endpoint conventions](https://simonerich.github.io/beak/serverpod/bridge/endpoint-conventions/): exact signatures, the query vocabulary, the type limits and the messages.
- [Bridge resources](https://simonerich.github.io/beak/serverpod/bridge/resources/): what a generated resource accepts and refuses at runtime.
- [Troubleshooting](https://simonerich.github.io/beak/serverpod/troubleshooting/): what each generator and bridge message means.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
