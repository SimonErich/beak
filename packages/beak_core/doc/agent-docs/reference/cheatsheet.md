# Cheatsheet

> The whole toolbox on one page. One resource end to end, then every common task mapped to the Beak declaration that does it.

Every row says what you want, what you declare, and which page has the signature. Nothing here is a string field name: fields are the generated references (`CategoryModel.name`), and every declaration is a typed object. Dense on purpose; the pages linked in the right column are the complete tables.

## Import

| A file that is... | Imports |
| --- | --- |
| a schema class | `package:beak/beak.dart` and `package:beak/schema.dart` |
| a resource, screen or `main.dart` | `package:beak/panel.dart`, plus `package:beak/ui.dart` for `OiIcons` and your own widgets |
| `lib/server.dart` | `package:beak/server.dart` |
| a migration or seeder | `package:beak/migrations.dart` |
| a test | `package:beak/testing.dart` |

The other libraries and what each may reach are in [Libraries](libraries.md).

## Summary

| Section | Answers |
| --- | --- |
| [One resource, end to end](#one-resource-end-to-end) | What a complete resource looks like, and the four commands around it |
| [Commands](#commands) | Which `beak` command for which job |
| [Schema](#schema) | Tables, columns, rules, relationships, behavior |
| [Lists and filters](#lists-and-filters) | Columns, filters, search, presets, saved views, summaries, export |
| [Forms](#forms) | Layouts, inputs, wizards, related rows, drafts, review |
| [Actions](#actions) | Buttons, bulk actions, model commands |
| [Pages and blocks](#pages-and-blocks) | Custom pages, dashboards, custom widgets |
| [The panel](#the-panel) | Navigation, auth, maintenance, theme, formatting |
| [The backend](#the-backend) | Policies, business rules, effects, storage, middleware |
| [Data and tests](#data-and-tests) | Queries, the data source, the testing toolkit |
| [Where a decision lives](#where-a-decision-lives) | Which file owns which choice |

## One resource, end to end

The schema class declares the table, the columns and the relationship. `beak prepare` writes everything derived from it.

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.dart"
/// Category title.
@Display()
@Column(searchable: true, sortable: true)
late final String name;

/// Description shown to administrators.
late final String? description;
```

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.dart"
/// Attributes expected for products in this category.
@HasMany(owned: true, onDelete: BeakOnDelete.cascade)
late final List<CategoryAttribute> attributes;
```

The resource class presents it: navigation, search, filters and screens. Everything not listed keeps its default.

```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
final class CategoryResource extends BeakResource {
  /// Creates the categories section.
  CategoryResource()
    : super(
        model: const CategoryModel(),
        title: 'Categories',
        icon: const BeakIconToken(OiIcons.folderTree),
        navigationGroup: 'Catalog',
        navigationRank: 5,
        globalSearchSources: [
          CategoryModel.name,
          CategoryModel.description,
          CategoryModel.attributes.search(CategoryAttributeModel.name),
        ],
        filters: [CategoryModel.name.textFilter()],
        screens: [
          BeakTableScreen(
            fields: [CategoryModel.name, CategoryModel.description],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: categoryForm(),
          ),
        ],
      );
}
```

```console
$ beak make:resource Category --fields name:string!,description:string   # or write the two classes by hand
$ beak prepare      # parts, registry, panel, server, entrypoints, first migration
$ beak migrate      # create the tables
$ beak dev          # serve the API, print the flutter run line
```

Add the resource to `resources: [...]` in an authored `lib/main.dart`; a generated `lib/main.dart` finds it by itself. Details: [CLI commands](cli-commands.md), [Generated files and symbols](generated-files.md).

## Commands

| You want to... | Run | Page |
| --- | --- | --- |
| Start a project | `beak create <name>` (`--authored`, `--no-example`, `--skills`) | [CLI commands](cli-commands.md#beak-create) |
| Add the panel to a Flutter app | `beak init` | [CLI commands](cli-commands.md#beak-init) |
| Regenerate after any declaration changed | `beak prepare` | [CLI commands](cli-commands.md#beak-prepare) |
| Scaffold a resource | `beak make:resource Name --fields a:string!,b:int` | [CLI commands](cli-commands.md#beak-makeresource) |
| Change a shipped table | `beak make:migration Name --from-drift` | [CLI commands](cli-commands.md#beak-makemigration) |
| Apply, inspect, undo migrations | `beak migrate [up\|status\|down\|fresh\|refresh]` | [CLI commands](cli-commands.md#beak-migrate) |
| Load demo data | `beak seed [--class Name]` | [CLI commands](cli-commands.md#beak-seed) |
| Adopt an existing database | `beak introspect <url> [--ownership adopt\|external]` | [CLI commands](cli-commands.md#beak-introspect) |
| Own a default | `beak eject main\|panel\|resource <table>\|theme\|auth\|server` | [CLI commands](cli-commands.md#beak-eject) |
| Serve the API | `beak dev` | [CLI commands](cli-commands.md#beak-dev) |
| Check the project | `beak doctor [--json]` | [CLI commands](cli-commands.md#beak-doctor) |
| Prepare a coding agent | `beak agents`, `beak docs` | [CLI commands](cli-commands.md#beak-agents) |

## Schema

| You want... | Declare | Page |
| --- | --- | --- |
| A table and a model from a class | `@Resource()` on `final class X extends BeakSchema`, with `part 'x.beak.dart';` | [Annotations](annotations.md#resource) |
| A custom table name, soft deletes, timestamps | `@Resource(table:, softDeletes: true, timestamps: true)` | [Annotations](annotations.md#resource) |
| A table another system migrates | `@Resource(managesSchema: false)` | [Annotations](annotations.md#resource) |
| A field to be required | A non-nullable Dart type | [Field types](field-types.md) |
| A record to be named in pickers and titles | `@Display()` on one field | [Annotations](annotations.md#display) |
| Search, sort or filter a column | `@Column(searchable: true, sortable: true, filterable: true)` | [Annotations](annotations.md#column) |
| A bound or a format on a value | `@Column(rules: [BeakMin(0), BeakMaxLength(255), BeakEmail()])` | [Validation rules](validation-rules.md) |
| Exact money | A `BeakDecimal` field with `semantic: BeakSemantic.money(currency: 'EUR')` | [Field types](field-types.md) |
| Long text, rich text, a colour, JSON | `BeakText`, `BeakRichText`, `BeakHexColor`, `BeakJson` | [Field types](field-types.md) |
| An enum shown as a badge | An enum-typed field with `@Badges` and `@EnumLabels` | [Annotations](annotations.md#badges-and-enumlabels) |
| An uploaded image or file | `@Image(...)` or `@FileField(...)` | [Annotations](annotations.md#image-and-filefield) |
| One related record | `@BelongsTo` (this table holds the key), `@HasOne` | [Annotations](annotations.md#belongsto) |
| Many related records | `@HasMany` (`owned: true` to edit them with the parent), `@BelongsToMany` | [Annotations](annotations.md#hasmany) |
| A rule across fields or rows | `static List<BeakRecordRule> get validationRules` with `BeakCount`, `BeakSameAs`, `BeakRequiredIf`, `BeakDistinct`, `BeakSum` | [Validation rules](validation-rules.md#record-rules) |
| A rule that asks the database | `BeakUnique`, `BeakExists` with `BeakFieldMatch` | [Validation rules](validation-rules.md#async-rules) |
| Default, suggested or calculated values | `static BeakModelBehavior get behavior` with `BeakValueBehavior.initial`, `.suggested`, `.derived`, `.snapshot` | [Behavior and actions](behavior-and-actions.md) |
| A guarded state change | `BeakModelAction` objects in `BeakModelBehavior.actions` | [Behavior and actions](behavior-and-actions.md) |
| Edit and delete guards | `BeakModelBehavior.editableWhen`, `deletableWhen` | [Behavior and actions](behavior-and-actions.md) |
| A column Beak has no type for | `@Custom` on an `Object` field, plus a registered renderer | [Custom columns](../extending/custom-columns.md) |

## Lists and filters

| You want... | Declare | Page |
| --- | --- | --- |
| A list with chosen columns | `BeakTableScreen(fields: [X.a, X.b])` in `BeakResource.screens` | [Screens and form layouts](screens-and-layouts.md) |
| A permanent scope on a list | `BeakTableScreen(query: X.query(filter: ...))` | [Queries](queries.md) |
| Filter controls | `BeakResource.filters: [X.name.textFilter(), X.status.selectFilter(), X.price.numberRangeFilter()]` | [Filter builders](filter-builders.md) |
| Search across own and related fields | `BeakResource.globalSearchSources: [X.name, X.attributes.search(Y.name)]` | [Queries](queries.md#search) |
| Named views with counts, quick filters, saved views | `BeakTableScreen(definition: BeakListDefinition(presets: [BeakQueryPreset(...)], savedViews: ...))` | [Composed lists](../panel/composed-lists.md) |
| A CSV of the whole query | `BeakListDefinition(export: BeakListExport(...))` | [Composed lists](../panel/composed-lists.md) |
| Totals over the whole matching set | `model.summary(...)` rendered by a summary block | [Queries](queries.md#summaries) |
| One number | `model.count`, `model.sum`, `model.avg` | [Queries](queries.md#aggregates) |
| A CSV import | `BeakImportView(definition: BeakImportDefinition(...))` | [Imports and bulk edits](../forms/imports-and-bulk-edits.md) |

## Forms

| You want... | Declare | Page |
| --- | --- | --- |
| One form for read, create and edit | `BeakFormScreen(roles: {read, create, edit}, layout: ...)` | [Screens and form layouts](screens-and-layouts.md) |
| Layout | `BeakFormLayout`, `BeakCard`, `BeakSection`, `BeakColumns`, `BeakTabs` | [Screens and form layouts](screens-and-layouts.md) |
| Sections shown as a form, tabs or steps | `BeakFormSections` projections | [Screens and form layouts](screens-and-layouts.md) |
| A wizard | `BeakWizardScreen` with `BeakWizardStep` | [Multi-step forms](../forms/multi-step-forms.md) |
| An input for a field | `X.name.inputText()`, `X.price.inputCurrency()`, `X.active.inputToggle()`, `X.due.inputDate()` | [Input builders](input-builders.md) |
| A related record picker | `X.category.inputCombobox()`, `.inputSearch()`, `.inputCards()` | [Input builders](input-builders.md) |
| Owned children edited inline | `X.items.tableForm(...)` | [Related records in forms](../forms/related-records.md) |
| An image gallery | `X.images.galleryForm(...)` | [Uploads and galleries](../forms/uploads-and-galleries.md) |
| Show or enable an input conditionally | `visibleIf:` and `enabledIf:` on any node or input | [Input builders](input-builders.md) |
| Client-only validation | `validate: [...]`, `validators: [...]` on an input | [Input builders](input-builders.md) |
| A reactive display value | `BeakCalculated`, `BeakFormSummary`, `BeakFormMetrics` | [Screens and form layouts](screens-and-layouts.md) |
| Resume drafts | `BeakFormScreen(drafts: ...)` | [Drafts, review and conflicts](../forms/drafts-and-review.md) |
| Review before saving | `BeakFormScreen(reviewBeforeSave: true)` with `BeakReviewSection` | [Drafts, review and conflicts](../forms/drafts-and-review.md) |
| See resolved state while building | `BeakFormScreen(showInspector: true)`, `session.explain()` | [Drafts, review and conflicts](../forms/drafts-and-review.md) |
| A custom input over the same draft | `BeakFormWidget`, reading `BeakDraftScope` | [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) |
| Duplicate a record with its children | `BeakResource.duplication: BeakDuplicationSpec(...)` | [Actions](../panel/actions.md#bulk-edits-and-duplication) |

## Actions

| You want... | Declare | Page |
| --- | --- | --- |
| A button per row | `BeakResource.recordActions: [BeakRecordAction(...)]` | [Behavior and actions](behavior-and-actions.md) |
| A button over the selection | `BeakResource.bulkActions: [BeakBulkAction(...)]` | [Behavior and actions](behavior-and-actions.md) |
| A bulk edit of typed fields | `BeakBulkAction.edit(...)` | [Imports and bulk edits](../forms/imports-and-bulk-edits.md) |
| A page-level button | `BeakResource.globalActions: [BeakGlobalAction(...)]` | [Behavior and actions](behavior-and-actions.md) |
| A guarded command in the layout | `BeakFormActions` over a `BeakModelAction` | [Behavior and actions](behavior-and-actions.md) |
| Hide create, edit or delete | `BeakResource(canCreate: false, canEdit: false, canDelete: false)` (UI only; the server decides) | [Panel and resource options](panel-options.md#beakresource) |

## Pages and blocks

| You want... | Declare | Page |
| --- | --- | --- |
| A custom page | `BeakScreen(path:, title:, icon:, body: ...)` in `lib/screens/` | [Custom screens](../panel/custom-screens.md) |
| A KPI, a chart, a table on a page | `BeakMetricBlock`, `BeakChartBlock`, `BeakTableBlock` | [Blocks](blocks.md) |
| A kanban, calendar, map, timeline | `BeakKanbanBlock`, `BeakCalendarBlock`, `BeakMapBlock`, `BeakTimelineBlock` | [Blocks](blocks.md) |
| Your own widget in a page | `BeakWidgetBlock((context) => ...)` | [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) |
| A dashboard as the home page | `BeakPanelConfig.home: BeakDestination` | [Dashboards](../panel/dashboards.md) |

## The panel

| You want... | Declare | Page |
| --- | --- | --- |
| A panel from resources you list | `BeakPanel(title:, resources: [...])` in an authored `lib/main.dart` | [Panel and resource options](panel-options.md#beakpanel) |
| A panel generated from the models | `beak.yaml` and `runApp(const BeakApp())` | [beak.yaml](beak-yaml.md) |
| Navigation groups and order | `BeakResource(navigationGroup:, navigationRank:)`, `BeakNavigation` with `BeakNavigationSection` and `BeakNavigationItem` | [Navigation](../panel/navigation.md) |
| Hide a resource from the sidebar | `resources.<table>.hidden: true` in `beak.yaml`, or leave it out of `resources: [...]` | [beak.yaml](beak-yaml.md#resources) |
| Sign-in, registration, idle lock | `BeakAuthConfig` in `lib/auth.dart` | [Auth and idle-lock](../panel/auth-and-idle-lock.md) |
| Maintenance and coming-soon pages | `BeakMaintenanceConfig` | [Maintenance and coming soon](../panel/maintenance-and-coming-soon.md) |
| Themes | `beakLightTheme()`, `beakDarkTheme()` in `lib/theme.dart` | [Theming basics](../theming/theming-basics.md) |
| Date, number and currency display | `BeakFormatting` | [Formatting and localization](../theming/formatting-and-localization.md) |
| Map server errors to messages | `BeakPanelConfig.mapException` | [Panel and resource options](panel-options.md#mapexception) |

## The backend

| You want... | Declare | Page |
| --- | --- | --- |
| Who may do what | `BeakPolicies(rules: [BeakModelRules(const OrderModel(), read: BeakAccess.role('staff'))])` passed to `defaults.build(policy:)` | [Auth and policies](../backend/auth-and-policies.md) |
| Row scoping | A `BeakRowPolicy` | [Auth and policies](../backend/auth-and-policies.md) |
| Field and action gates | `BeakFieldPolicy`, `BeakActionPolicy` | [Auth and policies](../backend/auth-and-policies.md) |
| Login, logout, me | `authSessions:` on `defaults.build` | [Auth and policies](../backend/auth-and-policies.md) |
| Business rules inside one transaction | `preparePlan:` returning an edited `BeakSavePlan` | [Transactional business rules](../backend/graph-business-rules.md) |
| Force writes through those rules | `graphOnly: const [OrderModel()]` | [Transactional business rules](../backend/graph-business-rules.md) |
| Durable effects | `finalizePlan:` and `outbox: BeakOutboxSchedule(...)` | [Durable effects](../backend/durable-effects.md) |
| Middleware and extra routes | `middleware:` and `routes:` on `defaults.build` | [Middleware](../backend/middleware.md) |
| A database | `DATABASE_URL` (`sqlite:` or `postgres://`) | [Configuration and environment](configuration.md#the-server) |
| An upload driver | `BEAK_STORAGE_DRIVER` and the driver's variables | [Configuration and environment](configuration.md#storage) |
| A migration | `beak make:migration Name`, or `--from-drift` | [Migrations](../backend/migrations.md) |
| Seed data | A `Seeder` under `lib/seeders/` | [Seeding](../backend/seeding.md) |

## Data and tests

| You want... | Use | Page |
| --- | --- | --- |
| A typed query | `const ProductModel().query(filter: BeakFilter.allOf([ProductModel.active.eq(true)]))` | [Queries](queries.md) |
| Sort | `X.price.ascending()`, `X.price.descending()` | [Queries](queries.md#sorts) |
| Load a relation | `spec.withRelation(...)` | [Queries](queries.md#relation-loads) |
| Call the API from Dart | `BeakClient`, or a `BeakDataSource` | [REST API](rest-api.md) |
| Handle a failure | `BeakException` variants; `BeakResult` in the panel | [Exceptions](exceptions.md) |
| A fake data source | `InMemoryBeakDataSource(registry: buildBeakRegistry())` | [Testing](../shipping/testing.md) |
| Prove a data source correct | `runBeakDataSourceContract` | [Testing](../shipping/testing.md) |
| Prove a model matches its migration | `expectSchemaParity` | [Testing](../shipping/testing.md) |
| Fake records | `beakFakeRecord(const ProductModel())` | [Testing](../shipping/testing.md) |

## Where a decision lives

| Decision | File |
| --- | --- |
| Columns, relationships, rules, behavior, table name | the schema class, `lib/resources/<plural>/models/<name>.dart` |
| How the panel presents one model | its `BeakResource` class, `lib/resources/<plural>/<name>_resource.dart` |
| A custom page | `lib/screens/<name>.dart` |
| Panel title, API origin, default port, agent files | `beak.yaml` |
| Which resources the panel lists, when you own `lib/main.dart` | `lib/main.dart` (or `panel.entrypoint`) |
| Theme, auth, panel config | `lib/theme.dart`, `lib/auth.dart`, `lib/panel.dart` |
| Policy, middleware, business rules, extra storage drivers | `lib/server.dart` |
| Database, port, storage credentials | the environment and `.env` |
| Derived code | `lib/beak/*.g.dart` and `*.beak.dart`: committed, never edited |

## Source

- `examples/clean_beak_config` is the maintained shop that every row above can be found in.
- `examples/quickstart` is the scaffold `beak create` writes.
- The pages linked in each table are the complete lookups.

## Continue reading

- [Annotations](annotations.md) the schema side in full.
- [Panel and resource options](panel-options.md) the presentation side in full.
- [CLI commands](cli-commands.md) every command, flag and exit code.
- [Configuration and environment](configuration.md) the environment and the override files.
