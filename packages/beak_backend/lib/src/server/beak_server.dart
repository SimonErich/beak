import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:beak_image/beak_image.dart';

import '../config/beak_backend_config.dart';
import '../data/beak_data_source.dart';
import '../endpoints/beak_resource_router.dart';
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
/// [storage] carries the configured storage driver for the upload
/// endpoints arriving in Phase 09.
final class BeakServer {
  /// Creates a server serving [router] (default: the generated API, with
  /// upload endpoints when [storage] is configured) with [config].
  ///
  /// [transformRunner] overrides the image pipeline (default: the real
  /// `beak_image` runner).
  BeakServer({
    required this.config,
    required this.dataSource,
    required this.registry,
    this.storage,
    BeakTransformRunner? transformRunner,
    Handler? router,
    BeakAuthGuard? authGuard,
    BeakRequestLogger? onRequest,
    BeakUnexpectedErrorListener? onUnexpectedError,
  }) : _router =
           router ??
           beakApiRouter(
             registry: registry,
             dataSource: dataSource,
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

  /// The composed Shelf handler.
  Handler get handler => const Pipeline()
      .addMiddleware(beakRequestLogMiddleware(onRequest: _onRequest))
      .addMiddleware(beakCorsMiddleware())
      .addMiddleware(beakJsonMiddleware())
      .addMiddleware(
        beakErrorMappingMiddleware(onUnexpectedError: _onUnexpectedError),
      )
      .addMiddleware(beakAuthMiddleware(guard: _authGuard))
      .addHandler(_router);

  /// Binds [handler] on the configured host and port.
  Future<HttpServer> start() =>
      shelf_io.serve(handler, config.host, config.port);

  static void _logToStderr(BeakRequestLogEntry entry) => stderr.writeln(entry);

  static void _reportToStderr(Object error, StackTrace stackTrace) => stderr
    ..writeln(error)
    ..writeln(stackTrace);
}
