part of 'beak_column.dart';

/// A rich-text column: a WYSIWYG editor in forms, rendered markup in tables
/// and detail views. Values are stored as the raw markup source string, not
/// as parsed nodes.
///
/// ```dart
/// static const body = BeakRichTextColumn(key: 'body', label: 'Body');
/// ```
final class BeakRichTextColumn extends BeakColumn with BeakTypedColumn<String> {
  /// Creates a rich-text column.
  // --8<-- [start:BeakRichTextColumn]
  const BeakRichTextColumn({
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
  // --8<-- [end:BeakRichTextColumn]

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.richText);

  /// Reads [value] as a string value.
  @override
  String? readValue(BeakValue? value) => _readText(value);
}
