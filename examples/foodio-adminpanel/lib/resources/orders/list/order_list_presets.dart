import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart' show FontWeight, TextStyle;

import '../../../domain/order_behavior.dart';
import '../../../models/models.dart';
import '../dashboard/order_overview.dart';
import '../presentations/order_presentations.dart';
import 'order_list_filters.dart';
import 'order_table_columns.dart';

/// Saved views and their matching list projections for the orders resource.
///
/// Each view is declared once here; the list, its counts and any navigation
/// destination refer to the [BeakQueryPreset] objects, never to their keys.
final class OrderListPresets {
  /// Builds the views over the list's [filters] and table [columns].
  factory OrderListPresets({
    required OrderListFilters filters,
    required List<BeakTableColumn> columns,
  }) {
    final date = filters.date;
    final status = filters.status;
    final organization = filters.organization;
    final slot = filters.slot;
    final payment = filters.payment;
    final today = BeakQueryPreset(
      key: 'today',
      label: 'Today',
      defaults: {
        date: BeakAndFilter([
          OrderModel.deliveryDate.gte(foodioToday),
          OrderModel.deliveryDate.lte(foodioToday),
        ]),
      },
    );
    final attention = BeakQueryPreset(
      key: 'attention',
      label: 'Needs attention',
      rowHeight: 64,
      countColor: BeakColor.error,
      filter: OrderModel.needsAttention.eq(true),
      quickFilters: [status, date, organization, slot, payment],
      defaults: {
        status: OrderModel.needsAttention.eq(true),
        date: BeakAndFilter([
          OrderModel.deliveryDate.gte(foodioToday),
          OrderModel.deliveryDate.lte(const BeakDate(2026, 9, 29)),
        ]),
      },
      columns: [
        for (final column in columns.where(
          (column) => {'order', 'customer', 'delivery'}.contains(column.key),
        ))
          BeakTableColumn(
            key: column.key,
            label: column.label,
            template: column.key == 'customer'
                ? BeakRecordTemplate(
                    textGap: 0,
                    title: BeakValueBinding.field(
                      OrderModel.customerName,
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: [orderOrganizationSummary(attention: true)],
                  )
                : column.key == 'delivery'
                ? BeakRecordTemplate(
                    textGap: 0,
                    title: orderDeliveryTitle(),
                    subtitle: [orderDeliverySummary(attention: true)],
                  )
                : column.template!,
            sortBy: column.sortBy,
            width: switch (column.key) {
              'order' => 112,
              'customer' => 168,
              _ => 132,
            },
          ),
        BeakTableColumn(
          key: 'issue',
          label: 'Problem',
          width: 188,
          template: BeakRecordTemplate(
            title: BeakValueBinding.field(
              OrderModel.attentionReason,
              maxLines: 2,
            ),
          ),
        ),
        BeakTableColumn.action(
          key: 'next_step',
          label: 'Next step',
          width: 188,
          selector: BeakValueBinding.field(OrderModel.nextAction),
          choices: {
            OrderActions.sendPaymentLink.name: BeakActionPresentation.model(
              OrderActions.sendPaymentLink,
            ),
            OrderActions.retryPayment.name: BeakActionPresentation.model(
              OrderActions.retryPayment,
            ),
            OrderActions.requestApproval.name: BeakActionPresentation.model(
              OrderActions.requestApproval,
              label: 'Ask for approval',
            ),
            OrderActions.acknowledgeAllergy.name: BeakActionPresentation.model(
              OrderActions.acknowledgeAllergy,
              label: 'Confirm with kitchen',
            ),
            OrderActions.reschedule.name: BeakActionPresentation.model(
              OrderActions.reschedule,
              label: 'Schedule redelivery',
            ),
            'reviewChange': BeakActionPresentation.model(
              OrderActions.resolveChange,
              label: 'Review change',
            ),
            'editAddress': const BeakActionPresentation(
              key: 'edit',
              label: 'Edit address',
            ),
          },
          fallback: const BeakActionPresentation(
            key: 'view',
            label: 'Review order',
          ),
        ),
        BeakTableColumn(
          key: 'status',
          label: 'Status',
          width: 164,
          template: BeakRecordTemplate(title: orderStatus()),
        ),
      ],
    );
    final scheduled = BeakQueryPreset(
      key: 'scheduled',
      label: 'Scheduled',
      filter: OrderModel.awaitingRelease.eq(true),
    );
    final drafts = BeakQueryPreset(
      key: 'drafts',
      label: 'Drafts',
      filter: OrderModel.status.eq(OrderStatus.draft),
    );
    return OrderListPresets._(
      today: today,
      attention: attention,
      scheduled: scheduled,
      drafts: drafts,
    );
  }

  const OrderListPresets._({
    required this.today,
    required this.attention,
    required this.scheduled,
    required this.drafts,
  });

  /// Orders delivered today; the list opens on this view.
  final BeakQueryPreset today;

  /// Orders that need a person to act, with the next step per row.
  final BeakQueryPreset attention;

  /// Orders released to the kitchen at a later time.
  final BeakQueryPreset scheduled;

  /// Orders not placed yet.
  final BeakQueryPreset drafts;

  /// Every order.
  final BeakQueryPreset everything = const BeakQueryPreset(
    key: 'all',
    label: 'All orders',
  );

  /// The views in tab order.
  List<BeakQueryPreset> get values => [
    today,
    attention,
    scheduled,
    drafts,
    everything,
  ];
}
