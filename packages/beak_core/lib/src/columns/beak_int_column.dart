part of 'beak_column.dart';

/// An integer column, rendered as a locale-aware number.
///
/// [min]/[max] bound the form's stepper; pair them with [BeakMin]/[BeakMax]
/// rules to reject out-of-range values on submit as well. A [prefix] or
/// [suffix] carries the unit into the rendering, so a count reads `42 pcs`
/// rather than `42`.
///
/// ```dart
/// static const stock = BeakIntColumn(
///   key: 'stock',
///   label: 'Stock',
///   min: 0,
///   suffix: ' pcs',
///   sortable: true,
///   rules: [BeakMin(0)],
/// );
/// ```
final class BeakIntColumn extends BeakColumn with BeakTypedColumn<int> {
  /// Creates an integer column, optionally bounded by [min]/[max].
  // --8<-- [start:BeakIntColumn]
  const BeakIntColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.indexed,
    super.unique,
    super.rules,
    this.min,
    this.max,
    this.prefix,
    this.suffix,
  });
  // --8<-- [end:BeakIntColumn]

  /// Lowest value the form input offers, if bounded.
  final int? min;

  /// Highest value the form input offers, if bounded.
  final int? max;

  /// Text rendered before the number (e.g. `#`), if any.
  final String? prefix;

  /// Text rendered after the number (e.g. ` pcs`), if any.
  final String? suffix;

  @override
  BeakRenderConfig get renderConfig => BeakRenderConfig.uniform(
    prefix != null || suffix != null
        ? BeakRenderIntent.currency
        : BeakRenderIntent.number,
  );

  /// Reads [value] as a int value.
  @override
  int? readValue(BeakValue? value) => _readInt(value);
}
