# beak_frontend

The Flutter admin panel of Beak. `BeakPanel` is the root widget: give it
resources and it builds the shell, the router, and for each resource a list
page, a form, a detail page, actions and filters, all on obers_ui. Custom pages
are trees of blocks, from a metric card to a kanban board.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter.

## When you depend on it

An app does not. It imports `package:beak/panel.dart` from the
[`beak`](https://github.com/SimonErich/beak/tree/main/packages/beak) umbrella,
which re-exports this package and `beak_core`. Depend on `beak_frontend`
directly to build a Flutter package that ships Beak widgets, as
`beak_serverpod_flutter` does.

The panel is obers_ui only. Beak imports no Material and no Cupertino, and the
repo's `melos run guard-material` fails on any that appear. State lives in
Signals view models, dependencies in a GetIt container the panel owns
(`beakDependencies(context)`), and routes in go_router.

## A panel from resources

A `BeakResource` says how one model is presented. The model is the generated
`XModel`, so a field is always a reference such as `HabitatModel.name` and never
a string:

```dart title="examples/showcase/lib/resources/habitats/habitat_resource.dart"
/// The exhibits, with the birds and keepers each one connects to.
final class HabitatResource extends BeakResource {
  /// Creates the habitats section.
  HabitatResource()
    : super(
        model: const HabitatModel(),
        title: 'Habitats',
        icon: const BeakIconToken(OiIcons.trees),
        navigationGroup: 'Collection',
        navigationRank: 2,
        globalSearchSources: [HabitatModel.name, HabitatModel.countryCode],
        filters: [HabitatModel.capacity.numberRangeFilter()],
      );
}
```

Leave `screens` empty and Beak derives the table, the form and the detail page
from the model. The panel is the list of resources plus one formatting policy:

```dart title="examples/clean_beak_config/lib/main.dart"
void main() => runApp(
  BeakPanel(
    title: 'Clean Beak Shop',
    theme: OiThemeData.fromBrand(color: const Color(0xFF315D91)),
    darkTheme: OiThemeData.fromBrand(
      color: const Color(0xFF82ACDF),
      brightness: Brightness.dark,
    ),
    locale: const Locale('en'),
    formatting: const BeakFormatting(
      locale: 'de_AT',
      currency: 'EUR',
      datePattern: 'dd.MM.yyyy',
      dateTimePattern: 'dd.MM.yyyy HH:mm',
    ),
    pages: [shopOverview(), shopOperations()],
    resources: [
      OrderResource(),
      InvoiceResource(),
      VoucherResource(),
      ProductResource(),
      VariantResource(),
      CategoryResource(),
      UserResource(),
      CompanyResource(),
      ProfileResource(),
      TaxRateResource(),
      FulfillmentPolicyResource(),
    ],
  ),
);
```

That is the authored bootstrap. A project that leaves the panel to `beak prepare`
boots the generated `BeakApp` (`lib/beak/app.g.dart`) instead, which builds the
same `BeakPanel` from `lib/beak/panel.g.dart`. Both are supported, and
`beak eject main` switches from the second to the first.

## Panel options

`BeakPanel(title:, resources:, ...)` takes the everyday options: `theme`,
`darkTheme`, `locale`, `formatting`, `pages`, `auth`, `navigation`,
`refreshPolicy`, `apiBaseUrl` and `home`. The rest lives on `BeakPanelConfig`,
which you pass as `BeakPanel(config: ...)` and never together with `resources:`:
`mapException`, `maintenance`, `notifications`, `shellActions`,
`initialThemeMode`, the sidebar flags, `supportedLocales` and
`localizationsDelegates`.

```dart
BeakException? mapDomainFailure(Exception exception, StackTrace stackTrace) =>
    null; // return a BeakException for the host errors you recognise

Widget panel() => BeakPanel(
  config: BeakPanelConfig(
    title: 'Acme Admin',
    resources: [NoteResource()],
    home: NoteResource(),
    mapException: mapDomainFailure,
  ),
);
```

`/` opens the `BeakScreen` mounted at `/` if there is one, else `home` (a
`BeakScreen` or a `BeakResource` the panel declares), else the first navigation
destination the account may see. `apiBaseUrl` defaults to the
`BEAK_API_BASE_URL` dart-define, then `http://localhost:8080`. `dataSource:` replaces the
HTTP data source entirely: widget tests pass an `InMemoryBeakDataSource`, and
the Serverpod admin app passes one that tunnels through its endpoint.

## Screens and blocks

A resource replaces any generated page with a screen. Each screen names the
roles it serves.

| Screen | Roles | What it is |
| --- | --- | --- |
| `BeakTableScreen` | list | Typed fields in display order, a base query, or a composed list with presets, saved views and typed cells (`BeakListDefinition`). |
| `BeakFormScreen` | create, edit by default; add `read` for the read page | One typed layout for all of them, built from `BeakFormSections` (cards, tabs, columns), with drafts, review before save and named actions. |
| `BeakWizardScreen` | create, edit | The same form session as ordered steps. |
| `BeakCustomResourceScreen` | any | A widget of your own that keeps the resource's routing and permissions. |

A `BeakScreen` is a page that belongs to no resource: a `path`, a `title`, an
`icon` and a `body` built from blocks (`BeakMetricBlock`, `BeakChartBlock`, the
table, summary, kanban, calendar and module blocks, and `BeakWidgetBlock` for
any obers_ui widget). Against `beak_backend`, a form save goes through
`POST /api/commits`, so it is atomic and a retry is safe.

## Main types

| Type | What it is |
| --- | --- |
| `BeakPanel`, `BeakPanelConfig` | The root widget, and the complete panel definition it builds. |
| `BeakResource` | One model as list, read, create and edit pages, with actions, filters and search. |
| `BeakNavigation`, `BeakNavigationItem` | An optional primary rail and contextual navigation. |
| `BeakFormLayout`, `BeakFormSections` | Typed form structure, projected into a form, tabs or wizard steps. |
| `BeakFormSession`, `BeakDraftScope` | The state a custom form widget reads and edits. |
| `BeakRecordAction`, `BeakBulkAction`, `BeakGlobalAction` | Presentation hooks. Authoritative lifecycle actions are `BeakModelAction`s declared on the model. |
| `BeakSelectFilter`, `BeakTextFilter`, `BeakBoolFilter` | List filters bound to a typed field (`NoteModel.title.textFilter()`). |
| `BeakImportView`, `BeakBulkEditView` | Typed preview, validation and commit outcomes for imports and bulk edits. |
| `BeakFormatting` | One date, number and currency policy for forms, tables and detail rows. |
| `BeakAuthConfig`, `BeakAuthAdapter` | Login, registration and idle lock over your auth backend. |
| `HttpBeakDataSource`, `BeakResourceRepository` | The REST data source, and the repository that is the catch boundary between it and the view models. |

## Limits

- **The obers_ui pin does not compile yet.** This package pins obers_ui,
  obers_ui_autoforms and obers_ui_charts by git commit. The commit is fetchable
  but predates components this package uses: `OiFilterChip`, `OiPageLayout`,
  `OiCapacityIndicator`, `OiHatchPlaceholder`, `OiIcon.raw`, and in
  `lib/src/form/beak_value_input.dart` `OiFieldLabel`,
  `OiComponentThemes.radio` and `OiTextInputThemeData.labelStyle`. The obers_ui
  state that has them is not published, so a project resolved from the pin fails
  to build. Until the pin moves to a published commit that has them, work from a
  checkout of the Beak repo with an `obers_ui` checkout beside it and run
  `melos run link-obers-ui`.
- **`BeakWizardScreen` takes a subset of `BeakFormScreen`'s options.** It has
  no `layout`, `submitIcon`, `outlinedCancel`, `editingLabel`,
  `showActionsWhileEditing`, `showChangeBar` or `asideFraction`.
- **Record blocks need a scope.** `BeakFieldBlock`, `BeakFieldGroupBlock` and
  `BeakRelationBlock` read a `BeakRecordScope`, and no built-in page mounts one.
  Wrap them yourself in a `BeakCustomResourceScreen`.
- **Some blocks fetch once.** Metric and summary blocks refetch after a write
  to their table. Chart, kanban and calendar blocks do not.
- **`BeakPanel(resources: ...)` has no `mapException`.** Domain errors from a
  custom source, such as the Serverpod bridge, need `BeakPanelConfig`.
- **Authorization is not here.** Permissions hide controls. The server, through
  `BeakPolicies`, decides.

## Continue reading

- [The panel](https://simonerich.github.io/beak/panel/): resources, navigation, tables, actions and custom screens.
- [Forms and records](https://simonerich.github.io/beak/forms/): form screens, wizards, drafts and related records.
- [Blocks and charts](https://simonerich.github.io/beak/blocks/): every block, by category.
- [Panel and resource options](https://simonerich.github.io/beak/reference/panel-options/): every `BeakPanel`, `BeakPanelConfig` and `BeakResource` parameter.
- [Two ways to boot a panel](https://simonerich.github.io/beak/start-here/generated-or-authored/): generated `BeakApp` or an authored `BeakPanel`.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
