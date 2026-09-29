# Population summaries

> Declare grouped, filtered totals that the server computes over the whole authorized population and show them as metrics, bars, donuts or capacity tracks.

A table shows one page of rows, so any total computed from that page is wrong the moment there is a second page. A summary asks the server instead: it groups and counts the whole population the user may see, and the block draws the answer. After this page you can declare measures, pick one of six presentations, scope a summary to a composed list, and read the request it sends.

## At a glance

A summary has four parts, and two of them are objects you declare once and reuse:

| Part | What it is | Declared with |
| --- | --- | --- |
| Measure | One named number per group: a count, or a sum of a numeric or exact-decimal field, optionally filtered. | `BeakSummaryMeasure.count`, `BeakSummaryMeasure.sum`, `BeakSummaryMeasure.sumDecimal` |
| Spec | Table, optional `groupBy`, 1 to 8 measures, filter, search, group `limit`. | `model.summary(...)` |
| Value | How one measure is labeled and formatted on screen. | `BeakSummaryValue(measure:, label:)` |
| Block | The spec, the values and a presentation. | `BeakSummaryBlock` |

Measures are matched by object, not by key. You read a number back with `row.valueOf(measure)`, and a value, a capacity pair or a footer binds to the same measure object you put in the spec. The `key` string only names the number on the wire.

| `presentation` | Draws | Needs |
| --- | --- | --- |
| `metrics` (default) | One caption and number per group and value. | nothing |
| `strip` | A row of labeled values without a card heading. | an ungrouped spec, normally |
| `bar` | Grouped bars, one series per value. | `groupBy` |
| `donut` | One measure split across groups, or one segment per measure when ungrouped. | nothing |
| `table` | One line per group with every value. | nothing |
| `capacity` | A used-against-total track per group. | `capacity:`, and normally a `groupBy` |

## Measures and one summary

```dart title="examples/showcase/lib/pages/data_blocks.dart"
const tasks = BeakSummaryMeasure.count('tasks');
final done = BeakSummaryMeasure.count(
  'done',
  filter: TaskModel.status.eq(TaskStatus.done),
);
const birds = BeakSummaryMeasure.count('birds');
final grams = BeakSummaryMeasure.sum(
  'grams',
  field: SpecimenModel.weightInGrams,
);
```

`count` is `const`. `sum` is not, because it takes a generated field and reads its key at runtime. A measure can carry a `filter:` (the `done` measure counts only finished tasks), and its population is the intersection of that filter, the summary's own filter and the row scope the user is authorized for. Here is the Aviary's donut over them:

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakSummaryBlock(
  title: 'Tasks by status',
  presentation: BeakSummaryPresentation.donut,
  scope: BeakSummaryScope.standalone,
  query: const TaskModel().summary(
    groupBy: TaskModel.status,
    measures: [tasks],
  ),
  values: [const BeakSummaryValue(measure: tasks, label: 'Tasks')],
  centerLabel: 'tasks',
),
```

`groupBy: TaskModel.status` also decides how each group is named. The block looks the field up in the model registry, so the segments carry the enum's labels and a date column would use the panel's date pattern. You declare the grouping once.

## The six presentations

### Bar, with a table toggle

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakSummaryBlock(
  title: 'Birds and weight by diet',
  presentation: BeakSummaryPresentation.bar,
  scope: BeakSummaryScope.standalone,
  showTableToggle: true,
  query: const SpecimenModel().summary(
    groupBy: SpecimenModel.diet,
    measures: [birds, grams],
  ),
  values: [
    const BeakSummaryValue(measure: birds, label: 'Birds'),
    BeakSummaryValue(measure: grams, label: 'Grams'),
  ],
),
```

Two values make two series. `showTableToggle: true` adds a small switch to the card header that shows the same loaded result as text rows, so no second request is made. `showValues` prints the numbers above the bars, `maximum` and `divisions` fix the value axis, and `heightInPixels` (240) sets the chart height.

### Capacity

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakSummaryBlock(
  title: 'Chores done',
  presentation: BeakSummaryPresentation.capacity,
  scope: BeakSummaryScope.standalone,
  query: const TaskModel().summary(
    groupBy: TaskModel.category,
    measures: [done, tasks],
  ),
  values: [
    BeakSummaryValue(measure: done, label: 'Done'),
    const BeakSummaryValue(measure: tasks, label: 'All'),
  ],
  capacity: BeakSummaryCapacity(used: done, total: tasks),
),
```

A capacity summary compares two measures per group, `used` against `total`, on a track. The pair is objects from the spec, never key strings. The track turns to a warning at `warningThreshold` (default `.95`), and `warning` can turn the row into a sentence. Foodio does that for its delivery slots:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
final _booked = BeakSummaryMeasure.sum(
  'booked',
  field: DeliverySlotModel.reservedOrders,
);

/// Orders the kitchen can take in each slot.
final _capacity = BeakSummaryMeasure.sum(
  'capacity',
  field: DeliverySlotModel.capacity,
);
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
BeakSummaryBlock _deliverySlotCapacity({required bool compact}) {
  return BeakSummaryBlock(
    title: 'Delivery slots today',
    legend: const [
      BeakSummaryLegend(label: 'Booked', color: GabelLight.chart1),
      BeakSummaryLegend(
        label: 'Free capacity',
        color: GabelLight.lineStrong,
        hatched: true,
      ),
      BeakSummaryLegend(label: 'Almost full', color: GabelLight.warning),
    ],
    subtitle: 'Booked against kitchen capacity',
    showTableToggle: true,
    query: const DeliverySlotModel().summary(
      groupBy: DeliverySlotModel.startMinute,
      filter: BeakAndFilter([
        DeliverySlotModel.date.eq(foodioToday),
        DeliverySlotModel.method.eq('office'),
      ]),
      measures: [_booked, _capacity],
    ),
    values: [
      BeakSummaryValue(measure: _booked, label: 'Booked'),
      BeakSummaryValue(measure: _capacity, label: 'Capacity'),
    ],
    groupStyle: (row) {
      final minute = switch (row.group.raw) {
        final num value => value.toInt(),
        _ => 0,
      };
      String clock(int value) =>
          '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
      return BeakSummaryGroupStyle(
        label: '${clock(minute)}–${clock(minute + 30)}',
        color: GabelLight.chart1,
        section: minute == 480 ? 'Breakfast' : null,
      );
    },
    capacity: BeakSummaryCapacity(
      trackHeightInPixels: 8,
      used: _booked,
      total: _capacity,
      warningColor: GabelLight.warning,
      warning: (row) =>
          '${(row.valueOf(_capacity) ?? 0) - (row.valueOf(_booked) ?? 0)} left · offer 12:00–12:30',
    ),
    footer: (_) => 'Same-day orders close 10:30 · 48 minutes left',
    presentation: BeakSummaryPresentation.capacity,
    scope: BeakSummaryScope.standalone,
    heightInPixels: compact
        ? _compactSlotRowsHeightInPixels
        : _slotRowsHeightInPixels,
  );
}
```

The displayed quantities stay authoritative when a slot is overbooked: the track clamps at full, the numbers do not.

### Strip, table and metrics

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakSummaryBlock(
  title: 'The collection at a glance',
  presentation: BeakSummaryPresentation.strip,
  scope: BeakSummaryScope.standalone,
  query: const SpecimenModel().summary(measures: [birds, grams]),
  values: [
    const BeakSummaryValue(
      measure: birds,
      label: 'birds',
      icon: OiIcons.bird,
      iconColor: BeakColor.primary,
    ),
    BeakSummaryValue(
      measure: grams,
      label: 'grams in all',
      icon: OiIcons.feather,
    ),
  ],
),
```

The strip is the compact one. It draws no card heading (the title stays as its accessible label), wraps into fewer columns as space narrows, and ignores `subtitle`, `legend`, `footer` and the table toggle. `BeakSummaryValue` gives each entry an `icon` and an `iconColor`, a `BeakColor` that the theme resolves. It is what Foodio uses as the `collapsedHeader` of its order list, shown when the charts are hidden.

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakSummaryBlock(
  title: 'Tasks by category',
  presentation: BeakSummaryPresentation.table,
  scope: BeakSummaryScope.standalone,
  query: const TaskModel().summary(
    groupBy: TaskModel.category,
    measures: [tasks, done],
  ),
  values: [
    const BeakSummaryValue(measure: tasks, label: 'Tasks'),
    BeakSummaryValue(measure: done, label: 'Done'),
  ],
),
```

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakSummaryBlock(
  title: 'Tasks in total',
  scope: BeakSummaryScope.standalone,
  query: const TaskModel().summary(measures: [tasks, done]),
  values: [
    const BeakSummaryValue(measure: tasks, label: 'Tasks'),
    BeakSummaryValue(measure: done, label: 'Done'),
  ],
),
```

`table` is text, not a table widget: one line per group, the group's name followed by `Tasks: 3` and `Done: 1`. `metrics` is what you get without a `presentation`: a caption and a number per value, and for a grouped summary one per group and value.

## Conditional measures

A measure with a `filter` lets one query count populations that overlap or that no status column expresses. Foodio splits today's orders into mutually exclusive operational states without adding a column:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
final statusValues = [
  for (final entry in [
    (OrderStatus.confirmed, 'Confirmed', GabelLight.chart1),
    (OrderStatus.inKitchen, 'In kitchen', GabelLight.chart2),
    (OrderStatus.outForDelivery, 'Out for delivery', GabelLight.chart3),
    (OrderStatus.delivered, 'Delivered', GabelLight.chart4),
  ])
    BeakSummaryValue(
      measure: BeakSummaryMeasure.count(
        entry.$1.name,
        filter: BeakAndFilter([
          OrderModel.status.eq(entry.$1),
          OrderModel.needsAttention.eq(false),
        ]),
      ),
      label: entry.$2,
      color: entry.$3,
    ),
  BeakSummaryValue(
    measure: BeakSummaryMeasure.count(
      'attention',
      filter: OrderModel.needsAttention.eq(true),
    ),
    label: 'Needs attention',
    color: GabelLight.danger,
  ),
];
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
BeakSummaryBlock(
  title: 'Status right now',
  subtitle: 'Active orders today',
  showTableToggle: true,
  span: const BeakSpan(columns: 3),
  query: const OrderModel().summary(
    filter: OrderModel.deliveryDate.eq(foodioToday),
    measures: [for (final value in statusValues) value.measure],
  ),
  values: statusValues,
  centerLabel: 'orders',
  presentation: BeakSummaryPresentation.donut,
  scope: BeakSummaryScope.standalone,
  heightInPixels: 264,
),
```

An ungrouped donut draws one segment per value, in the value's own `color`, and `centerLabel` puts their total in the middle. Overlapping populations therefore add up to more than the number of distinct records, so do not caption the total "orders" when a record can fall in two segments. Foodio's measures are exclusive on purpose (a status, and `needsAttention` false), plus one segment for the attention cases.

## Groups: order, style, legend, footer

Foodio's daily bar chart uses everything at once:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
const orders = BeakSummaryMeasure.count('orders');
final delivered = BeakSummaryMeasure.count(
  'delivered',
  filter: OrderModel.status.eq(OrderStatus.delivered),
);
final cancelled = BeakSummaryMeasure.count(
  'cancelled',
  filter: OrderModel.status.eq(OrderStatus.cancelled),
);
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
BeakSummaryBlock(
  title: 'Orders by delivery day',
  legend: const [
    BeakSummaryLegend(label: 'Orders', color: GabelLight.chart1),
    BeakSummaryLegend(
      label: 'Scheduled',
      color: GabelLight.chart1,
      hatched: true,
    ),
  ],
  subtitle: 'KW 39 and KW 40, scheduled orders hatched',
  showTableToggle: true,
  span: const BeakSpan(columns: 5),
  query: const OrderModel().summary(
    groupBy: OrderModel.deliveryDate,
    filter: BeakAndFilter([
      OrderModel.deliveryDate.gte(const BeakDate(2026, 9, 21)),
      OrderModel.deliveryDate.lte(const BeakDate(2026, 10, 2)),
    ]),
    measures: [orders, delivered, cancelled],
  ),
  values: const [
    BeakSummaryValue(
      measure: orders,
      label: 'Orders',
      color: GabelLight.chart1,
    ),
  ],
  groupStyle: (row) {
    final date = row.group.raw.toString().substring(0, 10);
    return BeakSummaryGroupStyle(
      label: int.parse(date.substring(8)).toString(),
      section: date.compareTo('2026-09-28') < 0
          ? 'KW 39 · 21–25 Sep'
          : 'KW 40 · 28 Sep–2 Oct',
      color: GabelLight.chart1,
      hatched: date.compareTo('2026-09-28') > 0,
      emphasized: date == '2026-09-28',
    );
  },
  maximum: 500,
  divisions: 5,
  footer: (result) {
    final today = result.rows
        .where(
          (row) =>
              row.group.raw.toString().startsWith(foodioToday.toString()),
        )
        .firstOrNull;
    final deliveredToday = today?.valueOf(delivered)?.toInt() ?? 0;
    final cancelledToday = today?.valueOf(cancelled)?.toInt() ?? 0;
    final progress =
        (today?.valueOf(orders)?.toInt() ?? 0) -
        deliveredToday -
        cancelledToday;
    return '$deliveredToday delivered today, $progress in progress, $cancelledToday cancelled.';
  },
  presentation: BeakSummaryPresentation.bar,
  scope: BeakSummaryScope.standalone,
  heightInPixels: 216,
),
```

- `groupStyle` maps each `BeakSummaryRow` to a `BeakSummaryGroupStyle`: a short `label` (the day number), a second-level `section` (the calendar week), a `color`, `hatched` for planned quantities and `emphasized` for the current group. It changes the picture and never a number.
- `legend` takes `BeakSummaryLegend` entries, so a hatched bar has a key that says "Scheduled".
- `footer` receives the whole `BeakSummaryResult` and returns a sentence, computed from the full population and not the visible page.
- `groupOrder` lists raw group values in display order (for an enum, the stored names such as `TaskStatus.todo.name`). Groups it does not name come after. Without it, groups come back sorted by stored value: a `null` group first, numbers ascending, everything else alphabetically. That means `doing`, `done`, `todo` for the task statuses, not their declaration order.

## Inside a composed list

A summary in a composed list's `header` or `collapsedHeader` shares the list's query. The `scope` says how much of it:

| `scope` | Inherits from the list | Use it for |
| --- | --- | --- |
| `active` (default) | permanent scope, selected preset, filters and search; never sorting or paging | totals that follow what the reader filters |
| `base` | the permanent query only | totals that stay put while the reader filters |
| `standalone` | nothing, the block's own query | a different model, or a fixed cohort |

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
header: orderOverview(),
collapsedHeader: orderCompactOverview(),
showHeaderToggle: true,
```

Foodio's compact overview uses `base`, so "orders today" does not change when a filter chip does:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
BeakBlock orderCompactOverview() {
  final today = OrderModel.deliveryDate.eq(foodioToday);
  final values = [
    BeakSummaryValue(
      measure: BeakSummaryMeasure.count('today', filter: today),
      label: 'orders today',
    ),
    BeakSummaryValue(
      measure: BeakSummaryMeasure.sum(
        'revenue',
        field: OrderModel.grossCents,
        filter: BeakAndFilter([
          today,
          OrderModel.status.notEq(OrderStatus.cancelled),
        ]),
      ),
      label: 'revenue',
      format: BeakValueFormat.currency,
      minorUnits: true,
    ),
    BeakSummaryValue(
      measure: BeakSummaryMeasure.count(
        'attention',
        filter: OrderModel.needsAttention.eq(true),
      ),
      label: 'need attention',
      icon: OiIcons.circleAlert,
      iconColor: BeakColor.error,
    ),
    BeakSummaryValue(
      measure: BeakSummaryMeasure.count(
        'busy_slot',
        filter: BeakAndFilter([
          today,
          OrderModel.slot.startMinute.eq(690),
          OrderModel.status.notEq(OrderStatus.cancelled),
        ]),
      ),
      label: 'orders in 11:30–12:00',
      icon: OiIcons.triangleAlert,
      iconColor: BeakColor.warning,
    ),
  ];
  return BeakSummaryBlock(
    title: 'Today at a glance',
    query: const OrderModel().summary(
      measures: [for (final value in values) value.measure],
    ),
    values: values,
    scope: BeakSummaryScope.base,
    presentation: BeakSummaryPresentation.strip,
  );
}
```

Under `active` and `base` the list's filter, search and trashed flag replace the summary's own. A `filter:` you put on the spec is dropped, and only the measure filters survive. Put your own scoping in measure filters, or use `standalone`. A summary over a different table than the list must be `standalone`, because the block refuses to merge two tables and throws a `BeakConfigurationException` when it builds. Outside a list there is nothing to inherit and the scope does not matter. Paging the list's table never changes a summary. Refreshing after a write does: the block fetches again whenever its table changes.

## The request behind it

`BeakClient.summary(spec)` posts the spec to `POST /api/{table}/summary`. The Aviary API answers the "Tasks by status" donut like this:

```console
$ curl -s -X POST localhost:8082/api/tasks/summary -H 'content-type: application/json' \
    -d '{"table":"tasks","groupBy":"status","measures":[{"key":"tasks","column":null}],"limit":100}'
{"rows":[{"group":"doing","values":{"tasks":2}},{"group":"done","values":{"tasks":4}},{"group":"todo","values":{"tasks":6}}],"truncated":false}
```

An ungrouped spec with a filtered measure answers with one row whose `group` is `null`:

```console
$ curl -s -X POST localhost:8082/api/tasks/summary -H 'content-type: application/json' \
    -d '{"table":"tasks","groupBy":null,"measures":[{"key":"tasks","column":null},{"key":"done","column":null,"filter":{"type":"field","column":"status","operator":"eq","value":"done"}}],"limit":100}'
{"rows":[{"group":null,"values":{"tasks":12,"done":4}}],"truncated":false}
```

When there are more groups than `limit`, the response keeps the first ones and says so:

```console
$ curl -s -X POST localhost:8082/api/tasks/summary -H 'content-type: application/json' \
    -d '{"table":"tasks","groupBy":"status","measures":[{"key":"tasks","column":null}],"limit":2}'
{"rows":[{"group":"doing","values":{"tasks":2}},{"group":"done","values":{"tasks":4}}],"truncated":true}
```

The block turns `truncated` into a line above the chart: "Only the first groups are shown. Narrow the filters to see every group."

## Rules and limits

- **Authorization is the server's.** Before it computes anything, the server checks view permission on the table, read access to the grouping field and to every summed field, and every field named in the spec's filter or a measure's filter, relationship paths included. Row policy and soft-delete scope are added to the shared population, so they apply to every measure. A summary can never count a row a list would not show.
- **Which sources can answer.** `WormDataSource` computes summaries, and the panel's HTTP source forwards to it. The in-memory source in `beak_test` and the Serverpod bridge do not implement `BeakSummaryDataSource`, so a summary over them shows the error card "This source does not support grouped summaries." with a retry button. In tests, give your fake source the interface, as the package tests do.
- **Bounds.** 1 to 8 measures with unique keys of at most 80 characters, and a `limit` from 1 to 500 (default 100). Outside those, the spec constructor throws a `BeakConfigurationException` and a hand-written request gets a 422.
- **Summed fields are numeric root fields.** `BeakSummaryMeasure.sum` takes an `int` or `double` field of the summarized model. `BeakSummaryMeasure.sumDecimal` takes a `BeakDecimal` (money or exact-decimal) field and adds its stored integer units on the server, which is exact. A field reached through a relationship is rejected when the measure is built, and a text field does not type-check. In code, `row.decimalOf(measure)` reads a decimal sum back as a `BeakDecimal`. A summary block shows the number `valueOf` returns, which for a decimal sum is a count of minor units, so give its value `minorUnits: true` and the field's `scale`.
- **Group by scalars and dates, not instants.** A date column groups by calendar date. A timestamp column groups by exact instant, which gives one group per distinct timestamp, and the API never buckets instants in a guessed timezone. Group by the date column, or by an enum. JSON and custom columns cannot be grouped, and neither can a related field.
- **`groupBy` and filters differ on relationships.** The grouping field must belong to the model. A filter may reach across relationships: Foodio's kitchen list filters order items by their order's delivery date.
- **`capacity` needs its parameter.** `presentation: BeakSummaryPresentation.capacity` without a `capacity:` throws a null-check error when the block renders. Nothing asserts it earlier.
- **English UI text.** The truncation line, the "Chart view" and "Table view" toggle labels are English whatever the panel locale.
- **The palette.** Without a color, series and segments cycle through the theme's primary, warning, info, success and error colors. Charts built by `BeakChartBlock` use the theme's chart palette instead, so a summary and a chart on one page can disagree. Set `color` on the values, or in `groupStyle`, when they must match ([Colors and tokens](../theming/colors-and-tokens.md)).

## Verify it

The presentation tests build every kind of summary against a source that answers `summary`:

```console
$ cd packages/beak_frontend
$ flutter test --no-pub test/src/panel/beak_summary_presentation_test.dart
00:00 +0: conditional donut and accessible table share one authoritative result
00:01 +1: group labels come from the summarised field, declared once
00:01 +2: capacity compares the used and total measures by object
00:01 +3: All tests passed!
```

The server side is covered by `packages/beak_backend/test/src/data/worm/summary_test.dart` and `summary_sqlite_test.dart`. To see the real numbers, run the Aviary API and use the `curl` requests above.

## Reference

The first three constructors are the measures. A measure is created once and passed by object:

```dart title="packages/beak_core/lib/src/query/beak_summary_spec.dart"
const BeakSummaryMeasure.count(this.key, {this.filter})
  : columnKey = null,
    scale = null;

/// Sums a numeric field of the summarized model, with zero for an empty
/// population.
///
/// Throws a [BeakConfigurationException] for a field reached through a
/// relationship.
BeakSummaryMeasure.sum(
  this.key, {
  required BeakScalarField<num> field,
  this.filter,
}) : columnKey = field.rootKey,
     scale = null;

/// Sums an exact-decimal or money field of the summarized model, with zero
/// for an empty population.
///
/// The wire form is the same as [BeakSummaryMeasure.sum]'s (stored integer
/// units are added, which is exact); the difference is on this side of the
/// wire, where the row reads the total back as an amount with
/// [BeakSummaryRow.decimalOf].
///
/// Throws a [BeakConfigurationException] for a field reached through a
/// relationship or one without exact-decimal or money semantics.
BeakSummaryMeasure.sumDecimal(
  this.key, {
  required BeakScalarField<BeakDecimal> field,
  this.filter,
}) : columnKey = field.exactColumn.key,
     scale = field.scale;

/// Wire constructor. A null column denotes a count.
const BeakSummaryMeasure.forKey(this.key, {this.columnKey, this.filter})
  : scale = null;
```

The spec comes from the model, never from a table string:

```dart title="packages/beak_core/lib/src/model/beak_model.dart"
BeakSummarySpec summary({
  BeakScalarField<Object>? groupBy,
  required List<BeakSummaryMeasure> measures,
  BeakFilter? filter,
  BeakSearch? search,
  int limit = 100,
  bool withTrashed = false,
}) => BeakSummarySpec.forKeys(
  table: table,
  groupByKey: groupBy == null ? null : _ownColumn(groupBy).key,
  measures: measures,
  filter: filter,
  search: search,
  limit: limit,
  withTrashed: withTrashed,
);
```

The block and its parts:

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryBlock({
  required this.title,
  required this.query,
  required this.values,
  this.presentation = BeakSummaryPresentation.metrics,
  this.scope = BeakSummaryScope.active,
  this.heightInPixels = 240,
  this.subtitle,
  this.footer,
  this.groupStyle,
  this.groupOrder = const [],
  this.showTableToggle = false,
  this.showValues = false,
  this.centerLabel,
  this.maximum,
  this.divisions,
  this.capacity,
  this.legend = const [],
  super.span,
});
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryValue({
  required this.measure,
  required this.label,
  this.format = BeakValueFormat.number,
  this.minorUnits = false,
  this.scale = 2,
  this.color,
  this.icon,
  this.iconColor,
});
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryCapacity({
  required this.used,
  required this.total,
  this.warningThreshold = .95,
  this.warning,
  this.warningColor,
  this.trackHeightInPixels = 6,
});
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryGroupStyle({
  this.label,
  this.section,
  this.color,
  this.hatched = false,
  this.emphasized = false,
});
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryLegend({
  required this.label,
  required this.color,
  this.hatched = false,
});
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
/// Population inherited by a summary inside a composed resource list.
enum BeakSummaryScope {
  /// Permanent, preset, user filters and search; never table pagination.
  active,

  /// Permanent application scope, independent of the selected preset.
  base,

  /// The summary's own explicit query, useful for a different model.
  standalone,
}
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
/// Rendering of authoritative summary rows.
enum BeakSummaryPresentation {
  /// One formatted card value per measure.
  metrics,

  /// Joined inline values for a compact operational overview.
  strip,

  /// Grouped multi-series bars.
  bar,

  /// One measure split across groups.
  donut,

  /// Compact grouped rows with all configured measures.
  table,

  /// Booked quantities against the configured capacity measure.
  capacity,
}
```

The wire types are `BeakSummarySpec`, `BeakSummaryRow` (`group`, `values`, `valueOf(measure)`, `decimalOf(measure)`), `BeakSummaryResult` (`rows`, `truncated`) and the capability interface `BeakSummaryDataSource`, all in `beak_core`. The endpoint is listed on [REST API](../reference/rest-api.md).

## Continue reading

- [Composed lists and query state](../panel/composed-lists.md) where `header` and `collapsedHeader` live.
- [Dashboards](../panel/dashboards.md) summaries next to metrics and tables on an overview page.
- [Charts](charts.md) the block for data that does not fit the summary contract.
- [Formatting and localization](../theming/formatting-and-localization.md) how the numbers and dates in a summary are formatted.
