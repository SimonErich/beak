part of 'beak_column.dart';

/// A rich-text column: a WYSIWYG editor in forms, rendered markup in tables
/// and detail views. Values are stored as the raw markup source string, not
/// as parsed nodes.
///
/// ```dart
/// static const body = BeakRichTextColumn(key: 'body', label: 'Body');
/// ```
final class BeakRichTextColumn extends BeakColumn {
  /// Creates a rich-text column.
  const BeakRichTextColumn({
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
      const BeakRenderConfig.uniform(BeakRenderIntent.richText);

  @override
  Type get valueType => String;
}
