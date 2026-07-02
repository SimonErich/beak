---
name: obers-ui-usage
description: How to build Beak's Flutter UI with obers_ui, obers_ui_autoforms, and obers_ui_charts — the no-Material rule, which widget to use for each admin need, and how to consult the obers_ui docs.
---

# obers-ui-usage

obers_ui is a 4-tier, Material-free Flutter design system with a strong **admin**
component set. Package lives at `~/Flutters/obers_ui`; **full docs are in
`~/Flutters/obers_ui/doc`** and the barrel is `package:obers_ui/obers_ui.dart`. When a
widget's exact params are unclear, read the doc file rather than guessing.

## The rule: no Material, ever

- Do **not** import `package:flutter/material.dart` or `.../cupertino.dart`, and do not
  use a single Material widget. If you reach for `Scaffold`, `AppBar`, `TextField`,
  `DataTable`, `ElevatedButton`, `showDialog`, `Navigator.push` — STOP and find the `Oi*`
  equivalent below.
- `package:flutter/widgets.dart` is fine for primitives only (`BuildContext`, `Widget`,
  `Key`, `EdgeInsets`, `Color`, `ValueChanged`, `Axis`, `TextAlign`).
- State = Signals, DI = GetIt, routing = go_router, widgets = `HookWidget` (no
  `StatefulWidget`). Local widget state uses hooks (`useState`, etc.) or Signals.

## 4 tiers (never skip a tier in composition)

Foundation → Primitives (`OiLabel`, `OiSurface`, `OiTappable`, `OiGrid`) → Components
(`OiButton`, `OiTextInput`, `OiCard`, `OiDialog`) → Composites (`OiTable`, `OiForm`,
`OiDetailView`, `OiSidebar`) → Modules (`OiAppShell`, `OiResourcePage`, `OiListView`).

## App shell & CRUD scaffolding (use these for Beak's panel)

- `OiApp` / `OiApp.router(routerConfig: goRouter, theme:, darkTheme:, themeMode:)` — root.
  Set `settingsDriver: OiLocalStorageDriver()` to auto-persist table state.
- `OiAppShell(child:, label:, navigation: [OiNavItem(...)], leading:, actions:, userMenu:,
  breadcrumbs:, sidebarCollapsible:)` — sidebar + top bar + content. Beak's panel maps
  each registered resource to an `OiNavItem`.
- `OiResourcePage(title:, label:, child:, variant: list|show|edit|create, actions:,
  filters:, pagination:, breadcrumbs:)` — CRUD page scaffold with sensible default
  action buttons per variant. Beak's auto CRUD pages render into this.
- `OiAuthPage.login(...)` / `.register(...)` / `.forgotPassword(...)` — auth screens.
- `OiErrorPage.notFound()/.forbidden()/.serverError()` — error routes.

## Tables (Beak DataTable → OiTable)

`OiTable<T>(label:, rows:, columns: [OiTableColumn<T>(id:, header:, cellBuilder:,
valueGetter:, sortable:, filterable:, resizable:, hidden:, frozen:)], controller:,
selectable:, multiSelect:, rowKey:, onSelectionChanged:, onRowTap:, onRowDoubleTap:,
serverSideSort: true + onSort:, serverSideFilter: true + onFilter:, paginationMode:
none|pages|infinite|virtual, totalRows:, onLoadMore:, pageSizeOptions:, showColumnManager:,
onCellChanged: (inline edit), striped:, dense:, loading:, settingsDriver:, settingsKey:)`.
- Beak maps each `BeakColumn` to an `OiTableColumn` and drives sort/filter/pagination
  **server-side** through the `BeakQuerySpec` → backend.
- `OiDataGrid<T>` is the lighter read-only alternative; use `OiTable` when you need
  inline edit / column management / server-side ops. `OiDetailView` for read-only records.

## Forms — prefer obers_ui_autoforms (controller-first, enum-keyed)

Import `package:obers_ui_autoforms/obers_ui_autoforms.dart` (prefix `OiAf`). This is the
best fit for Beak's typed field model — a form controller keyed by an enum, with 60+
Laravel-style validators.

```dart
enum ProductField { name, price, status }

class ProductFormController extends OiAfController<ProductField, ProductInput> {
  @override
  void defineFields() {
    addTextField(ProductField.name, required: true, validators: [OiAfValidators.maxLength(255)]);
    addNumberField(ProductField.price, min: 0);
    addSelectField<ProductStatus>(ProductField.status, options: [...]);
  }
  @override
  ProductInput buildData() => ProductInput(/* typed, from field values */);
}

OiAfForm<ProductField, ProductInput>(
  controller: controller,
  onSubmit: (data, ctrl) async { /* call repository */ },
  child: OiColumn(children: [
    OiAfTextInput<ProductField>(field: ProductField.name, label: 'Name'),
    OiAfNumberInput<ProductField>(field: ProductField.price, label: 'Price'),
    OiAfSelect<ProductField, ProductStatus>(field: ProductField.status, label: 'Status'),
    OiAfSubmitButton<ProductField, ProductInput>(label: 'Save'),
  ]),
)
```
Field widgets available: `OiAfTextInput`, `OiAfNumberInput`, `OiAfCheckbox`, `OiAfSwitch`,
`OiAfRadio`, `OiAfSelect`, `OiAfComboBox`, `OiAfDateInput/TimeInput/DateTimeInput`,
`OiAfTagInput`, `OiAfSlider`, `OiAfColorInput`, `OiAfFileInput`, `OiAfSegmentedControl`,
`OiAfArrayInput`, `OiAfRichEditor`. Aggregates: `OiAfErrorSummary`, `OiAfSubmitButton`,
`OiAfResetButton`. Beak GENERATES the enum + controller from a model's `BeakColumn` list.
(`OiForm`/`OiFormController` with `OiFieldType` also exists as the untyped fallback.)

## Optimistic updates + undo (Beak edit/delete)

`OiOptimisticAction.execute(context, apply:, rollback:, commit: () async {...},
message:, undoDuration:)` — apply locally, show undo snackbar, commit or rollback.
`OiUndoStack` gives global Ctrl+Z. Use these for Beak's mutation UX.

## Dashboard

Stats via `OiCard` + fields; charts via `obers_ui_charts`
(`package:obers_ui_charts/obers_ui_charts.dart` — line/area/bar/pie/etc.). Beak's
dashboard widgets wrap these and feed them from `BeakQuerySpec` aggregate reads.

## Theming & context

`OiThemeData.fromBrand(color:)` / `.light()` / `.dark()`. In code: `context.colors`,
`context.spacing`, `context.radius`, `context.components`, `OiTheme.of(context)`.
`OiThemeScope(data:, child:)` overrides a subtree.

## When unsure
Read the matching file under `~/Flutters/obers_ui/doc`, and check the "Decision Matrix"
and "Anti-Patterns" sections of the obers_ui reference before introducing a new pattern.
