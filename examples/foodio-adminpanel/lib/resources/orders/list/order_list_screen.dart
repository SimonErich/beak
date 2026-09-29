import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../../domain/order_behavior.dart';
import '../../../models/models.dart';
import '../dashboard/order_overview.dart';
import 'order_list_filters.dart';
import 'order_table_columns.dart';
import 'order_list_presets.dart';

/// Every list, filter, counter and chart shares this typed population.
BeakTableScreen orderList() {
  final filters = orderListFilters();
  final date = filters.date;
  final status = filters.status;
  final organization = filters.organization;
  final slot = filters.slot;
  final payment = filters.payment;
  final columns = orderTableColumns();
  final presets = OrderListPresets(filters: filters, columns: columns);
  return BeakTableScreen(
    query: const OrderModel()
        .query()
        .orderBy(OrderModel.number, descending: true)
        .paginate(perPage: 15),
    definition: BeakListDefinition(
      initialPreset: presets.today,
      filterSheetWidthInPixels: 480,
      recordNoun: 'orders',
      advancedFilterColumns: 2,
      advancedFilterDescription:
          'Voucher used, order value, allergy notes, created by',
      fitTableToRows: true,
      scrollMode: BeakListScrollMode.page,
      floatingBulkActions: true,
      filterDescription:
          'Combine filters, then save them as a view for your team.',
      title: 'Orders',
      searchPlaceholder: 'Search by order, customer, company or phone',
      subtitleBuilder: (counts) =>
          '${counts[presets.today] ?? '—'} orders for today · ${counts[presets.attention] ?? '—'} need attention · updated 09:42',
      createLabel: 'New order',
      export: BeakListExport(
        fileName: 'orders.csv',
        fields: [
          OrderModel.reference,
          OrderModel.customerName,
          OrderModel.organizationName,
          OrderModel.deliveryDate,
          OrderModel.itemCount,
          OrderModel.grossCents.currency(minorUnits: true),
          OrderModel.paymentStatus,
          OrderModel.status,
        ],
      ),
      quickFilters: [date, status, organization, slot, payment],
      quickFilterLabels: {slot: 'Slot', payment: 'Payment'},
      rowActions: [
        const BeakActionPresentation(
          key: 'view',
          label: 'View order',
          icon: OiIcons.eye,
          group: 'record',
        ),
        const BeakActionPresentation(
          key: 'edit',
          label: 'Edit delivery address',
          icon: OiIcons.mapPin,
          group: 'record',
        ),
        BeakActionPresentation(
          key: 'call-customer',
          icon: OiIcons.phone,
          group: 'record',
          labelValue: BeakValueBinding<String>.computed(
            dependencies: [OrderModel.customerName],
            compute: (row) =>
                'Call ${row.read(OrderModel.customerName) ?? 'customer'}',
          ),
        ),
        BeakActionPresentation.model(
          OrderActions.addNote,
          label: 'Add internal note',
          icon: OiIcons.messageSquare,
          group: 'record',
        ),
        BeakActionPresentation.model(
          OrderActions.cancel,
          label: 'Cancel order',
          icon: OiIcons.circleX,
          destructive: true,
          group: 'destructive',
        ),
      ],
      bulkActions: [
        BeakActionPresentation.model(
          OrderActions.sendPaymentLink,
          label: 'Send payment links',
          icon: OiIcons.send,
        ),
        const BeakActionPresentation(key: 'export', icon: OiIcons.download),
        BeakActionPresentation.model(
          OrderActions.cancel,
          icon: OiIcons.circleX,
          destructive: true,
          selectionLabel: (count) => 'Cancel $count orders',
        ),
      ],
      savedViews: BeakSavedViewStore.model(
        model: const SavedViewModel(),
        name: SavedViewModel.name,
        resource: SavedViewModel.resource,
        state: SavedViewModel.state,
      ),
      header: orderOverview(),
      collapsedHeader: orderCompactOverview(),
      showHeaderToggle: true,
      presets: presets.values,
      columns: columns,
      filters: [
        date,
        status,
        BeakChoiceFilter(
          field: OrderModel.profile.kind,
          label: 'Customer',
          presentation: BeakChoiceFilterPresentation.radio,
          options: [
            BeakFilterChoice(
              key: 'company',
              label: 'Company profiles',
              filter: OrderModel.profile.kind.eq('company'),
            ),
            BeakFilterChoice(
              key: 'private',
              label: 'Private profiles',
              filter: OrderModel.profile.kind.eq('private'),
            ),
          ],
        ),
        organization,
        slot,
        payment,
        BeakChoiceFilter(
          field: OrderModel.voucherCode,
          label: 'Voucher used',
          advanced: true,
          presentation: BeakChoiceFilterPresentation.select,
          allLabel: 'Any or none',
          options: [
            BeakFilterChoice(
              key: 'any',
              label: 'With a voucher',
              filter: BeakAndFilter([
                OrderModel.voucherCode.notEq(null),
                OrderModel.voucherCode.notEq(''),
              ]),
            ),
            for (final code in ['LUNCH15', 'WELCOME10'])
              BeakFilterChoice(
                key: code,
                label: code,
                filter: OrderModel.voucherCode.eq(code),
              ),
          ],
        ),
        BeakChoiceFilter(
          field: OrderModel.createdBy,
          label: 'Created by',
          advanced: true,
          presentation: BeakChoiceFilterPresentation.select,
          allLabel: 'Anyone',
          options: [
            BeakFilterChoice(
              key: 'customers',
              label: 'Customers (webshop and app)',
              filter: BeakOrFilter([
                OrderModel.source.eq('Webshop'),
                OrderModel.source.eq('App'),
              ]),
            ),
            BeakFilterChoice(
              key: 'staff',
              label: 'Staff (admin)',
              filter: OrderModel.source.eq('Admin'),
            ),
            BeakFilterChoice(
              key: 'marie',
              label: 'Marie Novak',
              filter: OrderModel.createdBy.eq('Marie Novak'),
            ),
          ],
        ),
        OrderModel.grossCents
            .currency(minorUnits: true)
            .numberRangeFilter(
              advanced: true,
              showMaximum: false,
              minimumLabel: 'Order value from (optional)',
              placeholder: 'e.g. 40.00',
            ),
        BeakChoiceFilter(
          field: OrderModel.allergenNote,
          label: 'Allergy note',
          showLabel: false,
          advanced: true,
          options: [
            BeakFilterChoice(
              key: 'with-note',
              label: 'Only orders with an allergy note',
              filter: BeakAndFilter([
                OrderModel.allergenNote.notEq(null),
                OrderModel.allergenNote.notEq(''),
              ]),
            ),
          ],
        ),
      ],
    ),
  );
}
