# The `<name>_beak` schema package

A pure Dart package that mirrors the Serverpod tables the admin shows as Beak
schema classes. It depends on `beak_core` only, so the server can import it
without pulling in Flutter, and the admin app shares the same classes.

Modeled on `examples/serverpod/bookshop_beak` in
https://github.com/SimonErich/beak (a workspace with `bookshop_server`,
`bookshop_client`, `bookshop_beak` and `bookshop_admin`). `acme` stands for
your project name.

## `acme_beak/pubspec.yaml`

```yaml
name: acme_beak
description: >-
  Beak models for acme (pure Dart, web-safe). Shared by acme_server and
  acme_admin; depends on beak_core only.
publish_to: none

environment:
  sdk: '^3.11.0'

resolution: workspace

dependencies:
  beak_core:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_core

dev_dependencies:
  lints: '>=3.0.0 <7.0.0'
```

Use the same `ref` for every Beak package in the workspace (the release tag that
matches your CLI: `beak --version`). Add `acme_beak` to the root `pubspec.yaml`
`workspace:` list, then run `dart pub get` at the root.

## Mirroring a `.spy.yaml` model

`acme_server/lib/src/catalog/book.spy.yaml`

```yaml
### A title the shop stocks.
class: Book
table: book
fields:
  ### The title printed on the cover.
  title: String
  ### How the book is bound.
  format: BookFormat
  ### Shelf price in cents.
  priceInCents: int
  ### First publication date.
  publishedOn: DateTime?
  ### What the shop pays the supplier. Never leaves the server.
  supplierCostInCents: int?, scope=serverOnly
  ### Who wrote it.
  author: Author?, relation(onDelete=Cascade)
```

`acme_beak/lib/models/book.dart`

```dart
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'author.dart';
import 'book_format.dart';

part 'book.beak.dart';

/// A title the shop stocks.
@Resource(table: 'book', managesSchema: false)
final class Book extends BeakSchema {
  /// Serverpod's serial id, assigned by the database.
  @Column(visibleOn: {BeakContext.detail})
  late final int? id;

  /// The title printed on the cover.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(200)])
  late final String title;

  /// How the book is bound.
  @Column(filterable: true)
  late final BookFormat format;

  /// Shelf price in cents.
  @Column(columnName: 'priceInCents', label: 'Price in cents', sortable: true)
  late final int priceInCents;

  /// First publication date.
  @Column(columnName: 'publishedOn', format: BeakDateFormat.dateOnly)
  late final DateTime? publishedOn;

  /// Who wrote it.
  @BelongsTo(
    foreignKey: 'authorId',
    onDelete: BeakOnDelete.cascade,
    inverse: false,
  )
  late final Author author;
}
```

The mapping:

| Serverpod | Beak schema class |
| --- | --- |
| `class: Book`, `table: book` | `@Resource(table: 'book', managesSchema: false)`; Serverpod owns the schema, so Beak never migrates it |
| serial `id` | declare `late final int? id;` yourself so Beak uses the integer key |
| `title: String` | `late final String title;` (non-null = required) |
| `bio: String?` | `late final BeakText? bio;` for long text, `String?` for short |
| `priceInCents: int` | `@Column(columnName: 'priceInCents')`: Serverpod's physical columns keep their camelCase, Beak's default is snake_case |
| `format: BookFormat` (enum) | a Dart enum with the same value names, in its own file |
| `author: Author?, relation(...)` | `@BelongsTo(foreignKey: 'authorId', ...)` on the child; `@HasMany(foreignKey: 'authorId')` on the parent |
| `unique` | `@Column(unique: true)` |
| `scope=serverOnly`, or a column the admin must not see | leave it out of the schema class: what Beak does not model never leaves the server |
| `default=0` | `@Column(defaultValue: 0)` |

Enums, mirrored in `acme_beak/lib/models/book_format.dart`, must list the same
names in the same spelling as the `.spy.yaml` enum (`serialized: byName`):

```dart
/// How a book is bound.
enum BookFormat { paperback, hardcover, ebook }
```

## The barrel `acme_beak/lib/acme_beak.dart`

```dart
library;

export 'beak/registry.g.dart';
export 'models/author.dart' hide Author;
export 'models/book.dart' hide Book;
export 'models/book_format.dart';
```

The schema classes are hidden because their names are the Serverpod protocol
classes' names, and code that needs both imports the protocol with a prefix
(`import '.../protocol.dart' as sp;`). Everyone else uses the generated
`AuthorModel`, `BookModel` and `buildBeakRegistry()`.

## Regenerate

Run `beak prepare` in `acme_beak`. In a package that depends on `beak_core`
alone it writes only the `*.beak.dart` parts and `lib/beak/registry.g.dart`. If
it also creates `bin/`, `lib/main.dart` or `lib/beak/app.g.dart`, your CLI is
older than this release: reactivate it at the project's tag (`beak-upgrade`).
Never edit the generated files.

## Keep the mirror honest

`acme_server/test/beak_models_match_serverpod_test.dart` turns a rename, a retype
or a new enum value on either side into a red build:

```dart
import 'package:acme_beak/acme_beak.dart' as beak;
import 'package:acme_server/src/generated/protocol.dart' as sp;
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  final tables = {
    for (final table in sp.Protocol.targetTableDefinitions)
      if (table.module == 'acme') table.name: table,
  };

  for (final model in [const beak.AuthorModel(), const beak.BookModel()]) {
    test('every Beak column of ${model.table} is a physical column', () {
      expect(tables, contains(model.table));
      final physical = {for (final c in tables[model.table]!.columns) c.name};
      final declared = {for (final column in model.columns) column.key};
      expect(declared.difference(physical), isEmpty);
    });
  }

  test('the server-only column exists and Beak does not model it', () {
    expect(
      {for (final c in tables['book']!.columns) c.name},
      contains('supplierCostInCents'),
    );
    expect(
      {for (final column in const beak.BookModel().columns) column.key},
      isNot(contains('supplierCostInCents')),
    );
  });

  test('the BookFormat mirror lists the protocol enum values', () {
    expect(
      [for (final v in beak.BookFormat.values) v.name],
      [for (final v in sp.BookFormat.values) v.name],
    );
  });
}
```

`table.module` is the Serverpod module name, the project name (`acme`).
Add `acme_beak` and `beak_core` to the server's dependencies for this to
compile.
