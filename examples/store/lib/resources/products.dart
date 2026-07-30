import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../models/product.dart';

/// The products resource, with the parts Beak cannot derive.
///
/// Everything else — the model, the label, the icon, the section — still comes
/// from the schema class and `beak.yaml`; this file only adds what a person
/// decides. The filters are not listed: every `filterable: true` column
/// already contributes its control.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  recordActions: [
    BeakRecordAction(
      key: 'publish',
      label: 'Publish',
      icon: OiIcons.rocket,
      onExecute: (record, context) async {
        final Object? id = context.model.primaryKeyOf(record);
        if (id == null) {
          return;
        }
        await context.dataSource.update(
          context.model.table,
          id,
          BeakRecord(
            values: {
              ProductColumns.status.key: BeakValue.of(
                ProductStatus.published.name,
              ),
              ProductColumns.publishedAt.key: BeakValue.of(DateTime.now()),
            },
          ),
        );
      },
    ),
  ],
  bulkActions: [
    BeakBulkAction(
      key: 'archive',
      label: 'Archive',
      icon: OiIcons.archive,
      color: BeakColor.warning,
      onExecute: (records, context) async {
        for (final record in records) {
          final Object? id = context.model.primaryKeyOf(record);
          if (id == null) {
            continue;
          }
          await context.dataSource.update(
            context.model.table,
            id,
            BeakRecord(
              values: {
                ProductColumns.status.key: BeakValue.of(
                  ProductStatus.archived.name,
                ),
              },
            ),
          );
        }
      },
    ),
  ],
  viewModes: const [
    BeakTableView(),
    BeakKanbanView(
      groupField: ProductColumns.status,
      titleField: ProductColumns.name,
      subtitleField: ProductColumns.sku,
    ),
  ],
);

/// The product layout, used for **both** the show page and the create/edit
/// form: the dual-mode blocks render values on one and inputs on the other,
/// so the two pages cannot drift apart.
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
              BeakFieldBlock(ProductColumns.summary),
              BeakFieldBlock(ProductColumns.description),
              BeakFieldGroupBlock([
                ProductColumns.stock,
                ProductColumns.featured,
                ProductColumns.publishedAt,
                ProductColumns.swatch,
              ], columnCount: 4),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Media',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(ProductColumns.image),
              BeakFieldBlock(ProductColumns.specSheet),
            ],
          ),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Related',
      child: BeakTabsBlock(
        tabs: [
          BeakTabBlockItem(
            label: 'Category',
            icon: OiIcons.folderTree,
            content: BeakFieldBlock(ProductColumns.categoryId),
          ),
          BeakTabBlockItem(
            label: 'Tags',
            icon: OiIcons.tag,
            content: BeakRelationBlock(ProductRelations.tags),
          ),
          BeakTabBlockItem(
            label: 'Sold in',
            icon: OiIcons.receipt,
            content: BeakRelationBlock(ProductRelations.orderItems),
          ),
        ],
      ),
    ),
  ],
);
