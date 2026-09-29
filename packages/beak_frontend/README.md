# beak_frontend

The Flutter admin panel for Beak: `BeakPanel` (shell + router) and generated
tables, forms, record views, actions, and filters on obers_ui, plus block-based
screens for overviews and dashboards.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture/index.md) for how the packages fit
together.

## What it is

The presentation layer of Beak. Pass resource objects to `BeakPanel` to install
navigation, list/read/create/edit routes, model-driven inputs, validation and
graph persistence. Resource screens describe layout; `BeakFormSession` owns
state and related drafts. Custom pages and widgets reuse the panel's data,
formatting and refresh scopes.

## Usage

With your generated models and resource definitions imported:

```dart
void main() => runApp(BeakPanel(
  title: 'Shop',
  resources: [ProductResource(), UserResource()],
  pages: [shopOverview(), shopOperations()],
));
```

`BeakPanel(config: config)` accepts a complete, host-built `BeakPanelConfig`
instead of the individual arguments. Tests may supply `dataSource: fakeSource`
to either form.

`/` opens the `BeakScreen` mounted at `/`, or else the panel's `home:` (a
`BeakScreen` or a `BeakResource`), or else the first visible navigation
destination.

See the [canonical shop entrypoint](../../examples/clean_beak_config/lib/main.dart)
and [declarative resources guide](../../docs/concepts/declarative-resources.md)
for complete runnable definitions.

## Key types

- `BeakPanel` — root widget with a scoped theme, router and data services.
- `BeakPanelConfig` — the declarative panel definition (resources, screens,
  apiBaseUrl, home, theming).
- `BeakResource` — one model surfaced as list/show/form pages, with its
  actions and filters.
- `BeakFormScreen` / `BeakWizardScreen` — layouts for ordinary and stepped forms.
- `BeakFormSections` — reusable sections projected into forms, tabs or steps.
- `BeakFormSession` / `BeakDraftScope` — state access for custom form widgets.
- `BeakRecordAction` / `BeakBulkAction` / `BeakGlobalAction` — presentation action
  hooks; model lifecycle actions are authoritative `BeakModelAction` declarations.
- `BeakImportView` / `BeakBulkEditView` — typed preview, validation and commit outcomes.
- `BeakSelectFilter` / `BeakTextFilter` / `BeakBoolFilter` — list-page filter
  controls bound to typed fields (`NoteModel.title.textFilter()`).
- `BeakScreen` — a custom route composed of blocks such as `BeakMetricBlock`
  and `BeakChartBlock`, for overviews and dashboards.
- `BeakIconToken` — a typed `OiIcons` wrapper for navigation icons.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[canonical shop](../../examples/clean_beak_config). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
