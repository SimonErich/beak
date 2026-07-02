part of 'beak_column.dart';

/// A color column holding hex strings (e.g. `#663399`), rendered as a
/// swatch with a color picker in forms.
final class BeakColorColumn extends BeakColumn {
  /// Creates a color column.
  const BeakColorColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
  });

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.color);

  /// Values are hex color strings.
  @override
  Type get valueType => String;
}
