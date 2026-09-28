import 'package:beak/panel.dart';
import 'package:beak/ui.dart' show OiIcons;
import '../../models/models.dart';
import '../../theme/gabel_tokens.dart';

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
        column: OrderModel.grossCents.column,
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
    query: BeakSummarySpec(
      table: const OrderModel().table,
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
        query: BeakSummarySpec(
          table: const OrderModel().table,
          groupBy: OrderModel.deliveryDate.column,
          filter: BeakAndFilter([
            OrderModel.deliveryDate.gte(const BeakDate(2026, 9, 21)),
            OrderModel.deliveryDate.lte(const BeakDate(2026, 10, 2)),
          ]),
          measures: [
            const BeakSummaryMeasure.count('orders'),
            BeakSummaryMeasure.count(
              'delivered',
              filter: OrderModel.status.eq(OrderStatus.delivered),
            ),
            BeakSummaryMeasure.count(
              'cancelled',
              filter: OrderModel.status.eq(OrderStatus.cancelled),
            ),
          ],
        ),
        values: const [
          BeakSummaryValue(
            measure: BeakSummaryMeasure.count('orders'),
            label: 'Orders',
            color: GabelLight.chart1,
          ),
        ],
        groupField: OrderModel.deliveryDate,
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
          final delivered = today?.values['delivered']?.toInt() ?? 0;
          final cancelled = today?.values['cancelled']?.toInt() ?? 0;
          final progress =
              (today?.values['orders']?.toInt() ?? 0) - delivered - cancelled;
          return '$delivered delivered today, $progress in progress, $cancelled cancelled.';
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
        query: BeakSummarySpec(
          table: const OrderModel().table,
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
        query: BeakSummarySpec(
          table: const DeliverySlotModel().table,
          groupBy: DeliverySlotModel.startMinute.column,
          filter: BeakAndFilter([
            DeliverySlotModel.date.eq(foodioToday),
            DeliverySlotModel.method.eq('office'),
          ]),
          measures: [
            BeakSummaryMeasure.sum(
              'booked',
              column: DeliverySlotModel.reservedOrders.column,
            ),
            BeakSummaryMeasure.sum(
              'capacity',
              column: DeliverySlotModel.capacity.column,
            ),
          ],
        ),
        values: [
          BeakSummaryValue(
            measure: BeakSummaryMeasure.sum(
              'booked',
              column: DeliverySlotModel.reservedOrders.column,
            ),
            label: 'Booked',
          ),
          BeakSummaryValue(
            measure: BeakSummaryMeasure.sum(
              'capacity',
              column: DeliverySlotModel.capacity.column,
            ),
            label: 'Capacity',
          ),
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
          trackHeight: 8,
          used: 'booked',
          total: 'capacity',
          warningColor: GabelLight.warning,
          warning: (row) =>
              '${row.values['capacity']! - row.values['booked']!} left · offer 12:00–12:30',
        ),
        footer: (_) => 'Same-day orders close 10:30 · 48 minutes left',
        presentation: BeakSummaryPresentation.capacity,
        scope: BeakSummaryScope.standalone,
        heightInPixels: 216,
      ),
    ],
  );
}
