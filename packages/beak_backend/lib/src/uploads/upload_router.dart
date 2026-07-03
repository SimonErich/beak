import 'package:beak_core/beak_core.dart';
import 'package:shelf_router/shelf_router.dart';

import 'upload_handler.dart';
import 'upload_service.dart';

/// Registers one model's upload surface on its resource [router]
/// (`POST`/`DELETE /api/{table}/{columnKey}/upload`).
void registerUploadRoutes(
  Router router, {
  required BeakModel model,
  required UploadService service,
}) {
  final handlers = BeakUploadHandlers(model: model, service: service);
  router
    ..post('/<columnKey>/upload', handlers.upload)
    ..delete('/<columnKey>/upload', handlers.remove);
}
