import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:reference_admin_models/reference_admin_models.dart';

/// Duplicates a product — the custom-action escape hatch: plain typed code
/// over the data source, surfaced as a row action.
Future<void> duplicateProduct(
  BeakRecord record,
  BeakActionContext context,
) async {
  final String name = record['name']?.raw?.toString() ?? 'Product';
  await context.dataSource.create(
    'products',
    BeakRecord(
      values: {
        'name': BeakStringValue('$name (copy)'),
        if (record['price'] case final BeakValue price) 'price': price,
        if (record['status'] case final BeakValue status) 'status': status,
        if (record['category_id'] case final BeakValue category)
          'category_id': category,
      },
    ),
  );
  await context.refresh?.call();
}

/// Maps a product page onto stock-per-product chart points.
List<BeakChartPoint> stockPerProduct(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: record['name']?.raw?.toString() ?? '',
      value: switch (record['stock']?.raw) {
        final num stock => stock.toDouble(),
        _ => 0,
      },
    ),
];

/// The whole reference panel from the shared model definitions: six
/// resources, a dashboard, and the filter/action escape hatches — no
/// endpoints, no per-page code.
BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  resources: const [
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
      filters: [
        BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
        BeakTextFilter(column: ProductColumns.name, label: 'Name'),
      ],
      recordActions: [
        BeakRecordAction(
          key: 'duplicate',
          label: 'Duplicate',
          icon: OiIcons.copy,
          onExecute: duplicateProduct,
        ),
      ],
    ),
    BeakResource(
      model: CategoryModel(),
      icon: BeakIconToken(OiIcons.folderTree),
    ),
    BeakResource(model: TagModel(), icon: BeakIconToken(OiIcons.tag)),
    BeakResource(
      model: UserModel(),
      icon: BeakIconToken(OiIcons.users),
      filters: [
        BeakBoolFilter(column: UserColumns.active, label: 'Active only'),
      ],
    ),
    BeakResource(
      model: OrderModel(),
      icon: BeakIconToken(OiIcons.shoppingCart),
    ),
    BeakResource(
      model: OrderItemModel(),
      icon: BeakIconToken(OiIcons.listOrdered),
    ),
  ],
  dashboardStats: [
    const BeakStat(
      label: 'Products',
      aggregate: BeakAggregateSpec.count(table: 'products'),
      icon: OiIcons.package,
    ),
    const BeakStat(
      label: 'Customers',
      aggregate: BeakAggregateSpec.count(table: 'users'),
      icon: OiIcons.users,
    ),
    BeakStat(
      label: 'Catalog value',
      aggregate: BeakAggregateSpec.sum(
        table: 'products',
        column: ProductColumns.price,
      ),
      icon: OiIcons.euro,
      prefix: '€',
    ),
  ],
  dashboardCharts: [
    const BeakChart(
      title: 'Stock per product',
      type: BeakChartType.bar,
      query: BeakQuerySpec(table: 'products'),
      map: stockPerProduct,
    ),
  ],
);

/// The reference admin app: one [BeakPanel] over the shared models.
final class ReferenceAdminApp extends StatelessWidget {
  /// Creates the app; [dataSource] injects a fake in widget tests.
  const ReferenceAdminApp({this.dataSource, super.key});

  /// Test seam replacing the HTTP-backed data source.
  final BeakDataSource? dataSource;

  @override
  Widget build(BuildContext context) =>
      BeakPanel(config: buildReferencePanelConfig(), dataSource: dataSource);
}

void main() => runApp(const ReferenceAdminApp());
