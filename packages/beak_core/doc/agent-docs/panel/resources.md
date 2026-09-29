# Resources

> Configure navigation, search and conventional screens around a shared model.

A `BeakResource` connects one model to navigation and screens. Register resource instances in `BeakPanel.resources`; omitted screens use model-derived defaults.

```dart title="examples/clean_beak_config/lib/resources/orders/order_resource.dart"
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
```

Titles, navigation grouping and rank belong here. `globalSearchSources` describes searchable fields, including typed related paths. Filters and table fields control presentation without changing the model's storage contract.

Each screen declares the route roles it serves. A form can handle create, edit and read with the same structure. Duplicate role declarations are configuration errors. Custom resource screens can replace a selected route while retaining the resource's surrounding navigation.

Model-owned transports and an injected panel source use the same resource definitions. Related models are registered recursively; a child model does not need a sidebar resource merely to participate in a relationship editor.

## Continue reading

- [Forms](../forms/form-screens.md)
- [Tables and filters](tables-and-filters.md)
