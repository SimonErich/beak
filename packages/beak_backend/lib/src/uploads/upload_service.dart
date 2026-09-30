import 'package:beak_core/beak_core.dart';

import '../common/uuid_v4.dart';

/// The logic layer behind the upload endpoints: resolves the target column,
/// enforces its Filament-style file rules, runs the image transform
/// pipeline, and stores every result via the configured driver.
///
/// Handlers stay parse-thin; this service throws typed exceptions only
/// (not-found for unknown columns/keys, validation for rule violations and
/// non-file columns). Internal to `beak_backend`: `beakApiRouter` builds one
/// when a storage driver is configured, and the upload routes call it.
///
/// ```dart
/// final service = UploadService(
///   registry: registry,
///   storage: resolveStorage(const BeakMemoryStorageConfig()),
///   transformRunner: const ImageTransformRunner(),
/// );
/// final stored = await service.handle(
///   table: 'products',
///   columnKey: 'thumbnail',
///   upload: BeakUpload(
///     filename: 'photo.png',
///     mimeType: 'image/png',
///     bytes: pngBytes,
///   ),
/// );
/// final Uri url = stored.url; // the public URL of the stored file
/// ```
final class UploadService {
  /// Creates an upload service over [registry], [storage], and
  /// [transformRunner].
  ///
  /// [generateKeyId] injects the storage-key mint for tests (defaults to
  /// uuid v4) — client filenames are never trusted for keys.
  ///
  /// [signedUrlLifetime] is how long the links [url] hands out stay valid on
  /// drivers that sign them (S3 presigned GETs); drivers whose links do not
  /// expire ignore it. It must be positive.
  UploadService({
    required this.registry,
    required this.storage,
    required this.transformRunner,
    String Function()? generateKeyId,
    this.signedUrlLifetime = defaultSignedUrlLifetime,
  }) : _generateKeyId = generateKeyId ?? generateUuidV4 {
    if (signedUrlLifetime <= Duration.zero) {
      throw BeakConfigurationException(
        'The signed URL lifetime must be positive, got $signedUrlLifetime.',
      );
    }
  }

  /// How long a signed link stays valid unless the host says otherwise.
  static const Duration defaultSignedUrlLifetime = Duration(hours: 1);

  /// The models whose file columns may be uploaded to.
  final BeakModelRegistry registry;

  /// The configured storage driver.
  final BeakStorageDriver storage;

  /// The pixel pipeline executing image transforms.
  final BeakTransformRunner transformRunner;

  /// How long the links [url] returns stay valid on signing drivers.
  final Duration signedUrlLifetime;

  final String Function() _generateKeyId;

  static const BeakUploadValidator _validator = BeakUploadValidator();

  /// Validates [upload] against the rules of `table.columnKey`, transforms
  /// images, stores everything, and returns the typed result.
  Future<BeakStoredFile> handle({
    required String table,
    required String columnKey,
    required BeakUpload upload,
  }) async {
    switch (_columnOf(table, columnKey)) {
      case final BeakFileColumn fileColumn:
        return _storeFile(fileColumn, upload);
      case final BeakImageColumn imageColumn:
        return _storeImage(imageColumn, upload);
      case final BeakColumn other:
        throw BeakValidationException(
          'Column "$columnKey" of "$table" is a ${other.runtimeType}; '
          'uploads need a file or image column.',
        );
    }
  }

  /// Deletes the stored file under [key], which must belong to the storage
  /// path of `table.columnKey`.
  Future<void> remove(String table, String columnKey, String key) async {
    await _requireKey(table, columnKey, key);
    await storage.delete(key);
  }

  /// Resolves only existing keys belonging to this column's storage path.
  ///
  /// The link is signed for [signedUrlLifetime] where the driver signs, so a
  /// private bucket is readable through the upload endpoint; a driver with
  /// public links returns them unchanged.
  Future<Uri> url(String table, String columnKey, String key) async {
    await _requireKey(table, columnKey, key);
    return storage.url(key, expiresIn: signedUrlLifetime);
  }

  Future<void> _requireKey(String table, String columnKey, String key) async {
    final String storagePath = switch (_columnOf(table, columnKey)) {
      BeakUploadColumn(:final storagePath) => storagePath,
      final BeakColumn other => throw BeakValidationException(
        'Column "$columnKey" of "$table" is a ${other.runtimeType}; '
        'uploads need a file or image column.',
      ),
    };
    if (!key.startsWith('$storagePath/') || !_isWellFormedKey(key)) {
      throw BeakValidationException(
        'Key "$key" does not belong to column "$columnKey" '
        '(expected the "$storagePath/" prefix).',
      );
    }
    if (!await storage.exists(key)) {
      throw BeakNotFoundException('No stored file "$key".');
    }
  }

  /// Whether [key] is a well-formed storage key. A key a client sends never
  /// reaches a driver otherwise: a malformed one is the client's mistake (422),
  /// not a storage failure.
  static bool _isWellFormedKey(String key) {
    try {
      BeakStorageKeys.validate(key);
      return true;
    } on BeakStorageException {
      return false;
    }
  }

  BeakColumn _columnOf(String table, String columnKey) {
    final model = registry.byTable(table);
    if (model == null) {
      throw BeakNotFoundException('No model registered for table "$table".');
    }
    return model.columnByKey(columnKey) ??
        (throw BeakNotFoundException(
          'Model "$table" has no column "$columnKey".',
        ));
  }

  Future<BeakStoredFile> _storeFile(
    BeakFileColumn column,
    BeakUpload upload,
  ) async {
    _validator
        .validate(
          upload,
          maxSizeInBytes: column.maxSizeInBytes,
          allowedTypes: column.allowedTypes,
        )
        .valueOrThrow;
    return storage.put(
      BeakUpload(
        filename: _mintedFilename(upload.mimeType, fallback: upload),
        mimeType: upload.mimeType,
        bytes: upload.bytes,
      ),
      path: column.storagePath,
    );
  }

  Future<BeakStoredFile> _storeImage(
    BeakImageColumn column,
    BeakUpload upload,
  ) async {
    // The header answers the dimension rules before a pixel is decoded, so a
    // few bytes declaring a huge bitmap never reach the decoder, and the
    // pipeline then decodes the file once (an empty one is a pass-through
    // that still proves the bytes decode).
    // --8<-- [start:imagePipeline]
    final BeakDimensions declared = await transformRunner.inspect(upload.bytes);
    _validator
        .validate(
          upload,
          maxSizeInBytes: column.maxSizeInBytes,
          allowedTypes: column.allowedTypes,
          maxDimensions: column.maxDimensions,
          aspectRatio: column.aspectRatio,
          actualDimensions: declared,
        )
        .valueOrThrow;
    final transformed = await transformRunner.run(
      upload.bytes,
      column.transforms,
    );
    // --8<-- [end:imagePipeline]

    final String keyId = _generateKeyId();
    final mainStored = await storage.put(
      BeakUpload(
        filename: _filenameFor(keyId, transformed.mimeType, fallback: upload),
        mimeType: transformed.mimeType,
        bytes: transformed.bytes,
      ),
      path: column.storagePath,
    );
    final variants = <String, BeakStoredFileVariant>{};
    try {
      for (final MapEntry(:key, :value) in transformed.variants.entries) {
        final variantStored = await storage.put(
          BeakUpload(
            filename: _filenameFor(
              '${keyId}_$key',
              value.mimeType,
              fallback: upload,
            ),
            mimeType: value.mimeType,
            bytes: value.bytes,
          ),
          path: column.storagePath,
        );
        variants[key] = BeakStoredFileVariant(
          key: variantStored.key,
          url: variantStored.url,
          widthInPixels: value.dimensions.widthInPixels,
          heightInPixels: value.dimensions.heightInPixels,
        );
      }
    } on Exception {
      // A rendition failure must not strand successfully written predecessors.
      for (final key in [
        mainStored.key,
        ...variants.values.map((v) => v.key),
      ]) {
        try {
          await storage.delete(key);
        } on Exception {
          // Preserve the original storage failure. Hosts can collect orphaned
          // files after infrastructure recovery.
        }
      }
      rethrow;
    }
    return BeakStoredFile(
      key: mainStored.key,
      url: mainStored.url,
      sizeInBytes: transformed.bytes.length,
      mimeType: transformed.mimeType,
      widthInPixels: transformed.dimensions.widthInPixels,
      heightInPixels: transformed.dimensions.heightInPixels,
      variants: variants,
    );
  }

  String _mintedFilename(String mimeType, {required BeakUpload fallback}) =>
      _filenameFor(_generateKeyId(), mimeType, fallback: fallback);

  String _filenameFor(
    String base,
    String mimeType, {
    required BeakUpload fallback,
  }) {
    final String? extension =
        _extensionForMime(mimeType) ?? _safeExtension(fallback.extension);
    return extension == null ? base : '$base.$extension';
  }

  /// [extension] as the client declared it, when it is short and plain enough
  /// to sit in a storage key: the filename is client input, and a key is a
  /// path on disk, a URL and an FTP command, so anything else is dropped.
  static String? _safeExtension(String? extension) =>
      extension != null && _plainExtension.hasMatch(extension)
      ? extension
      : null;

  static final RegExp _plainExtension = RegExp(r'^[a-z0-9]{1,16}$');

  String? _extensionForMime(String mimeType) {
    for (final type in BeakFileType.values) {
      if (type.mimeType == mimeType) {
        return type.extensions.first;
      }
    }
    return null;
  }
}
