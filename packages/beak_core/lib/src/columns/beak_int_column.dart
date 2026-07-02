part of 'beak_column.dart';

/// An integer column, rendered as a locale-aware number.
final class BeakIntColumn extends BeakColumn {
  /// Creates an integer column, optionally bounded by [min]/[max].
  const BeakIntColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.min,
    this.max,
  });

  /// Lowest value the form input offers, if bounded.
  final int? min;

  /// Highest value the form input offers, if bounded.
  final int? max;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.number);

  @override
  Type get valueType => int;
}
