import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:beak_image/beak_image.dart';

import '../auth/auth_router.dart';
import '../auth/beak_auth_guard.dart';
import '../auth/beak_policy.dart';
import '../config/beak_backend_config.dart';
import '../endpoints/beak_resource_router.dart';
import '../service/beak_graph_commit_service.dart';
import '../uploads/upload_service.dart';
import 'middleware/auth_middleware.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/error_mapping_middleware.dart';
import 'middleware/json_middleware.dart';
import 'middleware/request_log_middleware.dart';

/// The composed Beak backend: the full middleware stack (request log →
/// CORS → JSON → error mapping → auth) around the resource [router] — by
/// default the generated per-model CRUD surface over [registry] and
/// [dataSource].
///
/// [storage] carries the configured storage driver behind the generated
/// upload endpoints.
///
/// Construct it once at startup and call [start] to bind the socket:
///
/// ```dart
/// final config = BeakBackendConfig.fromEnv();
/// final registry = buildReferenceRegistry();
/// final server = BeakServer(
///   config: config,
///   registry: registry,
///   dataSource: WormDataSource(registry, adapter: adapter),
///   storage: resolveStorage(const BeakMemoryStorageConfig()),
///   policy: const BeakAllowAllPolicy(),
/// );
/// final http = await server.start();
/// print('Listening on http://${http.address.host}:${http.port}');
/// ```
final class BeakServer {
  /// Creates a server serving [router] (default: the generated API — with
  /// upload endpoints when [storage] is configured, the auth surface when
  /// [authSessions] is, and every operation gated by [policy]) with
  /// [config].
  ///
  /// [transformRunner] overrides the image pipeline (default: the real
  /// `beak_image` runner). [preparePlan] adds transactional business rules;
  /// [graphOnlyTables] restricts the selected resources to graph writes.
  BeakServer({
    required this.config,
    required this.dataSource,
    required this.registry,
    this.storage,
    BeakTransformRunner? transformRunner,
    BeakPolicy policy = const BeakAllowAllPolicy(),
    BeakAuthSessions? authSessions,
    Handler? router,
    BeakAuthGuard? authGuard,
    BeakRequestLogger? onRequest,
    BeakUnexpectedErrorListener? onUnexpectedError,
    BeakSavePlanPreparer? preparePlan,
    BeakSavePlanFinalizer? finalizePlan,
    Set<String> graphOnlyTables = const {},
  }) : _router =
           router ??
           beakApiRouter(
             registry: registry,
             dataSource: dataSource,
             policy: policy,
             preparePlan: preparePlan,
             finalizePlan: finalizePlan,
             graphOnlyTables: graphOnlyTables,
             auth: authSessions,
             storage: storage,
             uploads: storage == null
                 ? null
                 : UploadService(
                     registry: registry,
                     storage: storage,
                     transformRunner:
                         transformRunner ?? const ImageTransformRunner(),
                   ),
           ),
       _authGuard = authGuard,
       _onRequest = onRequest ?? _logToStderr,
       _onUnexpectedError = onUnexpectedError ?? _reportToStderr;

  /// The validated runtime configuration.
  final BeakBackendConfig config;

  /// The data source handlers read and write through.
  final BeakDataSource dataSource;

  /// The models this server exposes.
  final BeakModelRegistry registry;

  /// The storage driver behind file columns, when uploads are configured.
  final BeakStorageDriver? storage;

  final Handler _router;
  final BeakAuthGuard? _authGuard;
  final BeakRequestLogger _onRequest;
  final BeakUnexpectedErrorListener _onUnexpectedError;

  /// The full request pipeline as a single Shelf [Handler]: the middleware
  /// stack (request log → CORS → JSON → error mapping → auth) wrapped around
  /// the resource router, outermost first. Mount this directly to compose
  /// Beak inside a larger Shelf app instead of calling [start].
  Handler get handler => const Pipeline()
      .addMiddleware(beakRequestLogMiddleware(onRequest: _onRequest))
      .addMiddleware(beakCorsMiddleware())
      .addMiddleware(beakJsonMiddleware())
      .addMiddleware(
        beakErrorMappingMiddleware(onUnexpectedError: _onUnexpectedError),
      )
      .addMiddleware(beakAuthMiddleware(guard: _authGuard))
      .addHandler(_router);

  /// Binds [handler] on the configured host and port and starts serving.
  ///
  /// Returns the live [HttpServer]; close it to stop accepting connections.
  Future<HttpServer> start() =>
      shelf_io.serve(handler, config.host, config.port);

  static void _logToStderr(BeakRequestLogEntry entry) => stderr.writeln(entry);

  static void _reportToStderr(Object error, StackTrace stackTrace) => stderr
    ..writeln(error)
    ..writeln(stackTrace);
}
