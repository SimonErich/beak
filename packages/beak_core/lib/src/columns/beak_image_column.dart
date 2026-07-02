part of 'beak_column.dart';

/// An image column: a thumbnail in table cells, an image picker in forms,
/// and the full image in detail views. Values are stored file keys/URLs.
///
/// Upload rules (size, types, dimensions) and the [transforms] pipeline are
/// enforced server-side on upload; Phase 05 implements the storage layer.
final class BeakImageColumn extends BeakColumn {
  /// Creates an image column storing uploads under [storagePath].
  const BeakImageColumn({
    required super.key,
    required super.label,
    required this.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.maxSizeInBytes,
    this.allowedTypes = BeakFileType.images,
    this.maxDimensions,
    this.aspectRatio,
    this.thumbnail,
    this.transforms = const [],
  });

  /// Storage subfolder uploads of this column land in
  /// (e.g. `products/covers`).
  final String storagePath;

  /// Highest accepted upload size in bytes, if bounded.
  final int? maxSizeInBytes;

  /// Accepted upload types; defaults to raster images.
  final List<BeakFileType> allowedTypes;

  /// Largest accepted source dimensions, if bounded.
  final BeakDimensions? maxDimensions;

  /// Enforced width/height ratio, if any.
  final double? aspectRatio;

  /// Dimensions of the auto-generated thumbnail rendition, if any.
  final BeakDimensions? thumbnail;

  /// Transform pipeline run on upload, in order.
  final List<BeakImageTransform> transforms;

  @override
  BeakRenderConfig get renderConfig => const BeakRenderConfig(
    table: BeakRenderIntent.thumbnail,
    form: BeakRenderIntent.image,
    detail: BeakRenderIntent.image,
    // No built-in image filter; users supply one via the custom escape
    // hatch when needed.
    filter: BeakRenderIntent.custom,
  );

  /// Values are stored file keys/URLs.
  @override
  Type get valueType => String;
}
