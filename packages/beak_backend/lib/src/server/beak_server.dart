import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../auth/auth_router.dart';
import '../auth/beak_auth_guard.dart';
import '../auth/beak_policy.dart';
import '../config/beak_backend_config.dart';
import '../endpoints/beak_resource_router.dart';
import '../service/beak_graph_commit_service.dart';
import '../service/beak_outbox.dart';
import 'middleware/auth_middleware.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/error_mapping_middleware.dart';
import 'middleware/json_middleware.dart';
import 'middleware/request_log_middleware.dart';

/// Receives the one-line warning a server prints at boot when it is exposed
/// beyond this machine without a policy.
typedef BeakBootWarningListener = void Function(String message);

/// The composed Beak backend: the full middleware stack (request log →
/// CORS → JSON → error mapping → auth → your [BeakServer.new] `middleware`)
/// around the resource router — by default the generated per-model API over
/// [registry] and [dataSource], with any project `routes` in front of it.
///
/// Over a `WormDataSource` graph commits are atomic transactions with durable
/// receipts. Any other `dataSource` serves the same API, but saves through
/// `POST /api/commits` are staged (the source's own CRUD calls in order, no
/// rollback, receipts in memory), and behavior, `preparePlan` and
/// `finalizePlan` are refused at construction.
///
/// A project rarely constructs one: `beak prepare` generates a
/// `BeakServeHost`, and `lib/server.dart` returns
/// `defaults.build(...)`, which calls this constructor with everything the
/// host resolved. Build one by hand to embed Beak in a process you own:
///
/// ```dart
/// final config = BeakBackendConfig.fromEnv();
/// final registry = buildBeakRegistry();
/// await initializeBeakDatabase(config);
/// final server = BeakServer(
///   config: config,
///   registry: registry,
///   dataSource: WormDataSource(registry, adapter: Worm.adapter()),
///   storage: resolveStorage(const BeakMemoryStorageConfig()),
/// );
/// final http = await server.start();
/// stderr.writeln('listening on http://${http.address.host}:${http.port}');
/// ```
final class BeakServer {
  /// Creates a server over [registry] and [dataSource], configured by
  /// [config].
  ///
  /// The generated API serves upload endpoints when [storage] is set (images
  /// go through [transformRunner], default the real `beak_image` runner), the
  /// auth surface when [authSessions] is, and gates every operation with
  /// [policy]. [router] replaces that API outright; [routes] adds endpoints in
  /// front of it instead — a project route wins over a generated one on the
  /// same path, and anything it does not match (a 404 or 405) falls through
  /// to the generated API.
  ///
  /// [middleware] runs inside the stack, after authentication and inside
  /// the error mapping, first listed outermost: it sees `beakPrincipal`, and
  /// the typed exceptions it throws become JSON responses. [corsOrigin] is
  /// the origin browsers may call from (default: any).
  ///
  /// [authGuard] resolves each request's principal. When it is omitted and
  /// [authSessions] is set, a [TokenSessionAuthGuard] over the sessions'
  /// store validates the tokens `/api/auth/login` issues.
  ///
  /// [maxPerPage] is the largest page a query is served (default 200); a
  /// larger request is answered at that size.
  ///
  /// [signedUrlLifetime] is how long the links the upload endpoint resolves
  /// stay valid on storage drivers that sign them (default: one hour).
  ///
  /// [preparePlan] and [finalizePlan] add transactional business rules to
  /// graph commits; [graphOnly] restricts those models to that write path.
  /// [now] and [generateId] are the clock and the id mint behind every write
  /// (defaults: [DateTime.now] and a v4 uuid). [outbox] is the delivery
  /// schedule `BeakServeHost.serve` runs while this server listens.
  ///
  /// [onRequest] receives one entry per request and [onUnexpectedError]
  /// every failure no typed exception describes, including the one a failing
  /// `/readyz` hides from its caller; both default to stderr. [onWarning]
  /// receives the single line [start] emits when the server listens beyond
  /// loopback with the default allow-all [policy] (default: stderr).
  BeakServer({
    required this.config,
    required this.dataSource,
    required this.registry,
    this.storage,
    BeakTransformRunner? transformRunner,
    Duration? signedUrlLifetime,
    int maxPerPage = BeakPagination.maxPerPage,
    BeakPolicy policy = const BeakAllowAllPolicy(),
    BeakAuthSessions? authSessions,
    Handler? router,
    Handler? routes,
    List<Middleware> middleware = const [],
    String corsOrigin = '*',
    BeakAuthGuard? authGuard,
    BeakRequestLogger? onRequest,
    BeakUnexpectedErrorListener? onUnexpectedError,
    BeakBootWarningListener? onWarning,
    BeakSavePlanPreparer? preparePlan,
    BeakSavePlanFinalizer? finalizePlan,
    List<BeakModel> graphOnly = const [],
    DateTime Function()? now,
    String Function()? generateId,
    this.outbox,
  }) : onUnexpectedError = onUnexpectedError ?? _reportToStderr,
       _policy = router == null ? policy : null,
       _onWarning = onWarning ?? _warnOnStderr,
       _router = _inFront(
         routes,
         router ??
             beakApiRouter(
               registry: registry,
               dataSource: dataSource,
               policy: policy,
               auth: authSessions,
               storage: storage,
               transformRunner: transformRunner,
               signedUrlLifetime: signedUrlLifetime,
               maxPerPage: maxPerPage,
               now: now,
               generateId: generateId,
               preparePlan: preparePlan,
               finalizePlan: finalizePlan,
               graphOnly: graphOnly,
               onUnexpectedError: onUnexpectedError ?? _reportToStderr,
             ),
       ),
       _middleware = List.unmodifiable(middleware),
       _corsOrigin = corsOrigin,
       _authGuard =
           authGuard ??
           switch (authSessions) {
             null => null,
             final BeakAuthSessions sessions => TokenSessionAuthGuard(
               sessions.store,
             ),
           },
       _onRequest = onRequest ?? _logToStderr;

  /// The validated runtime configuration.
  final BeakBackendConfig config;

  /// The data source handlers read and write through.
  final BeakDataSource dataSource;

  /// The models this server exposes.
  final BeakModelRegistry registry;

  /// The storage driver behind file columns, when uploads are configured.
  final BeakStorageDriver? storage;

  /// The outbox delivery schedule, or `null` when nothing drains the outbox.
  ///
  /// `BeakServeHost.serve` starts it once the socket is bound and stops it
  /// when that server closes. [start] alone does not: a process composing
  /// this server itself calls [BeakOutboxSchedule.start].
  final BeakOutboxSchedule? outbox;

  /// Receives every failure no typed exception describes.
  final BeakUnexpectedErrorListener onUnexpectedError;

  // The policy the generated API enforces, or null when `router:` replaced
  // that API and so no policy of this server's is in force.
  final BeakPolicy? _policy;
  final BeakBootWarningListener _onWarning;
  final Handler _router;
  final List<Middleware> _middleware;
  final String _corsOrigin;
  final BeakAuthGuard? _authGuard;
  final BeakRequestLogger _onRequest;

  /// The full request pipeline as a single Shelf [Handler]: the middleware
  /// stack (request log → CORS → JSON → error mapping → auth → the project's
  /// middleware) wrapped around the router, outermost first. Mount this
  /// directly to compose Beak inside a larger Shelf app instead of calling
  /// [start].
  // --8<-- [start:BeakServerHandler]
  late final Handler handler = _middleware
      .fold(
        const Pipeline()
            .addMiddleware(beakRequestLogMiddleware(onRequest: _onRequest))
            .addMiddleware(beakCorsMiddleware(allowedOrigin: _corsOrigin))
            .addMiddleware(beakJsonMiddleware())
            .addMiddleware(
              beakErrorMappingMiddleware(onUnexpectedError: onUnexpectedError),
            )
            .addMiddleware(beakAuthMiddleware(guard: _authGuard)),
        (Pipeline pipeline, Middleware next) => pipeline.addMiddleware(next),
      )
      .addHandler(_router);
  // --8<-- [end:BeakServerHandler]

  /// Binds [handler] on the configured host and port and starts serving.
  ///
  /// Returns the live [HttpServer]; close it to stop accepting connections.
  ///
  /// Emits one warning through `onWarning` once it is listening, when the
  /// server is bound beyond loopback and its policy is the allow-all default.
  ///
  /// Throws a [BeakConfigurationException] that names `PORT` (or `HOST`) when
  /// the address cannot be bound, a port already in use being the usual
  /// cause.
  Future<HttpServer> start() async {
    final HttpServer http;
    try {
      http = await shelf_io.serve(handler, config.host, config.port);
    } on SocketException catch (error) {
      throw BeakConfigurationException(_bindFailure(error));
    }
    _warnWhenWideOpen(http.port);
    return http;
  }

  void _warnWhenWideOpen(int boundPort) {
    final BeakPolicy? policy = _policy;
    final bool loopback =
        config.host == 'localhost' ||
        (InternetAddress.tryParse(config.host)?.isLoopback ?? false);
    if (loopback ||
        policy == null ||
        policy.runtimeType != BeakAllowAllPolicy) {
      return;
    }
    final String cors = _corsOrigin == '*' ? ' and CORS admits any origin' : '';
    _onWarning(
      'Beak is listening on ${config.host}:$boundPort with '
      'BeakAllowAllPolicy, so every route answers every caller$cors. '
      'Pass a BeakPolicy to defaults.build(policy: ...), or set '
      'HOST=127.0.0.1 to keep it on this machine.',
    );
  }

  String _bindFailure(SocketException error) {
    // EADDRINUSE: 98 on Linux, 48 on macOS, WSAEADDRINUSE 10048 on Windows.
    const addressInUse = {98, 48, 10048};
    if (addressInUse.contains(error.osError?.errorCode)) {
      return 'Port ${config.port} is already in use on ${config.host}. '
          'Stop the other process or choose another port with PORT '
          '(server.port in beak.yaml).';
    }
    return 'Cannot listen on ${config.host}:${config.port}: '
        '${error.osError?.message ?? error.message}. '
        'Check HOST and PORT (server.host and server.port in beak.yaml).';
  }

  /// [api] with [routes] tried first, when there are any.
  static Handler _inFront(Handler? routes, Handler api) => switch (routes) {
    null => api,
    final Handler project => Cascade().add(project).add(api).handler,
  };

  static void _logToStderr(BeakRequestLogEntry entry) => stderr.writeln(entry);

  static void _warnOnStderr(String message) =>
      stderr.writeln('warning: $message');

  static void _reportToStderr(Object error, StackTrace stackTrace) => stderr
    ..writeln(error)
    ..writeln(stackTrace);
}
