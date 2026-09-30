# Defining models

> Write one annotated class per table, run beak prepare, and get typed columns, relations, records and a first migration.

You know which table you want and have no code for it yet. After this page you can write the schema class, run `beak prepare`, and say which parts of the class Beak reads and which files it writes back.

A schema class is a description, not an object. Nobody constructs it: its fields are `late final`, it has no constructor, and Beak reads it as source text instead of running it. That is why the fields carry no values and the annotations carry only constants.

## At a glance

The smallest useful schema is the one `beak create` scaffolds, the quickstart's `Note`:

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

Four things in it carry information:

| In the class | What Beak does with it |
| --- | --- |
| `@Resource(timestamps: true)` on a `final class ... extends BeakSchema` | Makes `Note` a table (`notes`) and adds `created_at` and `updated_at` |
| `String title` (non-nullable) | A required column: the form, the API and the migration agree on it |
| `BeakText? body` (nullable) | An optional multi-line column, shown in the form and the detail view only |
| `@Display()` | Marks the field that stands for a note in pickers, links and page titles |

Everything else, `NoteColumns`, `NoteModel`, `NoteRecord` and the rest, lands in `note.beak.dart` when you run:

```bash
beak prepare
```

```text
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  8 of 9 files
  agents     up to date · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md
```

The first line is what discovery found, the second how many files changed (Beak leaves a file alone when its text would not change, which keeps Flutter's file watcher quiet), the third the agent files. On a clone that has not run `flutter pub get` yet, the third line says the docs are not materialized and tells you to run it. That does not fail the run. The nine files are the part next to your schema, the four wiring files under `lib/beak/`, three entrypoints and the first migration, all listed on [Generated code](generated-code.md).

## Write the class

### The annotations

`@Resource` sits on the class, `@Column` and friends on its fields. Both come from `package:beak/schema.dart`, kept apart from `package:beak/beak.dart` because `Column` and `Image` are also Flutter widget names. A model file imports both:

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';
```

The `part` line is the one thing to remember: the generated file is a part of yours and declares itself with `part of`. Its name is your file name with `.beak.dart` in place of `.dart`.

`@Resource` takes four options, all optional:

| Option | Default | Meaning |
| --- | --- | --- |
| `table` | Plural snake case of the class name | Physical table name |
| `softDeletes` | `false` | Deletes write `deleted_at` instead of removing the row |
| `timestamps` | `false` | Adds `created_at` and `updated_at` |
| `managesSchema` | `true` | `false` when another system migrates the table |

The default table name is the plural of the class name: `Category` becomes `categories`, `Box` becomes `boxes`, `Person` becomes `people`. The pluraliser knows the regular rules and a short list of irregular words, so set `table:` for anything else. `managesSchema: false` is for a Serverpod model or a database Beak was pointed at: `beak prepare` writes no migration for it and everything else works the same.

### Nullability means required

You never write `BeakRequired()` on a column. A non-nullable field is required, a nullable one is not, and that single fact reaches every layer:

| Field | Form | API | Table |
| --- | --- | --- | --- |
| `late final String title;` | Cannot submit empty | 422 with a field error | `NOT NULL` |
| `late final BeakText? body;` | Can stay empty | Accepts null or omission | Nullable |

The API half, from the scaffolded `Note` (a `POST` without a `title`, and one with a title longer than its `BeakMaxLength(255)`):

```json
{"code":"validation","message":"Validation failed for \"notes\".","fieldErrors":{"title":["This field is required."],"pinned":["This field is required."]},"requestId":"7da4dad935eac84a"}
{"code":"validation","message":"Validation failed for \"notes\".","fieldErrors":{"title":["Must be at most 255 characters."]},"requestId":"99b2addca4916eef"}
```

The table half, from `sqlite3 beak.db ".schema notes"` after the first `beak migrate`:

```text
CREATE TABLE IF NOT EXISTS "notes" ("id" TEXT PRIMARY KEY, "title" TEXT NOT NULL, "body" TEXT, "pinned" INTEGER NOT NULL DEFAULT 0, "created_at" TEXT, "updated_at" TEXT);
```

Two edges. A plain `bool` is required in the API too (`pinned` above), so give it `@Column(defaultValue: false)` if callers should be able to leave it out; a `bool?` becomes a three-state editor (true, false, unset). And a belongs-to foreign key is required by the form and the API when the field is non-nullable, but its database column is always nullable, so that requirement lives in the validation and not in `NOT NULL`.

### One display field

`@Display()` marks the column that stands for a record wherever the record appears as a label: relationship pickers, links in tables, page titles. Put it on exactly one field. Without one, Beak uses the first `String` field that is not a password (a `BeakDate` or `BeakTime` field counts too, because they share the text column), and the `id` when there is none.

### Columns you do not write

Some columns exist without a field:

| Column | Comes from | Where it shows |
| --- | --- | --- |
| `id` | Always, unless the class declares its own `id` | Detail view only |
| `created_at`, `updated_at` | `timestamps: true` | Detail view, and `updated_at` in tables as a relative time |
| `deleted_at` | `softDeletes: true` | Detail view only |
| A foreign key such as `category_id` | Every `@BelongsTo`, unless the class declares that column | Form only, as the picker |

A Beak-managed table gets a UUID `id`, minted by the API when a create arrives without one. A class that declares `id` itself (Serverpod models declare `int? id`) keeps it.

## Where the file goes

Anywhere under `lib/`. `beak prepare` parses every `.dart` file there and looks for `@Resource`. It skips `.beak.dart`, `.g.dart` and `.freezed.dart` files, and any file whose name starts with an underscore.

The shop groups files by resource, `lib/resources/products/models/product.dart` next to its resource class and screens, and the scaffold does the same. A flat `lib/models/` works just as well. Beak does not care, so pick the layout your team can find things in.

Keep one schema class per file. A file has one `part`, so two `@Resource` classes in it write to the same `.beak.dart` and the second silently overwrites the first. This is real: with `Category` and `Tag` in one file, `beak prepare` succeeded and `category.beak.dart` held only `TagColumns` and its siblings, so `CategoryModel` no longer existed.

## Add a field later

1. Add the field to the class.
2. Run `beak prepare`. The `.beak.dart` part changes, nothing else does.
3. If the table already exists in a database, run `beak make:migration AddSourceToNotes --from-drift`. Beak compares the schema classes to the live database and writes the missing columns into a migration in `lib/migrations/`.
4. Read the migration, then run `beak migrate`.

```text
$ beak make:migration AddSourceToNotes --from-drift
  created lib/migrations/add_source_to_notes.dart
  run `beak migrate` to apply it

$ beak migrate
migrated  20260929_122119_add_source_to_notes
```

The generated migration asks the database whether the column is missing before it alters anything, so it also runs on a fresh database whose create-table migration already reads the new field. A required column without a default cannot be added to a table that has rows, and the drift command tells you when that is the case.

A brand new resource needs no step 3: `beak prepare` writes `lib/migrations/create_<table>_table.dart` for it once and never touches it again. That file is yours from then on. Migrations have their own page, [Migrations](../backend/migrations.md).

> **Note: What `prepare` will not do**
>
> It never applies a migration and never edits one that exists. Editing a migration that already ran is how two machines end up with different databases. Write a new one instead.

## When Beak says no

`beak prepare` reads all your schemas before it writes anything, and refuses the whole run if any of them cannot be mapped. It reports every problem at once, at the declaration that caused it. This is real output for a schema with four mistakes:

```text
Cannot generate: fix these first:
  lib/models/product.dart: Product.link is a Uri, which Beak cannot map to a column. Use a supported type, annotate it with @BelongsTo / @HasMany for a relationship, or @Custom for an opaque value.
  lib/models/product.dart: Product.code: @Column(maxLength:) was removed. Declare the bound as a rule instead: rules: [BeakMaxLength(10)].
  lib/models/product.dart: Product.cost: currencyFrom #curency must name a String schema field on a BeakDecimal money column.
  lib/models/product.dart: Product.category searches #nme, which is not a field of Category. Its fields are: id, name.
```

Symbols such as `#curency` and `#nme` are checked against the schema, so a typo is an error naming the field instead of a picker that finds nothing. The full list of messages is on [Annotations](../reference/annotations.md#errors-from-beak-prepare).

## Rules and limits

- Parsed, not executed. Beak reads annotation arguments as source text and writes them into the part. Anything valid in a `const` expression works, and a computed value does not.
- Every field needs a declared type. The type picks the column, so a field without one is reported.
- Unsupported types are errors. `Uri`, `Map`, `List<DateTime>` and the like do not map to a column. Use a supported [field type](fields.md), or `@Custom` for an opaque value you render yourself.
- Enums must live under `lib/`. Beak collects the enum declarations of your source, so an enum imported from a package is not recognised.
- Renaming a field renames its column. `--from-drift` adds the new column and leaves the old one alone, because it cannot know the data should move. Pin the old name with `@Column(columnName: 'old_name')` when the column must stay.
- Shared rules live on the class. Static getters named `validationRules`, `behavior`, `permissions` and `capabilities` are forwarded to the generated model. See [Validation](validation.md) and [Model behavior](behavior.md).
- A package of schemas only. A pure Dart package that depends on `beak_core` alone gets the `.beak.dart` parts and `lib/beak/registry.g.dart` from `beak prepare`, and no panel, server or entrypoint.
- Field names that collide. A field named like a member of `BeakModel` gets no static shortcut, and a field named `record` is reported by `beak prepare` because the typed record view already owns that name. See [Generated code](generated-code.md#rules-and-limits).

## Verify it

```bash
beak prepare
beak doctor
```

`beak doctor` compares every generated file to what `prepare` would write now, and the live database to your schema classes. Edit a schema and skip both `prepare` and the migration, and it says so:

```text
  FAIL generated files out of date (0 missing, 1 stale)
       → beak prepare
  WARN notes.rating is declared by Note.rating but missing from the database
       → beak make:migration AddRatingToNotes --from-drift, then beak migrate
```

Run `dart analyze` too: a schema that reads fine can still fail to compile, for example a `defaultValue` that does not match the field type.

## Reference

| Symbol | Kind | Purpose |
| --- | --- | --- |
| `BeakSchema` | abstract base class | Marker for every schema class |
| `Resource` | annotation | Table options: `table`, `softDeletes`, `timestamps`, `managesSchema` |
| `Column` | annotation | Column options, see [Fields](fields.md) |
| `Display` | annotation | The label field |
| `BelongsTo`, `HasOne`, `HasMany`, `BelongsToMany` | annotations | Relationships, see [Relationships](relationships.md) |
| `Image`, `FileField` | annotations | Upload columns, see [Files and storage columns](files-and-storage-columns.md) |
| `EnumLabels`, `Badges` | annotations | Enum display, see [Fields](fields.md) |
| `Custom` | annotation | Opaque column drawn by a registered renderer |

The full parameter lists are in [Annotations](../reference/annotations.md), the commands in [CLI commands](../reference/cli-commands.md).

## Continue reading

- [Generated code](generated-code.md) what `beak prepare` wrote and how to use it.
- [Fields](fields.md) which Dart type becomes which column.
- [Relationships](relationships.md) linking one schema to another.
