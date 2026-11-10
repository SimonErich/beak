import '../behavior/beak_model_behavior.dart';
import '../columns/beak_column.dart';

/// Localized names for the enum values, columns and commands a panel shows.
///
/// Beak's generated model carries wire values, not display names: an enum value
/// is its `name`, a field its inventory label. A host that translates them sets
/// one [BeakLabels] on its `BeakPanelConfig`, and every table cell, filter,
/// form input and export reads the same mapping:
///
/// ```dart
/// BeakPanelConfig(
///   labels: BeakLabels(
///     enumValue: (value) => switch (value) {
///       OrderStatus.pending => strings.pending,
///       _ => null,
///     },
///     field: (column) => column.key == 'sku' ? strings.sku : null,
///   ),
/// )
/// ```
///
/// Returning `null` keeps the generated default, so a mapping only lists the
/// values it renames.
final class BeakLabels {
  /// Creates a label mapping.
  const BeakLabels({this.enumValue, this.field, this.action});

  /// The label of an enum value, or `null` to keep its wire name.
  final String? Function(Object value)? enumValue;

  /// The label of a column, or `null` to keep its declared label.
  final String? Function(BeakColumn column)? field;

  /// The label of a model command, or `null` to keep its declared label.
  final String? Function(BeakModelAction action)? action;

  /// The labels the nearest [BeakPanel] installed, or an empty mapping.
  ///
  /// Beak's columns and commands read this so one mapping reaches every
  /// surface. Set it through `BeakPanelConfig.labels`; do not assign it
  /// directly outside a test.
  static BeakLabels current = const BeakLabels();

  /// The label of [value], falling back to its enum name.
  String enumLabelOf(Object value) =>
      enumValue?.call(value) ?? (value is Enum ? value.name : '$value');
}
