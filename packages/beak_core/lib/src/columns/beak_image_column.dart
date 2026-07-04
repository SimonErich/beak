part of 'beak_column.dart';

/// An image column: a thumbnail in table cells, an image picker in forms,
/// and the full image in detail views. Values are stored file keys/URLs.
///
/// Upload rules (size, types, dimensions) and the [transforms] pipeline are
/// enforced server-side on upload (and mirrored client-side for fast
/// feedback). [transforms] run in order; a [thumbnail] rendition is generated
/// automatically when set.
///
/// ```dart
/// static const image = BeakImageColumn(
///   key: 'image',
///   label: 'Image',
///   storagePath: 'products',
///   maxSizeInBytes: 5 * 1024 * 1024,
///   allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
///   thumbnail: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
///   transforms: [
///     BeakThumbnailTransform(
///       size: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
///     ),
///     BeakFormatTransform.webp(),
///   ],
/// );
/// ```
final class BeakImageColumn extends BeakUploadColumn {
  /// Creates an image column storing uploads under [storagePath]
  /// (e.g. `products/covers`); [allowedTypes] defaults to raster images.
  const BeakImageColumn({
    required super.key,
    required super.label,
    required super.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    super.maxSizeInBytes,
    super.allowedTypes = BeakFileType.images,
    this.maxDimensions,
    this.aspectRatio,
    this.thumbnail,
    this.transforms = const [],
  });

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
}
