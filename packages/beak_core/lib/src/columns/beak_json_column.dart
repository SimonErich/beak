part of 'beak_column.dart';

/// A structured-JSON column. Values are typed [BeakJson] trees — never raw
/// `Map<String, dynamic>` — rendered as pretty-printed JSON.
final class BeakJsonColumn extends BeakColumn {
  /// Creates a JSON column.
  const BeakJsonColumn({
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
      const BeakRenderConfig.uniform(BeakRenderIntent.json);

  @override
  Type get valueType => BeakJson;
}
