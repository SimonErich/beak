import 'package:meta/meta.dart';

import '../common/beak_exception.dart';
import '../common/json_support.dart';
import '../common/map_equality.dart';

/// The typed description of a successfully stored file, returned by every
/// `BeakStorageDriver.put` and by the upload endpoint (as JSON, via
/// [toJson]/[fromJson]).
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

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakStoredFile fromJson(Map<String, Object?> json) {
    const context = 'BeakStoredFile';
    final variantsJson = requireJsonMap(json, 'variants', context);
    return BeakStoredFile(
      key: requireJsonString(json, 'key', context),
      url: Uri.parse(requireJsonString(json, 'url', context)),
      sizeInBytes: requireJsonInt(json, 'sizeInBytes', context),
      mimeType: requireJsonString(json, 'mimeType', context),
      widthInPixels: requireJsonIntOrNull(json, 'widthInPixels', context),
      heightInPixels: requireJsonIntOrNull(json, 'heightInPixels', context),
      variants: {
        for (final MapEntry(:key, :value) in variantsJson.entries)
          key: switch (value) {
            final Map<String, Object?> map => BeakStoredFileVariant.fromJson(
              map,
            ),
            final Object? other => throw BeakConfigurationException(
              '$context JSON key "variants" must hold JSON objects, '
              'got $other.',
            ),
          },
      },
    );
  }

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

  /// This description as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'key': key,
    'url': url.toString(),
    'sizeInBytes': sizeInBytes,
    'mimeType': mimeType,
    'widthInPixels': widthInPixels,
    'heightInPixels': heightInPixels,
    'variants': {
      for (final MapEntry(:key, :value) in variants.entries)
        key: value.toJson(),
    },
  };

  @override
  bool operator ==(Object other) =>
      other is BeakStoredFile &&
      other.key == key &&
      other.url == url &&
      other.sizeInBytes == sizeInBytes &&
      other.mimeType == mimeType &&
      other.widthInPixels == widthInPixels &&
      other.heightInPixels == heightInPixels &&
      mapEquals(other.variants, variants);

  @override
  int get hashCode => Object.hash(
    key,
    url,
    sizeInBytes,
    mimeType,
    widthInPixels,
    heightInPixels,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in variants.entries)
        Object.hash(key, value),
    ]),
  );

  @override
  String toString() =>
      'BeakStoredFile($key, $mimeType, $sizeInBytes bytes, '
      'variants: ${variants.keys.toList()})';
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

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakStoredFileVariant fromJson(Map<String, Object?> json) {
    const context = 'BeakStoredFileVariant';
    return BeakStoredFileVariant(
      key: requireJsonString(json, 'key', context),
      url: Uri.parse(requireJsonString(json, 'url', context)),
      widthInPixels: requireJsonIntOrNull(json, 'widthInPixels', context),
      heightInPixels: requireJsonIntOrNull(json, 'heightInPixels', context),
    );
  }

  /// Driver-scoped storage key the variant is retrievable under.
  final String key;

  /// Public (or signed) URL the variant is served from.
  final Uri url;

  /// Decoded image width in pixels, when known.
  final int? widthInPixels;

  /// Decoded image height in pixels, when known.
  final int? heightInPixels;

  /// This variant as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'key': key,
    'url': url.toString(),
    'widthInPixels': widthInPixels,
    'heightInPixels': heightInPixels,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakStoredFileVariant &&
      other.key == key &&
      other.url == url &&
      other.widthInPixels == widthInPixels &&
      other.heightInPixels == heightInPixels;

  @override
  int get hashCode => Object.hash(key, url, widthInPixels, heightInPixels);

  @override
  String toString() =>
      'BeakStoredFileVariant($key, ${widthInPixels}x$heightInPixels)';
}
