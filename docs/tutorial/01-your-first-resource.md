---
title: Your first resource
description: Scaffold a Beak project, declare one resource, and get a list, a form, a detail page and a REST API without registering anything.
---

# Your first resource

By the end of this chapter you have a running admin panel for a coffee
roastery, built from one class you wrote: a list, a create form, a detail page,
an edit form, and a REST API that enforces the same rules the form does.

You need the `beak` command on your path:
[Installation](../start-here/installation.md).

## Create the project

```console
$ beak create roastery
  created roastery/pubspec.yaml
  created roastery/beak.yaml
  created roastery/lib/models/note.dart
  …
  1 model · 0 screens · 0 overrides
  generated  9 of 9 files
```

```bash
cd roastery
flutter pub get
```

!!! note "What just happened"
    - One package, one dependency. No workspace, no melos, no Docker, no `.env`.
    - Eight files are yours, plus the `web/` folder `flutter create` contributed.
      Nine were generated (the sample model's columns and migration, the
      registry, the panel config, the app widget, the server host, and three
      entrypoints).
    - `lib/models/note.dart` is a sample resource, written to be replaced.
      [Project structure](../start-here/project-structure.md) maps the rest.

## Declare a resource

A roastery sells coffee, and coffee sits on shelves. Start with the shelf.
Delete the sample note and the two files generated from it:

```bash
rm lib/models/note.dart lib/models/note.beak.dart \
   lib/migrations/create_notes_table.dart
```

Write the category in its place:

```dart title="examples/store/lib/models/category.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'category.beak.dart';

/// A shelf of the catalog.
///
/// The `products` side of the relationship is not declared here: `@BelongsTo`
/// on [Product.category] generates it, so the pair cannot drift apart.
@Resource()
final class Category extends BeakSchema {
  /// What the category is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The one-line blurb shown above the product list.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? blurb;
}
```

`Product` arrives in the next chapter. The class doc says up front that you will
never write the other half of that relationship by hand.

The **type picks the column kind**. The **nullability decides required-ness**,
once, for the form validator, the API and the `NOT NULL` in the database.

| Declaration | Column kind | Required |
| --- | --- | --- |
| `late final String name` | single-line text | yes, because `String` is not nullable |
| `late final BeakText? blurb` | multi-line text | no, because `BeakText?` is |

`@Column` carries what a type cannot: `searchable`, `sortable`, rules like
`BeakMaxLength(120)`, and `visibleOn`, the surfaces a column appears on. `blurb`
is listed for the form and the detail page but not the table, so a paragraph
never squeezes itself into a cell. `@Display()` names the column that stands for
a whole record, which is what a page title and a relationship link show.

`beak.yaml` decides presentation, not structure, and it still points at the
deleted sample. Replace its `notes` entry:

```yaml
resources:
  categories:
    icon: folderTree
    section: Catalog
```

Forget it and generation stops with `resources.notes names no discovered table.`
rather than quietly dropping a sidebar entry.

## Generate

```console
$ beak prepare
  1 model · 0 screens · 0 overrides
  generated  5 of 9 files
```

That one command read `lib/models/`, `lib/screens/`, `lib/migrations/`,
`lib/seeders/` and `beak.yaml`, and wrote:

| File | What it is |
| --- | --- |
| `lib/models/category.beak.dart` | Typed column constants, the `CategoryModel`, both sides of every relationship, and a typed record view. Committed. |
| `lib/migrations/create_categories_table.dart` | The migration this resource needs and does not have. Written once, then yours. |
| `lib/beak/{registry,panel,server}.g.dart` | The wiring: the model registry, the panel config, the server host. Committed. |

Open the part file. Inside `CategoryColumns`, the two rules above are there in
plain sight:

```dart title="examples/store/lib/models/category.beak.dart"
  /// What the category is called.
  static const BeakStringColumn name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired(), BeakMaxLength(120)],
    searchable: true,
    sortable: true,
  );

  /// The one-line blurb shown above the product list.
  static const BeakTextColumn blurb = BeakTextColumn(
    key: 'blurb',
    label: 'Blurb',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );
```

`String` became a `BeakStringColumn` and `BeakText?` a `BeakTextColumn`. The
non-nullable field picked up a `BeakRequired()` you never typed; the nullable one
did not. A primary key was added ahead of both, visible on the detail page only.

!!! note "What just happened"
    You registered nothing. There is no model list, no resource list, no route
    table and no migration list to keep in step. A file under `lib/models/` is a
    resource, and `beak prepare` is what notices.

## Create the table

Beak wrote that migration by reading the model, so the table and the API cannot
drift. Applying it stays your call: nothing alters a database on boot.

```console
$ dart run bin/migrate.dart migrate
migrated  20260727_152054_create_categories_table
```

Your timestamp will differ, since it is minted when the migration is written. A
`beak.db` file now sits beside your `pubspec.yaml`: the default database, a
SQLite file created on first run. `DATABASE_URL` switches it to Postgres.

## Run it

```console
$ beak dev
  1 model · 0 screens · 0 overrides
  generated  up to date (7 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
```

`beak dev` regenerates and serves the API on `http://localhost:8080`. Do as it
says and run `flutter run -d chrome` in a second terminal.

The sidebar has a **Catalog** section with **Categories** under a folder icon,
exactly as `beak.yaml` asked. Click it and four generated pages are waiting.

- **The list.** One **Name** column, sorted by clicking its header because the
  column is `sortable`. Paged 25 rows at a time, with view and edit on every row.
- **The create form.** A single-line **Name** input above a multi-line **Blurb**
  box, in declaration order. Save with an empty name and the field turns red with
  *This field is required*; paste 200 characters in and `BeakMaxLength(120)`
  objects before the request leaves the browser.
- **The detail page**, a headline card holding **Name** and **Blurb**, with edit
  and an undoable delete in its header. **The edit form** is the same two fields,
  filled in.

Create one now: name it `Single origin`, blurb it `One farm, one lot.`, save.

## Read it back

The panel is one client of the API, not a privileged one. Ask for the record
you created:

```bash
curl -X POST localhost:8080/api/categories/query \
  -H 'content-type: application/json' -d '{"table":"categories"}'
```

```json
{"items": [{"values": {"id": "7aec2191-13e9-4bf4-8db6-0c3ac3d95485",
                       "name": "Single origin",
                       "blurb": "One farm, one lot."},
            "relations": {}}],
 "total": 1, "page": 1, "perPage": 25}
```

Only `table` is required: filters, sorts, paging and relations to load all have
defaults, so a request sends what it means and nothing else.

The form's validation is not a courtesy. Post a category with no name and the
server answers `422`:

```bash
curl -X POST localhost:8080/api/categories \
  -H 'content-type: application/json' -d '{"blurb":"no name"}'
```

```json
{"code": "validation",
 "message": "Validation failed for \"categories\".",
 "fieldErrors": {"name": ["This field is required."]},
 "requestId": "352e3768c75ec1f4"}
```

Same rule, same message, both sides, from `String` not being `String?`.

!!! note "What just happened"
    One class produced a database table, eleven REST routes, four panel pages,
    and client and server validation that cannot disagree, because both come
    from the same declaration.

!!! question "What this skipped"
    The other eleven column kinds ([Column types](../models/column-types.md)),
    everything the API does beyond a bare query
    ([The generated API](../backend/the-generated-api.md)), and how `visibleOn`
    decides surfaces ([Column basics](../models/column-basics.md)).

## Continue reading

- [Columns and validation](02-columns-and-validation.md), the next chapter: the
  roastery gets products, with prices, stock, a status enum and an image upload.
- [Project structure](../start-here/project-structure.md) explains every folder
  the scaffold created and the optional files that take a default over.
- [Tutorial overview](index.md) lists the six chapters and what each adds.
