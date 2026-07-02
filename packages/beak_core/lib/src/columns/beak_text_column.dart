part of 'beak_column.dart';

/// A multiline text column: a textarea in forms, truncated text in table
/// cells, and the full text in detail views.
final class BeakTextColumn extends BeakColumn {
  /// Creates a multiline text column.
  const BeakTextColumn({
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
      const BeakRenderConfig.uniform(BeakRenderIntent.text);

  @override
  Type get valueType => String;
}
