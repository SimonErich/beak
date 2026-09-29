# Custom screens

> Compose dashboards and complete custom application screens from Beak blocks and widgets.

Register custom pages with `BeakPanel.pages`. Each `BeakScreen` provides a route,
optional navigation entry and `BeakBlock` body. The panel supplies its normal theme,
dependencies, formatting and resource navigation.

The shop dashboard mixes live metrics and filtered tables with a reusable custom
receivables widget. The same widget appears on the Operations page; both observe
confirmed writes through Beak's mutation source.

```dart title="examples/clean_beak_config/lib/overview.dart"
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
            aggregate: const ProductModel().count(),
          ),
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
```

Use `BeakWidgetBlock` to embed custom UI and `BeakCustomResourceScreen` to replace a
specific resource route. A custom widget inside an otherwise ordinary form uses
`BeakFormWidget` and the existing draft session, so custom interactions still take
part in save, cancel and validation.

See [custom screens and pages](custom-screens.md) for route
options, [custom blocks and widgets](../extending/custom-blocks-and-widgets.md) for
the embedded-widget example, and [dynamic attributes and variants](../models/dynamic-attributes-and-variants.md)
for a custom editor that stages owned relationships.

## Continue reading

- [Custom pages](custom-screens.md).
- [Custom widgets](../extending/custom-blocks-and-widgets.md).
