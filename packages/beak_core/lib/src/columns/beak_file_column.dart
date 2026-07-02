part of 'beak_column.dart';

/// A generic file-attachment column. Values are stored file keys/URLs;
/// rendering goes through the custom escape hatch (a download/preview
/// widget in `beak_frontend`).
final class BeakFileColumn extends BeakColumn {
  /// Creates a file column storing uploads under [storagePath].
  const BeakFileColumn({
    required super.key,
    required super.label,
    required this.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.maxSizeInBytes,
    this.allowedTypes = const [],
  });

  /// Storage subfolder uploads of this column land in.
  final String storagePath;

  /// Highest accepted upload size in bytes, if bounded.
  final int? maxSizeInBytes;

  /// Accepted upload types; empty means unrestricted.
  final List<BeakFileType> allowedTypes;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.custom);

  /// Values are stored file keys/URLs.
  @override
  Type get valueType => String;
}
