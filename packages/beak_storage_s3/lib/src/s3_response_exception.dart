/// An S3 endpoint answered a request with an error status.
///
/// [S3StorageDriver] catches it and rethrows a [BeakStorageException], so
/// application code seldom sees this type; a custom [S3ObjectClient] wrapper
/// can match on [code] to tell "no such key" from "access denied".
///
/// ```dart
/// try {
///   await client.putObject(
///     bucket: 'uploads',
///     key: 'a.png',
///     bytes: bytes,
///     contentType: 'image/png',
///   );
/// } on S3ResponseException catch (error) {
///   if (error.code == 'AccessDenied') {
///     // The credentials cannot write to this bucket.
///   }
/// }
/// ```
final class S3ResponseException implements Exception {
  /// Creates the exception for an HTTP [statusCode], with the S3 error [code]
  /// and human [message] from the response's error document when it had one.
  const S3ResponseException({
    required this.statusCode,
    this.code,
    this.message,
  });

  /// Reads the `<Code>` and `<Message>` elements of the S3 error document in
  /// [body], for a response with [statusCode].
  ///
  /// A body that is empty or is not an S3 error document (an HTML page from a
  /// proxy, say) leaves [code] and [message] `null`.
  factory S3ResponseException.fromResponse({
    required int statusCode,
    required String body,
  }) => S3ResponseException(
    statusCode: statusCode,
    code: _elementText(body, 'Code'),
    message: _elementText(body, 'Message'),
  );

  /// The HTTP status of the response.
  final int statusCode;

  /// The S3 error code, such as `NoSuchKey` or `AccessDenied`, or `null` when
  /// the response carried no error document.
  final String? code;

  /// The human-readable sentence S3 gave, or `null` when there was none.
  final String? message;

  static String? _elementText(String body, String element) {
    final RegExpMatch? match = RegExp(
      '<$element>([^<]*)</$element>',
    ).firstMatch(body);
    final String? raw = match?.group(1);
    return raw == null ? null : _unescape(raw);
  }

  /// Replaces the five predefined XML entities. `&amp;` goes last so an
  /// escaped entity (`&amp;lt;`) is read as the text `&lt;`, not as `<`.
  static String _unescape(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  @override
  String toString() {
    final String? errorCode = code;
    final String? sentence = message;
    final String head = errorCode == null
        ? 'S3ResponseException($statusCode)'
        : 'S3ResponseException($statusCode $errorCode)';
    return sentence == null ? head : '$head: $sentence';
  }
}
