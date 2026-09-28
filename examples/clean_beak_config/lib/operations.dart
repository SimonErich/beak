import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'resources/orders/models/order.dart';
import 'resources/categories/models/category.dart';
import 'resources/products/models/product_variant.dart';
import 'widgets/receivables_card.dart';

/// A custom operations route sharing ordinary resource queries and mutations.
// --8<-- [start:shopOperations]
BeakScreen shopOperations() => BeakScreen(
  path: '/operations',
  title: 'Operations',
  section: 'Workspace',
  icon: const BeakIconToken(OiIcons.listChecks),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      const BeakTextBlock(
        'Prepare the next deliveries, keep sellable stock available and follow up on billing.',
      ),
      BeakWidgetBlock((context) => const ShopReceivablesCard()),
      BeakSectionBlock(
        title: 'Fulfillment queue',
        description:
            'Confirmed and packing orders, earliest delivery first. Open an order to update its fulfillment status.',
        child: BeakTableBlock(
          model: const OrderModel(),
          fields: [
            OrderModel.reference,
            OrderModel.customer.email,
            OrderModel.status,
            OrderModel.deliveryDate,
          ],
          enableDelete: false,
          initialSpec: const OrderModel().query(
            sorts: [BeakSort(OrderModel.deliveryDate.key)],
            pagination: const BeakPagination(perPage: 10),
          ),
          baseFilter: fulfillmentQueueFilter(),
        ),
      ),
      BeakSectionBlock(
        title: 'Replenishment queue',
        description:
            'Active variants with five or fewer units remaining. Open a variant to update stock.',
        child: BeakTableBlock(
          model: const ProductVariantModel(),
          fields: [
            ProductVariantModel.sku,
            ProductVariantModel.name,
            ProductVariantModel.product.name,
            ProductVariantModel.stock,
          ],
          enableDelete: false,
          initialSpec: const ProductVariantModel().query(
            sorts: [BeakSort(ProductVariantModel.stock.key)],
            pagination: const BeakPagination(perPage: 10),
          ),
          baseFilter: BeakAndFilter([
            ProductVariantModel.active.eq(true),
            ProductVariantModel.stock.lte(5),
          ]),
        ),
      ),
      BeakSectionBlock(
        title: 'Import categories',
        description:
            'Preview a small catalog import, correct any errors and confirm the records to save.',
        child: BeakWidgetBlock(
          (context) => BeakImportView(
            title: 'Category import',
            definition: BeakImportDefinition(
              model: const CategoryModel(),
              fields: [CategoryModel.name, CategoryModel.description],
            ),
          ),
        ),
      ),
    ],
  ),
);
// --8<-- [end:shopOperations]

/// The same operational definition is used by the dashboard and work queue.
BeakFilter fulfillmentQueueFilter() => BeakOrFilter([
  OrderModel.status.eq(OrderStatus.confirmed),
  OrderModel.status.eq(OrderStatus.packing),
]);
