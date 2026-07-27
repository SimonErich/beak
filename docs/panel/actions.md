---
title: Actions
description: How to add typed record, bulk, and global actions to a resource from lib/resources/<table>.dart, what an action receives, and how confirmation works.
---

# Actions

After this page you can add a button to a row, a selection, or a page that runs your own typed code against the data source, refreshes the surface it ran from, and optionally asks the user to confirm first.

Beak's generated pages already carry view, edit, delete, and create. When you need more (publish a product, archive a selection, export a page), you declare a `BeakAction` in that resource's file under `lib/resources/`. An action is a small piece of typed Dart, not a widget: it reads from a `BeakActionContext` and returns a `Future`. Beak renders the button, routes the tap through one execution path, and hands your code everything it needs.

## Where actions are declared

A generated `BeakResource` has no custom actions on it. To add some, create `lib/resources/<table>.dart` with one function that receives the generated resource and returns a copy carrying yours:

```dart title="examples/store/lib/resources/products.dart"
/// The products resource, with the parts Beak cannot derive.
///
/// Everything else — the model, the label, the icon, the section — still comes
/// from the schema class and `beak.yaml`; this file only adds what a person
/// decides. The filters are not listed: every `filterable: true` column
/// already contributes its control.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  recordActions: [
    BeakRecordAction(
      key: 'publish',
      label: 'Publish',
      icon: OiIcons.rocket,
      onExecute: (record, context) async {
        final Object? id = context.model.primaryKeyOf(record);
        if (id == null) {
          return;
        }
        await context.dataSource.update(
          context.model.table,
          id,
          BeakRecord(
            values: {
              ProductColumns.status.key: BeakValue.of(
                ProductStatus.published.name,
              ),
              ProductColumns.publishedAt.key: BeakValue.of(DateTime.now()),
            },
          ),
        );
      },
    ),
  ],
  // ... bulk actions and view modes ...
);
```

The file is named after the table, the function is named `beakResource`, and `beak prepare` wires it in. Nothing else registers it.

!!! note "What just happened"
    - The action never captured widget state. It read the model, the data source and the record id off the context it was handed.
    - It addressed fields through `ProductColumns` constants, generated from the `status` and `publishedAt` fields of the `Product` schema class. Rename a field and this is a compile error, not a runtime surprise.
    - `context.model.primaryKeyOf(record)` is the typed way to get a record's id. There is no `record['id']` anywhere.

## Three shapes

`BeakAction` is a sealed hierarchy with exactly three targets, so every surface can switch over them exhaustively. All three share the same base fields.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
sealed class BeakAction {
  /// Creates an action identified by [key] and labelled [label].
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
  /// Creates a record action running [onExecute].
  const BeakRecordAction({
    required super.key,
    required super.label,
    required this.onExecute,
    super.icon,
    super.color,
    super.requiresConfirmation,
  });

  /// Runs the action on [BeakRecord].
  final Future<void> Function(BeakRecord record, BeakActionContext context)
  onExecute;
}
```

The built-in view, edit, delete, and create actions subclass these, so your custom actions sit alongside them on the generated pages. `BeakDeleteAction`, for instance, is a `BeakRecordAction` that renders destructively and commits through an optimistic undo window.

### A bulk action over the selection

A bulk action gets the whole selection in one call, so mass work runs in a single pass rather than one round trip per checkbox. The store archives products this way:

```dart title="examples/store/lib/resources/products.dart"
  bulkActions: [
    BeakBulkAction(
      key: 'archive',
      label: 'Archive',
      icon: OiIcons.archive,
      color: BeakColor.warning,
      onExecute: (records, context) async {
        for (final record in records) {
          final Object? id = context.model.primaryKeyOf(record);
          if (id == null) {
            continue;
          }
          await context.dataSource.update(
            context.model.table,
            id,
            BeakRecord(
              values: {
                ProductColumns.status.key: BeakValue.of(
                  ProductStatus.archived.name,
                ),
              },
            ),
          );
        }
      },
    ),
  ],
```

## What an action receives

Every action's `onExecute` is handed a `BeakActionContext`: the resource's model, the data source, the router, the build context overlays mount from, and a hook to refresh the surface the action ran from. Custom actions read from it rather than capturing widget state.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
final class BeakActionContext {
  /// Creates the execution context handed to every action.
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

  /// The declarative overlay handle — confirmations, modals, sheets, and
  /// toasts — bound to this action's [buildContext].
  BeakOverlays get overlays => BeakOverlays(buildContext);
}
```

Two members carry most of the weight. `dataSource` is the same source-agnostic interface the panel reads through, so an action's mutation goes through the identical path as everything else. `refresh` reloads the surface the action ran from.

`refresh` is nullable on purpose: the list page supplies one, and the show page does not (it has a single record and its own load). Call it as `await context.refresh?.call()` and the same action works on both. The `overlays` getter is covered in [Overlays](overlays.md).

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
    - Where actions sit alongside filters, view modes and layouts: [Resources](resources.md).
    - How a failed mutation surfaces: [Results and errors](../concepts/results-and-errors.md).

## Continue reading

- [Overlays](overlays.md) the confirm, modal, sheet, and toast an action reaches through the context.
- [Resources](resources.md) the rest of what a `lib/resources/<table>.dart` can change.
- [Tables and filters](tables-and-filters.md) the list surface most actions run from.
- [Results and errors](../concepts/results-and-errors.md) how a rejected mutation is reported.
