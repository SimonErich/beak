import 'package:beak_core/beak_core.dart';

import '../common/uuid_v4.dart';

/// The logic layer behind the upload endpoints: resolves the target column,
/// enforces its Filament-style file rules, runs the image transform
/// pipeline, and stores every result via the configured driver.
///
/// Handlers stay parse-thin; this service throws typed exceptions only
/// (not-found for unknown columns/keys, validation for rule violations and
/// non-file columns).
final class UploadService {
  /// Creates an upload service over [registry], [storage], and
  /// [transformRunner].
  ///
  /// [generateKeyId] injects the storage-key mint for tests (defaults to
  /// uuid v4) — client filenames are never trusted for keys.
  UploadService({
    required this.registry,
    required this.storage,
    required this.transformRunner,
    String Function()? generateKeyId,
  }) : _generateKeyId = generateKeyId ?? generateUuidV4;

  /// The models whose file columns may be uploaded to.
  final BeakModelRegistry registry;

  /// The configured storage driver.
  final BeakStorageDriver storage;

  /// The pixel pipeline executing image transforms.
  final BeakTransformRunner transformRunner;

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
    final String storagePath = switch (_columnOf(table, columnKey)) {
      BeakUploadColumn(:final storagePath) => storagePath,
      final BeakColumn other => throw BeakValidationException(
        'Column "$columnKey" of "$table" is a ${other.runtimeType}; '
        'uploads need a file or image column.',
      ),
    };
    if (!key.startsWith('$storagePath/')) {
      throw BeakValidationException(
        'Key "$key" does not belong to column "$columnKey" '
        '(expected the "$storagePath/" prefix).',
      );
    }
    if (!await storage.exists(key)) {
      throw BeakNotFoundException('No stored file "$key".');
    }
    await storage.delete(key);
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
    // An empty pipeline is a decoding pass-through: it yields the source
    // bytes plus decoded dimensions (or a validation failure for bytes that
    // are not a supported raster image).
    final decoded = await transformRunner.run(upload.bytes, const []);
    _validator
        .validate(
          upload,
          maxSizeInBytes: column.maxSizeInBytes,
          allowedTypes: column.allowedTypes,
          maxDimensions: column.maxDimensions,
          aspectRatio: column.aspectRatio,
          actualDimensions: decoded.dimensions,
        )
        .valueOrThrow;
    final transformed = column.transforms.isEmpty
        ? decoded
        : await transformRunner.run(upload.bytes, column.transforms);

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
    final String? extension = _extensionForMime(mimeType) ?? fallback.extension;
    return extension == null ? base : '$base.$extension';
  }

  String? _extensionForMime(String mimeType) {
    for (final type in BeakFileType.values) {
      if (type.mimeType == mimeType) {
        return type.extensions.first;
      }
    }
    return null;
  }
}
