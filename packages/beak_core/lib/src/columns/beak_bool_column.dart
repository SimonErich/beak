part of 'beak_column.dart';

/// A boolean column: a toggle in forms, a yes/no indicator elsewhere.
///
/// [trueLabel]/[falseLabel] override the default state text (e.g. show
/// "In stock"/"Sold out" instead of "Yes"/"No").
///
/// ```dart
/// static const active = BeakBoolColumn(
///   key: 'active',
///   label: 'Active',
///   trueLabel: 'In stock',
///   falseLabel: 'Sold out',
/// );
/// ```
final class BeakBoolColumn extends BeakColumn {
  /// Creates a boolean column with optional state labels.
  const BeakBoolColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.trueLabel,
    this.falseLabel,
  });

  /// Display label of the `true` state, if customized.
  final String? trueLabel;

  /// Display label of the `false` state, if customized.
  final String? falseLabel;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.boolean);

  @override
  Type get valueType => bool;
}
