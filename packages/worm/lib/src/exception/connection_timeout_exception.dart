/// Exception for connection timeouts.
library;

import 'connection_exception.dart';

/// Thrown when establishing a database connection
/// exceeds the configured timeout.
///
/// Extends [ConnectionException] so callers can
/// catch a broader connection problem and still
/// access [host], [port], and the elapsed
/// [timeoutMs].
class ConnectionTimeoutException extends ConnectionException {
  /// Creates a [ConnectionTimeoutException].
  const ConnectionTimeoutException({
    required super.host,
    required super.port,
    required this.timeoutMs,
    required super.message,
  });

  /// Milliseconds that elapsed before the connection
  /// attempt was abandoned.
  final int timeoutMs;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'host': host,
    'port': port,
    'timeoutMs': timeoutMs,
  };

  @override
  String toString() =>
      'ConnectionTimeoutException: $message '
      '(host: $host, port: $port, timeoutMs: $timeoutMs)';
}
