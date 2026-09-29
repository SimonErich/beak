import '../common/beak_exception.dart';

/// Builds and validates the relative, `/`-separated storage keys shared by
/// every `BeakStorageDriver`.
abstract final class BeakStorageKeys {
  /// Appends [key]'s segments to [baseUrl]'s path — the one way every
  /// storage driver turns a base URL plus a storage key into a public URL.
  static Uri appendToBaseUrl(Uri baseUrl, String key) => baseUrl.replace(
    pathSegments: [
      ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      ...key.split('/'),
    ],
  );

  /// Joins a [path] prefix and a [filename] into a validated key, trimming
  /// redundant slashes around [path] (an empty [path] stores at the root).
  ///
  /// Throws a [BeakStorageException] when the resulting key is malformed.
  static String join({required String path, required String filename}) {
    final String prefix = path.replaceAll(RegExp(r'^/+|/+$'), '');
    final String key = prefix.isEmpty ? filename : '$prefix/$filename';
    validate(key);
    return key;
  }

  /// Validates [key]: non-empty, relative, `/`-separated, without empty,
  /// `.` or `..` segments and without backslashes.
  ///
  /// Throws a [BeakStorageException] describing the first violation.
  // --8<-- [start:validate]
  static void validate(String key) {
    if (key.isEmpty) {
      throw const BeakStorageException('Storage keys must not be empty.');
    }
    if (key.contains(r'\')) {
      throw BeakStorageException(
        'Storage key "$key" must use "/" separators, not backslashes.',
      );
    }
    if (key.startsWith('/')) {
      throw BeakStorageException(
        'Storage key "$key" must be relative, not absolute.',
      );
    }
    for (final String segment in key.split('/')) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        throw BeakStorageException(
          'Storage key "$key" contains the invalid segment "$segment".',
        );
      }
    }
  }
  // --8<-- [end:validate]
}
