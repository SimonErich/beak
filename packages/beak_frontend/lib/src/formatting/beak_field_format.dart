import 'package:beak_core/beak_core.dart';

/// A typed field reference with a display-only formatting override.
///
/// Queries, sorting, filters and persistence retain the original field path and
/// value type. No formatted strings or scaled amounts enter API payloads.
class BeakFormattedField<T extends Object> extends BeakScalarField<T> {
  /// Wraps [field] while retaining its model, column, path and validation.
  BeakFormattedField({
    required BeakScalarField<T> field,
    required this.format,
    this.minorUnits = false,
    this.scale = 2,
    String? label,
  }) : assert(scale >= 0 && scale <= 12),
       _label = label ?? field.label,
       super(
         model: field.model,
         column: field.column,
         path: field.path,
         isRequired: field.isRequired,
       );

  /// How values should be displayed by tables and configured read forms.
  final BeakValueFormat format;

  /// Whether monetary values are stored in minor units such as cents.
  final bool minorUnits;

  /// Decimal places in stored integer minor units, independent of display policy.
  final int scale;

  final String _label;

  @override
  String get label => _label;
}

/// Declarative monetary presentation for generated numeric fields.
extension BeakCurrencyPresentation<T extends num> on BeakScalarField<T> {
  /// Displays this amount using the panel's currency; cents remain integers.
  BeakFormattedField<T> currency({
    bool minorUnits = false,
    int scale = 2,
    String? label,
  }) => BeakFormattedField<T>(
    field: this,
    format: BeakValueFormat.currency,
    minorUnits: minorUnits,
    scale: scale,
    label: label,
  );
}

/// Shared display overrides for generated scalar fields.
extension BeakFieldPresentation<T extends Object> on BeakScalarField<T> {
  /// Applies a display format without changing the field's typed value.
  BeakFormattedField<T> formatted(BeakValueFormat format, {String? label}) =>
      BeakFormattedField<T>(field: this, format: format, label: label);
}
