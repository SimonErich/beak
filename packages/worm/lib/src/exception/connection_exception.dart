/// Exception for database connection failures.
library;

import 'adapter_exception.dart';

/// Thrown when a database connection cannot be
/// established or is lost.
class ConnectionException extends AdapterException {
  /// Creates a [ConnectionException].
  const ConnectionException({
    required this.host,
    required this.port,
    required String message,
  }) : super(message);

  /// The database host that failed.
  final String host;

  /// The database port that failed.
  final int port;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'host': host,
    'port': port,
  };

  @override
  String toString() =>
      'ConnectionException: $message (host: $host, port: $port)';
}
