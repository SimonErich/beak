---
title: Custom blocks and widgets
description: Put your own widget in a block tree with BeakWidgetBlock or inside a form with BeakFormWidget, and keep the panel's data, formatting and draft.
type: guide
audience: [expert]
status: stable
---

# Custom blocks and widgets

After this page you can put your own widget where Beak has no block for it, on a page or inside a form, and keep the panel's data source, formatting, refresh and draft while you do.

The typed blocks cover metrics, tables, charts and forms. When a page needs a receivables card with two buttons and a retry, or a form needs a tool that stages variant rows from two text fields, you write Flutter. Beak gives you two seams for that, and they differ in what they hand your widget.

## At a glance

| Hatch | Sits in | Your builder receives | Use it for |
| --- | --- | --- | --- |
| `BeakWidgetBlock` | A block tree: a `BeakScreen` body, a column, grid, card or section | `BuildContext` | A card, chart or composition that reads its own data |
| `BeakFormWidget` | A form layout: a section, tab or wizard step | `BuildContext` and the form's `BeakDraftRecord` | A tool that reads or edits the record being edited |

`BeakWidgetBlock` is a block that holds one builder. `BeakFormWidget` is one node in a form layout, and the shop places it inside a section:

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_widget_block.dart:BeakWidgetBlock"
```

```dart title="examples/clean_beak_config/lib/resources/products/screens/product_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:variantBuilderWidget"
```

Import `package:beak/panel.dart` for Beak and `package:beak/ui.dart` for the `Oi*` widgets. The typed path stays cheaper when it exists: a metric block is a handful of lines, and `ShopReceivablesCard` is about ninety. Reach for a hatch when the typed blocks have no entry for what you want, not when they are one option short.

## A widget in a page

Your widget lives inside the panel's widget tree, so it inherits what the panel provides. Nothing has to be passed down.

| You want | Read it from | Notes |
| --- | --- | --- |
| The panel's data source | `beakDependencies(context)<BeakDataSource>()` | The panel's routing source: model-bound transports, error mapping and the change stream included. |
| Typed errors instead of exceptions | `BeakResourceRepository(source).run(...)` | Turns a `BeakException` into `BeakErr`. Anything else still propagates. `beakRun(...)` does the same without a repository. |
| A refresh after a confirmed write | `useBeakDataRevision(source, table: ...)` | Returns a counter that changes when that table (or an owner of it) is written. It owns its subscription. |
| Numbers, money and dates | `BeakFormatting.of(context)` | Falls back to a default policy outside a configured panel. |
| Localised strings | `BeakLocalizations.of(context)` | `loading`, `retry`, `errorMessage(error)` among others. |
| Navigation | `context.go(BeakRoutes.list(table))` | go_router's `context.go` (import `package:go_router/go_router.dart`) with a route Beak builds. |

The shop's receivables card sums the issued invoices. The first half wires the data: the source, the revision that re-runs the request after an invoice changes, and the typed `sum` that returns exact `BeakDecimal` money.

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:receivablesData"
```

The second half is the part a typed block does for you and a custom widget does not: loading, failure with a retry, and the result.

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:receivablesStates"
```

The full widget is `ShopReceivablesCard` in `examples/clean_beak_config/lib/widgets/receivables_card.dart`. It appears in the shop's overview and in its operations page as `BeakWidgetBlock((context) => const ShopReceivablesCard())`, so one widget serves two pages, and both stay current after an invoice changes.

!!! note "What just happened"
    - The revision counter is a `useMemoized` key. A confirmed write to `invoices` bumps it, the memo re-runs, and the card reads the new sum.
    - A failed load is a `BeakErr`, which the widget renders as a message and a retry. It never shows a zero it did not read.
    - `BeakWidgetBlock` accepts a `span`, like every block, when its parent is a grid.

## A widget in a form

`BeakFormWidget` gets the form's `BeakDraftRecord`, the same object the automatic inputs edit. Your widget does not need a second controller, a save handler or a cancel button: the form still owns validation, cancellation, persistence and receipt recovery.

| Member of `BeakDraftRecord` | Does |
| --- | --- |
| `read(Model.field)` | Returns the current typed value of a field, or null. |
| `set(Model.field, value)` | Writes a scalar field of this record's own model. |
| `rows(Model.children)` | The visible related rows of a to-many relationship. |
| `addRow(Model.children)` | Adds an unsaved related row and returns it. Read and write the row with the same `read` and `set`. |
| `removeRow(row)` | Removes a new row, or stages an existing one for removal. |
| `isDirty`, `fieldChanged(field)` | Whether the draft, or one field, differs from what was loaded. |

The shop's variant builder previews combinations from two text fields, then stages the picked ones as ordinary unsaved rows. Every change goes through those members:

```dart title="examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart:stageShopVariants"
```

Before it offers an editing action, the widget asks the enclosing scope whether editing is allowed:

```dart title="examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart:variantBuilderEnabled"
```

`BeakDraftScope.of(context).enabled` is true only when the screen is editing (not reading), the widget's own `enabledIf` and every enclosing section guard allow it, and no save is running or unresolved. Set `showOnRead: false` on a widget that is an editing tool, as the shop does, so the read view does not show a dead panel.

## Rules and limits

| Rule | Enforced where | What it means |
| --- | --- | --- |
| Beak does not look inside a hatch | Client | Loading, error, retry, responsive layout and accessibility are yours. |
| A widget block needs a panel scope | Client | Outside a panel `beakDependencies(context)` falls back to the global `beakLocator`, which throws if nothing registered it. See [Using Beak widgets standalone](using-beak-widgets-standalone.md). |
| Refresh needs a change stream | Client | `useBeakDataRevision` reacts only when the source implements `BeakMutationSource`. The panel's registered source does. A raw `HttpBeakDataSource` you construct yourself does not. |
| `set` is silent while saving | Client | While a save runs, or its outcome is unknown, `set` does nothing and `addRow` throws a `StateError`. Read `enabled` first. |
| `set` writes this record only | Client | A field of another model, or a related path such as `ProductModel.category.name`, throws `BeakConfigurationException`. Write related fields on the row `addRow` or `rows` gives you. |
| `addRow` needs the editor in the layout | Client | The layout must contain the relationship's table (`ProductModel.variants.tableForm(...)`). Without one, `addRow` throws a `BeakConfigurationException` that names the form and the relationship and tells you to place `tableForm` for it. An editor declared with `allowAdding: false` throws a `BeakConfigurationException` too. The shop puts the table right below its builder. |
| Server rules still run | Server | Model behavior and record rules re-run when the form saves, whatever your widget staged. A custom widget cannot skip them. |
| No Material | You | Use the `Oi*` controls, as Beak does. Beak's guard reads its own source, not your closure. |

## Verify it

Test a form widget's logic without pumping any UI. A `BeakFormSession` over an in-memory source gives you the same `BeakDraftRecord` the form would:

```dart title="examples/clean_beak_config/test/custom_shop_test.dart"
--8<-- "examples/clean_beak_config/test/custom_shop_test.dart:draftWithoutUi"
```

The rest of the test calls `stageShopVariants(session.root, ...)` and asserts on the staged rows and on the recording source: no `create` and no `update` was called, and `session.isDirty` is true.

For a widget block, pump a panel around it and make one operation fail. `BeakRecordingDataSource` is a `base class` so a test can override the one call:

```dart title="examples/clean_beak_config/test/custom_shop_test.dart"
--8<-- "examples/clean_beak_config/test/custom_shop_test.dart:FailingAggregate"
```

```dart title="examples/clean_beak_config/test/custom_shop_test.dart"
--8<-- "examples/clean_beak_config/test/custom_shop_test.dart:retryableBillingTest"
```

## Reference

| Symbol | Library | Role |
| --- | --- | --- |
| `BeakWidgetBlock(WidgetBuilder builder, {BeakSpan? span})` | `package:beak/panel.dart` | The block. |
| `BeakFormWidget({required builder, showOnRead = true, visibleIf, enabledIf})` | `package:beak/panel.dart` | The form node. `builder` is `Widget Function(BuildContext, BeakDraftRecord)`. |
| `BeakDraftScope` | `package:beak/panel.dart` | Inherited scope above a form widget: `draft`, `readOnly`, `enabled`. `BeakDraftScope.of(context)` throws if none is mounted. |
| `BeakDraftRecord` | `package:beak/panel.dart` | The local record: `read`, `set`, `rows`, `addRow`, `removeRow`, `session`. |
| `beakDependencies(context)` | `package:beak/panel.dart` | The nearest panel's `GetIt` container. |
| `useBeakDataRevision(source, {table})` | `package:beak/panel.dart` | Hook returning a revision counter. |
| `BeakResourceRepository`, `beakRun` | `package:beak/panel.dart` | The result boundary. |

Sources: `packages/beak_frontend/lib/src/blocks/beak_widget_block.dart`, `packages/beak_frontend/lib/src/form/beak_form_layout.dart` (`BeakFormWidget`, `BeakDraftScope`), `packages/beak_frontend/lib/src/form/beak_form_session.dart` (`BeakDraftRecord`), `packages/beak_frontend/lib/src/data/beak_data_changes.dart`.

## Continue reading

- [Custom screens](../panel/custom-screens.md) a whole page, or a replacement for one resource route.
- [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md) the model behind the variant builder.
- [Form screens](../forms/form-screens.md) the layout a `BeakFormWidget` sits in.
- [Using Beak widgets standalone](using-beak-widgets-standalone.md) the same widgets outside a panel.
