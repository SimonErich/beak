---
title: Cheatsheet
description: One dense page with the minimal wiring, every column type, rule, and relationship, the block and config fields, the REST routes, and the CLI and gate commands.
---

# Cheatsheet

Everything you reach for while building, on one page. Skim it, pin it, or feed
it to an AI agent. Each row links out to the page that explains it in full.
Snippets are lifted from the store example (the coffee-roastery demo, served
on port 8080), so the ports and model names all line up.

## Minimal wiring

Four moving parts stand up a whole panel: a model, a registry over your models,
a server, and the panel config. No endpoints, no client plumbing.

### 1. Define a model

One columns class of `static const` [column](column-types.md) fields, then a
`BeakModel` that lists them.

```dart
abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: '€',
    filterable: true,
    rules: [BeakRequired(), BeakMin(0)],
  );

  static const List<BeakColumn> values = [name, price];
}

final class ProductModel extends BeakModel {
  const ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ProductColumns.values;
}
```

### 2. Register the models

The registry is the single index both the server and the panel read.

```dart
const List<BeakModel> beakModels = [
  ProductModel(),
  CategoryModel(),
  TagModel(),
  UserModel(),
  OrderModel(),
  OrderItemModel(),
];

BeakModelRegistry buildBeakRegistry() {
  final registry = BeakModelRegistry();
  for (final model in beakModels) {
    registry.register(model);
  }
  return registry;
}
```

### 3. Serve the API

Wrap the registry in a worm-backed data source and hand both to a `BeakServer`.

```dart title="examples/store/lib/server.dart"
BeakServer buildReferenceServer({
  required BeakBackendConfig config,
  required DatabaseAdapter adapter,
  BeakStorageDriver? storage,
}) {
  final BeakModelRegistry registry = buildBeakRegistry();
  return BeakServer(
    config: config,
    registry: registry,
    dataSource: WormDataSource(registry, adapter: adapter),
    storage: storage,
  );
}
```

### 4. Build the panel

Point a `BeakPanelConfig` at the running server and drop it into a `BeakPanel`.

```dart
BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  resources: const [
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
    ),
    // ... one BeakResource per model
  ],
);

void main() => runApp(const ReferenceAdminApp());
```

!!! tip "Scaffold it instead of typing it"
    `beak make:resource Product --fields name:string,price:decimal` writes the
    worm model, the Beak columns/model, and the migration for you. See the
    [CLI commands](#cli-commands) below.

## Column types

Thirteen leaf columns. Every one also accepts the base options `key`, `label`,
`visibleOn` (a `Set<BeakContext>`: `table`, `form`, `detail`, `filter`),
`sortable`, `searchable`, `filterable`, and `rules`. Declare each as a
`static const` and reference the constant, never a string.

| Column | Dart value | Options beyond the base | Renders as |
| --- | --- | --- | --- |
| `BeakStringColumn` | `String` | `placeholder`, `maxLength` | single-line text |
| `BeakTextColumn` | `String` | none | multiline text / textarea |
| `BeakIntColumn` | `int` | `min`, `max` | number |
| `BeakDecimalColumn` | `double` | `precision` (2), `prefix`, `suffix` | number, or currency when a `prefix`/`suffix` is set |
| `BeakBoolColumn` | `bool` | `trueLabel`, `falseLabel` | toggle / yes-no |
| `BeakDateTimeColumn` | `DateTime` | `format` (`BeakDateFormat`), `withFormat(...)` | date, or relative date |
| `BeakEnumColumn<T extends Enum>` | `T` | `values`, `defaultValue`, `badgeColors`, `labelOf` | colored badge / select |
| `BeakJsonColumn` | `String` (JSON text) | none | pretty-printed JSON / textarea |
| `BeakRichTextColumn` | `String` | none | rendered markup / WYSIWYG |
| `BeakColorColumn` | `String` (hex) | none | swatch / color picker |
| `BeakImageColumn` | `String` (key/URL) | `storagePath` (required), `maxSizeInBytes`, `allowedTypes`, `maxDimensions`, `aspectRatio`, `thumbnail`, `transforms` | thumbnail / image picker |
| `BeakFileColumn` | `String` (key/URL) | `storagePath` (required), `maxSizeInBytes`, `allowedTypes` | download / file picker |
| `BeakCustomColumn` | `Object` | `tag` (required, `BeakColumnTag`) | a renderer you register |

`BeakDateFormat` values: `standard`, `relative`, `dateOnly`, `timeOnly`, `iso`.
Full options per type: [Column types reference](column-types.md).

## Validation rules

Eleven rules, attached to a column's `rules` list, run in order; the first
non-null message wins. A rule that does not apply to the value's runtime type
reports it as valid, so rules compose freely and presence stays `BeakRequired`'s
job alone.

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

## Relationship kinds

Four sealed relationship types, declared in a model's `relationships` list. All
share `key`, `label`, `relatedTable`, `displayColumnKey`, and `searchColumnKeys`.

| Kind | Where the foreign key lives | Extra required params | Cardinality | Renders as |
| --- | --- | --- | --- | --- |
| `BeakBelongsTo` | this table's `foreignKey` | `foreignKey` | one | link / searchable single-select |
| `BeakHasOne` | the related table's `foreignKey` | `foreignKey` | one | link / searchable single-select |
| `BeakHasMany` | the related table's `foreignKey` | `foreignKey` (+ `onDelete`, default `restrict`) | many | badge list / relation manager |
| `BeakBelongsToMany` | a `pivotTable` | `pivotTable`, `foreignPivotKey`, `relatedPivotKey` (+ `allowCreate` `false`, `maxAllowed`, `onDelete` default `cascade`) | many | badge list / searchable multi-select |

`BeakOnDelete` values mirror worm 1:1: `cascade`, `ormCascade`, `restrict`,
`setNull`, `setDefault`, `noAction`. `BeakHasOne` lives only in the showcase app
(`superdashboard`), not the reference store. See
[Relationships](../models/relationships.md).

```dart
static const category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
  searchColumnKeys: ['name'],
);

static const tags = BeakBelongsToMany(
  key: 'tags',
  label: 'Tags',
  relatedTable: 'tags',
  displayColumnKey: 'name',
  pivotTable: 'product_tag',
  foreignPivotKey: 'product_id',
  relatedPivotKey: 'tag_id',
  searchColumnKeys: ['name'],
);
```

## Blocks you reach for most

Blocks compose the dashboard, custom screens, and (record-bound) the detail and
form layouts. The record-bound trio renders read-only inside a detail scope and
editable inside a form scope. Full catalog: [Blocks index](blocks-index.md).

| Block | What it is | Key args |
| --- | --- | --- |
| `BeakColumnBlock` | vertical stack | `children`, `gapInPixels` (16) |
| `BeakRowBlock` | horizontal stack | `children`, `gapInPixels` |
| `BeakGridBlock` | responsive grid | `children`, `columns`, `minColumnWidthInPixels` |
| `BeakCardBlock` | card container | `child`, `title`, `subtitle`, `footer` |
| `BeakTabsBlock` | tabbed panes | `tabs`, `initialIndex` (0) |
| `BeakTextBlock` | typographic text | `text`, `variant` (`body`) |
| `BeakMarkdownBlock` | rendered markdown | source string |
| `BeakAlertBlock` | inline alert | `message`, `level` (`info`) |
| `BeakKpiBlock` | metric card from an aggregate | `title`, `value` (`BeakAggregateSpec`), `format` (`number`) |
| `BeakChartBlock` | a dashboard chart | chart spec |
| `BeakTableBlock` | embedded data table | `model`, `title`, `baseFilter` |
| `BeakFieldBlock` | dual-mode single field | `column`, `label`, `layout` (`stacked`) |
| `BeakFieldGroupBlock` | grid of fields | `columns`, `columnCount` (2) |
| `BeakRelationBlock` | dual-mode relation | `relationship`, `title` |
| `BeakWidgetBlock` | escape hatch to a raw widget | a `WidgetBuilder` |

## `BeakResource` fields

One resource per model, in navigation order. `view`, `edit`, `delete`, and
`create` actions are always present; the lists below add to them.

| Field | Type | Default |
| --- | --- | --- |
| `model` | `BeakModel` | required |
| `icon` | `BeakIconToken` | required |
| `label` | `String?` | title-cased table name |
| `section` | `String?` | none |
| `recordActions` | `List<BeakRecordAction>` | `const []` |
| `bulkActions` | `List<BeakBulkAction>` | `const []` |
| `globalActions` | `List<BeakGlobalAction>` | `const []` |
| `filters` | `List<BeakFilterDef>` | `const []` |
| `viewModes` | `List<BeakResourceView>` | `const [BeakTableView()]` |
| `detail` | `BeakBlock?` | generated detail grid |
| `formSteps` | `List<BeakFormStep>?` | single-page form |
| `formLayout` | `BeakBlock?` | generated form |

See [Resources](../panel/resources.md).

## `BeakPanelConfig` fields

The one declarative entry point of a panel; hand it to a `BeakPanel`.

| Field | Type | Default |
| --- | --- | --- |
| `title` | `String` | required |
| `resources` | `List<BeakResource>` | required |
| `apiBaseUrl` | `String` | required |
| `pages` | `List<BeakScreen>` | `const []` |
| `auth` | `BeakAuthConfig?` | default `/login` only |
| `maintenance` | `BeakMaintenanceConfig?` | none |
| `theme` | `OiThemeData?` | `OiThemeData.light()` |
| `darkTheme` | `OiThemeData?` | `OiThemeData.dark()` |
| `initialThemeMode` | `OiThemeMode` | `system` |
| `sidebarCollapsible` | `bool` | `true` |
| `sidebarDefaultCollapsed` | `bool` | `false` |
| `dashboardStats` | `List<BeakStat>` | `const []` |
| `dashboardCharts` | `List<BeakChart>` | `const []` |
| `notifications` | `BeakNotificationSource?` | no bell |

`buildRegistry()` turns the resources into a `BeakModelRegistry`. Full field
docs: [Configuration options](configuration-options.md).

## REST endpoints

Registering a model mounts its surface under `/api/{table}`. `{id}` is the
record id, `{columnKey}` an upload column, `{relationKey}` a to-many relation.

| Method + path | Does |
| --- | --- |
| `POST /api/{table}/query` | list with filter, sort, search, pagination |
| `POST /api/{table}/aggregate` | count / sum / avg |
| `POST /api/{table}/batch` | fetch many records by id |
| `POST /api/{table}` | create a record |
| `GET /api/{table}/{id}` | read one record |
| `PATCH /api/{table}/{id}` | update a record |
| `DELETE /api/{table}/{id}` | delete a record |
| `POST /api/{table}/{id}/relations/{relationKey}/attach` | attach to-many records |
| `POST /api/{table}/{id}/relations/{relationKey}/detach` | detach to-many records |
| `POST /api/{table}/export` | CSV export |
| `POST /api/{table}/{columnKey}/upload` | upload to a file/image column |
| `DELETE /api/{table}/{columnKey}/upload` | remove an uploaded file |

Global routes: `GET /api/search` (across searchable columns), and, when auth is
configured, `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/auth/me`.
Upload routes appear only when uploads are wired. Bodies and error codes:
[REST API reference](rest-api.md).

## CLI commands

Run `beak <command>` from the project root. Every `make:*` command takes
`--fields name:kind,...` where `kind` is one of `string`, `text`, `int`,
`decimal`, `bool`, `datetime`, and `Name` is `UpperCamelCase`.

| Command | Generates |
| --- | --- |
| `beak make:resource Name --fields ...` | worm model + Beak columns/model + create-table migration |
| `beak make:model Name --fields ...` | the worm model only |
| `beak make:columns Name --fields ...` | the Beak columns class and `BeakModel` only |
| `beak make:migration Name --fields ...` | the create-table migration only |
| `beak doctor` | checks worm/obers_ui paths, `.env`, Postgres `:25432`, MinIO `:29000` |

Scaffolding does not auto-register anything: add the migration to `bin/migrate.dart`
and the model to your registry yourself. See [CLI commands](cli-commands.md).

## The gate

Every change has to pass these four, run from the repo root, before it lands.

```bash
melos run analyze       # analyze + material guard, 0 issues required
melos run test          # every package's tests, all green, no skips
melos run coverage      # per-package line-coverage threshold
melos run format-check  # dart format --set-exit-if-changed, must be clean
```

Bring the dev services up and down with `melos run up` (Postgres + MinIO, waits
for health, inits the bucket) and `melos run down`.

## Continue reading

- [Reference index](index.md) the exhaustive per-topic reference pages.
- [Quickstart](../start-here/quickstart.md) the same wiring, run end to end.
- [Defining models](../models/defining-models.md) the long-form walkthrough of a model.
