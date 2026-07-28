part of 'beak_column.dart';

/// A fractional-number column with fixed [precision]; a [prefix] or
/// [suffix] (e.g. a currency symbol or unit) switches its rendering from a
/// plain number to a decorated currency-style amount.
///
/// ```dart
/// // Currency amount: "€19.99".
/// static const price = BeakDecimalColumn(
///   key: 'price',
///   label: 'Price',
///   prefix: '€',
///   sortable: true,
///   filterable: true,
///   rules: [BeakRequired(), BeakMin(0)],
/// );
///
/// // Plain number with a trailing unit: "1.50 kg".
/// static const weight = BeakDecimalColumn(
///   key: 'weight',
///   label: 'Weight',
///   suffix: 'kg',
/// );
/// ```
final class BeakDecimalColumn extends BeakColumn with BeakTypedColumn<double> {
  /// Creates a decimal column displaying [precision] fraction digits, stored
  /// in [totalDigits] digits overall.
  const BeakDecimalColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.indexed,
    super.unique,
    super.rules,
    this.precision = 2,
    this.totalDigits = 10,
    this.prefix,
    this.suffix,
  });

  /// Number of fraction digits, displayed and stored.
  ///
  /// The generated migration uses this as the column's SQL scale, so a
  /// column that shows four decimals holds four. It used to be display-only
  /// while every decimal column was created `NUMERIC(10, 2)`, which rounded
  /// the value on the way in and then showed the rounded number to four
  /// places.
  final int precision;

  /// Total digits the column stores, fraction digits included.
  ///
  /// The SQL precision of `NUMERIC(totalDigits, precision)`. The default
  /// leaves eight digits ahead of the point, which is enough for money and
  /// not enough for a scientific quantity, so say so when it is not.
  final int totalDigits;

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

  /// Reads [value] as a double value.
  @override
  double? readValue(BeakValue? value) => _readDouble(value);
}
