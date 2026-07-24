import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// The product layout, used for **both** the show page and the create/edit
/// form (the dual-mode blocks render values on one and inputs on the other):
/// a headline strip, an overview + primary-image split, and a tab per
/// data-heavy relation — variants, pricing rules, gallery, reviews, order
/// history, and tags. Each form column appears exactly once.
const BeakBlock productLayout = BeakColumnBlock(
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
          title: 'Overview',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(ProductColumns.description),
              BeakFieldGroupBlock([
                ProductColumns.cost,
                ProductColumns.stock,
                ProductColumns.categoryId,
              ], columnCount: 3),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Primary image',
          child: BeakFieldBlock(ProductColumns.image),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Related',
      child: BeakTabsBlock(
        tabs: [
          BeakTabBlockItem(
            label: 'Variants',
            icon: OiIcons.layers,
            content: BeakRelationBlock(ProductRelations.variants),
          ),
          BeakTabBlockItem(
            label: 'Pricing rules',
            icon: OiIcons.percent,
            content: BeakRelationBlock(ProductRelations.priceRules),
          ),
          BeakTabBlockItem(
            label: 'Gallery',
            icon: OiIcons.image,
            content: BeakRelationBlock(ProductRelations.images),
          ),
          BeakTabBlockItem(
            label: 'Reviews',
            icon: OiIcons.star,
            content: BeakRelationBlock(ProductRelations.reviews),
          ),
          BeakTabBlockItem(
            label: 'Order history',
            icon: OiIcons.history,
            content: BeakRelationBlock(ProductRelations.items),
          ),
          BeakTabBlockItem(
            label: 'Tags',
            icon: OiIcons.tag,
            content: BeakRelationBlock(ProductRelations.tags),
          ),
        ],
      ),
    ),
  ],
);

/// The order layout, shared by the show page and the create/edit form: a
/// headline strip, a money-breakdown + customer split, and tabs for the line
/// items, the lifecycle history, and internal comments.
const BeakBlock orderLayout = BeakColumnBlock(
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
          ]),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 5),
          title: 'Customer & channel',
          child: BeakFieldGroupBlock([
            OrderColumns.userId,
            OrderColumns.source,
            OrderColumns.placedAt,
          ]),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Related',
      child: BeakTabsBlock(
        tabs: [
          BeakTabBlockItem(
            label: 'Line items',
            icon: OiIcons.list,
            content: BeakRelationBlock(OrderRelations.items),
          ),
          BeakTabBlockItem(
            label: 'History',
            icon: OiIcons.history,
            content: BeakRelationBlock(OrderRelations.events),
          ),
          BeakTabBlockItem(
            label: 'Comments',
            icon: OiIcons.messageSquare,
            content: BeakRelationBlock(OrderRelations.comments),
          ),
        ],
      ),
    ),
  ],
);
