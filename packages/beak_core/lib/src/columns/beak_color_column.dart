part of 'beak_column.dart';

/// A color column holding hex strings (e.g. `#663399`), rendered as a
/// swatch with a color picker in forms.
///
/// ```dart
/// static const brandColor = BeakColorColumn(
///   key: 'brand_color',
///   label: 'Brand color',
/// );
/// ```
final class BeakColorColumn extends BeakColumn with BeakTypedColumn<String> {
  /// Creates a color column.
  const BeakColorColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.indexed,
    super.unique,
    super.rules,
  });

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.color);

  /// Reads [value] as a string value.
  @override
  String? readValue(BeakValue? value) => _readText(value);
}
