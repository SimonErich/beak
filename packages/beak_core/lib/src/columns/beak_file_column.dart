part of 'beak_column.dart';

/// A generic file-attachment column. Values are stored file keys/URLs;
/// rendering goes through the custom escape hatch (a download/preview
/// widget in `beak_frontend`).
final class BeakFileColumn extends BeakUploadColumn {
  /// Creates a file column storing uploads under [storagePath].
  const BeakFileColumn({
    required super.key,
    required super.label,
    required super.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    super.maxSizeInBytes,
    super.allowedTypes,
  });

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.custom);
}
