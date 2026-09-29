# AI directory

> Route a coding agent through Beak 0.9. The read order, the corrections to its training data, then rules, task map, source map, prompts and the docs bundle.

For coding agents. Humans: see [Beak](../index.md). Beak 0.9 is the first release of the `beak*` packages and it removed much of the tree most training data comes from. Read this page before you write Beak code: it gives the read order, the habits to drop and the page that answers each kind of question.

## Read in this order

1. Read the `AGENTS.md` block of the project. It names the docs folder and the rules for that kind of project. When `.dart_tool/beak/docs/` is missing, run `beak docs`.
2. Read the corrections table below. Whatever it lists, your memory has it wrong.
3. Read [Rules for agents](rules.md): the MUST and NEVER list, each rule with the command that checks it, and the known traps.
4. Open [Task map](task-map.md), find the row for your task, read the page it names, open the example file it names and copy the shape.
5. Open [Source map](source-map.md) when you need a symbol: its import library, its source file and its test.
6. Write the change, then run the verify command of the row. A task is done when that command shows it, not when the code looks right.

Read files by path (`.dart_tool/beak/docs/panel/resources.md`) and search with `grep -rn "<term>" .dart_tool/beak/docs`. A signature in a page can lag the code. When a page and the source disagree, the source wins, and you report the mismatch.

## What your training data gets wrong

Rows marked `(removed)` name symbols that no Beak package declares any more. The other rows name the 0.9 form that replaces a habit. `dart run tool/build_agent_docs.dart --check` fails when a symbol in the `Beak 0.9 does` column does not exist, or when a removed symbol is still declared by a Beak package (the vendored worm packages are not searched). A contributor who removes an API adds a row here.

| You may remember | Beak 0.9 does | Read |
| --- | --- | --- |
| `BeakResource.label`, `BeakResource.section`, `BeakScreen.label` (removed) | `title` is the page title, `navigationTitle` the sidebar entry, `navigationGroup` the sidebar heading. The generated panel fills `title` and `navigationGroup` from `label` and `section` in `beak.yaml` | [Resources](../panel/resources.md) |
| `viewModes`, `BeakTableView`, `BeakCalendarView`, `BeakResource.detail` (removed) | `screens:` on `BeakResource` holds a `BeakTableScreen` for the list and a `BeakFormScreen` whose `roles` say read, create or edit. Board and calendar are `BeakKanbanBlock` and `BeakCalendarBlock` on a `BeakScreen`, switched by `BeakTabsBlock`. The show page is derived from the model | [View modes](../panel/view-modes.md) |
| `createFields`, `editFields`, `createBuilder`, `editBuilder`, `formValueMode` (removed) | One `BeakFormScreen` layout serves every role. A custom screen uses `BeakConfiguredForm(valueMode:)` | [Form screens](../forms/form-screens.md) |
| `canCreateWhen`, `canEditWhen`, `canDeleteWhen`, `BeakResource.visibleWhen` (removed) | `BeakModel.permissions` holds live callbacks per `BeakOperation`. `canCreate`, `canEdit` and `canDelete` stay on `BeakResource` as booleans, and they only hide UI | [Resources](../panel/resources.md) |
| `BeakPanel.fromConfig(config: c)` (removed) | `BeakPanel(config: c)` or `BeakPanel(resources: [...])`, never both | [Two ways to boot a panel](../start-here/generated-or-authored.md) |
| `BeakDashboard`, `BeakStat`, `dashboardStats`, `dashboardCharts` (removed) | `home:` on `BeakPanel` names a `BeakScreen` or `BeakResource`, and `/` redirects to it, else to the first visible destination. Metrics and charts are `BeakMetricBlock` and `BeakChartBlock` on a `BeakScreen` | [Dashboards](../panel/dashboards.md) |
| `BeakKpiBlock`, `BeakKpiFormat` (removed) | `BeakMetricBlock` with `previous:`, `target:`, `format:` (`BeakValueFormat.number`, `.currency`, `.percent`) and `unit:` | [A dashboard KPI](../recipes/a-dashboard-kpi.md) |
| `BeakWizardBlock`, `BeakBlockWizardStep` (removed) | `BeakWizardScreen` for a wizard over a model. The obers_ui wizard from `package:beak/ui.dart` for anything else | [Multi-step forms](../forms/multi-step-forms.md) |
| `GET /api/search`, `GlobalSearchService`, `BeakSearchHandlers`, `BeakSearchHit` (removed) | `globalSearchSources` on `BeakResource`. The command bar sends one `POST /api/{table}/query` per resource | [Search and export](../backend/search-and-export.md) |
| `column: ProductColumns.status` on a filter (removed) | `field:`. Write `BeakSelectFilter(field: ProductModel.status, label: 'Status')` or `ProductModel.status.selectFilter(label: 'Status')` | [Filter builders](../reference/filter-builders.md) |
| `@Column(maxLength: 80)`, `@Column(min: 1)`, `@Column(max: 9)` (removed) | `rules: [BeakMaxLength(80)]`, `[BeakMin(1)]`, `[BeakMax(9)]`. A rule also sets the stored column length or bound | [Validation](../models/validation.md) |
| `lib/resources/<table>.dart`, `lib/dashboard.dart`, `beak eject dashboard` (removed) | A `BeakResource` subclass under `lib/resources/<plural>/` (`beak eject resource <table>` writes one). A `BeakScreen` with `path: '/'` under `lib/screens/`, or `home:` | [Panel and resource options](../reference/panel-options.md) |
| `BeakNavigationItem.page('/kitchen', label: 'Kitchen')` (removed) | `BeakNavigationItem.screen(kitchenScreen)`. `label:` and `icon:` stay as overrides | [Navigation](../panel/navigation.md) |
| `graphOnlyTables: {'orders'}` (removed) | `graphOnly: const [OrderModel()]` on `BeakServer` and `defaults.build`. Every model must be registered. It closes the per-record write routes and needs no `preparePlan` | [Transactional business rules](../backend/graph-business-rules.md) |
| `initializeWormPostgres`, `postgresAdapterFromUrl` (removed) | `initializeBeakDatabase`, `adapterFromUrl` | [Databases](../backend/databases.md) |
| `MinioS3ObjectClient` (removed), `dependency_overrides: xml` | `HttpS3ObjectClient(httpClient: ...)`. The S3 driver signs its own requests, so `beak` and `beak_storage_s3` resolve together with no override | [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) |
| `BeakSort(OrderModel.deliveryDate.key)`, `spec.orderBy(x.column)`, `sum(ProductModel.weight.column)` | `OrderModel.deliveryDate.ascending()` or `.descending()`, `spec.orderBy(OrderModel.deliveryDate)`, `spec.searching(term, [ProductModel.name])`, `sum(ProductModel.weight)` | [Queries](../reference/queries.md) |
| `submitAction: 'place'` and other actions by name | A `BeakModelAction` object: `submitAction: OrderActions.place`, `BeakFormActions(actions: [...])`, `bulkModelActions`. A preparer asks `plan.runs(OrderActions.place)` | [Actions](../panel/actions.md) |
| `BeakSummarySpec(table: ..., groupBy: X.label.column)` | `const XModel().summary(groupBy: XModel.label, measures: [measure])`, read with `row.valueOf(measure)`. A `BeakDecimal` money field sums with `BeakSummaryMeasure.sumDecimal`, read with `row.decimalOf(measure)` | [Population summaries](../blocks/summaries.md) |
| `@BelongsTo(searchOn: ['email'])` | `searchOn: [#email, #lastName]`. Each symbol is checked against the related schema | [Relationships](../models/relationships.md) |
| `NoteColumns.title`, `lib/models/note.dart` | `NoteModel.title`, from `lib/resources/<plural>/models/<name>.dart`. You never write a column string | [Generated files and symbols](../reference/generated-files.md) |
| `Map<String, dynamic>` rows, `as` casts, string keys | `BeakRecord` and `BeakValue` on the wire, `BeakQuerySpec` for queries, generated field references in your code | [The type-safety promise](../concepts/the-type-safety-promise.md) |
| A `double` price | A `BeakDecimal` field with `semantic: BeakSemantic.money(currency: 'EUR')`. Exact, stored as a scaled integer, formatted by the panel | [A money field](../recipes/a-money-field.md) |
| Any size, gap or timeout without a unit | The unit is in the name: `headerGapInPixels`, `minColumnWidthInPixels`, `maxSizeInBytes`, `timeoutInSeconds` | [Screens and form layouts](../reference/screens-and-layouts.md) |
| One editable `lib/main.dart` | Two bootstraps. Generated: `runApp(const BeakApp())` in a `lib/main.dart` that `beak prepare` owns. Authored: `BeakPanel(resources: [...])` in a `lib/main.dart` you own. `beak eject main` switches, `beak create --authored` starts authored | [Two ways to boot a panel](../start-here/generated-or-authored.md) |
| Editing `*.beak.dart` or `lib/beak/*.g.dart` to change wiring | Never. Edit the schema class, resource class, screen or `beak.yaml`, then run `beak prepare`. `beak doctor` byte-compares generated files | [Generated code](../models/generated-code.md) |
| The ORM syncs the schema at startup, or `build_runner` generates code | Migrations are explicit `Migration` classes in `lib/migrations/`. `beak prepare` writes the create-table migration for a new model, `beak migrate` applies migrations, and nothing applies one on its own. A shipped table changes with `beak make:migration <Name> --from-drift`; an applied migration is never edited | [Migrations](../backend/migrations.md) |
| A Beak server is closed until you add auth | A `BeakServer` without a `policy` runs `BeakAllowAllPolicy`: everyone, anonymous included, may read and write. `BeakPolicies` with `BeakModelRules` and `BeakAccess` denies whatever it does not list | [Auth and policies](../backend/auth-and-policies.md) |
| `StatefulWidget`, `package:flutter/material.dart` | `HookWidget`, and the UI from `package:beak/ui.dart` (obers_ui): `OiCard`, `OiColumn`. A Material or Cupertino import is a defect | [Rules for agents](rules.md) |
| A Serverpod project means the client bridge | Two paths. The admin app inside the workspace runs Beak's API in the Serverpod server (`BeakServerpodEngine` behind `BeakAdminGate`). The bridge (`ServerpodResource`) puts the panel over an existing client and changes nothing on the server | [Choosing an integration](../serverpod/choosing-an-integration.md) |

Search your own code for the removed names before you report a change. Nothing should match:

```bash
grep -rnE "viewModes|fromConfig|BeakKpiBlock|BeakWizardBlock|graphOnlyTables|initializeWormPostgres|api/search|BeakDashboard" lib test
```

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Give an agent the AGENTS.md block, the skills and the docs it needs in a Beak project | [Set up your agent](setup.md) | What `beak agents` writes, the markers, `CLAUDE.md` pairing, skills and how to check the agent reads the docs |
| Know what an agent must and must never do in a Beak project | [Rules for agents](rules.md) | The MUST and NEVER list with a check for each, and the open traps that change generated code |
| Find the page, the example file and the check for a task | [Task map](task-map.md) | More than seventy tasks, each with the page to read, the file to open and the command that verifies it |
| Find the import, the file and the test for a symbol or an area | [Source map](source-map.md) | Which `package:beak/...` library carries a symbol, where it is defined and which test covers it |
| Start an agent on a Beak task with a prompt that asks for evidence | [Prompt recipes](prompts.md) | Paste-ready prompts per starting situation and per workflow skill, with the evidence to demand |
| Read the docs as files, or pin them to a version | [Machine-readable docs](machine-readable-docs.md) | `llms.txt`, `llms-full.txt`, Markdown twins, the bundle in `beak_core` and what each promises |

## Continue reading

- [Rules for agents](rules.md): the MUST and NEVER list and the open traps.
- [Task map](task-map.md): the page, file and command for each common task.
- [Set up your agent](setup.md): install the AGENTS.md block, skills and docs in a project.
