import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../data/beak_data_source.dart';
import '../service/beak_resource_service.dart';
import '../service/validation_service.dart';
import '../uploads/upload_router.dart';
import '../uploads/upload_service.dart';
import 'crud_handlers.dart';

/// The generated routes of one model's REST surface, relative to its mount
/// point (`/api/{table}`).
Router beakResourceRouter(BeakResourceService service) {
  final handlers = BeakCrudHandlers(service);
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

/// The full generated API: one resource router per registered model,
/// mounted under `/api/{table}` — registering a model is all it takes to
/// get its CRUD surface, and configuring [uploads] adds the per-column
/// upload endpoints alongside it.
///
/// [validation], [now], and [generateId] configure every model's service
/// (the latter two inject the clock and id mint for tests).
Handler beakApiRouter({
  required BeakModelRegistry registry,
  required BeakDataSource dataSource,
  ValidationService validation = const ValidationService(),
  UploadService? uploads,
  DateTime Function()? now,
  String Function()? generateId,
}) {
  final router = Router(
    notFoundHandler: (Request request) => throw BeakNotFoundException(
      'No handler for ${request.method} /${request.url.path}.',
    ),
  );
  for (final model in registry.all) {
    final service = BeakResourceService(
      model,
      dataSource,
      validation: validation,
      now: now,
      generateId: generateId,
    );
    final resourceRouter = beakResourceRouter(service);
    if (uploads != null) {
      registerUploadRoutes(resourceRouter, model: model, service: uploads);
    }
    router.mount('/api/${model.table}', resourceRouter.call);
  }
  return router.call;
}
