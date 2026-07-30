part of 'beak_column.dart';

/// A multiline text column: a textarea in forms, truncated text in table
/// cells, and the full text in detail views.
final class BeakTextColumn extends BeakColumn with BeakTypedColumn<String> {
  /// Creates a multiline text column.
  // --8<-- [start:BeakTextColumn]
  const BeakTextColumn({
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
  // --8<-- [end:BeakTextColumn]

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.text);

  /// Reads [value] as a string value.
  @override
  String? readValue(BeakValue? value) => _readText(value);
}
