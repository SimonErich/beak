import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

/// Typed columns of the purchase-sources resource — the dashboard
/// source-of-purchases donut, one row per acquisition channel.
abstract final class PurchaseSourceColumns {
  /// The acquisition channel.
  static const source = BeakEnumColumn<PurchaseSource>(
    key: 'source',
    label: 'Source',
    values: PurchaseSource.values,
    defaultValue: PurchaseSource.direct,
    filterable: true,
    badgeColors: {
      PurchaseSource.direct: BeakColor.primary,
      PurchaseSource.social: BeakColor.info,
      PurchaseSource.email: BeakColor.success,
      PurchaseSource.affiliate: BeakColor.warning,
      PurchaseSource.search: BeakColor.secondary,
    },
  );

  /// Human-readable channel label.
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Label',
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Revenue from this channel.
  static const total = BeakDecimalColumn(
    key: 'total',
    label: 'Total',
    prefix: r'$',
    sortable: true,
  );

  /// Order count from this channel.
  static const count = BeakIntColumn(
    key: 'count',
    label: 'Orders',
    min: 0,
    sortable: true,
  );

  /// Share of total, 0..100.
  static const percent = BeakDecimalColumn(
    key: 'percent',
    label: 'Share',
    suffix: '%',
    sortable: true,
  );

  /// Chart swatch color.
  static const color = BeakColorColumn(
    key: 'color',
    label: 'Color',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    source,
    label,
    total,
    count,
    percent,
    color,
  ];
}

/// The purchase-sources resource — acquisition-channel breakdown.
final class PurchaseSourceModel extends BeakModel {
  /// Creates the purchase-sources model.
  const PurchaseSourceModel();

  @override
  String get table => 'purchase_sources';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => PurchaseSourceColumns.values;

  @override
  List<BeakRelationship> get relationships => const [];
}
