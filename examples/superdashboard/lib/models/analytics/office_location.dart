import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the office-locations resource — a physical office pinned
/// on the tile map by its latitude/longitude.
abstract final class OfficeLocationColumns {
  /// The office name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Office',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// The city.
  static const city = BeakStringColumn(
    key: 'city',
    label: 'City',
    searchable: true,
  );

  /// The country.
  static const country = BeakStringColumn(
    key: 'country',
    label: 'Country',
    filterable: true,
  );

  /// The office latitude.
  static const latitude = BeakDecimalColumn(
    key: 'latitude',
    label: 'Latitude',
    precision: 5,
  );

  /// The office longitude.
  static const longitude = BeakDecimalColumn(
    key: 'longitude',
    label: 'Longitude',
    precision: 5,
  );

  /// The number of people at the office.
  static const headcount = BeakIntColumn(
    key: 'headcount',
    label: 'Headcount',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    city,
    country,
    latitude,
    longitude,
    headcount,
  ];
}

/// The office-locations resource — the pins on the tile map.
final class OfficeLocationModel extends BeakModel {
  /// Creates the office-locations model.
  const OfficeLocationModel();

  @override
  String get table => 'office_locations';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => OfficeLocationColumns.values;
}
