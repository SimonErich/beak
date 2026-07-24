---
title: Actions
description: How to add typed record, bulk, and global actions to a resource, what an action receives, and how confirmation works.
---

# Actions

After this page you can add a button to a row, a selection, or a page that runs your own typed code against the data source, refreshes the surface it ran from, and optionally asks the user to confirm first.

Beak's generated pages already carry view, edit, delete, and create. When you need more (duplicate a product, archive an order, export a selection), you declare a `BeakAction` on the resource. An action is a small piece of typed Dart, not a widget: it reads from a `BeakActionContext` and returns a `Future`. Beak renders the button, routes the tap through one execution path, and hands your code everything it needs.

## Three shapes

`BeakAction` is a sealed hierarchy with exactly three targets, so every surface can switch over them exhaustively. All three share the same base fields.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
sealed class BeakAction {
  const BeakAction({
    required this.key,
    required this.label,
    this.icon,
    this.color,
    this.requiresConfirmation = false,
  });

  /// Stable identifier (test hooks, telemetry).
  final String key;

  /// The button label.
  final String label;

  /// The button icon, if any.
  final IconData? icon;

  /// Semantic color driving the button variant ([BeakColor.error] renders
  /// destructively, [BeakColor.primary] prominently).
  final BeakColor? color;

  /// Whether a confirmation dialog gates execution.
  final bool requiresConfirmation;
}
```

The three subclasses differ only in what their `onExecute` receives:

| Action | Declared on | `onExecute` receives |
| --- | --- | --- |
| `BeakRecordAction` | `recordActions` | one `BeakRecord` plus the context |
| `BeakBulkAction` | `bulkActions` | every selected `BeakRecord` at once, plus the context |
| `BeakGlobalAction` | `globalActions` | the context only |

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
final class BeakRecordAction extends BeakAction {
  const BeakRecordAction({
    required super.key,
    required super.label,
    required this.onExecute,
    super.icon,
    super.color,
    super.requiresConfirmation,
  });

  final Future<void> Function(BeakRecord record, BeakActionContext context)
  onExecute;
}
```

The built-in view, edit, delete, and create actions subclass these, so your custom actions sit alongside them on the generated pages. `BeakDeleteAction`, for instance, is a `BeakRecordAction` that renders destructively and commits through an optimistic undo window.

## What an action receives

Every action's `onExecute` is handed a `BeakActionContext`: the resource's model, the data source, the router, the build context overlays mount from, and a hook to refresh the surface the action ran from. Custom actions read from it rather than capturing widget state.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
final class BeakActionContext {
  const BeakActionContext({
    required this.buildContext,
    required this.model,
    required this.dataSource,
    required this.router,
    this.refresh,
  });

  /// The context overlays (dialogs, undo toasts) mount from.
  final BuildContext buildContext;

  /// The model of the resource the action runs on.
  final BeakModel model;

  /// The source mutations run against.
  final BeakDataSource dataSource;

  /// The panel router, for navigating actions.
  final GoRouter router;

  /// Reloads the surface the action ran from (e.g. the list), if any.
  final Future<void> Function()? refresh;

  BeakOverlays get overlays => BeakOverlays(buildContext);
}
```

Two members carry most of the weight. `dataSource` is the same source-agnostic interface the panel reads through, so an action's mutation goes through the identical path as everything else. `refresh` reloads the surface (typically the list), letting the table reflect what your action just did. The `overlays` getter is covered in [Overlays](overlays.md).

## A real custom action

The reference store adds a Duplicate action to Products. It is plain typed code over the data source: read the source record through the shared column constants (never string literals), write a `"(copy)"` clone, then refresh so the table reloads.

```dart title="apps/reference_admin/lib/main.dart"
Future<void> duplicateProduct(
  BeakRecord record,
  BeakActionContext context,
) async {
  final String? name = switch (record[ProductColumns.name.key]?.raw) {
    final String value => value,
    _ => null,
  };
  if (name == null) {
    throw const BeakConfigurationException(
      'Cannot duplicate a product that has no name.',
    );
  }
  await context.dataSource.create(
    context.model.table,
    BeakRecord(
      values: {
        ProductColumns.name.key: BeakStringValue('$name (copy)'),
        if (record[ProductColumns.price.key] case final BeakValue price)
          ProductColumns.price.key: price,
        if (record[ProductColumns.status.key] case final BeakValue status)
          ProductColumns.status.key: status,
        if (record[ProductColumns.categoryId.key] case final BeakValue category)
          ProductColumns.categoryId.key: category,
      },
    ),
  );
  await context.refresh?.call();
}
```

You wire it into the resource as the `onExecute` of a `BeakRecordAction`, on the store's panel config (port 8080):

```dart title="apps/reference_admin/lib/main.dart"
BeakResource(
  model: ProductModel(),
  icon: BeakIconToken(OiIcons.package),
  filters: [
    BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
    BeakTextFilter(column: ProductColumns.name, label: 'Name'),
  ],
  recordActions: [
    BeakRecordAction(
      key: 'duplicate',
      label: 'Duplicate',
      icon: OiIcons.copy,
      onExecute: duplicateProduct,
    ),
  ],
),
```

!!! note "What just happened"
    - `duplicateProduct` never captured widget state; it read model, data source, and refresh off the context.
    - It addressed fields through `ProductColumns` constants, so a renamed column is a compile error, not a runtime surprise.
    - `await context.refresh?.call()` reloaded the list, and the new copy appeared.

## Confirmation

Set `requiresConfirmation: true` and Beak shows a dialog before running. The single execution path both the buttons and the table rows route through checks it first, and a destructive color turns the confirm button destructive:

```dart title="packages/beak_frontend/lib/src/actions/beak_action_button.dart"
Future<void> executeBeakAction({
  required BeakAction action,
  required BeakActionContext context,
  BeakRecord? record,
  List<BeakRecord> records = const [],
}) async {
  if (action.requiresConfirmation) {
    final bool confirmed = await context.overlays.confirm(
      title: '${action.label}?',
      confirmLabel: action.label,
      destructive: action.color == BeakColor.error,
    );
    if (!confirmed) {
      return;
    }
  }
  switch (action) {
    case final BeakRecordAction recordAction:
      final BeakRecord? target = record;
      if (target != null) {
        await recordAction.onExecute(target, context);
      }
    case final BeakBulkAction bulkAction:
      await bulkAction.onExecute(records, context);
    case final BeakGlobalAction globalAction:
      await globalAction.onExecute(context);
  }
}
```

If you need finer control (a custom message, a modal instead of a yes/no), skip `requiresConfirmation` and call `context.overlays.confirm(...)` inside `onExecute` yourself, as [Overlays](overlays.md) shows.

## How the button renders

You never build the button; the generated pages do. `BeakActionButton` picks the obers_ui variant from the action's color and can render a compact icon-only version inside a table row:

```dart title="packages/beak_frontend/lib/src/actions/beak_action_button.dart"
return switch (action.color) {
  BeakColor.primary => OiButton.primary(label: action.label, onTap: run),
  BeakColor.error => OiButton.destructive(label: action.label, onTap: run),
  _ => OiButton.secondary(label: action.label, onTap: run),
};
```

So the only things you choose are the `key`, the `label`, an optional `icon`, an optional `color`, whether it confirms, and the code that runs.

!!! question "What this skipped"
    - Dialogs, sheets, and toasts an action can raise: [Overlays](overlays.md).
    - Where actions are declared alongside filters and view modes: [Resources](resources.md).
    - How a failed mutation surfaces: [Results and errors](../concepts/results-and-errors.md).

## Continue reading

- [Overlays](overlays.md) the confirm, modal, sheet, and toast an action reaches through the context.
- [Resources](resources.md) where `recordActions`, `bulkActions`, and `globalActions` live.
- [Tables and filters](tables-and-filters.md) the list surface most actions run from.
- [Results and errors](../concepts/results-and-errors.md) how a rejected mutation is reported.
