/// Database connection configuration.
library;

/// Configuration for a single named database connection.
///
/// Ten fields describe the full surface: five network parameters,
/// one transport flag, and four pool / lifecycle parameters.
/// Adapter packages consume the subset they require.
final class ConnectionConfig {
  /// Creates a [ConnectionConfig].
  const ConnectionConfig({
    this.driver = 'inMemory',
    this.host = 'localhost',
    this.port = 0,
    this.database = '',
    this.username,
    this.password,
    this.useSsl = false,
    this.poolSize = 10,
    this.maxTotalConnections,
    this.connectionTimeout = const Duration(seconds: 5),
    this.idleTimeout = const Duration(seconds: 300),
  });

  /// Adapter / driver identifier (e.g. `'postgres'`, `'mongodb'`,
  /// `'inMemory'`). Adapter packages match against this to claim a
  /// connection.
  final String driver;

  /// Hostname or socket path of the database server.
  final String host;

  /// TCP port. `0` indicates "unset"; adapters are expected to
  /// supply their protocol default when this value is `0`.
  final int port;

  /// Database (or keyspace / namespace) name.
  final String database;

  /// Username for authentication, or `null` if unauthenticated.
  final String? username;

  /// Password for authentication, or `null` if unauthenticated.
  final String? password;

  /// Whether to negotiate TLS on the wire.
  final bool useSsl;

  /// Number of connections held open per isolate.
  final int poolSize;

  /// Cap on total connections across all isolates. `null` disables
  /// the cap.
  final int? maxTotalConnections;

  /// Maximum time to wait when acquiring a new connection.
  final Duration connectionTimeout;

  /// Time a connection may idle before being closed.
  final Duration idleTimeout;

  /// Returns a copy of this config with selected fields overridden.
  ConnectionConfig copyWith({
    String? driver,
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    bool? useSsl,
    int? poolSize,
    int? maxTotalConnections,
    Duration? connectionTimeout,
    Duration? idleTimeout,
  }) => ConnectionConfig(
    driver: driver ?? this.driver,
    host: host ?? this.host,
    port: port ?? this.port,
    database: database ?? this.database,
    username: username ?? this.username,
    password: password ?? this.password,
    useSsl: useSsl ?? this.useSsl,
    poolSize: poolSize ?? this.poolSize,
    maxTotalConnections: maxTotalConnections ?? this.maxTotalConnections,
    connectionTimeout: connectionTimeout ?? this.connectionTimeout,
    idleTimeout: idleTimeout ?? this.idleTimeout,
  );
}
