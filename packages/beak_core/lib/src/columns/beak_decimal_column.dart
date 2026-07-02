part of 'beak_column.dart';

/// A fractional-number column with fixed [precision]; a [prefix] or
/// [suffix] (e.g. a currency symbol or unit) switches its rendering from a
/// plain number to a decorated currency-style amount.
final class BeakDecimalColumn extends BeakColumn {
  /// Creates a decimal column displaying [precision] fraction digits.
  const BeakDecimalColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.precision = 2,
    this.prefix,
    this.suffix,
  });

  /// Number of fraction digits displayed.
  final int precision;

  /// Text rendered before the number (e.g. `€`), if any.
  final String? prefix;

  /// Text rendered after the number (e.g. `kg`), if any.
  final String? suffix;

  @override
  BeakRenderConfig get renderConfig => BeakRenderConfig.uniform(
    prefix != null || suffix != null
        ? BeakRenderIntent.currency
        : BeakRenderIntent.number,
  );

  @override
  Type get valueType => double;
}
