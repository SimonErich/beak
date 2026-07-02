/// Exception for authentication failures.
library;

import 'adapter_exception.dart';

/// Thrown when a database refuses an authentication
/// attempt (wrong user, wrong password, missing
/// role, expired credentials, …).
class AuthenticationException extends AdapterException {
  /// Creates an [AuthenticationException].
  const AuthenticationException({
    required this.host,
    required String message,
    this.username,
  }) : super(message);

  /// The host that refused the credentials.
  final String host;

  /// The user identifier that failed to authenticate,
  /// when known.
  final String? username;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'host': host,
    'username': username,
  };

  @override
  String toString() {
    final user = username;
    if (user == null) {
      return 'AuthenticationException: $message (host: $host)';
    }
    return 'AuthenticationException: $message '
        '(host: $host, username: $user)';
  }
}
