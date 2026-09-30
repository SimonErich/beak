import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../models/models.dart';
import 'list/order_list_screen.dart';
import 'forms/order_wizard_screen.dart';
import 'details/order_detail_screen.dart';
import 'actions/order_documents.dart';

/// Orders use one shared model for searchable lists and transactional workflows.
final class OrderResource extends BeakResource {
  /// Registers the complete order workflow.
  OrderResource()
    : super(
        model: const OrderModel(),
        title: 'Orders',
        icon: const BeakIconToken(OiIcons.shoppingBag),
        navigationGroup: 'Orders',
        navigationRank: 0,
        canDelete: false,
        recordActions: [
          deliveryNoteAction(),
          BeakRecordAction.link(
            key: 'call-customer',
            roles: const {BeakScreenRole.list},
            label: 'Call customer',
            icon: OiIcons.phone,
            uri: (record) {
              final phone = OrderModel.contactPhone.readFrom(record);
              return phone == null || phone.isEmpty
                  ? null
                  : Uri(scheme: 'tel', path: phone);
            },
          ),
        ],
        globalSearchSources: [
          OrderModel.reference,
          OrderModel.customer.name,
          OrderModel.customer.email,
          OrderModel.customer.phone,
          OrderModel.organization.name,
          OrderModel.items.search(OrderItemModel.label),
        ],
        screens: [orderList(), orderWizard(), orderDetailAndEdit()],
      );
}
