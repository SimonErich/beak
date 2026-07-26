import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/beak_policy.dart';
import '../server/middleware/auth_middleware.dart';
import '../server/middleware/json_middleware.dart';
import '../service/beak_resource_service.dart';
import 'csv_export_service.dart';

/// The thin handler behind one model's `POST /export`: policy check, spec
/// parse, and a streamed CSV attachment.
final class BeakExportHandlers {
  /// Creates export handlers for [model] over [service], gated by
  /// [policy].
  const BeakExportHandlers({
    required this.model,
    required this.service,
    this.policy = const BeakAllowAllPolicy(),
  });

  /// The model this handler exports.
  final BeakModel model;

  /// The CSV engine.
  final CsvExportService service;

  /// The visibility gate.
  final BeakPolicy policy;

  /// `POST /export` — body: a `BeakQuerySpec` for this model.
  Future<Response> export(Request request) async {
    enforcePolicyDecision(
      allowed: policy.canView(beakPrincipal(request), model.table),
      principal: beakPrincipal(request),
      action: 'export',
      table: model.table,
    );
    final spec = readBeakSpec(
      await readJsonObject(request),
      BeakQuerySpec.fromJson,
    );
    // Export is a query that returns a file. A row scope that held for
    // `/query` but not here would be the easiest bypass in the API.
    return Response.ok(
      await service.exportCsv(
        model.table,
        BeakResourceService.scopedQuery(
          spec,
          beakRowScope(policy, beakPrincipal(request), model.table),
        ),
      ),
      headers: {
        'content-type': 'text/csv; charset=utf-8',
        'content-disposition': 'attachment; filename="${model.table}.csv"',
      },
    );
  }
}

/// Registers one model's export surface on its resource [router].
void registerExportRoutes(
  Router router, {
  required BeakModel model,
  required CsvExportService service,
  required BeakPolicy policy,
}) {
  final handlers = BeakExportHandlers(
    model: model,
    service: service,
    policy: policy,
  );
  router.post('/export', handlers.export);
}
