part of '../beak_storage_config.dart';

/// Configures the FTP storage driver; consumed by `beak_storage_ftp`
/// (Phase 06). `beak_core` owns the config surface so apps configure
/// storage without importing driver packages.
final class BeakFtpConfig extends BeakStorageConfig {
  /// Creates an FTP storage configuration.
  const BeakFtpConfig({
    required this.host,
    this.port = 21,
    required this.user,
    required this.password,
    required this.baseDir,
    required this.publicBaseUrl,
  });

  /// FTP server host name.
  final String host;

  /// FTP server port.
  final int port;

  /// Login user name.
  final String user;

  /// Login password; redacted from [toString].
  final String password;

  /// Remote directory uploads are stored under.
  final String baseDir;

  /// Base URL stored files are publicly served from.
  final Uri publicBaseUrl;

  @override
  String get driverId => 'ftp';

  @override
  String toString() =>
      'BeakFtpConfig(host: $host, port: $port, user: $user, '
      'baseDir: $baseDir, publicBaseUrl: $publicBaseUrl, '
      'password: [redacted])';
}
