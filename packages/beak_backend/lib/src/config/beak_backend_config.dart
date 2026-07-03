import 'dart:io';

import 'package:beak_core/beak_core.dart';

/// Typed, validated runtime configuration for a Beak backend.
///
/// Built once at startup — usually with [fromEnv] over `BeakEnv.resolve()` —
/// and passed to the server; nothing else reads environment variables.
final class BeakBackendConfig {
  /// Creates a configuration from already-validated parts.
  const BeakBackendConfig({
    required this.databaseUrl,
    this.port = defaultPort,
    this.host = defaultHost,
  });

  /// Reads and validates the configuration from [environment] (defaults to
  /// [Platform.environment]).
  ///
  /// Requires `DATABASE_URL` (an absolute URL); `PORT` (1–65535, default
  /// [defaultPort]) and `HOST` (non-empty, default [defaultHost]) are
  /// optional. Throws a [BeakConfigurationException] on anything missing or
  /// malformed.
  factory BeakBackendConfig.fromEnv({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final rawDatabaseUrl = env['DATABASE_URL'];
    if (rawDatabaseUrl == null) {
      throw const BeakConfigurationException(
        'DATABASE_URL is required (e.g. postgres://user:pass@host:5432/db).',
      );
    }
    final Uri? databaseUrl = Uri.tryParse(rawDatabaseUrl);
    if (databaseUrl == null ||
        databaseUrl.scheme.isEmpty ||
        databaseUrl.host.isEmpty) {
      throw BeakConfigurationException(
        'DATABASE_URL must be an absolute URL with a host, '
        'got "$rawDatabaseUrl".',
      );
    }
    final rawPort = env['PORT'];
    final int port = rawPort == null ? defaultPort : _parsePort(rawPort);
    final host = env['HOST'] ?? defaultHost;
    if (host.isEmpty) {
      throw const BeakConfigurationException('HOST must not be empty.');
    }
    return BeakBackendConfig(databaseUrl: databaseUrl, port: port, host: host);
  }

  /// The port the server listens on when `PORT` is unset.
  static const int defaultPort = 8080;

  /// The interface the server binds when `HOST` is unset.
  static const String defaultHost = '0.0.0.0';

  /// The database connection URL (credentials included — see [toString]).
  final Uri databaseUrl;

  /// The port the HTTP server listens on.
  final int port;

  /// The interface the HTTP server binds.
  final String host;

  static int _parsePort(String raw) {
    final int? port = int.tryParse(raw);
    if (port == null || port < 1 || port > 65535) {
      throw BeakConfigurationException(
        'PORT must be an integer between 1 and 65535, got "$raw".',
      );
    }
    return port;
  }

  @override
  String toString() =>
      'BeakBackendConfig(databaseUrl: ${databaseUrl.replace(userInfo: '')}, '
      'port: $port, host: $host)';
}
