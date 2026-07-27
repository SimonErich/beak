import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import '../auth/auth_router.dart';
import '../auth/beak_auth_guard.dart';
import '../auth/beak_policy.dart';
import '../config/beak_backend_config.dart';
import '../config/env_loader.dart';
import '../data/worm/worm_bootstrap.dart';
import '../data/worm/worm_data_source.dart';
import 'beak_server.dart';
import 'beak_storage_settings.dart';
import 'middleware/error_mapping_middleware.dart';
import 'middleware/request_log_middleware.dart';
import 'storage_wiring.dart';

/// Builds the server once its dependencies are resolved, so a project can
/// add middleware, routes or a [BeakPolicy] without giving up the wiring.
typedef BeakServerCustomizer = BeakServer Function(BeakServerDefaults defaults);

/// Everything [BeakServeHost] resolved, handed to a [BeakServerCustomizer].
///
/// Call [build] for the standard server, or read the parts and construct a
/// [BeakServer] yourself.
final class BeakServerDefaults {
  /// Creates the resolved defaults.
  const BeakServerDefaults({
    required this.config,
    required this.registry,
    required this.dataSource,
    required this.environment,
    this.storage,
  });

  /// Host, port and database URL, resolved from the environment.
  final BeakBackendConfig config;

  /// Every model the project registered.
  final BeakModelRegistry registry;

  /// The data source the server reads and writes through.
  final BeakDataSource dataSource;

  /// The resolved upload driver, or `null` when uploads are disabled.
  final BeakStorageDriver? storage;

  /// The environment the host resolved, `.env` included.
  ///
  /// Read app-specific settings from here rather than [Platform.environment]:
  /// a test that injects an environment into [BeakServeHost] injects it into
  /// the policy and the auth configuration too.
  ///
  /// ```dart
  /// final secret = defaults.environment['AUTH_SECRET'] ?? 'dev-secret';
  /// ```
  final Map<String, String> environment;

  /// The server Beak would have built.
  ///
  /// Pass the arguments you want to change; everything else comes from the
  /// resolved defaults.
  BeakServer build({
    BeakPolicy policy = const BeakAllowAllPolicy(),
    BeakAuthSessions? authSessions,
    BeakAuthGuard? authGuard,
    BeakRequestLogger? onRequest,
    BeakUnexpectedErrorListener? onUnexpectedError,
  }) => BeakServer(
    config: config,
    registry: registry,
    dataSource: dataSource,
    storage: storage,
    policy: policy,
    authSessions: authSessions,
    authGuard: authGuard,
    onRequest: onRequest,
    onUnexpectedError: onUnexpectedError,
  );
}

/// Owns a Beak backend's whole lifecycle: environment to typed config to
/// database adapter to registry to running server — plus the migration and
/// seeding CLI over the same wiring.
///
/// This exists because every Beak project used to hand-write the same ~180
/// lines: a storage-driver switch, a `buildXServer` function, a
/// `bin/server.dart`, and a `bin/worm.dart`. Both demo apps' copies differed
/// only in identifiers. Declare the parts that are actually yours — the
/// models, the migrations, the seeders — and Beak does the rest:
///
/// ```dart
/// // bin/server.dart
/// Future<void> main() => acmeHost().serve();
///
/// // bin/migrate.dart
/// Future<void> main(List<String> args) async =>
///     exit(await acmeHost().runCli(args));
///
/// BeakServeHost acmeHost() => BeakServeHost(
///   registry: buildAcmeRegistry(),
///   migrations: acmeMigrations,
///   seeders: const [AcmeSeeder()],
///   storageRegistry: () => createDefaultStorageRegistry()..registerS3(),
/// );
/// ```
final class BeakServeHost {
  /// Creates a host over [registry], with optional [migrations], [seeders],
  /// and a [storageRegistry] contributing plug-in upload drivers.
  ///
  /// [configure] receives the resolved [BeakServerDefaults] and returns the
  /// server to serve, for projects that add middleware, extra routes or a
  /// policy. [environment] and [now] are injected seams for tests.
  BeakServeHost({
    required this.registry,
    this.migrations = const [],
    this.seeders = const [],
    this.storageRegistry,
    this.configure,
    Map<String, String>? environment,
    DateTime Function()? now,
  }) : _environment = environment ?? BeakEnv.resolve(),
       _now = now ?? DateTime.now;

  /// Every model this backend serves.
  final BeakModelRegistry registry;

  /// Migrations the CLI applies, in order.
  final List<Migration> migrations;

  /// Seeders the CLI can run.
  final List<Seeder> seeders;

  /// Builds the storage registry, for projects using a plug-in driver.
  ///
  /// `beak_backend` depends on no driver package, so an app uploading to S3
  /// supplies `() => createDefaultStorageRegistry()..registerS3Storage(...)`.
  /// Defaults to the in-box `memory` and `local` drivers.
  final BeakStorageRegistry Function()? storageRegistry;

  /// Hook to customise the server before it is served.
  final BeakServerCustomizer? configure;

  final Map<String, String> _environment;
  final DateTime Function() _now;

  /// The backend configuration this host resolved from the environment.
  late final BeakBackendConfig config = BeakBackendConfig.fromEnv(
    environment: _environment,
  );

  /// The upload driver the environment selects, or `null` when uploads are
  /// disabled.
  ///
  /// Throws a [BeakConfigurationException] when a driver is selected but not
  /// registered — a missing `registerS3Storage` fails at boot, by name.
  BeakStorageDriver? resolveStorageDriver() {
    final BeakStorageConfig? storageConfig = BeakStorageSettings.fromEnv(
      _environment,
    );
    if (storageConfig == null) {
      return null;
    }
    return resolveStorage(
      storageConfig,
      registry: storageRegistry?.call() ?? createDefaultStorageRegistry(),
    );
  }

  /// Builds the server over [adapter] without binding a port — the test seam.
  ///
  /// ```dart
  /// final server = host.buildServer(adapter: InMemoryAdapter());
  /// final response = await server.handler(request);
  /// ```
  BeakServer buildServer({
    required DatabaseAdapter adapter,
    BeakStorageDriver? storage,
  }) {
    final defaults = BeakServerDefaults(
      config: config,
      registry: registry,
      dataSource: WormDataSource(registry, adapter: adapter, now: _now),
      environment: _environment,
      storage: storage,
    );
    return configure?.call(defaults) ?? defaults.build();
  }

  /// Connects worm, builds the server, and binds the HTTP listener.
  ///
  /// Returns the bound [HttpServer] so a caller can log its address or close
  /// it; the process keeps serving until it does.
  Future<HttpServer> serve() async {
    await initializeWormPostgres(config);
    final server = buildServer(
      adapter: Worm.adapter(),
      storage: resolveStorageDriver(),
    );
    return server.start();
  }

  /// Runs the worm CLI (`migrate`, `db:seed`, `migrate:fresh`, …) against this
  /// host's [migrations] and [seeders], returning the process exit code.
  ///
  /// Replaces the hand-written `bin/worm.dart` every project used to carry.
  Future<int> runCli(
    List<String> args, {
    StringSink? out,
    StringSink? err,
  }) async {
    final context = CliContext(
      out: out ?? stdout,
      err: err ?? stderr,
      projectRoot: Directory.current,
      environment: Worm.environment,
      now: _now,
      adapterFactory: () async {
        final adapter = adapterFromUrl(config.databaseUrl);
        await adapter.connect();
        return adapter;
      },
      migrations: migrations,
      seeders: seeders,
    );
    return await WormCommandRunner(context).run(args) ?? 0;
  }
}
