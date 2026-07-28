import 'package:beak_core/beak_core.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/beak_policy.dart';
import 'upload_handler.dart';
import 'upload_service.dart';

/// Registers one model's upload surface on its resource [router]
/// (`POST`/`DELETE /api/{table}/{columnKey}/upload`), gated by [policy].
// --8<-- [start:registerUploadRoutes]
void registerUploadRoutes(
  Router router, {
  required BeakModel model,
  required UploadService service,
  BeakPolicy policy = const BeakAllowAllPolicy(),
}) {
  final handlers = BeakUploadHandlers(
    model: model,
    service: service,
    policy: policy,
  );
  router
    ..post('/<columnKey>/upload', handlers.upload)
    ..delete('/<columnKey>/upload', handlers.remove);
}

// --8<-- [end:registerUploadRoutes]
