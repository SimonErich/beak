part of 'beak_block.dart';

/// A choropleth world map: each region is shaded by a value read from the
/// bound query — the dashboard's "live users by country".
///
/// Renders onto `OiVectorMap` with its bundled world geometry. [query]
/// returns one row per region; [regionCodeField] is the ISO 3166-1 alpha-2
/// code keying the map, and [valueField] drives the shade.
///
/// ```dart
/// BeakMapBlock(
///   title: 'Live users by country',
///   query: BeakQuerySpec(table: 'country_stats'),
///   regionCodeField: CountryStatColumns.countryCode,
///   valueField: CountryStatColumns.activeUsers,
///   valueLabel: 'Active users',
/// );
/// ```
final class BeakMapBlock extends BeakBlock {
  /// Creates a map block.
  const BeakMapBlock({
    required this.title,
    required this.query,
    required this.regionCodeField,
    required this.valueField,
    this.valueLabel = 'Value',
    this.heightInPixels = 320,
    super.span,
  });

  /// The card heading.
  final String title;

  /// The query producing one row per region.
  final BeakQuerySpec query;

  /// The column holding each row's ISO 3166-1 alpha-2 region code.
  final BeakColumn regionCodeField;

  /// The column holding each row's value (drives the shade).
  final BeakColumn valueField;

  /// The tooltip/legend caption for the value.
  final String valueLabel;

  /// Rendered height (the map needs bounded constraints).
  final double heightInPixels;
}
