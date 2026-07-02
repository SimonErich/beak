part of 'beak_column.dart';

/// A rich-text column: a rich editor in forms, rendered markup elsewhere.
/// Values are the raw markup source.
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
