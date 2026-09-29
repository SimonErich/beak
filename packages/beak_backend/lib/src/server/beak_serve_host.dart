import 'dart:async';
import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';
import 'package:shelf/shelf.dart';
import 'package:worm/worm.dart';

import '../auth/auth_router.dart';
import '../auth/beak_auth_guard.dart';
import '../auth/beak_policy.dart';
import '../config/beak_backend_config.dart';
import '../config/env_loader.dart';
import '../data/worm/worm_bootstrap.dart';
import '../data/worm/worm_data_source.dart';
import '../service/beak_graph_commit_service.dart';
import '../service/beak_outbox.dart';
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
  ///
  /// [now] is the host's clock, which [build] hands to every write path.
  const BeakServerDefaults({
    required this.config,
    required this.registry,
    required this.dataSource,
    required this.environment,
    this.storage,
    this.now,
  });

  /// Host, port and database URL, resolved from the environment.
  final BeakBackendConfig config;

  /// Every model the project registered.
  final BeakModelRegistry registry;

  /// The data source the server reads and writes through.
  ///
  /// Its [WormDataSource.adapter] is the database connection itself, which an
  /// outbox provider writing its own receipts needs:
  ///
  /// ```dart
  /// outbox: MailEffects().schedule(defaults.dataSource.adapter),
  /// ```
  final WormDataSource dataSource;

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

  /// The host's clock, or `null` for [DateTime.now].
  final DateTime Function()? now;

  /// The server Beak would have built.
  ///
  /// Pass the arguments you want to change; everything else comes from the
  /// resolved defaults. Each one is documented on [BeakServer.new]:
  /// [middleware] and [routes] extend the generated API, [corsOrigin] names
  /// the origin browsers may call from, [preparePlan] adds transactional
  /// business rules and [graphOnly] closes the per-record routes that could
  /// bypass them, [outbox] schedules effect delivery while the host serves,
  /// and [generateId] and [transformRunner] replace the id mint and the image
  /// pipeline.
  BeakServer build({
    BeakPolicy policy = const BeakAllowAllPolicy(),
    BeakAuthSessions? authSessions,
    BeakAuthGuard? authGuard,
    List<Middleware> middleware = const [],
    Handler? routes,
    String corsOrigin = '*',
    BeakRequestLogger? onRequest,
    BeakUnexpectedErrorListener? onUnexpectedError,
    BeakSavePlanPreparer? preparePlan,
    BeakSavePlanFinalizer? finalizePlan,
    List<BeakModel> graphOnly = const [],
    BeakOutboxSchedule? outbox,
    String Function()? generateId,
    BeakTransformRunner? transformRunner,
  }) => BeakServer(
    config: config,
    registry: registry,
    dataSource: dataSource,
    storage: storage,
    policy: policy,
    authSessions: authSessions,
    authGuard: authGuard,
    middleware: middleware,
    routes: routes,
    corsOrigin: corsOrigin,
    onRequest: onRequest,
    onUnexpectedError: onUnexpectedError,
    preparePlan: preparePlan,
    finalizePlan: finalizePlan,
    graphOnly: graphOnly,
    outbox: outbox,
    now: now,
    generateId: generateId,
    transformRunner: transformRunner,
  );
}

/// Owns a Beak backend's whole lifecycle: environment to typed config to
/// database adapter to registry to running server — plus the migration and
/// seeding CLI over the same wiring.
///
/// A project does not write one: `beak prepare` emits `beakHost()` into
/// `lib/beak/server.g.dart` with every discovered model, migration and
/// seeder, and the generated `bin/serve.dart` and `bin/migrate.dart` call it.
/// The project's own part is `lib/server.dart`, which the host hands its
/// resolved [BeakServerDefaults]:
///
/// ```dart
/// // lib/server.dart
/// import 'package:beak/server.dart';
///
/// BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
///   policy: const ShopPolicy(),
///   middleware: [rateLimit()],
/// );
///
/// // bin/serve.dart (generated)
/// Future<void> main() async {
///   final HttpServer server = await beakHost().serve();
///   stderr.writeln('listening on http://${server.address.host}:${server.port}');
/// }
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

  /// Migrations the CLI applies, in order, and [serve] applies itself to an
  /// in-memory database.
  final List<Migration> migrations;

  /// Seeders the CLI can run, and [serve] runs itself on an in-memory
  /// database.
  final List<Seeder> seeders;

  /// Builds the storage registry, for projects using a plug-in driver.
  ///
  /// `beak_backend` depends on no driver package, so an app uploading to S3
  /// registers the driver on the default registry itself:
  ///
  /// ```dart
  /// storageRegistry: () {
  ///   final registry = createDefaultStorageRegistry();
  ///   registerS3Storage(registry);
  ///   return registry;
  /// },
  /// ```
  ///
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

  /// The host a stored file's URL should name.
  ///
  /// `0.0.0.0` is a bind address, not somewhere a browser can go, so a URL
  /// built from it would be handed out and then fail to load.
  String get _reachableHost =>
      config.host == '0.0.0.0' ? 'localhost' : config.host;

  /// Where uploads land by default: a directory beside the project, served
  /// by this server.
  static const String defaultUploadDir = 'storage/uploads';

  /// The path the default upload driver serves its files under.
  static const String defaultUploadPath = '/uploads';

  /// The upload driver the environment selects.
  ///
  /// With nothing configured this is local disk under [defaultUploadDir],
  /// served by this server at [defaultUploadPath] — the same posture as the
  /// database, which is a SQLite file until `DATABASE_URL` says otherwise. An
  /// upload column works on a fresh project with no setup, and a deployment
  /// changes it with one variable.
  ///
  /// `BEAK_STORAGE_DRIVER=none` returns `null`, which turns the upload
  /// endpoints off outright.
  ///
  /// Throws a [BeakConfigurationException] when a driver is selected but not
  /// registered — a missing `registerS3Storage` fails at boot, by name.
  // --8<-- [start:resolveStorageDriver]
  BeakStorageDriver? resolveStorageDriver() {
    final BeakStorageConfig? storageConfig = BeakStorageSettings.fromEnv(
      _environment,
    );
    if (storageConfig == null) {
      return _environment[BeakStorageSettings.driverKey] == 'none'
          ? null
          : BeakLocalDiskStorageDriver(
              rootDir: defaultUploadDir,
              publicBaseUrl: Uri.parse(
                'http://$_reachableHost:${config.port}$defaultUploadPath',
              ),
            );
    }
    return resolveStorage(
      storageConfig,
      registry: storageRegistry?.call() ?? createDefaultStorageRegistry(),
    );
  }
  // --8<-- [end:resolveStorageDriver]

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
      now: _now,
    );
    return configure?.call(defaults) ?? defaults.build();
  }

  /// Connects the database, builds the server, and binds the HTTP listener.
  ///
  /// An in-memory database (`sqlite::memory:`) lives and dies with this
  /// process, so `beak migrate` — another process — cannot prepare it. For
  /// one, [serve] applies [migrations] and runs [seeders] itself before it
  /// listens. Every other database is migrated explicitly and never on boot.
  ///
  /// When the configured server carries a [BeakServer.outbox] schedule, it is
  /// validated before the socket is bound, so a misconfigured one fails the
  /// boot without serving a request. Its drain loop starts once the socket is
  /// bound and stops when the returned server is closed, after the drain in
  /// flight finishes. Drain failures go to [BeakServer.onUnexpectedError].
  ///
  /// Returns the bound [HttpServer] so a caller can log its address or close
  /// it; the process keeps serving until it does.
  Future<HttpServer> serve() async {
    await initializeBeakDatabase(config);
    final DatabaseAdapter adapter = Worm.adapter();
    if (isSqliteUrl(config.databaseUrl) &&
        sqliteFilePathOf(config.databaseUrl) == null) {
      await MigrationRunner(adapter: adapter, migrations: migrations).migrate();
      await SeederRunner(
        adapter: adapter,
        seeders: seeders,
        environment: Worm.environment,
      ).run();
    }
    final server = buildServer(
      adapter: adapter,
      storage: resolveStorageDriver(),
    );
    final BeakOutboxSchedule? outbox = server.outbox?..validate();
    final HttpServer http = await server.start();
    if (outbox == null) {
      return http;
    }
    return _OutboxServingHttpServer(
      http,
      outbox.start(adapter, onError: server.onUnexpectedError, now: _now),
    );
  }

  /// Runs the worm CLI (`migrate`, `db:seed`, `migrate:fresh`, …) against this
  /// host's [migrations] and [seeders], returning the process exit code.
  ///
  /// The generated `bin/migrate.dart` is a one-line call to this.
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

/// The listener [BeakServeHost.serve] returns while an outbox schedule runs:
/// the bound server itself, except that closing it also stops the schedule.
final class _OutboxServingHttpServer extends StreamView<HttpRequest>
    implements HttpServer {
  _OutboxServingHttpServer(this._server, this._outbox) : super(_server);

  final HttpServer _server;
  final BeakOutboxLoop _outbox;

  @override
  Future<void> close({bool force = false}) async {
    await _server.close(force: force);
    await _outbox.stop();
  }

  @override
  InternetAddress get address => _server.address;

  @override
  int get port => _server.port;

  @override
  bool get autoCompress => _server.autoCompress;

  @override
  set autoCompress(bool value) => _server.autoCompress = value;

  @override
  Duration? get idleTimeout => _server.idleTimeout;

  @override
  set idleTimeout(Duration? value) => _server.idleTimeout = value;

  @override
  String? get serverHeader => _server.serverHeader;

  @override
  set serverHeader(String? value) => _server.serverHeader = value;

  @override
  set sessionTimeout(int timeoutInSeconds) =>
      _server.sessionTimeout = timeoutInSeconds;

  @override
  HttpHeaders get defaultResponseHeaders => _server.defaultResponseHeaders;

  @override
  HttpConnectionsInfo connectionsInfo() => _server.connectionsInfo();
}
