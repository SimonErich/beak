import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';

import '../auth/beak_policy.dart';
import '../server/middleware/auth_middleware.dart';
import '../server/middleware/json_middleware.dart';
import '../service/beak_resource_service.dart';

/// The thin Shelf handlers behind one model's generated REST surface: they
/// consult the [policy], parse requests into typed records/specs, call the
/// service, and encode typed results — all logic and validation lives
/// below, all error mapping above.
final class BeakCrudHandlers {
  /// Creates handlers delegating to [service], gated by [policy].
  const BeakCrudHandlers(
    this.service, {
    this.policy = const BeakAllowAllPolicy(),
  });

  /// The per-model service the handlers delegate to.
  final BeakResourceService service;

  /// The authorization gate consulted before every operation.
  final BeakPolicy policy;

  /// `POST /query` — runs a posted [BeakQuerySpec].
  Future<Response> query(Request request) async {
    _requireView(request);
    final spec = BeakQuerySpec.fromJson(await readJsonObject(request));
    final page = await service.query(spec);
    return _json(200, page.toJson((record) => record.toJson()));
  }

  /// `GET /<id>` — fetches one record.
  Future<Response> getOne(Request request, String id) async {
    _requireView(request);
    final record = await service.getOne(_coerceId(id));
    return _json(200, record.toJson());
  }

  /// `POST /` — creates a record from flat field values.
  Future<Response> create(Request request) async {
    _require(
      request,
      policy.canCreate(beakPrincipal(request), service.model.table),
      'create',
    );
    final record = await _readRecord(request);
    final created = await service.create(record);
    return _json(201, created.toJson());
  }

  /// `PATCH /<id>` — partially updates a record.
  Future<Response> update(Request request, String id) async {
    final Object recordId = _coerceId(id);
    _require(
      request,
      policy.canUpdate(beakPrincipal(request), service.model.table, recordId),
      'update',
    );
    final record = await _readRecord(request);
    final updated = await service.update(recordId, record);
    return _json(200, updated.toJson());
  }

  /// `DELETE /<id>?force=` — soft-deletes (or force-deletes) a record.
  Future<Response> delete(Request request, String id) async {
    final Object recordId = _coerceId(id);
    _require(
      request,
      policy.canDelete(beakPrincipal(request), service.model.table, recordId),
      'delete',
    );
    final force = request.url.queryParameters['force'] == 'true';
    await service.delete(recordId, force: force);
    return Response(204);
  }

  /// `POST /batch` — fetches the records named by `{"ids": [...]}` in one
  /// query.
  Future<Response> batch(Request request) async {
    _requireView(request);
    final records = await service.batchGet(await _readIds(request));
    return _json(200, [for (final record in records) record.toJson()]);
  }

  /// `POST /<id>/relations/<relationKey>/attach` — links related ids.
  Future<Response> attach(
    Request request,
    String id,
    String relationKey,
  ) async {
    final Object recordId = _coerceId(id);
    _require(
      request,
      policy.canUpdate(beakPrincipal(request), service.model.table, recordId),
      'update',
    );
    await service.attach(recordId, relationKey, await _readIds(request));
    return Response(204);
  }

  /// `POST /<id>/relations/<relationKey>/detach` — unlinks related ids.
  Future<Response> detach(
    Request request,
    String id,
    String relationKey,
  ) async {
    final Object recordId = _coerceId(id);
    _require(
      request,
      policy.canUpdate(beakPrincipal(request), service.model.table, recordId),
      'update',
    );
    await service.detach(recordId, relationKey, await _readIds(request));
    return Response(204);
  }

  void _requireView(Request request) => _require(
    request,
    policy.canView(beakPrincipal(request), service.model.table),
    'view',
  );

  void _require(Request request, bool allowed, String action) =>
      enforcePolicyDecision(
        allowed: allowed,
        principal: beakPrincipal(request),
        action: action,
        table: service.model.table,
      );

  /// Parses a flat `{column: value}` body into a typed record; malformed
  /// values are user errors (422), never internal ones.
  Future<BeakRecord> _readRecord(Request request) async {
    final body = await readJsonObject(request);
    try {
      return BeakRecord(
        values: {
          for (final MapEntry(:key, :value) in body.entries)
            key: BeakValue.fromJson(value),
        },
      );
    } on BeakConfigurationException catch (exception) {
      throw BeakValidationException(
        'Malformed record body: ${exception.message}',
      );
    }
  }

  Future<List<Object>> _readIds(Request request) async {
    final body = await readJsonObject(request);
    return switch (body['ids']) {
      final List<Object?> raw => [
        for (final id in raw)
          switch (id) {
            final int value => value,
            final String value => value,
            final Object? other => throw BeakValidationException(
              'Ids must be integers or strings, got $other.',
            ),
          },
      ],
      final Object? other => throw BeakValidationException(
        'Request body must carry an "ids" list, got $other.',
      ),
    };
  }

  /// Coerces the path id segment to the model's primary-key type.
  Object _coerceId(String raw) {
    if (service.model.primaryKey is BeakIntColumn) {
      return int.tryParse(raw) ??
          (throw BeakNotFoundException(
            'No record of "${service.model.table}" with id "$raw".',
          ));
    }
    return raw;
  }

  Response _json(int statusCode, Object body) =>
      Response(statusCode, body: jsonEncode(body));
}
