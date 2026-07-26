import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:reference_admin_models/reference_admin_models.dart';

/// Duplicates a product — the custom-action escape hatch: plain typed code
/// over the data source, surfaced as a row action.
///
/// Reads the source [record] through the shared [ProductColumns] constants
/// (never string literals), writes a `"(copy)"` clone via
/// `context.dataSource`, then triggers `context.refresh` so the table
/// reloads. Throws [BeakConfigurationException] when the record has no name.
///
/// Wire it into a resource as the `onExecute` of a [BeakRecordAction]:
///
/// ```dart
/// BeakResource(
///   model: const ProductModel(),
///   recordActions: [
///     BeakRecordAction(
///       key: 'duplicate',
///       label: 'Duplicate',
///       icon: OiIcons.copy,
///       onExecute: duplicateProduct,
///     ),
///   ],
/// )
/// ```
Future<void> duplicateProduct(
  BeakRecord record,
  BeakActionContext context,
) async {
  // `require` throws a BeakRecordShapeException naming the column when the
  // record has no readable name, so no hand-written null check is needed.
  final String name = ProductColumns.name.require(record);
  await context.dataSource.create(
    context.model.table,
    BeakRecord(
      values: {
        ProductColumns.name.key: BeakStringValue('$name (copy)'),
        if (record[ProductColumns.price.key] case final BeakValue price)
          ProductColumns.price.key: price,
        if (record[ProductColumns.status.key] case final BeakValue status)
          ProductColumns.status.key: status,
        if (record[ProductColumns.categoryId.key] case final BeakValue category)
          ProductColumns.categoryId.key: category,
      },
    ),
  );
  await context.refresh?.call();
}

/// Maps a page of product records onto stock-per-product chart points.
///
/// Used as the `map` callback of a dashboard [BeakChart]: each record
/// becomes one bar labelled by product name and sized by its stock count.
/// Records with a missing or non-numeric stock contribute a zero-height bar
/// rather than being dropped.
List<BeakChartPoint> stockPerProduct(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: ProductColumns.name.readFrom(record) ?? '',
      value: (ProductColumns.stock.readFrom(record) ?? 0).toDouble(),
    ),
];

/// The whole reference panel from the shared model definitions: six
/// resources, a dashboard, and the filter/action escape hatches — no
/// endpoints, no per-page code.
///
/// [apiBaseUrl] points the panel's HTTP data source at the running
/// reference server (`reference_admin_server`); override it to target a
/// non-local backend. The
/// result is handed straight to a [BeakPanel], which renders navigation, a
/// table/detail/form page per [BeakResource], and the dashboard stats and
/// charts.
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
  // Every aggregate and query is derived from its model — no table strings.
  dashboardStats: [
    BeakStat(
      label: 'Products',
      aggregate: const ProductModel().count(),
      icon: OiIcons.package,
    ),
    BeakStat(
      label: 'Customers',
      aggregate: const UserModel().count(),
      icon: OiIcons.users,
    ),
    BeakStat(
      label: 'Catalog value',
      aggregate: const ProductModel().sum(ProductColumns.price),
      icon: OiIcons.euro,
      prefix: '€',
    ),
  ],
  dashboardCharts: [
    BeakChart(
      title: 'Stock per product',
      type: BeakChartType.bar,
      query: const ProductModel().query(),
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

/// Boots the Flutter reference admin against the default local backend.
void main() => runApp(const ReferenceAdminApp());
