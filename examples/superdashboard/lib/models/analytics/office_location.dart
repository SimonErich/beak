import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'office_location.beak.dart';

/// The office-locations resource — the pins on the tile map.
@Resource()
final class OfficeLocation extends BeakSchema {
  /// The office name.
  @Display()
  @Column(label: 'Office', searchable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The city.
  @Column(searchable: true)
  late final String? city;

  /// The country.
  @Column(filterable: true)
  late final String? country;

  /// The office latitude.
  @Column(precision: 5)
  late final double? latitude;

  /// The office longitude.
  @Column(precision: 5)
  late final double? longitude;

  /// The number of people at the office.
  @Column(sortable: true, min: 0)
  late final int? headcount;
}
