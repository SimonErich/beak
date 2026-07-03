import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_router.dart';
import '../auth/beak_policy.dart';
import '../export/csv_export_service.dart';
import '../export/export_router.dart';
import '../search/global_search_service.dart';
import '../search/search_router.dart';
import '../service/beak_resource_service.dart';
import '../service/validation_service.dart';
import '../uploads/upload_router.dart';
import '../uploads/upload_service.dart';
import 'crud_handlers.dart';

/// The generated routes of one model's REST surface, relative to its mount
/// point (`/api/{table}`).
Router beakResourceRouter(
  BeakResourceService service, {
  BeakPolicy policy = const BeakAllowAllPolicy(),
}) {
  final handlers = BeakCrudHandlers(service, policy: policy);
  return Router()
    ..post('/query', handlers.query)
    ..post('/batch', handlers.batch)
    ..post('/', handlers.create)
    ..get('/<id>', handlers.getOne)
    ..patch('/<id>', handlers.update)
    ..delete('/<id>', handlers.delete)
    ..post('/<id>/relations/<relationKey>/attach', handlers.attach)
    ..post('/<id>/relations/<relationKey>/detach', handlers.detach);
}

/// The full generated API: one resource router per registered model
/// (mounted under `/api/{table}`, with CSV export), the global search
/// endpoint, the auth surface when [auth] is configured, and per-column
/// upload endpoints when [uploads] is — registering a model is all it
/// takes to get its surface, and every operation consults [policy].
///
/// [validation], [now], and [generateId] configure every model's service
/// (the latter two inject the clock and id mint for tests).
Handler beakApiRouter({
  required BeakModelRegistry registry,
  required BeakDataSource dataSource,
  ValidationService validation = const ValidationService(),
  BeakPolicy policy = const BeakAllowAllPolicy(),
  BeakAuthSessions? auth,
  UploadService? uploads,
  DateTime Function()? now,
  String Function()? generateId,
}) {
  final router = Router(
    notFoundHandler: (Request request) => throw BeakNotFoundException(
      'No handler for ${request.method} /${request.url.path}.',
    ),
  );
  if (auth != null) {
    router.mount('/api/auth', beakAuthRouter(auth).call);
  }
  final searchHandlers = BeakSearchHandlers(
    service: GlobalSearchService(registry, dataSource),
    policy: policy,
  );
  router.get('/api/search', searchHandlers.search);
  final exportService = CsvExportService(registry, dataSource);
  for (final model in registry.all) {
    final service = BeakResourceService(
      model,
      dataSource,
      validation: validation,
      now: now,
      generateId: generateId,
    );
    final resourceRouter = beakResourceRouter(service, policy: policy);
    registerExportRoutes(
      resourceRouter,
      model: model,
      service: exportService,
      policy: policy,
    );
    if (uploads != null) {
      registerUploadRoutes(
        resourceRouter,
        model: model,
        service: uploads,
        policy: policy,
      );
    }
    router.mount('/api/${model.table}', resourceRouter.call);
  }
  return router.call;
}
