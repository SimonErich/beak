import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';

/// The product show page: a headline strip of the key facts, a two-column
/// body splitting the write-up and pricing from the image, and tabs for the
/// data-heavy relations (order lines, tags).
const BeakBlock productDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Product',
      child: BeakFieldGroupBlock([
        ProductColumns.name,
        ProductColumns.sku,
        ProductColumns.status,
        ProductColumns.price,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Details',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(ProductColumns.description),
              BeakFieldGroupBlock([
                ProductColumns.price,
                ProductColumns.cost,
                ProductColumns.stock,
                ProductColumns.categoryId,
              ]),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Image',
          child: BeakFieldBlock(ProductColumns.image),
        ),
      ],
    ),
    BeakTabsBlock(
      tabs: [
        BeakTabBlockItem(
          label: 'Order lines',
          content: BeakRelationBlock(ProductRelations.items),
        ),
        BeakTabBlockItem(
          label: 'Tags',
          content: BeakRelationBlock(ProductRelations.tags),
        ),
      ],
    ),
  ],
);

/// The order show page: totals and lifecycle up top, the money breakdown and
/// the customer side by side, and the line items in a tab.
const BeakBlock orderDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Order',
      child: BeakFieldGroupBlock([
        OrderColumns.reference,
        OrderColumns.status,
        OrderColumns.paymentStatus,
        OrderColumns.total,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 7),
          title: 'Amounts',
          child: BeakFieldGroupBlock([
            OrderColumns.subtotal,
            OrderColumns.shipping,
            OrderColumns.tax,
            OrderColumns.total,
          ]),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 5),
          title: 'Customer & channel',
          child: BeakFieldGroupBlock([
            OrderColumns.userId,
            OrderColumns.source,
            OrderColumns.placedAt,
            OrderColumns.paymentStatus,
          ]),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Line items',
      child: BeakRelationBlock(OrderRelations.items),
    ),
  ],
);
