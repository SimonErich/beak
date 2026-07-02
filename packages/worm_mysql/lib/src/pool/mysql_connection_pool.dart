/// Per-isolate MySQL connection pool.
library;

import 'dart:io';

import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:worm/worm.dart';

/// Thin wrapper around the `mysql_client_plus` [MySQLConnectionPool]
/// providing connection-pooling for a single isolate.
///
/// The wrapper does not reimplement connection management — the
/// underlying pool owns socket lifecycle and check-in/check-out. This
/// class adds:
///
/// - [MysqlConnectionPool.fromConfig] translating a worm
///   [ConnectionConfig] into pool settings.
/// - [MysqlConnectionPool.fromUri] parsing a `mysql://` URL (used by
///   the integration tests).
/// - A process-isolate-wide reservation counter that enforces
///   [ConnectionConfig.maxTotalConnections] across named connections.
/// - [run], which checks out a pooled connection for the duration of an
///   action and returns it afterwards — matching the worm adapter's
///   execution contract for both single statements and whole
///   transactions.
final class MysqlConnectionPool {
  /// Creates a pool wrapping an already-constructed [pool].
  ///
  /// Prefer [MysqlConnectionPool.fromConfig] / [MysqlConnectionPool.fromUri]
  /// in production; this constructor exists so tests can inject a
  /// pre-configured pool.
  MysqlConnectionPool({
    required MySQLConnectionPool pool,
    required this.maxConnectionCount,
  }) : _pool = pool;

  /// Build a pool from a worm [ConnectionConfig].
  ///
  /// `poolSize` becomes the maximum connection count, clamped against
  /// [ConnectionConfig.maxTotalConnections] when set. `useSsl` selects
  /// TLS. A `port` of `0` (worm's sentinel for "unset") resolves to
  /// MySQL's default `3306`.
  factory MysqlConnectionPool.fromConfig(
    ConnectionConfig config, {
    bool Function(X509Certificate certificate)? onBadCertificate,
  }) {
    final cap = config.maxTotalConnections;
    final effective = cap == null
        ? config.poolSize
        : _reserve(config.poolSize, cap);
    final pool = MySQLConnectionPool(
      host: config.host,
      port: config.port == 0 ? 3306 : config.port,
      userName: config.username ?? '',
      password: config.password ?? '',
      databaseName: config.database.isEmpty ? null : config.database,
      maxConnections: effective < 1 ? 1 : effective,
      secure: config.useSsl,
      collation: 'utf8mb4_general_ci',
      timeoutMs: config.connectionTimeout.inMilliseconds,
      onBadCertificate: onBadCertificate,
    );
    return MysqlConnectionPool(pool: pool, maxConnectionCount: effective);
  }

  /// Build a pool from a `mysql://user:pass@host:port/database` URL.
  ///
  /// TLS is enabled when the URL carries `?ssl=true` (or `?secure=true`);
  /// otherwise the connection is plain. When TLS is enabled a permissive
  /// certificate callback is installed by default so development servers
  /// with self-signed certificates connect — override
  /// [onBadCertificate] to tighten this.
  factory MysqlConnectionPool.fromUri(
    String url, {
    int maxConnections = 5,
    bool Function(X509Certificate certificate)? onBadCertificate,
  }) {
    final uri = Uri.parse(url);
    final userInfo = uri.userInfo.split(':');
    final user = userInfo.isNotEmpty ? Uri.decodeComponent(userInfo.first) : '';
    final password = userInfo.length > 1
        ? Uri.decodeComponent(userInfo[1])
        : '';
    final database = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    final sslParam =
        uri.queryParameters['ssl'] ?? uri.queryParameters['secure'];
    final secure = sslParam == 'true' || sslParam == '1';
    final pool = MySQLConnectionPool(
      host: uri.host.isEmpty ? 'localhost' : uri.host,
      port: uri.hasPort ? uri.port : 3306,
      userName: user,
      password: password,
      databaseName: database,
      maxConnections: maxConnections,
      secure: secure,
      collation: 'utf8mb4_general_ci',
      onBadCertificate: onBadCertificate ?? (secure ? (_) => true : null),
    );
    return MysqlConnectionPool(pool: pool, maxConnectionCount: maxConnections);
  }

  /// Process-isolate-local count of slots reserved by every pool
  /// created via `fromConfig`. Enforces `maxTotalConnections` across
  /// multiple named connections.
  static int _isolateReserved = 0;

  static int _reserve(int requested, int cap) {
    if (cap <= 0) return 0;
    final available = cap - _isolateReserved;
    if (available <= 0) {
      throw const ConfigurationException(
        key: 'maxTotalConnections',
        message:
            'MysqlConnectionPool: maxTotalConnections cap reached. '
            'Close existing pools or raise the cap to add more.',
      );
    }
    final granted = requested <= available ? requested : available;
    _isolateReserved += granted;
    return granted;
  }

  static void _release(int amount) {
    _isolateReserved -= amount;
    if (_isolateReserved < 0) _isolateReserved = 0;
  }

  /// Number of pool slots currently reserved across every pool built
  /// via `fromConfig` in this isolate.
  static int get isolateReservedSlots => _isolateReserved;

  /// Resets the isolate-wide reservation counter to zero. Test-only —
  /// production code should call [close] on every pool instead.
  static void resetIsolateReservationForTesting() {
    _isolateReserved = 0;
  }

  final MySQLConnectionPool _pool;

  /// Maximum concurrent connections the underlying pool will open.
  final int maxConnectionCount;

  bool _closed = false;

  /// Checks out a pooled connection, passes it to [action], and returns
  /// it to the pool when [action] completes (normally or with an error).
  Future<R> run<R>(Future<R> Function(MySQLConnection conn) action) async =>
      _pool.withConnection(action);

  /// Live count of connections currently executing a statement.
  int get activeConnections => _pool.activeConnectionsQty;

  /// Live count of idle pooled connections.
  int get idleConnections => _pool.idleConnectionsQty;

  /// Closes the underlying pool, releasing every connection and
  /// returning its reservation to the global cap.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _release(maxConnectionCount);
    await _pool.close();
  }
}
