import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the country-stats resource — the dashboard
/// live-users-by-country map, one row per country.
abstract final class CountryStatColumns {
  /// Country name.
  static const country = BeakStringColumn(
    key: 'country',
    label: 'Country',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(80)],
  );

  /// ISO 3166-1 alpha-2 code, keying the map region.
  static const countryCode = BeakStringColumn(
    key: 'country_code',
    label: 'Code',
    rules: [BeakRequired(), BeakMaxLength(2)],
  );

  /// Active users in this country.
  static const activeUsers = BeakIntColumn(
    key: 'active_users',
    label: 'Active users',
    min: 0,
    sortable: true,
  );

  /// Revenue from this country.
  static const sales = BeakDecimalColumn(
    key: 'sales',
    label: 'Sales',
    prefix: r'$',
    sortable: true,
  );

  /// Change versus the prior period, as a percentage.
  static const changePercent = BeakDecimalColumn(
    key: 'change_percent',
    label: 'Change',
    suffix: '%',
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    country,
    countryCode,
    activeUsers,
    sales,
    changePercent,
  ];
}

/// The country-stats resource — per-country activity for the map.
final class CountryStatModel extends BeakModel {
  /// Creates the country-stats model.
  const CountryStatModel();

  @override
  String get table => 'country_stats';

  @override
  String get displayColumnKey => 'country';

  @override
  List<BeakColumn> get columns => CountryStatColumns.values;

  @override
  List<BeakRelationship> get relationships => const [];
}
