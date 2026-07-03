import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

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

/// Builds a lazily connecting Postgres adapter from a `DATABASE_URL`.
PostgresAdapter postgresAdapterFromUrl(Uri databaseUrl, {int poolSize = 10}) =>
    PostgresAdapter(
      pool: PostgresConnectionPool.fromConfig(
        postgresConnectionConfig(databaseUrl, poolSize: poolSize),
      ),
    );

/// Initializes worm once at startup on the Postgres database [config]
/// points at; pair with `Worm.reset()` on shutdown.
Future<void> initializeWormPostgres(BeakBackendConfig config) =>
    Worm.initialize(
      config: const WormConfig(),
      adapters: <String, DatabaseAdapter>{
        'default': postgresAdapterFromUrl(config.databaseUrl),
      },
    );
