import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../models/product.dart';

/// A screen the generated pages could not produce: everything running low, in
/// one list, next to the number that matters.
///
/// A custom screen is still blocks, not widgets — so it gets the same data
/// wiring, the same theming and the same empty states as a generated page,
/// and it is declared in one const expression.
const BeakScreen restockScreen = BeakScreen(
  path: '/restock',
  title: 'Restock',
  icon: BeakIconToken(OiIcons.packageSearch),
  section: 'Catalog',
  body: BeakColumnBlock(
    gapInPixels: 20,
    children: [
      BeakGridBlock(
        columns: 12,
        children: [
          BeakMetricBlock(
            span: BeakSpan(columns: 6),
            label: 'Out of stock',
            aggregate: BeakAggregateSpec.count(
              table: 'products',
              filter: BeakFieldFilter(
                column: ProductColumns.stock,
                operator: BeakOperator.eq,
                value: BeakIntValue(0),
              ),
            ),
            icon: OiIcons.packageX,
          ),
          BeakMetricBlock(
            span: BeakSpan(columns: 6),
            label: 'Stock on hand',
            aggregate: BeakAggregateSpec.sum(
              table: 'products',
              column: ProductColumns.stock,
            ),
            icon: OiIcons.package,
          ),
        ],
      ),
      BeakCardBlock(
        title: 'Running low',
        child: BeakTableBlock(
          model: ProductModel(),
          columns: [
            ProductColumns.name,
            ProductColumns.sku,
            ProductColumns.stock,
            ProductColumns.status,
          ],
          baseFilter: BeakFieldFilter(
            column: ProductColumns.stock,
            operator: BeakOperator.lt,
            value: BeakIntValue(10),
          ),
          initialSpec: BeakQuerySpec(
            table: 'products',
            sorts: [BeakSort('stock')],
          ),
        ),
      ),
    ],
  ),
);
