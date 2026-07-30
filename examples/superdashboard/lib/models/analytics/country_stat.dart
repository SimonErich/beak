import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'country_stat.beak.dart';

/// The country-stats resource — per-country activity for the map.
@Resource()
final class CountryStat extends BeakSchema {
  /// Country name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(80)])
  late final String country;

  /// ISO 3166-1 alpha-2 code, keying the map region.
  @Column(label: 'Code', rules: [BeakMaxLength(2)])
  late final String countryCode;

  /// Active users in this country.
  @Column(label: 'Active users', sortable: true, min: 0)
  late final int? activeUsers;

  /// Revenue from this country.
  @Column(sortable: true, prefix: r'$')
  late final double? sales;

  /// Change versus the prior period, as a percentage.
  @Column(label: 'Change', sortable: true, suffix: '%')
  late final double? changePercent;
}
