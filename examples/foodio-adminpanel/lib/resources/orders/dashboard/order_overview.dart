import 'package:beak/panel.dart';
import 'package:beak/ui.dart' show OiIcons;
import '../../../models/models.dart';
import '../../../theme/gabel_tokens.dart';

/// Stable operating date for reproducible demo workflows.
const foodioToday = BeakDate(2026, 9, 28);

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
  final booked = BeakSummaryMeasure.sum(
    'booked',
    field: DeliverySlotModel.reservedOrders,
  );
  final capacity = BeakSummaryMeasure.sum(
    'capacity',
    field: DeliverySlotModel.capacity,
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
      BeakSummaryBlock(
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
        span: const BeakSpan(columns: 4),
        query: const DeliverySlotModel().summary(
          groupBy: DeliverySlotModel.startMinute,
          filter: BeakAndFilter([
            DeliverySlotModel.date.eq(foodioToday),
            DeliverySlotModel.method.eq('office'),
          ]),
          measures: [booked, capacity],
        ),
        values: [
          BeakSummaryValue(measure: booked, label: 'Booked'),
          BeakSummaryValue(measure: capacity, label: 'Capacity'),
        ],
        groupStyle: (row) {
          final minute = (row.group.raw as num).toInt();
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
          used: booked,
          total: capacity,
          warningColor: GabelLight.warning,
          warning: (row) =>
              '${(row.valueOf(capacity) ?? 0) - (row.valueOf(booked) ?? 0)} left · offer 12:00–12:30',
        ),
        footer: (_) => 'Same-day orders close 10:30 · 48 minutes left',
        presentation: BeakSummaryPresentation.capacity,
        scope: BeakSummaryScope.standalone,
        heightInPixels: 216,
      ),
    ],
  );
}
