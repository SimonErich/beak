/// Per-isolate PostgreSQL connection pool.
library;

import 'package:postgres/postgres.dart';
import 'package:worm/worm.dart';

/// Thin wrapper around the `postgres` v3 [Pool] providing
/// connection-pooling for a single isolate.
///
/// The wrapper does not reimplement connection management — the
/// underlying [Pool] owns socket lifecycle, health checking, and
/// backpressure. [PostgresConnectionPool] only adds:
///
/// - [PostgresConnectionPool.fromConfig] that translates a worm
///   [ConnectionConfig] into an [Endpoint] + [PoolSettings] pair.
/// - A process-isolate-wide reservation counter that enforces
///   [ConnectionConfig.maxTotalConnections] when configured.
/// - [run] and [transaction] wrappers matching the worm adapter's
///   execution contract.
/// - [maxConnectionCount], exposed so the configured pool size is
///   inspectable without reaching into the opaque [PoolSettings].
final class PostgresConnectionPool {
  /// Creates a pool wrapping an already-constructed [Pool].
  ///
  /// Prefer [PostgresConnectionPool.fromConfig] in production —
  /// the raw-[Pool] constructor exists so adapters and tests can
  /// inject a pre-configured or instrumented pool.
  PostgresConnectionPool({
    required Pool<Object?> pool,
    required this.maxConnectionCount,
  }) : _pool = pool;

  /// Build a pool from a worm [ConnectionConfig].
  ///
  /// `poolSize` becomes [PoolSettings.maxConnectionCount]. When
  /// [ConnectionConfig.maxTotalConnections] is set, the
  /// per-isolate `poolSize` is clamped so the sum of every pool's
  /// `maxConnectionCount` in the current isolate never exceeds
  /// `maxTotalConnections`. `useSsl` selects [SslMode.require] /
  /// [SslMode.disable]. `connectionTimeout` is forwarded to
  /// [PoolSettings]. A `port` of `0` (worm's sentinel for "unset")
  /// resolves to Postgres' default `5432`.
  factory PostgresConnectionPool.fromConfig(ConnectionConfig config) {
    final cap = config.maxTotalConnections;
    final effective = cap == null
        ? config.poolSize
        : _reserve(config.poolSize, cap);
    final endpoint = Endpoint(
      host: config.host,
      port: config.port == 0 ? 5432 : config.port,
      database: config.database,
      username: config.username,
      password: config.password,
    );
    final settings = PoolSettings(
      maxConnectionCount: effective,
      sslMode: config.useSsl ? SslMode.require : SslMode.disable,
      connectTimeout: config.connectionTimeout,
    );
    final pool = Pool<Object?>.withEndpoints(<Endpoint>[
      endpoint,
    ], settings: settings);
    return PostgresConnectionPool(pool: pool, maxConnectionCount: effective);
  }

  /// Process-isolate-local count of slots reserved by every
  /// pool created via `PostgresConnectionPool.fromConfig`. Used to
  /// enforce `ConnectionConfig.maxTotalConnections` across multiple
  /// named connections.
  static int _isolateReserved = 0;

  static int _reserve(int requested, int cap) {
    if (cap <= 0) return 0;
    final available = cap - _isolateReserved;
    if (available <= 0) {
      throw const ConfigurationException(
        key: 'maxTotalConnections',
        message:
            'PostgresConnectionPool: maxTotalConnections cap reached. '
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

  /// Number of pool slots currently reserved across every pool
  /// built via `fromConfig` in this isolate.
  static int get isolateReservedSlots => _isolateReserved;

  /// Resets the isolate-wide reservation counter to zero.
  /// Test-only — production code should call [close] on every pool
  /// instead.
  static void resetIsolateReservationForTesting() {
    _isolateReserved = 0;
  }

  final Pool<Object?> _pool;

  /// Maximum concurrent connections the underlying pool will open.
  /// Mirrors the value passed to [PoolSettings.maxConnectionCount]
  /// after any `maxTotalConnections` clamp is applied.
  final int maxConnectionCount;

  bool _closed = false;

  /// Acquires a pooled [Session] and passes it to [action].
  ///
  /// The session is released back to the pool when [action]
  /// completes (whether normally or with an error).
  Future<R> run<R>(Future<R> Function(Session session) action) =>
      _pool.run(action);

  /// Acquires a pooled connection, starts a transaction, and
  /// passes the transactional [TxSession] to [action].
  ///
  /// If [action] throws, the transaction is rolled back and the
  /// error is rethrown.
  Future<R> transaction<R>(Future<R> Function(TxSession tx) action) =>
      _pool.runTx(action);

  /// Closes the underlying [Pool], releasing every connection and
  /// returning its reservation to the global cap.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _release(maxConnectionCount);
    await _pool.close();
  }
}
