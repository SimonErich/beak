import 'package:beak_core/beak_core.dart';

/// The catch boundary for column uploads: mirrors the column's file rules
/// client-side for fast feedback, then ships the file through a
/// [BeakUploadClient] — every outcome lands in a typed [BeakResult].
///
/// [upload] validates the file against the column's size and type rules
/// before it leaves the client (dimension rules need decoding and stay
/// server-side); a failed rule short-circuits to [BeakErr] without a
/// network call.
///
/// ```dart
/// final repository = BeakUploadRepository(uploadClient);
/// final result = await repository.upload('products', ProductColumns.image, file);
/// switch (result) {
///   case BeakOk(:final value):
///     print('stored at ${value.url}');
///   case BeakErr(:final error):
///     print('rejected: ${error.message}');
/// }
/// ```
final class BeakUploadRepository {
  /// Creates a repository uploading through [client].
  const BeakUploadRepository(
    this.client, {
    this.validator = const BeakUploadValidator(),
  });

  /// The transport uploads go through.
  final BeakUploadClient client;

  /// Enforces the column's size/type rules before the file leaves the
  /// client (dimension rules need decoding and stay server-side).
  final BeakUploadValidator validator;

  /// Validates [file] against [column]'s rules and uploads it to [table]'s
  /// upload endpoint.
  Future<BeakResult<BeakStoredFile>> upload(
    String table,
    BeakColumn column,
    BeakUpload file,
  ) async {
    final (
      int? maxSizeInBytes,
      List<BeakFileType> allowedTypes,
    ) = switch (column) {
      BeakUploadColumn(:final maxSizeInBytes, :final allowedTypes) => (
        maxSizeInBytes,
        allowedTypes,
      ),
      _ => (null, const <BeakFileType>[]),
    };
    final BeakResult<BeakUpload> validated = validator.validate(
      file,
      maxSizeInBytes: maxSizeInBytes,
      allowedTypes: allowedTypes,
    );
    if (validated case BeakErr(:final error)) {
      return BeakErr(error);
    }
    try {
      return BeakOk(await client.upload(table, column.key, file));
    } on BeakException catch (exception) {
      return BeakErr(exception);
    } on Exception {
      return const BeakErr(
        BeakStorageException('Unable to upload the file. Please try again.'),
      );
    }
  }
}
