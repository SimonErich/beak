---
title: Cheatsheet
description: One dense page: a resource end to end, every annotation, authoring type, column, rule, block and REST route, and every CLI command.
---

# Cheatsheet

Everything you reach for while building, on one page. Skim it, pin it, or feed
it to an AI agent. Each row links out to the page that explains it in full.
Snippets come from the store example (a coffee roastery, API on port 8080), so
the names all line up.

## A resource, end to end

One file. No registry to edit, no endpoint to write, no resource to register.

```dart title="examples/store/lib/models/category.dart"
--8<-- "examples/store/lib/models/category.dart"
```

Then:

```bash
beak prepare   # generate; every other beak command runs this first
beak migrate   # apply the migration prepare wrote
beak dev       # serve the API, print the flutter run line
```

`prepare` writes `category.beak.dart` beside the class:

```dart title="examples/store/lib/models/category.beak.dart"
/// Typed column constants of the categories resource.
abstract final class CategoryColumns {
  // ... the primary key ...

  /// What the category is called.
  static const BeakStringColumn name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired(), BeakMaxLength(120)],
    searchable: true,
    sortable: true,
  );

  // ... blurb ...

  /// Every column, in declaration order.
  static const List<BeakColumn> values = [id, name, blurb];
}
```

plus `CategoryRelations` (both sides of every relationship), `CategoryModel`,
and a typed `CategoryRecord` view. Committed, never edited.

The **field's type picks the column kind**. Its **nullability decides
required-ness**, once, for the form validator, the API and the database:
`String name` is required, `BeakText? blurb` is not.

## Where each decision lives

| Decision | Where |
| --- | --- |
| Columns, relationships, table, soft deletes, timestamps | the `@Resource` class in `lib/models/<name>.dart` |
| Panel title, API origin, server port | `beak.yaml` |
| A resource's icon, label, section, or hiding it | `beak.yaml`, under `resources.<table>` |
| A resource's filters, actions, view modes, detail layout, form steps | `lib/resources/<table>.dart` |
| Theme, auth, the `/` screen, the server | `lib/theme.dart`, `lib/auth.dart`, `lib/dashboard.dart`, `lib/server.dart` |
| Everything else | generated into `lib/beak/*.g.dart` and `lib/models/*.beak.dart`, committed, never edited |

`beak eject <target>` writes any of those override files out, pre-filled with
Beak's own default so it compiles and changes nothing until your first edit.

## Libraries

One dependency, `beak`; eight libraries. Which one a file imports says what the
file is.

| Import | What it holds |
| --- | --- |
| `package:beak/beak.dart` | columns, models, relationships, the query spec, `BeakClient`, storage |
| `package:beak/schema.dart` | the annotations a schema class carries |
| `package:beak/panel.dart` | the panel: `BeakPanel`, resources, blocks, tables, forms |
| `package:beak/server.dart` | the Shelf host, config, storage wiring, auth, policy |
| `package:beak/migrations.dart` | `Migration`, `Schema`, `Seeder`, `BeakBlueprint` |
| `package:beak/testing.dart` | `InMemoryBeakDataSource`, `BeakRecordingDataSource`, fixtures |
| `package:beak/ui.dart` | obers_ui, for a screen that draws its own widgets |
| `package:beak/charts.dart` | obers_ui_charts |

Full table and the reason for the split: [Libraries](libraries.md).

## Authoring types and the columns they become

The type on the left is what you write; the column on the right is what
`beak prepare` generates. Reference the generated constant
(`CategoryColumns.name`), never a string.

| You declare | Column | Options beyond the base |
| --- | --- | --- |
| `String` | `BeakStringColumn` | `placeholder`, `maxLength` |
| `BeakText` | `BeakTextColumn` | none |
| `BeakRichText` | `BeakRichTextColumn` | none |
| `int` | `BeakIntColumn` | `min`, `max`, `prefix`, `suffix` |
| `double` | `BeakDecimalColumn` | `precision` (2), `prefix`, `suffix` |
| `bool` | `BeakBoolColumn` | `trueLabel`, `falseLabel` |
| `DateTime` | `BeakDateTimeColumn` | `format` (`BeakDateFormat`) |
| any `enum` | `BeakEnumColumn<T>` | `defaultValue`, plus `@Badges({...})` |
| `BeakJson` | `BeakJsonColumn` | none |
| `BeakHexColor` | `BeakColorColumn` | none |
| `BeakImageRef` + `@Image(...)` | `BeakImageColumn` | `storagePath`, `maxSizeInBytes`, `allowedTypes`, `maxDimensions`, `aspectRatio`, `thumbnail`, `transforms` |
| `BeakFileRef` + `@FileField(...)` | `BeakFileColumn` | `storagePath`, `maxSizeInBytes`, `allowedTypes` |
| `Object?` + `@Custom('tag')` | `BeakCustomColumn` | the tag your renderer is registered under |

`BeakDateFormat` values: `standard`, `relative`, `dateOnly`, `timeOnly`, `iso`.
Full options per type: [Column types reference](column-types.md).

## `@Resource` and `@Column`

```dart
@Resource(table: 'products', softDeletes: true, timestamps: true, managesSchema: true)
```

| `@Resource` parameter | Default | What it does |
| --- | --- | --- |
| `table` | pluralised, snake-cased class name | The physical table name |
| `softDeletes` | `false` | Deletes write a `deleted_at` marker |
| `timestamps` | `false` | Adds `created_at` and `updated_at` |
| `managesSchema` | `true` | Whether Beak generates a migration for this table |

`@Column` carries what the type cannot: `columnName`, `label`, `visibleOn`,
`sortable`, `searchable`, `filterable`, `indexed`, `unique`, `rules`, `prefix`,
`suffix`, `precision`, `min`, `max`, `maxLength`, `format`, `placeholder`,
`trueLabel`, `falseLabel`, `defaultValue`.

`@Display()` marks the field that names a record in pickers, links and titles
(one per schema; without it, the first string field). Full table:
[Annotations](annotations.md).

## Relationships

Each takes the related **schema class** as the field type. Beak derives the
foreign key, the pivot table, and the other side.

| Annotation | Field type | Where the key lives | Renders as |
| --- | --- | --- | --- |
| `@BelongsTo` | `Other?` or `Other` | this table | link / searchable single-select |
| `@HasOne` | `Other?` | the other table | link / searchable single-select |
| `@HasMany` | `List<Other>` | the other table | badge list / relation manager |
| `@BelongsToMany` | `List<Other>` | a pivot table | badge list / searchable multi-select |

All four take `label:`. `@BelongsTo` and `@BelongsToMany` take
`searchOn: ['name', 'email']`, the columns of the related table a picker
searches (default: its display column). `onDelete` defaults to `setNull` for
belongs-to, `restrict` for has-many, `cascade` for many-to-many;
`inverse: false` stops Beak generating the other side.

```dart title="examples/store/lib/models/product.dart"
  /// The category this product is filed under.
  @BelongsTo(onDelete: BeakOnDelete.setNull)
  late final Category? category;

  /// The roast profile for this product, if it is coffee.
  @HasOne()
  late final RoastProfile? roastProfile;

  /// The tags attached to this product.
  @BelongsToMany(allowCreate: true)
  late final List<Tag> tags;

  /// The order lines that sold this product.
  @HasMany(onDelete: BeakOnDelete.restrict)
  late final List<OrderItem> orderItems;
```

`BeakOnDelete` values mirror worm one for one: `cascade`, `ormCascade`,
`restrict`, `setNull`, `setDefault`, `noAction`. See
[Relationships](../models/relationships.md).

## Validation rules

Eleven rules, listed in `@Column(rules: [...])`, run in order; the first
non-null message wins. A rule that does not apply to the value's runtime type
reports it as valid, so rules compose freely. Presence is not among them: a
non-nullable field gets `BeakRequired()` from its type.

| Rule | Bites on | Fails when |
| --- | --- | --- |
| `BeakRequired()` | anything | value is null, a blank/whitespace string, or an empty collection |
| `BeakMin(num min)` | `num` | value `< min` |
| `BeakMax(num max)` | `num` | value `> max` |
| `BeakMinLength(int minLength)` | `String` | length `< minLength` |
| `BeakMaxLength(int maxLength)` | `String` | length `> maxLength` |
| `BeakPattern(String regex, {String? message})` | `String` | no match (the pattern is unanchored) |
| `BeakEmail()` | `String` | not `local@domain.tld` shaped |
| `BeakUrl()` | `String` | not an absolute `http`/`https` URL with a host |
| `BeakInList<T>(List<T> allowed)` | any non-null | value not in `allowed` |
| `BeakAllowedFileTypes(List<BeakFileType>)` | `BeakFileType`, filename, or MIME | type not in the allowed set |
| `BeakMaxFileSize(int maxSizeInBytes)` | `int` (size in bytes) | size `> maxSizeInBytes` |

Details and worked examples: [Validation rules reference](validation-rules.md).

## What the panel derives

Nothing below needs configuring. Each one is what you get before you say
anything, and each is replaceable.

| Surface | Derived default |
| --- | --- |
| Filters | one control per `@Column(filterable: true)`: select for an enum, switch for a bool, contains-search for text, range for a date |
| Show page | a headline card of the first four fields, the rest beside it, and a tab per to-many relationship |
| List table | a column per to-one relationship showing the related record's **name**, not the foreign key, loaded with the page in one query |
| Label | the title-cased table name |
| View modes | a single table view |

## Adjusting one resource

`lib/resources/<table>.dart`, written by `beak eject resource <table>`:

```dart
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  viewModes: const [BeakTableView(), BeakKanbanView(/* ... */)],
);
```

| `copyWith` field | Type | Default |
| --- | --- | --- |
| `model` | `BeakModel` | the generated one |
| `icon` | `BeakIconToken` | `beak.yaml`, else a default |
| `label` | `String?` | title-cased table name |
| `section` | `String?` | `beak.yaml`, else none |
| `recordActions` | `List<BeakRecordAction>` | `const []` (view/edit/delete are built in) |
| `bulkActions` | `List<BeakBulkAction>` | `const []` |
| `globalActions` | `List<BeakGlobalAction>` | `const []` (create is built in) |
| `filters` | `List<BeakFilterDef>` | derived from `filterable` columns |
| `viewModes` | `List<BeakResourceView>` | `const [BeakTableView()]` |
| `detail` | `BeakBlock?` | the derived show page |
| `formSteps` | `List<BeakFormStep>?` | single-page form |
| `formLayout` | `BeakBlock?` | generated form |

See [Resources](../panel/resources.md).

## Blocks you reach for most

Blocks compose the dashboard, custom screens, and (record-bound) the detail and
form layouts. The record-bound trio renders read-only inside a detail scope and
editable inside a form scope. Full catalog: [Blocks index](blocks-index.md).

| Block | What it is | Key args |
| --- | --- | --- |
| `BeakColumnBlock` | vertical stack | `children`, `gapInPixels` (16) |
| `BeakRowBlock` | horizontal stack | `children`, `gapInPixels` |
| `BeakGridBlock` | responsive grid | `children`, `columns`, `minColumnWidthInPixels` |
| `BeakCardBlock` | card container | `child`, `title`, `subtitle`, `footer`, `span` |
| `BeakTabsBlock` | tabbed panes | `tabs`, `initialIndex` (0) |
| `BeakTextBlock` | typographic text | `text`, `variant` (`body`) |
| `BeakMarkdownBlock` | rendered markdown | source string |
| `BeakAlertBlock` | inline alert | `message`, `level` (`info`) |
| `BeakKpiBlock` | metric card from an aggregate | `title`, `value` (`BeakAggregateSpec`), `format` (`number`) |
| `BeakChartBlock` | a dashboard chart | `title`, `type`, `query`, `map`, `heightInPixels` (260) |
| `BeakTableBlock` | embedded data table | `model`, `title`, `baseFilter` |
| `BeakFieldBlock` | dual-mode single field | `column`, `label`, `layout` (`stacked`) |
| `BeakFieldGroupBlock` | grid of fields | `columns`, `columnCount` (2) |
| `BeakRelationBlock` | dual-mode relation | `relationship`, `title` |
| `BeakWidgetBlock` | escape hatch to a raw widget | a `WidgetBuilder` |

## beak.yaml

```yaml title="examples/store/beak.yaml"
name: Beak Store

api:
  # The origin the panel calls. `auto` calls the origin the panel was served
  # from, which is what a single-host deployment wants.
  baseUrl: http://localhost:8080
```

| Key | Default | Decides |
| --- | --- | --- |
| `name` | title-cased package name | The panel title |
| `api.baseUrl` | `http://localhost:8080` | Where the panel calls. `auto` means the origin it was served from |
| `server.port` / `server.host` | Beak's defaults (`8080`, `0.0.0.0`) | Where the server binds, unless `PORT`/`HOST` say otherwise |
| `resources.<table>.icon` | a default | The sidebar icon, a lowerCamelCase `OiIcons` name |
| `resources.<table>.label` | title-cased table | The navigation label |
| `resources.<table>.section` | none | The sidebar group |
| `resources.<table>.hidden` | `false` | `true` keeps it out of the sidebar; the API and relationships stay |
| `theme.sidebar.collapsible` / `.startCollapsed` | `true` / `false` | How the sidebar behaves |

Every key is optional. Delete the file and Beak still boots. Full page:
[beak.yaml](beak-yaml.md).

## REST endpoints

Registering a model mounts its surface under `/api/{table}`. `{id}` is the
record id, `{columnKey}` an upload column, `{relationKey}` a to-many relation.

| Method + path | Does |
| --- | --- |
| `POST /api/{table}/query` | list with filter, sort, search, eager loads, pagination |
| `POST /api/{table}/aggregate` | count / sum / avg |
| `POST /api/{table}/batch` | fetch many records by id |
| `POST /api/{table}` | create a record |
| `GET /api/{table}/{id}` | read one record |
| `PATCH /api/{table}/{id}` | update a record (honours `If-Unmodified-Since`) |
| `DELETE /api/{table}/{id}` | soft-delete, or `?force=true` to delete for real |
| `POST /api/{table}/{id}/restore` | clear a soft-delete marker |
| `POST /api/{table}/{id}/relations/{relationKey}/attach` | attach to-many records |
| `POST /api/{table}/{id}/relations/{relationKey}/detach` | detach to-many records |
| `POST /api/{table}/export` | CSV export |
| `POST /api/{table}/{columnKey}/upload` | upload to a file/image column |
| `DELETE /api/{table}/{columnKey}/upload` | remove an uploaded file |

Global routes: `GET /api/search`, the `/healthz` and `/readyz` probes (outside
`/api`, so they skip auth), and, when auth is configured,
`POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/auth/me`. Upload
routes appear only when storage is wired.

A query spec needs only `table`; every other key falls back to its default. Its
eager loads are objects, not names:

```json
{
  "table": "products",
  "relations": [{ "relation": "category", "filter": null, "nested": [] }],
  "pagination": { "page": 1, "perPage": 25 }
}
```

Bodies, error codes, and the record wire shape:
[REST API reference](rest-api.md).

## CLI commands

Run `beak <command>` from the project root. Every command regenerates first, so
none of them can act on stale wiring.

| Command | Does |
| --- | --- |
| `beak create <name>` | Scaffold a project (`--beak-path` for a local Beak checkout). |
| `beak prepare` | Regenerate the part files, the wiring, and any missing migration. |
| `beak dev` | Regenerate, print the `flutter run` line, serve the API (`-d`, `--no-serve`). |
| `beak migrate [status\|fresh\|refresh]` | Apply migrations. |
| `beak seed` | Run the seeders. |
| `beak make:resource Name --fields name:string!,price:decimal` | One `@Resource` class, then `prepare`. |
| `beak make:migration Name` | An empty, correctly-named migration for a change `prepare` cannot derive. |
| `beak make:migration Name --from-drift` | The same, filled in from what the database is missing. |
| `beak eject <main\|panel\|resource\|theme\|auth\|dashboard\|server>` | Take a default over (`--force` to overwrite). |
| `beak introspect <database-url>` | Write schema classes for a database you already have (Postgres or SQLite). |
| `beak doctor` | Diagnose the project (`--json` for CI). |

`--fields` kinds: `string`, `text`, `int`, `decimal`, `bool`, `datetime`. A
trailing `!` means non-nullable, and so required. See
[CLI commands](cli-commands.md).

## Testing

```dart
final source = InMemoryBeakDataSource(registry: buildBeakRegistry());
await tester.pumpWidget(BeakApp(dataSource: source));
```

`package:beak/testing.dart` gives you `InMemoryBeakDataSource` (a complete data
source over maps that honours the query spec), `BeakRecordingDataSource` (wraps
any source and counts the round trips a screen costs), `beakFakeRecord`, and the
data-source contract suite. See [Testing](../guides/testing.md).

## Continue reading

- [Reference index](index.md) the exhaustive per-topic reference pages.
- [Quickstart](../start-here/quickstart.md) the same resource, run end to end.
- [Annotations](annotations.md) everything a schema class can say.
