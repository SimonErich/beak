part of 'beak_column.dart';

/// A generic file-attachment column. Values are stored file keys/URLs;
/// rendering goes through the custom escape hatch (a download/preview
/// widget in `beak_frontend`).
///
/// Use [BeakImageColumn] instead for images. Bound uploads with
/// `maxSizeInBytes` and `allowedTypes`; both are enforced server-side.
///
/// ```dart
/// static const attachment = BeakFileColumn(
///   key: 'attachment',
///   label: 'Attachment',
///   storagePath: 'articles/files',
///   maxSizeInBytes: 10 * 1024 * 1024,
///   allowedTypes: [BeakFileType.pdf],
/// );
/// ```
final class BeakFileColumn extends BeakUploadColumn
    with BeakTypedColumn<String> {
  /// Creates a file column storing uploads under [storagePath].
  // --8<-- [start:BeakFileColumn]
  const BeakFileColumn({
    required super.key,
    required super.label,
    required super.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.indexed,
    super.unique,
    super.rules,
    super.semantic,
    super.defaultValue,
    super.maxSizeInBytes,
    super.allowedTypes,
  });
  // --8<-- [end:BeakFileColumn]

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.custom);

  /// Reads [value] as a string value.
  @override
  String? readValue(BeakValue? value) => _readText(value);
}
