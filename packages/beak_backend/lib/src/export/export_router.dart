import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/beak_policy.dart';
import '../auth/beak_field_policy.dart';
import '../auth/beak_query_authorizer.dart';
import '../server/middleware/auth_middleware.dart';
import '../server/middleware/json_middleware.dart';
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
  // --8<-- [start:export]
  Future<Response> export(Request request) async {
    enforcePolicyDecision(
      allowed: policy.canView(beakPrincipal(request), model),
      principal: beakPrincipal(request),
      action: 'export',
      model: model,
    );
    final body = await readJsonObject(request);
    final spec = readBeakSpec(body, BeakQuerySpec.fromJson);
    final columns = switch (body['columns']) {
      null => null,
      final List<Object?> values
          when values.every((value) => value is String) =>
        values.cast<String>(),
      _ => throw const BeakValidationException(
        'Export columns must be a list of field names.',
      ),
    };
    final raw = switch (body['raw']) {
      null => false,
      final bool value => value,
      _ => throw const BeakValidationException('Export raw must be a boolean.'),
    };
    final BeakFormatPolicy? formatting;
    final formats = <String, BeakExportFormat>{};
    try {
      if (body['formats'] case final Object value) {
        final Map<String, Object?> fields = switch (value) {
          final Map<String, Object?> map => map,
          _ => throw const FormatException(
            'Export field formats must be an object.',
          ),
        };
        for (final MapEntry(:key, :value) in fields.entries) {
          formats[key] = switch (value) {
            final Map<String, Object?> format => BeakExportFormat.fromJson(
              format,
            ),
            _ => throw const FormatException(
              'Export field format must be an object.',
            ),
          };
        }
      }
      formatting = switch (body['formatting']) {
        null => null,
        final Map<String, Object?> value => BeakFormatPolicy.fromJson(value),
        _ => throw const FormatException(
          'Export formatting must be an object.',
        ),
      };
    } on FormatException catch (error) {
      throw BeakValidationException(
        'Malformed export formatting: ${error.message}',
      );
    }
    // Export is a query that returns a file. A row scope that held for
    // `/query` but not here would be the easiest bypass in the API.
    return Response.ok(
      await service.exportCsv(
        model.table,
        BeakQueryAuthorizer(
          registry: service.registry,
          policy: policy,
          principal: beakPrincipal(request),
        ).authorizeQuery(spec),
        formatting: formatting,
        columns: columns,
        formats: formats,
        raw: raw,
        canRead: (column) => BeakFieldAccess(
          registry: service.registry,
          policy: policy,
          principal: beakPrincipal(request),
        ).canReadColumn(model, column),
      ),
      headers: {
        'content-type': 'text/csv; charset=utf-8',
        'content-disposition': 'attachment; filename="${model.table}.csv"',
      },
    );
  }

  // --8<-- [end:export]
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
