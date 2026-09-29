# beak_core

The shared vocabulary of Beak, in pure Dart: typed columns, rules, relationships,
the serializable `BeakQuerySpec`, the storage abstraction and the
`BeakDataSource` seam. It has no Flutter, no ORM and no HTTP server, so a
server, a panel and a test can all speak it.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter.

## When you depend on it

An app never does. It depends on
[`beak`](https://github.com/SimonErich/beak/tree/main/packages/beak), which
re-exports this package as `package:beak/beak.dart` and
`package:beak/schema.dart`. Depend on `beak_core` directly in two cases:

- A pure Dart package that only declares schema classes, shared by a server and
  an admin that live elsewhere (the models package of a Serverpod workspace).
  There `beak prepare` writes the `*.beak.dart` parts and
  `lib/beak/registry.g.dart` and nothing else.
- You write a `BeakDataSource` for a source Beak does not know. Run
  `runBeakDataSourceContract` from
  [`beak_test`](https://github.com/SimonErich/beak/tree/main/packages/beak_test)
  against it.

## Declare a resource once

A resource is an annotated `BeakSchema` class. The field's Dart type picks the
column kind, and its nullability decides whether the field is required, once,
for the form validator, the API and the database alike:

```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'note.beak.dart';

/// A note.
///
/// Declared once. `beak prepare` generates the typed columns, the model, the
/// relationships (both sides), and a typed record view into `note.beak.dart`,
/// so there is no registry to edit.
@Resource(timestamps: true)
final class Note extends BeakSchema {
  /// What the note is called.
  ///
  /// Non-nullable, so it is required: the form validator, the API and the
  /// schema all derive that from the type rather than restating it.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])
  late final String title;

  /// The note itself.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? body;

  /// Whether the note is pinned to the top of the list.
  @Column(filterable: true)
  late final bool pinned;
}
```

Run `beak prepare`. It writes `note.beak.dart` next to the schema, with
`NoteModel` and one typed field reference per property: `NoteModel.title`,
`NoteModel.body`, `NoteModel.pinned`. You never write a table or column name as
a string.

## Query with the references

A model builds specs, and a spec travels as JSON between panel and server
without losing anything:

```dart
final BeakQuerySpec spec = const NoteModel()
    .query(
      filter: BeakFilter.allOf([
        NoteModel.pinned.eq(true),
        NoteModel.title.contains('release'),
      ]),
      sorts: [NoteModel.title.ascending()],
    )
    .paginate(page: 1, perPage: 50);

final BeakQuerySpec decoded = BeakQuerySpec.fromJson(spec.toJson());

Future<void> read(BeakDataSource source) async {
  final page = await source.query(spec);
  final pinned = await source.aggregate(
    const NoteModel().count(filter: NoteModel.pinned.eq(true)),
  );
  final String firstTitle = NoteModel.title.require(page.items.first);
}
```

`BeakDataSource` is the seam. `WormDataSource` (in `beak_backend`) and
`HttpBeakDataSource` (in `beak_frontend`) implement it, and so does
`InMemoryBeakDataSource` in `beak_test`. A model with no generated part, for a
table Beak does not generate, is written by hand as a `BeakModel` subclass; the
generated part file is the reference for what to override.

## Libraries

| Library | Holds |
| --- | --- |
| `package:beak_core/beak_core.dart` | Everything above. Web-safe: it never reaches `dart:io`. |
| `package:beak_core/schema.dart` | The annotations (`@Resource`, `@Column`, `@Display`, `@BelongsTo`, `@HasOne`, `@HasMany`, `@BelongsToMany`, `@Image`, `@FileField`, `@Badges`, `@EnumLabels`, `@Custom`) and `BeakSchema`. |
| `package:beak_core/io.dart` | The storage drivers that need a filesystem, such as the local disk driver. Server code only. |

## Main types

| Type | What it is |
| --- | --- |
| `BeakColumn` | A sealed, `const` column definition (`BeakStringColumn`, `BeakDecimalColumn`, `BeakEnumColumn`, `BeakImageColumn` and the rest). |
| `BeakModel` | The metadata of one resource: table, columns, relationships, rules, behavior, permissions. |
| `BeakFieldRef` | The generated typed references (`BeakScalarField`, `BeakToOneField`, `BeakToManyField`) that build filters and sorts and read records. |
| `BeakQuerySpec` | The JSON wire contract of a query: filter, sorts, search, relation loads, pagination. |
| `BeakRelationship` | `BeakBelongsTo`, `BeakHasOne`, `BeakHasMany`, `BeakBelongsToMany`. |
| `BeakRule`, `BeakRecordRule` | Scalar, conditional, cross-field and collection validation, run on the client and again on the server. |
| `BeakModelBehavior`, `BeakModelAction` | Value lifecycles and named actions that the server enforces. |
| `BeakCandidateGraph`, `BeakSavePlan`, `BeakSaveResult` | The typed final-state graph a transactional preparer reads, and the outcome of a graph commit. |
| `BeakSemantic`, `BeakDecimal`, `BeakFormatPolicy` | Semantic fields (money, email, slug and more), exact decimals, and display formatting. |
| `BeakDataSource` | The source-agnostic data boundary. |
| `BeakClient` | The typed REST transport underneath the HTTP data source, and the raw escape hatch. |
| `BeakStorageDriver`, `BeakStorageRegistry` | Pluggable file storage. `memory` ships here, `local` in `io.dart`. |
| `BeakException` | The sealed family the server maps to HTTP status and JSON. |

## The docs bundle

`doc/agent-docs` in this package is a copy of the Beak docs, built from the
site's Markdown, with links pinned to the release. `beak docs` copies the
bundle of the `beak_core` a project resolved into `.dart_tool/beak/docs`, and
`beak agents` points `AGENTS.md` at it. It is generated (`melos run agent-docs`
in the Beak repo), not written by hand.

## Limits

- `BeakClient` has a case for `validation`, `not_found`, `authentication`,
  `authorization`, `conflict` and `storage`. Any other code, including the
  server's own `internal`, becomes a `BeakConfigurationException`, so a 500 and
  a misconfiguration look alike on the client.
- `BeakDateTimeValue.toJson` writes a local `DateTime` without an offset. Pass
  UTC values in a query that crosses machines.
- `BeakPagination` has a floor (`perPage >= 1`) and no ceiling. The server does
  not cap it either.

## Continue reading

- [The one-definition promise](https://simonerich.github.io/beak/concepts/the-one-definition-promise/): what one schema class drives.
- [The query contract](https://simonerich.github.io/beak/architecture/query-contract/): the wire format of `BeakQuerySpec`.
- [The data source seam](https://simonerich.github.io/beak/architecture/data-source-seam/): who implements `BeakDataSource`, and how to add one.
- [Architecture](https://simonerich.github.io/beak/architecture/): how the packages fit together.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
