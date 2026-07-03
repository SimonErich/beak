import 'package:meta/meta.dart';

/// The typed description of a successfully stored file, returned by every
/// `BeakStorageDriver.put` and by the upload endpoint.
@immutable
final class BeakStoredFile {
  /// Creates a stored-file description.
  const BeakStoredFile({
    required this.key,
    required this.url,
    required this.sizeInBytes,
    required this.mimeType,
    this.widthInPixels,
    this.heightInPixels,
    this.variants = const {},
  });

  /// Driver-scoped storage key the file is retrievable under.
  final String key;

  /// Public (or signed) URL the file is served from.
  final Uri url;

  /// Stored size in bytes.
  final int sizeInBytes;

  /// MIME type of the stored content.
  final String mimeType;

  /// Decoded image width in pixels, when known.
  final int? widthInPixels;

  /// Decoded image height in pixels, when known.
  final int? heightInPixels;

  /// Additional stored renditions (e.g. `thumbnail`), keyed by variant name.
  final Map<String, BeakStoredFileVariant> variants;
}

/// A stored rendition of a [BeakStoredFile], e.g. a generated thumbnail.
@immutable
final class BeakStoredFileVariant {
  /// Creates a stored-variant description.
  const BeakStoredFileVariant({
    required this.key,
    required this.url,
    this.widthInPixels,
    this.heightInPixels,
  });

  /// Driver-scoped storage key the variant is retrievable under.
  final String key;

  /// Public (or signed) URL the variant is served from.
  final Uri url;

  /// Decoded image width in pixels, when known.
  final int? widthInPixels;

  /// Decoded image height in pixels, when known.
  final int? heightInPixels;
}
