import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/order.dart';
import 'models/order_item.dart';
import 'screens/order_form_wizard_screen.dart';

/// Sales and fulfillment configured over a reusable staged order workflow.
final class OrderResource extends BeakResource {
  /// Creates the orders section.
  OrderResource()
    : super(
        model: const OrderModel(),
        title: 'Orders',
        icon: const BeakIconToken(OiIcons.shoppingCart),
        navigationGroup: 'Sales',
        navigationRank: 0,
        canDelete: false,
        globalSearchSources: [
          OrderModel.reference,
          OrderModel.customer.email,
          OrderModel.items.search(OrderItemModel.label),
        ],
        filters: [
          OrderModel.status.selectFilter(),
          OrderModel.customer.relationFilter(),
          OrderModel.deliveryDate.dateRangeFilter(label: 'Delivery'),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              OrderModel.reference,
              OrderModel.status,
              OrderModel.customer.email,
              OrderModel.deliveryDate,
            ],
          ),
          OrderFormWizardScreen(),
          BeakFormScreen(
            roles: const {BeakScreenRole.read},
            layout: BeakFormLayout(children: [orderSections().tabs]),
          ),
        ],
      );
}
