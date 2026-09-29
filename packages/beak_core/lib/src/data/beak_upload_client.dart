import '../storage/beak_stored_file.dart';
import '../storage/beak_upload.dart';

/// The client-side upload boundary: sends a file to a column's upload
/// endpoint and returns the stored result.
///
/// Kept separate from [BeakDataSource] because only client-side sources
/// transport uploads — the backend's worm-backed source persists rows, while
/// its upload pipeline runs through `BeakStorageDriver` directly. The
/// frontend's HTTP source implements both interfaces.
abstract interface class BeakUploadClient {
  /// Uploads [file] for the [columnKey] column of [table] and returns the
  /// stored file description.
  ///
  /// Throws a `BeakValidationException` when the backend rejects the file
  /// against the column's rules.
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  );
}

/// Upload transport that can discard files created by an abandoned draft.
///
/// Implementations remove every rendition and treat missing files as success.
/// Only newly uploaded, definitely uncommitted files may be passed here.
abstract interface class BeakManagedUploadClient implements BeakUploadClient {
  /// Removes [file] and its variants from this column's storage.
  Future<void> discardUpload(
    String table,
    String columnKey,
    BeakStoredFile file,
  );
}

/// Optional resolution of persisted storage keys into current display URLs.
abstract interface class BeakUploadUrlClient {
  /// Resolves a key through the storage driver.
  ///
  /// A driver that signs its links (S3) answers with one that is valid for
  /// the server's signed-URL lifetime (default: one hour), so resolve a key
  /// again when you need to display it instead of persisting the returned
  /// address. Drivers with public links answer with the same address every
  /// time.
  Future<Uri> uploadUrl(String table, String columnKey, String key);
}
