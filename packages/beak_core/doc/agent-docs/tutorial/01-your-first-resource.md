# Your first resource

> Create a Beak project, declare a Category schema and its resource, run the migration and see the table, the form and the REST API Beak builds from them.

This chapter starts a project called `shop` and gets one resource, Categories, from an empty folder to a running panel and API. You write a schema class, a resource class and one line in `main.dart`. Beak writes the rest.

## What you'll build

By the end you have:

- a project that `beak doctor` calls healthy,
- a `Category` schema class and a `CategoryResource` that puts it in the sidebar,
- a SQLite table for categories, created by a migration you can read,
- a panel with a table, a create form and a detail page for categories,
- a REST API you can call with `curl`.

The six chapters grow this project into a subset of the shop in `examples/clean_beak_config`: categories, products, the links between them, seed data, a shaped panel and a server that checks who is asking. Most code blocks are quoted from that example, so they compile. The few that are not say so.

## Before you start

| You need | Why |
| --- | --- |
| Dart `^3.11` and Flutter stable `3.41` or newer | The CLI and the server run on Dart, the panel on Flutter. |
| The `beak` command on your path | [Installation](../start-here/installation.md) has the one line. |
| Chrome and `curl` | Chrome runs the panel, `curl` talks to the API. |
| Port `8080` free | The API listens there. |

No database to install. A new project uses a SQLite file that Beak creates on first migrate.

> **Note: Running from a checkout of Beak**
>
> `beak create` points the new project at the Beak release that matches your CLI, as a git dependency on the tag of that version. If you work from a clone of the repository instead, add `--beak-path <clone>` to the command below, where `<clone>` is the root of the clone (Beak appends `packages/beak`). The dependency becomes a path dependency, and nothing else differs.
>
> **Released Beak**
>
> ```yaml
> dependencies:
>   beak:
>     git:
>       url: https://github.com/SimonErich/beak.git
>       ref: v0.9.0
>       path: packages/beak
> ```
>
> **A clone (`--beak-path`)**
>
> ```yaml
> dependencies:
>   beak:
>     path: /path/to/beak/packages/beak
> ```

## Create the project

```bash
beak create shop --authored --no-example
cd shop
```

Two flags. `--authored` writes a `lib/main.dart` that you own and compose from resource classes, which is the form this tutorial teaches. Without it Beak generates the panel entrypoint from your models instead ([Two ways to boot a panel](../start-here/generated-or-authored.md) compares the two). `--no-example` skips the sample `Note` resource, so the project starts empty.

```console
$ beak create shop --authored --no-example
  created shop/pubspec.yaml
  created shop/beak.yaml
  created shop/lib/main.dart
  created shop/.gitignore
  created shop/analysis_options.yaml
  created shop/AGENTS.md
  created shop/CLAUDE.md
  created shop/test/widget_test.dart
  created shop/README.md
Resolving dependencies...
...
Changed 142 dependencies!
  0 models · 0 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  no models yet: add a @Resource class under lib/, or run `beak make:resource Product`, then `beak prepare` again
  generated  4 of 5 files
  agents     AGENTS.md updated · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md

  next:
    cd shop
    beak make:resource Product --fields name:string!
    beak migrate
    beak dev
```

> **Note: What just happened**
>
> - One dependency, `beak`. It re-exports the panel, the server, the migration DSL, the testing kit and the UI library as separate libraries, so there is no version list to keep in step.
> - `flutter create` added `web/` for you, `flutter pub get` ran, and so did `beak prepare`. That is the generator, and you will meet it again in a minute.
> - `lib/beak/*.g.dart`, `bin/serve.dart` and `bin/migrate.dart` are generated wiring. You commit them and never edit them.
> - `AGENTS.md` and the `.claude/` and `.agents/` skill folders are for AI coding agents working in the project. Delete them if you never use one.

## Declare the schema

A schema class states facts about stored data and nothing about how it looks. Create `lib/resources/categories/models/category.dart`:

```dart title="lib/resources/categories/models/category.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'category.beak.dart';

/// Catalog grouping with reusable attribute definitions.
@Resource()
final class Category extends BeakSchema {
  /// Category title.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Description shown to administrators.
  late final String? description;
}
```

The doc comment mentions attribute definitions because the shop's category has them. Yours gets them in [chapter 3](03-relationships.md).

The rule is short: a field's Dart type picks the column, and its nullability decides whether the value is required.

| Declaration | Column | Required |
| --- | --- | --- |
| `late final String name` | single-line text | yes, `String` is not nullable |
| `late final String? description` | single-line text | no, `String?` is |

`@Column` carries what a type cannot say: `searchable` puts the field into the panel's search, `sortable` makes the header clickable. `@Display()` marks the field that stands for a whole record wherever Beak shows one, in a page title, in a picker, in a link from another record.

You wrote no table name, no id field and no `toJson`. The table is `categories`, derived from the class name, and the primary key is added for you.

## Generate the rest

```bash
beak prepare
```

```console
$ beak prepare
  1 model · 0 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  4 of 7 files
  agents     up to date · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md
```

`beak prepare` reads every schema class, resource class and screen under `lib/` plus `beak.yaml`, and writes what is missing or stale. Four files changed here:

| File | What it is |
| --- | --- |
| `lib/resources/categories/models/category.beak.dart` | The typed columns, `CategoryModel`, the typed record view. Regenerated on every run. |
| `lib/migrations/create_categories_table.dart` | The migration that creates the table. Written once, then yours. |
| `lib/beak/registry.g.dart`, `server.g.dart` | The model registry and the server host. |

There is no `panel.g.dart` in this project. `lib/main.dart` is yours and builds its own `BeakPanel`, so `prepare` leaves the generated panel config out.

Open the part file. This is the column your two fields turned into, with the rules you never typed:

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.beak.dart"
/// Category title.
static const BeakStringColumn name = BeakStringColumn(
  key: 'name',
  label: 'Name',
  rules: [BeakRequired()],
  searchable: true,
  sortable: true,
);
```

`rules: [BeakRequired()]` is the non-nullable `String` speaking. The panel's form checks it before it sends anything, and the server checks it again when the request arrives. Same rule, one source.

The `CategoryModel` in that file is what the rest of the code refers to: `CategoryModel.name` is a typed reference, so a filter, a sort or a search never contains the string `'name'`.

## Look at the migration

The migration reads the model, so the first version of the table matches the schema class exactly:

```dart title="examples/clean_beak_config/lib/migrations/create_categories_table.dart"
await schema.create('categories', (table) {
  BeakBlueprint.defineColumns(table, const CategoryModel());
  BeakBlueprint.defineForeignKeys(table, const CategoryModel());
});
```

Nothing applies it yet. Beak does not touch a database file on boot or on `prepare`. The migration is yours from now on and Beak will not rewrite it, so you review it like any other code. When the schema class changes later, you add a migration for the change, and `beak doctor` tells you when the database and the classes disagree. Chapter 3 does exactly that.

## Add the resource

The schema says what is stored. A resource says how the panel presents it. Create `lib/resources/categories/category_resource.dart`:

```dart title="lib/resources/categories/category_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/category.dart';

/// Catalog organization and reusable attribute definitions.
final class CategoryResource extends BeakResource {
  /// Creates the categories section.
  CategoryResource()
    : super(
        model: const CategoryModel(),
        title: 'Categories',
        icon: const BeakIconToken(OiIcons.folderTree),
        navigationGroup: 'Catalog',
        navigationRank: 5,
      );
}
```

A second file for one model looks redundant. It is not: the schema is shared with the server and the tests, and the resource pulls in the UI library, which the server must never import. Keeping them apart keeps Flutter out of the server, so it compiles to a plain Dart executable (chapter 6 builds one).

| Argument | What it does |
| --- | --- |
| `model` | The schema this resource presents. |
| `title` | The sidebar label and the page heading. |
| `icon` | A `BeakIconToken` over an obers_ui icon. |
| `navigationGroup` | The sidebar group. Resources with the same group sit together. |
| `navigationRank` | Sort order inside the group, lowest first. |

Every other argument is optional, and this resource sets none of them. Without a `screens:` list the resource gets a table, a create form, an edit form and a detail page, all built from the model's columns. Configured screens replace those one at a time; chapter 5 does that.

## Register it in the panel

`lib/main.dart` is yours, and `beak prepare` never rewrites it. Add the resource to the list:

```dart title="lib/main.dart"
import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

import 'resources/categories/category_resource.dart';

/// Boots the panel.
void main() => runApp(buildPanel());

/// The panel, and every resource it shows.
///
/// This file is yours: `beak prepare` never rewrites it, so add each
/// resource class you write to `resources`.
///
/// [dataSource] replaces the HTTP-backed source, so a widget test
/// can pump this exact panel against an in-memory one.
BeakPanel buildPanel({BeakDataSource? dataSource}) => BeakPanel(
  title: 'Shop',
  resources: [CategoryResource()],
  dataSource: dataSource,
);
```

Forget this step and the resource does not appear. `beak doctor` notices: it checks that `lib/main.dart` lists every resource class.

The `dataSource:` parameter is already there for a reason you will meet in chapter 6: a widget test pumps this exact panel against an in-memory source instead of the network.

## Run it

Create the table. `beak migrate` runs `beak prepare` first, so the wiring is fresh, and then applies every pending migration:

```bash
beak migrate
```

```console
$ beak migrate
  1 model · 1 resource class · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (6 files)
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_174129_create_categories_table
```

Three migrations ran. The first two belong to the framework: one keeps the receipts that make saves replayable, the other the queue for durable effects. They exist in every project. The third is yours, and its timestamp will differ from the one printed here. A `beak.db` file now sits next to `pubspec.yaml`; it is git-ignored.

Start the API:

```bash
beak dev
```

```console
$ beak dev
  1 model · 1 resource class · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (6 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
warning: Beak is listening on 0.0.0.0:8080 with BeakAllowAllPolicy, so every route answers every caller and CORS admits any origin. Pass a BeakPolicy to defaults.build(policy: ...), or set HOST=127.0.0.1 to keep it on this machine.
listening on http://0.0.0.0:8080
```

The `warning` is expected: no policy restricts the API yet. Chapter 6 adds one.

`beak dev` regenerates the wiring, serves the API and prints the line that starts the panel. It does not start the panel itself, because a dev server that proxies `flutter run`'s console is one more thing to break. It also does not watch for changes: after you edit a schema, stop it, run `beak migrate` and start it again.

Leave it running. In a second terminal, from the project folder:

```bash
flutter run -d chrome
```

The panel opens on Categories. The sidebar has a Catalog group with one entry, the table shows Name and Description, and a Create button sits top right. Click it, enter a name and save. The row appears, with icons to open, edit and delete it.

The panel talked to the API you started. Talk to it yourself:

```bash
curl -s -X POST localhost:8080/api/categories \
  -H 'content-type: application/json' \
  -d '{"name":"Coffee","description":"Beans and blends"}'
```

```json
{"values":{"id":"67060d38-2d5d-499e-9b85-b339ff3c51cd","name":"Coffee","description":"Beans and blends"},"relations":{}}
```

```bash
curl -s -X POST localhost:8080/api/categories/query \
  -H 'content-type: application/json' \
  -d '{"table":"categories"}'
```

```json
{"items":[{"values":{"id":"67060d38-2d5d-499e-9b85-b339ff3c51cd","name":"Coffee","description":"Beans and blends"},"relations":{}}],"total":1,"page":1,"perPage":25}
```

Reload the panel and the category is in the table. The ids will differ.

> **Note: What just happened**
>
> - You declared one class and got a create route, a query route and the rest of the resource's REST surface. Nothing in `lib/` is an endpoint.
> - The query is a `POST` with a JSON body because a query is a value: a table, filters, sorts, a search term, relations to load, a page. [How data flows](../concepts/how-data-flows.md) shows the whole shape.
> - The panel is not special. It calls these same routes through a typed client.

> **Question: What this skipped**
>
> - What `@Column` and `@Resource` accept: [Defining models](../models/defining-models.md).
> - The full argument list of a resource: [Resources](../panel/resources.md).
> - Why the schema and the resource are two classes: [Declarative resources](../concepts/declarative-resources.md).
> - A faster start for the next resource: `beak make:resource Brand --fields name:string!,notes:string` writes both classes, runs `beak prepare` and prints the line to add to `lib/main.dart`. This chapter wrote them by hand once so you know what it writes. Money is better declared by hand, as chapter 2 does.

## Checkpoint

```bash
beak doctor
```

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 1 model · 1 resource class · screens and overrides not applicable (lib/main.dart is authored)
  OK   lib/main.dart lists every resource class
  OK   generated files up to date
  OK   every model has a migration
  ...
All checks passed.
```

Your project should look like this, plus the scaffolding `beak create` wrote:

```text
lib/
├── beak/                     generated wiring, committed
├── main.dart                 yours: the panel and its resources
├── migrations/
│   └── create_categories_table.dart
└── resources/categories/
    ├── category_resource.dart
    └── models/
        ├── category.dart
        └── category.beak.dart   generated, committed
```

Two files you wrote, one line you added, and you have a table, forms, a detail page and an API. Products come next, and they bring money and rules with them.

## Continue reading

- [Columns and validation](02-columns-and-validation.md): the next chapter adds products with exact money and rules.
- [Generated code](../models/generated-code.md): what is in `category.beak.dart` and why you never edit it.
- [Project structure](../start-here/project-structure.md): where every file of a Beak project lives.
