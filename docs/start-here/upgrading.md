---
title: Upgrading
description: Move a pre-0.9 Beak project to 0.9.0 in the order the tools report it, with an old-to-new table for every breaking change and the silent behavior changes.
type: guide
audience: [expert, agent]
status: stable
---

# Upgrading

You have a project written against the tree before the 0.9 cleanup, and you want it on `0.9.0`. After this page you know the order to fix things in, what each old API became, and which changes do not produce a compile error.

0.9.0 is the first release of the `beak*` packages, so "before" means the pre-release line (`0.0.x`, the repository before the cleanup). Beak is not 1.0: the API is not frozen, and a change to the query spec, the commit and receipt JSON or the Serverpod tunnel envelope counts as breaking. None of the breaking entries below changes those, apart from the removed route `GET /api/search`.

## At a glance

| | |
| --- | --- |
| Method | Compile-driven. Let `beak prepare` and the analyzer produce the punch list |
| Order | Schema classes, resource and screen options, typed references, blocks, server |
| Biggest changes | One way to configure a resource, no string references, units in size names, typed policies |
| Silent changes | Six, listed [below](#changes-that-do-not-fail-to-compile) |
| Source of truth | [`CHANGELOG.md`](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md) and the code |

## Do it in this order

1. **Move the dependency.** Point the `beak` dependency at the release (or at a branch or checkout until `v0.9.0` is tagged, see [Installation](installation.md#the-release-is-not-tagged-yet)), install the matching CLI, and give the project the obers_ui override from the same page. `beak --version` should print `beak 0.9.0`.
2. **Run `beak prepare` and read the list.** It stops at the first batch of errors, writes nothing, and names the replacement for each:

   ```console
   $ beak prepare
   Cannot generate: fix these first:
     lib/resources/notes/models/note.dart: Note.title: @Column(maxLength:) was removed. Declare the bound as a rule instead: rules: [BeakMaxLength(255)].
     lib/resources/notes/models/note.dart: Note.priority: @Column(min:) was removed. Declare the bound as a rule instead: rules: [BeakMin(1)].
     lib/resources/comments/models/comment.dart: Comment.note: searchOn takes the related schema's fields as symbols, not column keys as strings. Write searchOn: [#title].
     lib/resources/notes.dart: Beak no longer reads beakResource() overrides. Configure the notes resource with a BeakResource subclass instead: `beak eject resource notes` writes one under lib/resources/notes/, and the generated panel uses it in place of the default. Then delete this file.
     lib/dashboard.dart: Beak no longer reads the beakDashboard() override. Declare the screen as a BeakScreen with path: '/' under lib/screens/ instead, and the panel opens on it. Then delete this file.
   ```

   Fix every line and run it again. It exits `1` until the list is empty.
3. **Fix the compile errors of your resources and screens.** Start with the resource options, then the typed references, then the sizes; the tables below are in that order.
4. **Fix the blocks and the server.** Removed blocks first, then `lib/server.dart`.
5. **Run `beak doctor`, `dart analyze` and your tests.** `beak doctor` byte-compares every generated file and checks the database against your classes.

## Schema classes and the CLI

| Before | Now | Notes |
| --- | --- | --- |
| `@Column(maxLength: 80)`, `min:`, `max:` | `rules: [BeakMaxLength(80)]`, `[BeakMin(n)]`, `[BeakMax(n)]` | The rule now also sets the stored column length or bound. With several, the tightest wins |
| `@BelongsTo(searchOn: ['email'])`, `@BelongsToMany(searchOn: [...])` | `searchOn: [#email, #lastName]` | Each symbol is checked against the related schema's fields |
| `lib/resources/<table>.dart` with `BeakResource beakResource(BeakResource generated)` | A `BeakResource` subclass. `beak eject resource <table>` writes it | Refuses a table that `beak.yaml` marks `hidden: true` |
| `lib/dashboard.dart` with `beakDashboard()`, `beak eject dashboard` | A `BeakScreen` with `path: '/'` under `lib/screens/`, or `home:` on the panel | `beak eject` targets are now `main`, `panel`, `resource`, `theme`, `auth`, `server` |
| Scaffold layout `lib/models/<name>.dart` | `lib/resources/<plural>/models/<name>.dart`, plus `<name>_resource.dart` from `make:resource` | Discovery scans all of `lib/`, so an old flat layout keeps working |
| `NoteColumns.title` in scaffold text | `NoteModel.title` | `XColumns` is still generated; field references are what the docs use |
| `beak introspect` wrote into `lib/models/` | Writes `lib/resources/<table>/models/`. `--out` writes flat | New `--ownership adopt\|external`, `--save-url`, `--dry-run` |
| `package:beak_cli/beak_cli.dart` exported its internals | Exports only `createBeakRunner`, `BeakCliEnvironment`, `BeakPortProbe`, `BeakProcessRunner` | Run the CLI as a command |
| A panel entrypoint you edited by hand (`lib/main.dart`) | `beak eject main`, or `beak create --authored` | See [Two ways to boot a panel](generated-or-authored.md) |
| The `:3000` panel port in the old scaffold text | `beak dev` serves the API on `:8080` and prints the `flutter run` line | The CLI never started Flutter |

## Resources, screens and panel

| Before | Now | Notes |
| --- | --- | --- |
| `BeakResource(label:, section:)` | `title:` (page), `navigationTitle:` (sidebar), `navigationGroup:` | The generated panel sets `title:` and `navigationGroup:` from `beak.yaml` `label` and `section` |
| `BeakScreen(label:, section:)` | `navigationTitle:`, `navigationGroup:` | |
| `BeakResource.detail:` | Nothing to set: the default show page is a read-mode form derived from the model | Customise it with a `BeakFormScreen` whose `roles` contain `BeakScreenRole.read`, in `screens:` |
| `BeakResource.viewModes: [BeakTableView(), BeakCalendarView(...)]` | Table: `BeakTableScreen` in `screens:`. Board, calendar, timeline: blocks on a `BeakScreen`. Switch: `BeakTabsBlock` | [View modes](../panel/view-modes.md) |
| `createFields`, `editFields`, `createBuilder`, `editBuilder`, `formValueMode`, `editValues` | A `BeakFormScreen` layout per role. `BeakConfiguredForm(valueMode:)` for a custom screen | Configured forms are the single editing runtime |
| `createModel`, `editModel` on `BeakResource` | The same hooks on `BeakModel` | [Model-owned transports](../extending/model-transports.md) |
| `canCreateWhen`, `canEditWhen`, `canDeleteWhen`, `visibleWhen` | `BeakModel.permissions`, live callbacks per `BeakOperation` | `canCreate`, `canEdit`, `canDelete` (booleans) stay on the resource |
| `BeakSelectFilter(column: ProductColumns.status, label: 'Status')` | `BeakSelectFilter(field: ProductModel.status, label: 'Status')`, or `ProductModel.status.selectFilter(label: 'Status')` | Every filter takes a typed `field:` |
| `BeakPanel.fromConfig(config: c)` | `BeakPanel(config: c)` | Give `config:` or the individual arguments, never both |
| `BeakDashboard`, `BeakStat`, `BeakChart`, `dashboardStats:`, `dashboardCharts:` | `home:` (a `BeakScreen` or `BeakResource`) plus `BeakMetricBlock` and chart blocks on a screen | `/` redirects to `home:`, else to the first visible destination |
| `BeakNavigationItem.page('/kitchen', label: ..., icon: ...)` | `BeakNavigationItem.screen(kitchenScreen)` | `label:` and `icon:` stay optional overrides |
| `BeakDataForm`, `FormViewModel`, the resource form-step and layout fallbacks | `BeakConfiguredForm` and `BeakFormScreen` | |
| `TableViewModel` | `BeakTableViewModel` | The form controller types are no longer exported |
| `BeakDetailView`, relation fields, `ReferenceCache` | Removed, with no replacement | They were dead code |
| `BeakSummaryBlock(groupField: ...)` | The group label comes from the summary query's `groupBy` | |

## References that used to be strings

The rule is that Beak takes an object wherever it already knows the thing. The wire name of an action stays the identifier on the wire.

| Before | Now |
| --- | --- |
| `submitAction: 'place'` | `submitAction: OrderActions.place` |
| `BeakFormActionInput(action: 'x')`, `BeakFormActions(actions: ...)`, `BeakFormSession.save(action: 'x')` | The same parameters, taking the `BeakModelAction` object |
| `bulkModelActions`, `BeakActionPresentation.model`, `snapshot(onAction:)` by name | The `BeakModelAction` object |
| `plan.action == 'place'` in a preparer | `plan.runs(OrderActions.place)` |
| `BeakSort(OrderModel.deliveryDate.key)` | `OrderModel.deliveryDate.ascending()` (or `.descending()`) |
| `spec.orderBy(OrderModel.deliveryDate.column)` | `spec.orderBy(OrderModel.deliveryDate)`, `descending: true` for the other direction |
| `spec.searching(term, [column])` | `spec.searching(term, [ProductModel.name])` |
| `sum(ProductModel.weight.column)` | `sum(ProductModel.weight)`: aggregates take numeric fields |
| `BeakSummarySpec(table: ..., groupBy: X.label.column, measures: [BeakSummaryMeasure.sum('portions', column: X.quantity.column)])` | `const XModel().summary(groupBy: XModel.label, measures: [portions])`, with `final portions = BeakSummaryMeasure.sum('portions', field: XModel.quantity)` |
| Reading a summary row by measure key string | `row.valueOf(portions)` |
| A list preset or preset count referenced by its key | The `BeakQueryPreset` object |
| `BeakNotificationSource(titleField: NotificationModel.title.column, ...)` | `titleField: NotificationModel.title`; the kanban and inbox blocks take typed field references too |

The summary and navigation rows come straight from foodio's history. Before:

```dart
// Before (pre-0.9): examples/foodio-adminpanel, kitchen summary.
query: BeakSummarySpec(
  table: const OrderItemModel().table,
  groupBy: OrderItemModel.label.column,
  measures: [
    BeakSummaryMeasure.sum(
      'portions',
      column: OrderItemModel.quantity.column,
    ),
  ],
),
```

Now:

```dart
// Now: the measure is declared once and read back with row.valueOf(_portions).
final _portions = BeakSummaryMeasure.sum(
  'portions',
  field: OrderItemModel.quantity,
);

query: const OrderItemModel().summary(
  groupBy: OrderItemModel.label,
  measures: [_portions],
),
```

`BeakSummaryMeasure.sum` takes numeric fields. For a `BeakDecimal` money column use `BeakSummaryMeasure.sumDecimal(key, field: OrderModel.total)`, and read the total with `row.decimalOf(measure)`.

## Units in names

Every numeric size, gap and spacing parameter carries its unit. The compiler finds them all:

| Before | Now |
| --- | --- |
| `headerGap`, `minColumnWidth`, `dividerSpacing` | `headerGapInPixels`, `minColumnWidthInPixels`, `dividerSpacingInPixels` |
| The same for the form layout family and its input helpers, the aside and page gaps, the filter sheet, table columns, record templates and stored images | The same names with an `InPixels` suffix |

## Blocks

| Before | Now |
| --- | --- |
| `BeakKpiBlock(title:, value:, previous:, target:, format: BeakKpiFormat.currency, currencySymbol:, decimals:)` | `BeakMetricBlock(label:, aggregate:, previous:, target:, format: BeakValueFormat.currency, minorUnits:, unit:)` |
| `BeakKpiFormat` | `BeakValueFormat`. `BeakMetricBlock.format` accepts `number`, `currency` and `percent` only, and asserts on the rest |
| `BeakMetricBlock.prefix`, `.suffix` | `format:` for money, `unit:` for a unit such as `kg` |
| `BeakWizardBlock`, `BeakBlockWizardStep` | `BeakWizardScreen` for data wizards, `OiWizard` from `package:beak/ui.dart` for anything else |
| `beakChartWidget` | Not exported. The chart data types (`BeakChartType`, `BeakChartPoint`, `BeakChartMapper` and friends) live with the blocks and import as before |

## The server

Before and now, in the shop's `lib/server.dart` (the before is from the baseline commit):

```dart
// Before (pre-0.9)
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: ShopGraphPreparer(defaults.registry).prepare,
  graphOnlyTables: const {
    'orders',
    'order_items',
    'invoices',
  },
);
```

```dart title="examples/clean_beak_config/lib/server.dart"
--8<-- "examples/clean_beak_config/lib/server.dart:shopServer"
```

| Before | Now | Notes |
| --- | --- | --- |
| `graphOnlyTables: Set<String>` | `graphOnly: List<BeakModel>` (`graphOnly: [OrderModel()]`) | On `beakApiRouter`, `BeakServer` and `BeakServerDefaults.build`. Every model listed must be registered |
| `initializeWormPostgres` | `initializeBeakDatabase` | |
| `postgresAdapterFromUrl` | `adapterFromUrl`, or `initializeBeakDatabase` | The former is private now |
| `beakApiRouter(uploads:, validation:)`, `BeakGraphCommitService(validation:)` | `storage:` with `transformRunner:` and `generateId:`. Custom rules go on the model or in `preparePlan` | `ValidationService` never had any configuration |
| `BeakPolicy.canView(principal, String table)` and the other policy hooks | `canView(principal, BeakModel model)`. `BeakFieldPolicy` takes a model and a field ref, `BeakActionPolicy` a `BeakModelAction`, upload hooks a `BeakUploadColumn` | Wire strings are resolved inside the handlers |
| An allow-list written as hand code | `BeakPolicies`, `BeakModelRules` and `BeakAccess`: deny by default, with row scopes, per-action rules and read-only fields | New, and optional |
| `GET /api/search`, `GlobalSearchService`, `BeakSearchHandlers`, `BeakClient.search`, `BeakSearchHit` | `globalSearchSources` on the resource | The panel's command bar sends one `POST /api/{table}/query` per resource |
| `BeakResourceService.query`, `aggregate(scope:)`, `scopedQuery`, `intersect` | Removed | Internal |
| Foodio's own `Timer.periodic` worker in `bin/serve.dart` | `outbox: BeakOutboxSchedule(...)` on `defaults.build`; the host starts and stops the loop | |
| `BeakServerDefaults.dataSource` typed `BeakDataSource` | Typed `WormDataSource`, so a customizer can reach `defaults.dataSource.adapter` | A different source goes in `defaults.build(dataSource:)` |
| `MinioS3ObjectClient(minio: ...)` and `dependency_overrides: xml: ^7.0.1` | `HttpS3ObjectClient(httpClient: ..., clock: ...)`, and no override | A failing S3 response throws `S3ResponseException` |
| An exhaustive `switch` over `BeakException` | Add arms for `BeakInternalException`, `BeakPayloadTooLargeException` and `BeakTransportException` | `BeakClient` reports a 5xx as `BeakInternalException` and a 413 as `BeakPayloadTooLargeException` |
| A `BeakTransformRunner` of your own | Implement `inspect`, which reads an image's size from its header | `ImageTransformRunner` has it |

`package:beak_backend` no longer exports these internals: `WormQueryTranslator`, `WormRecordModel`, the column type mapper, `BeakCrudHandlers`, `BeakExportHandlers`, `registerExportRoutes`, `BeakUploadHandlers`, `registerUploadRoutes`, `registerBeakCommitRoutes`, `beakResourceRouter`, `beakLocalUploadsRouter`, `beakHealthRouter`, `generateUuidV4`, `CsvExportService`, `UploadService`, `BeakResourceService`, `ValidationService` and `beakRowScope`. Code that reached for one builds a server through `BeakServerDefaults.build` instead.

## Examples that are gone

The store, superdashboard and embedded examples were removed with their CI and deployment files. `examples/quickstart`, `examples/clean_beak_config`, `examples/foodio-adminpanel`, `examples/showcase` and `examples/serverpod` are the maintained ones. Anything that linked to a removed example now links to [Examples](../examples/index.md).

## Serverpod

A panel that reads through an existing Serverpod client changes in three places. `beak_serverpod_flutter` now requires Serverpod `>=4.0.3 <5.0.0` (0.0.x pinned `4.0.0-beta.0`), where `ServerpodClientException` is sealed and only `ServerpodClientHttpException` carries a `statusCode`, so code that caught the base class and read `statusCode` must catch the subclass. `BeakQuerySpec.orderBy` and `searching` take typed fields (`spec.orderBy(BookModel.title)`). A bridge resource is configured like any other: `title` and `navigationGroup` replace `label` and `section`, and filters take `field:`. [Version compatibility](../serverpod/versions.md) has the pins.

## Changes that do not fail to compile

These compile and behave differently. Check them by hand.

- **`/` no longer shows a dashboard.** It redirects to `home:` or the first visible navigation destination.
- **The default show page is derived from the model**, with a read-only tab per to-many relationship, loaded by one query.
- **`rules: [BeakMaxLength(n)]` now sets the column length.** A Postgres database created with the old default may show length drift in `beak doctor`. `beak make:migration --from-drift` adds columns only, so an altered length is a migration you write.
- **`authSessions` without an `authGuard` now installs `TokenSessionAuthGuard`**, so issued tokens are validated and `/api/auth/me` works.
- **The host clock reaches every write**, including per-record CRUD, graph commits and upload storage keys.
- **CORS allows the `if-unmodified-since` header**, and `/readyz` answers `503` with a generic detail instead of the driver's text. `PUT` is no longer a CORS method.
- **A backslash in `like` and `ilike` is the escape character.** `contains`, `startsWith`, `endsWith` and searches escape `%`, `_` and `\` in the term. A hand-written pattern that meant a literal backslash needs two.
- **A page is at most 200 rows.** A request for more gets 200, and the envelope's `perPage` says so. Page through the rest, or take totals from a summary.
- **A wrong spec is a `422`, not a `500`.** That covers an unknown table, field or relation, a dotted sort key and a non-numeric aggregate column.
- **Dates travel as UTC**, and `BeakDateTimeValue` compares by instant.
- **A CSV cell that would run as a formula starts with `'`.** A null cell is empty.
- **`beak make:resource --fields price:decimal` writes a `BeakDecimal`.** It wrote a `double` before; the kind for that is now `double`.

## Rules and limits

- **`beak prepare` does not touch your database.** The upgrade changes code and generated files. Run `beak migrate` only for migrations you have read.
- **The shop example needs a fresh database.** It stores every amount as an exact `BeakDecimal`, so an older `beak.db` must be deleted, then migrated and seeded. That applies to the example, not to your project.
- **Nothing is deprecated first.** Removed APIs are gone, not marked. There is no compatibility shim.
- **The CLI and the packages move together.** All `beak*` packages share `0.9.0`, and `beak doctor` reports whether the CLI matches the project's Beak.
- **A default `beak create` cannot resolve until the tag exists.** The scaffold pins `ref: v0.9.0`.

## Verify it

```console
$ beak prepare
  2 models · 1 resource class · 0 screens · 0 overrides
  generated  up to date (9 files)
$ beak doctor
  ...
All checks passed.
$ dart analyze
No issues found!
```

Then run your tests. The old API names are also good search terms: a grep for `viewModes`, `fromConfig`, `graphOnlyTables`, `BeakKpiBlock`, `BeakWizardBlock`, `initializeWormPostgres` and `api/search` over your `lib/` and `test/` finds what is left.

## Reference

The full list of breaking changes, with the commit that made each, is the `Changed` and `Removed` sections of `CHANGELOG.md`. Its `Migrating` table is the short version of the tables above.

## Continue reading

- [Two ways to boot a panel](generated-or-authored.md): the generated and authored entrypoints your upgraded project ends up with.
- [Project structure](project-structure.md): the feature-folder layout the tools now write.
- [CLI commands](../reference/cli-commands.md): `prepare`, `migrate`, `eject` and the rest.
- [Contributing to Beak](paths/contributing.md): send a fix if you hit a break this page does not cover.
