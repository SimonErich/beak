import 'package:beak/panel.dart';
import 'package:beak/ui.dart' show OiIcons;
import 'package:flutter/widgets.dart' show LayoutBuilder;
import '../../../models/models.dart';
import '../../../theme/gabel_tokens.dart';

/// Stable operating date for reproducible demo workflows.
const foodioToday = BeakDate(2026, 9, 28);

/// Orders booked into each delivery slot.
final _booked = BeakSummaryMeasure.sum(
  'booked',
  field: DeliverySlotModel.reservedOrders,
);

/// Orders the kitchen can take in each slot.
final _capacity = BeakSummaryMeasure.sum(
  'capacity',
  field: DeliverySlotModel.capacity,
);

/// Height of the five single-line slot rows and their warning line.
const _slotRowsHeightInPixels = 216.0;

/// Height when every row wraps its time range, as on a phone.
///
/// Two-line rows of 56, 40, 58, 40 and 40 px, four 16 px gaps and the 8 px
/// the capacity view keeps above its first row.
const _compactSlotRowsHeightInPixels = 306.0;

/// Card width below which a time range no longer fits beside the ratio.
///
/// A range such as 08:00–08:30 needs about 80 px next to the 110 px track and
/// the 68 px ratio column, which takes a card of roughly 330 px.
const _compactSlotCardWidthInPixels = 330.0;

/// A compact live overview remains useful when operational charts are hidden.
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

/// Full-population summaries stay independent of table pagination and tab state.
BeakBlock orderOverview() {
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
  const orders = BeakSummaryMeasure.count('orders');
  final delivered = BeakSummaryMeasure.count(
    'delivered',
    filter: OrderModel.status.eq(OrderStatus.delivered),
  );
  final cancelled = BeakSummaryMeasure.count(
    'cancelled',
    filter: OrderModel.status.eq(OrderStatus.cancelled),
  );
  return BeakRowBlock(
    expand: true,
    gapInPixels: 24,
    children: [
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
      BeakWidgetBlock(
        (context) => LayoutBuilder(
          builder: (context, constraints) => BeakBlockHost(
            block: _deliverySlotCapacity(
              compact: constraints.maxWidth < _compactSlotCardWidthInPixels,
            ),
          ),
        ),
        span: const BeakSpan(columns: 4),
      ),
    ],
  );
}

/// Booked delivery capacity, one row per half-hour office slot.
///
/// The capacity rows are a fixed-height stack, so [compact] gives them the
/// extra height they need once each time range wraps onto two lines.
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
