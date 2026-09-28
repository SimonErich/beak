import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart' show FontWeight, TextStyle;

import '../../../models/models.dart';
import '../dashboard/order_overview.dart';
import '../presentations/order_presentations.dart';
import 'order_list_filters.dart';
import 'order_table_columns.dart';

/// Saved views and their matching list projections for the orders resource.
List<BeakQueryPreset> orderListPresets({
  required OrderListFilters filters,
  required List<BeakTableColumn> columns,
}) {
  final date = filters.date;
  final status = filters.status;
  final organization = filters.organization;
  final slot = filters.slot;
  final payment = filters.payment;
  return [
    BeakQueryPreset(
      key: 'today',
      label: 'Today',
      defaults: {
        date: BeakAndFilter([
          OrderModel.deliveryDate.gte(foodioToday),
          OrderModel.deliveryDate.lte(foodioToday),
        ]),
      },
    ),
    BeakQueryPreset(
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
          choices: const {
            'sendPaymentLink': BeakActionPresentation.model('sendPaymentLink'),
            'retryPayment': BeakActionPresentation.model('retryPayment'),
            'requestApproval': BeakActionPresentation.model(
              'requestApproval',
              label: 'Ask for approval',
            ),
            'acknowledgeAllergy': BeakActionPresentation.model(
              'acknowledgeAllergy',
              label: 'Confirm with kitchen',
            ),
            'reschedule': BeakActionPresentation.model(
              'reschedule',
              label: 'Schedule redelivery',
            ),
            'reviewChange': BeakActionPresentation.model(
              'resolveChange',
              label: 'Review change',
            ),
            'editAddress': BeakActionPresentation(
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
    ),
    BeakQueryPreset(
      key: 'scheduled',
      label: 'Scheduled',
      filter: OrderModel.awaitingRelease.eq(true),
    ),
    BeakQueryPreset(
      key: 'drafts',
      label: 'Drafts',
      filter: OrderModel.status.eq(OrderStatus.draft),
    ),
    const BeakQueryPreset(key: 'all', label: 'All orders'),
  ];
}
