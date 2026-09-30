# An enum badge column

> Turn a Dart enum into a status column with readable labels, coloured badges, a select filter and server-side validation of the stored value.

You want a status column: a coloured badge in the table, a readable label instead of `inKitchen`, a select in the form and a filter on the list, without a string anywhere that could drift from the values the model allows.

## Recipe

Declare the enum next to the schema, then annotate the field. Foodio's order status is the full version, with a label and a colour for each of seven values:

```dart title="examples/foodio-adminpanel/lib/models/enums.dart"
/// Fulfillment is independent of payment and approval.
enum OrderStatus {
  /// Unsaved business intent; reserves no capacity or budget.
  draft,

  /// Placed and waiting for preparation.
  confirmed,

  /// Preparation started; customer and date are locked.
  inKitchen,

  /// Dispatched and no longer editable.
  outForDelivery,

  /// Fulfilled; budget reservation becomes spending.
  delivered,

  /// Closed without further preparation.
  cancelled,

  /// A failed delivery awaits an explicit redelivery slot.
  onHold,
}
```

```dart title="examples/foodio-adminpanel/lib/models/order.dart"
/// Status.
@Column(defaultValue: OrderStatus.draft, filterable: true)
@EnumLabels<OrderStatus>({
  OrderStatus.draft: 'Draft',
  OrderStatus.confirmed: 'Confirmed',
  OrderStatus.inKitchen: 'In kitchen',
  OrderStatus.outForDelivery: 'Out for delivery',
  OrderStatus.delivered: 'Delivered',
  OrderStatus.cancelled: 'Cancelled',
  OrderStatus.onHold: 'On hold',
})
@Badges<OrderStatus>({
  OrderStatus.draft: BeakColor.muted,
  OrderStatus.confirmed: BeakColor.info,
  OrderStatus.inKitchen: BeakColor.warning,
  OrderStatus.outForDelivery: BeakColor.primary,
  OrderStatus.delivered: BeakColor.success,
  OrderStatus.cancelled: BeakColor.muted,
  OrderStatus.onHold: BeakColor.error,
})
late final OrderStatus status;
```

Run `beak prepare`. The generator turns the field into a `BeakEnumColumn<OrderStatus>` in `order.beak.dart`, with the labels and colours copied in and `values: OrderStatus.values`:

```dart title="examples/foodio-adminpanel/lib/models/order.beak.dart"
static const BeakEnumColumn<OrderStatus> status = BeakEnumColumn<OrderStatus>(
    key: 'status',
    label: 'Status',
    rules: [BeakRequired()],
    defaultValue: OrderStatus.draft,
    filterable: true,
    // ...
    values: OrderStatus.values,
  );
```

From then on the field is typed. A filter on it takes the enum, not a string. The shop declares its own `OrderStatus` and uses it like this:

```dart title="examples/clean_beak_config/lib/operations.dart"
/// The same operational definition is used by the dashboard and work queue.
BeakFilter fulfillmentQueueFilter() => BeakOrFilter([
  OrderModel.status.eq(OrderStatus.confirmed),
  OrderModel.status.eq(OrderStatus.packing),
]);
```

The smallest version is an enum, `@Column(defaultValue: ...)` and `@Badges`. The Aviary's task board uses no labels because `todo`, `doing` and `done` read fine as they are:

```dart title="examples/showcase/lib/resources/tasks/models/task.dart"
@Column(defaultValue: TaskStatus.todo, filterable: true)
@Badges<TaskStatus>({
  TaskStatus.todo: BeakColor.muted,
  TaskStatus.doing: BeakColor.info,
  TaskStatus.done: BeakColor.success,
})
late final TaskStatus status;
```

## How it works

- The Dart type picks the column. An enum field becomes a `BeakEnumColumn<T>`, stored in a string column as the value's `name`. The server rejects a write whose value is not one of the enum's names, with `Must be one of: draft, confirmed, ...`.
- Tables and detail views render the column as a badge. The label is `@EnumLabels` if the value has one and the enum `name` otherwise. `@Badges` maps a value to a `BeakColor`: `primary`, `secondary`, `success`, `warning`, `error`, `info` or `muted`. An unmapped value gets the theme's default badge.
- The form input is a select of the same labels. Colours are not shown in it.
- `filterable: true` adds a select filter to the list when the resource declares no `filters:` of its own.
- `@Badges<T>` and `@EnumLabels<T>` are generic, so a map with keys from a different enum does not compile.

Stored values are the Dart names, so renaming an enum value is a data migration. A stored name the enum no longer has reads as `null` instead of crashing the table, which is kind, and also how a column full of dashes happens. Add a migration that rewrites the old name in the same commit that renames the value.

## Variations

| You want | Do this |
| --- | --- |
| The state changes only through business commands | Declare a `BeakModelAction` per transition whose `values` set the field. The server then refuses a direct edit of it with `This field is controlled by the record workflow.` See [A row action](a-row-action.md). |
| One list tab per state | Give the list a `BeakQueryPreset` per value, see [Composed lists](../panel/composed-lists.md). |
| A board with one column per state | [A kanban view](a-kanban-view.md) reads the same enum, in declaration order, with the same labels and colours. |
| A stepper of the states in the form | `BeakFormProgress` over the enum field, see [Screens and form layouts](../reference/screens-and-layouts.md). |
| A colour outside `BeakColor` | Not available on `@Badges`. Use a `BeakCustomColumn` with your own cell renderer, see [Custom columns](../extending/custom-columns.md). |

The enum has to live under `lib/` of the same package, or `beak prepare` cannot find it.

## Verify

Both halves are covered by package tests: the column (labels, colours, default, decoding by name) and the cell that renders it.

```console
$ cd packages/beak_core && dart test test/src/columns/beak_enum_column_test.dart
All tests passed!
$ cd packages/beak_frontend && flutter test test/src/table/column_cell_renderer_test.dart --plain-name 'enum badges'
All tests passed!
```

In your own project, `beak prepare` followed by a look at the generated `*.beak.dart` shows whether the labels and colours arrived. A missing one means the annotation is on the wrong field or its map keys belong to a different enum.

## Continue reading

- [A row action](a-row-action.md) moves a status field through named transitions instead of a free select.
- [A kanban view](a-kanban-view.md) turns the same enum into a board.
- [Fields](../models/fields.md) lists every Dart type and the column it becomes.
