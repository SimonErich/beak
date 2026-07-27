part of 'beak_column.dart';

/// An integer column, rendered as a locale-aware number.
///
/// [min]/[max] bound the form's stepper; pair them with [BeakMin]/[BeakMax]
/// rules to reject out-of-range values on submit as well.
///
/// ```dart
/// static const stock = BeakIntColumn(
///   key: 'stock',
///   label: 'Stock',
///   min: 0,
///   sortable: true,
///   rules: [BeakMin(0)],
/// );
/// ```
final class BeakIntColumn extends BeakColumn with BeakTypedColumn<int> {
  /// Creates an integer column, optionally bounded by [min]/[max].
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
  });

  /// Lowest value the form input offers, if bounded.
  final int? min;

  /// Highest value the form input offers, if bounded.
  final int? max;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.number);

  /// Reads [value] as a int value.
  @override
  int? readValue(BeakValue? value) => _readInt(value);
}
