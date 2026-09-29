# Dashboards

> Combine live queries, aggregates and custom widgets on a page.

A dashboard is a `BeakScreen` with declarative blocks. `BeakMetricBlock` loads an aggregate, `BeakTableBlock` shows a scoped list, and layout blocks arrange them. Blocks use the panel source, share model formatting and respond to mutation notifications.

The page frame supplies the heading, gutters and scrolling without adding a
background around your cards. Each card or chart owns its surface. A table's
`baseFilter` is permanent: it constrains the first request, pagination totals,
search, sorting, user-filter changes and refreshes after confirmed writes.

The shop overview combines fulfillment and stock counts, a custom receivables widget and compact operational tables. The custom widget demonstrates exact money formatting, loading, a retryable error state and refresh after invoice changes.

```dart title="examples/clean_beak_config/lib/overview.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'operations.dart';
import 'widgets/receivables_card.dart';

import 'resources/invoices/models/invoice.dart';
import 'resources/orders/models/order.dart';
import 'resources/products/models/product.dart';
import 'resources/products/models/product_variant.dart';

/// Live operational overview assembled entirely from Beak's data blocks.
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
      BeakGridBlock(
        minColumnWidthInPixels: 220,
        children: [
          BeakMetricBlock(
            label: 'Products',
            icon: OiIcons.package,
            aggregate: BeakAggregateSpec.count(
              table: const ProductModel().table,
            ),
          ),
          BeakMetricBlock(
            label: 'Orders to fulfill',
            icon: OiIcons.shoppingCart,
            aggregate: BeakAggregateSpec.count(
              table: const OrderModel().table,
              filter: fulfillmentQueueFilter(),
            ),
          ),
          BeakMetricBlock(
            label: 'Awaiting payment',
            icon: OiIcons.receiptText,
            aggregate: BeakAggregateSpec.count(
              table: const InvoiceModel().table,
              filter: InvoiceModel.status.eq(InvoiceStatus.issued),
            ),
          ),
          BeakMetricBlock(
            label: 'Low-stock variants',
            icon: OiIcons.layers,
            aggregate: BeakAggregateSpec.count(
              table: const ProductVariantModel().table,
              filter: ProductVariantModel.stock.lte(5),
            ),
          ),
        ],
      ),
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
                sorts: [BeakSort(OrderModel.deliveryDate.key)],
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
                InvoiceModel.number,
                InvoiceModel.customerEmail.formatted(
                  BeakValueFormat.text,
                  label: 'Customer',
                ),
                InvoiceModel.dueAt.formatted(
                  BeakValueFormat.date,
                  label: 'Due date',
                ),
              ],
              enableDelete: false,
              initialSpec: const InvoiceModel().query(
                sorts: [BeakSort(InvoiceModel.dueAt.key)],
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
```

## Continue reading

- [Data blocks](../blocks/data-blocks.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
