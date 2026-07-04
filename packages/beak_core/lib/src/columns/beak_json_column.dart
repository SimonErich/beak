part of 'beak_column.dart';

/// A structured-JSON column.
///
/// The column carries its document as a JSON **text** value (a
/// `BeakStringValue`), rendered pretty-printed and edited as multiline
/// text — Beak never surfaces a raw `Map<String, dynamic>`. Parse that text
/// into a typed, pattern-matchable tree with [BeakJson.decode] when you need
/// structured access:
///
/// ```dart
/// const column = BeakJsonColumn(key: 'meta', label: 'Metadata');
/// final BeakValue? value = record[column.key];
/// final tree = switch (value?.raw) {
///   final String json => BeakJson.decode(json),
///   _ => const BeakJsonNull(),
/// };
/// ```
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
  Type get valueType => String;
}
