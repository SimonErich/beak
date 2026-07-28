import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../../config/beak_backend_config.dart';

/// Maps a `DATABASE_URL` onto worm's Postgres connection config.
///
/// Accepts `postgres://` / `postgresql://` URLs with a host and database
/// name; the port defaults to 5432 and `?sslmode=require` enables TLS.
/// Throws a [BeakConfigurationException] for anything else.
ConnectionConfig postgresConnectionConfig(
  Uri databaseUrl, {
  int poolSize = 10,
}) {
  if (databaseUrl.scheme != 'postgres' && databaseUrl.scheme != 'postgresql') {
    throw BeakConfigurationException(
      'DATABASE_URL must use the postgres:// scheme, got '
      '"${databaseUrl.scheme}".',
    );
  }
  final String database = databaseUrl.pathSegments.isEmpty
      ? ''
      : databaseUrl.pathSegments.first;
  if (database.isEmpty) {
    throw const BeakConfigurationException(
      'DATABASE_URL is missing the database name '
      '(postgres://user:pass@host:5432/db).',
    );
  }
  String? username;
  String? password;
  final String userInfo = databaseUrl.userInfo;
  if (userInfo.isNotEmpty) {
    final int separatorIndex = userInfo.indexOf(':');
    username = Uri.decodeComponent(
      separatorIndex < 0 ? userInfo : userInfo.substring(0, separatorIndex),
    );
    password = separatorIndex < 0
        ? null
        : Uri.decodeComponent(userInfo.substring(separatorIndex + 1));
  }
  return ConnectionConfig(
    driver: 'postgres',
    host: databaseUrl.host,
    port: databaseUrl.hasPort ? databaseUrl.port : 5432,
    database: database,
    username: username,
    password: password,
    useSsl: databaseUrl.queryParameters['sslmode'] == 'require',
    poolSize: poolSize,
  );
}

/// Builds the adapter [databaseUrl] names: SQLite for a `sqlite:` URL,
/// Postgres otherwise.
///
/// The one place that maps a URL scheme to a driver, so `beak dev`, the
/// migration CLI and a hand-built server cannot disagree about what
/// `DATABASE_URL` means.
// --8<-- [start:adapterFromUrl]
DatabaseAdapter adapterFromUrl(Uri databaseUrl, {int poolSize = 10}) {
  if (isSqliteUrl(databaseUrl)) {
    final String? path = sqliteFilePathOf(databaseUrl);
    return path == null ? SqliteAdapter.memory() : SqliteAdapter.open(path);
  }
  return postgresAdapterFromUrl(databaseUrl, poolSize: poolSize);
}
// --8<-- [end:adapterFromUrl]

/// Builds a lazily connecting Postgres adapter from a `DATABASE_URL`.
///
/// The returned [PostgresAdapter] opens a pool of at most [poolSize]
/// connections on first use; hand it straight to a [WormDataSource].
///
/// ```dart
/// final adapter = postgresAdapterFromUrl(
///   Uri.parse('postgres://user:pass@localhost:5432/beak'),
/// );
/// final dataSource = WormDataSource(registry, adapter: adapter);
/// ```
PostgresAdapter postgresAdapterFromUrl(Uri databaseUrl, {int poolSize = 10}) =>
    PostgresAdapter(
      pool: PostgresConnectionPool.fromConfig(
        postgresConnectionConfig(databaseUrl, poolSize: poolSize),
      ),
    );

/// Initializes worm once at startup on the database [config] points at;
/// pair with `Worm.reset()` on shutdown.
///
/// Registers a single `'default'` adapter chosen by the URL scheme — SQLite
/// for `sqlite:`, Postgres otherwise. Call once before serving requests;
/// calling it twice without a [Worm.reset] in between throws.
///
/// ```dart
/// await initializeWormPostgres(config);
/// try {
///   await serve(handler, config.host, config.port);
/// } finally {
///   await Worm.reset();
/// }
/// ```
// --8<-- [start:initializeWormPostgres]
Future<void> initializeWormPostgres(BeakBackendConfig config) =>
    Worm.initialize(
      config: const WormConfig(),
      adapters: <String, DatabaseAdapter>{
        'default': adapterFromUrl(config.databaseUrl),
      },
    );

// --8<-- [end:initializeWormPostgres]
