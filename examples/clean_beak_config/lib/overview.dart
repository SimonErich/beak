import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'operations.dart';
import 'widgets/receivables_card.dart';

import 'resources/invoices/models/invoice.dart';
import 'resources/orders/models/order.dart';
import 'resources/products/models/product.dart';
import 'resources/products/models/product_variant.dart';

/// Live operational overview assembled entirely from Beak's data blocks.
// --8<-- [start:shopOverview]
BeakScreen shopOverview() => BeakScreen(
  path: '/',
  title: 'Shop overview',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      const BeakTextBlock(
        'Your catalog, fulfillment and billing in one place.',
      ),
      // --8<-- [start:overviewMetricGrid]
      BeakGridBlock(
        minColumnWidthInPixels: 220,
        children: [
          // --8<-- [start:overviewProductsMetric]
          BeakMetricBlock(
            label: 'Products',
            icon: OiIcons.package,
            aggregate: const ProductModel().count(),
          ),
          // --8<-- [end:overviewProductsMetric]
          BeakMetricBlock(
            label: 'Orders to fulfill',
            icon: OiIcons.shoppingCart,
            aggregate: const OrderModel().count(
              filter: fulfillmentQueueFilter(),
            ),
          ),
          BeakMetricBlock(
            label: 'Awaiting payment',
            icon: OiIcons.receiptText,
            aggregate: const InvoiceModel().count(
              filter: InvoiceModel.status.eq(InvoiceStatus.issued),
            ),
          ),
          BeakMetricBlock(
            label: 'Low-stock variants',
            icon: OiIcons.layers,
            aggregate: const ProductVariantModel().count(
              filter: ProductVariantModel.stock.lte(5),
            ),
          ),
        ],
      ),
      // --8<-- [end:overviewMetricGrid]
      BeakWidgetBlock((context) => const ShopReceivablesCard()),
      BeakGridBlock(
        minColumnWidthInPixels: 480,
        children: [
          BeakCardBlock(
            title: 'Upcoming deliveries',
            child: BeakTableBlock(
              model: const OrderModel(),
              fields: [
                OrderModel.reference,
                OrderModel.status,
                OrderModel.deliveryDate,
              ],
              enableDelete: false,
              initialSpec: const OrderModel().query(
                sorts: [OrderModel.deliveryDate.ascending()],
                pagination: const BeakPagination(perPage: 5),
              ),
              baseFilter: BeakAndFilter([
                OrderModel.status.notEq(OrderStatus.cancelled),
                OrderModel.status.notEq(OrderStatus.delivered),
              ]),
            ),
          ),
          BeakCardBlock(
            title: 'Invoices awaiting payment',
            child: BeakTableBlock(
              model: const InvoiceModel(),
              fields: [
                // --8<-- [start:overviewFormattedFields]
                InvoiceModel.number,
                InvoiceModel.customerEmail.formatted(
                  BeakValueFormat.text,
                  label: 'Customer',
                ),
                InvoiceModel.dueAt.formatted(
                  BeakValueFormat.date,
                  label: 'Due date',
                ),
                // --8<-- [end:overviewFormattedFields]
              ],
              enableDelete: false,
              initialSpec: const InvoiceModel().query(
                sorts: [InvoiceModel.dueAt.ascending()],
                pagination: const BeakPagination(perPage: 5),
              ),
              baseFilter: InvoiceModel.status.eq(InvoiceStatus.issued),
            ),
          ),
        ],
      ),
      const BeakSectionBlock(
        title: 'Daily workflow',
        description:
            'Keep catalog data current, fulfill orders and track payment.',
        child: BeakGridBlock(
          minColumnWidthInPixels: 240,
          children: [
            BeakCardBlock(
              title: '1. Maintain the catalog',
              child: BeakTextBlock(
                'Create categories and attributes, then add products and their sellable variants.',
              ),
            ),
            BeakCardBlock(
              title: '2. Prepare fulfillment',
              child: BeakTextBlock(
                'Create an order, choose the customer’s delivery profile and review its lines.',
              ),
            ),
            BeakCardBlock(
              title: '3. Invoice and follow up',
              child: BeakTextBlock(
                'Add goods or services, apply vouchers and taxes, then track the invoice status.',
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
// --8<-- [end:shopOverview]
