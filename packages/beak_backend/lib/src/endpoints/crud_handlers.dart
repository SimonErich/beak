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
///
/// [beakResourceRouter] constructs and mounts these onto the model's routes;
/// wire them by hand only for a bespoke router.
///
/// ```dart
/// final handlers = BeakCrudHandlers(service, policy: policy);
/// final router = Router()
///   ..post('/query', handlers.query)
///   ..get('/<id>', handlers.getOne);
/// ```
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

  /// The row scope [policy] applies to this model for [request]'s principal.
  ///
  /// Read once per handler and handed to the service, which is where it is
  /// enforced — a handler that forgot to pass it would be a hole, so no
  /// handler decides whether to.
  BeakFilter? _scope(Request request) =>
      beakRowScope(policy, beakPrincipal(request), service.model.table);

  /// `POST /query` — runs a posted [BeakQuerySpec].
  // --8<-- [start:query]
  Future<Response> query(Request request) async {
    _requireView(request);
    final spec = readBeakSpec(
      await readJsonObject(request),
      BeakQuerySpec.fromJson,
    );
    final page = await service.query(spec, scope: _scope(request));
    return _json(200, page.toJson((record) => record.toJson()));
  }
  // --8<-- [end:query]

  /// `POST /aggregate` — computes a posted [BeakAggregateSpec].
  // --8<-- [start:aggregate]
  Future<Response> aggregate(Request request) async {
    _requireView(request);
    final spec = readBeakSpec(
      await readJsonObject(request),
      BeakAggregateSpec.fromJson,
    );
    final num value = await service.aggregate(spec, scope: _scope(request));
    return _json(200, {'value': value});
  }
  // --8<-- [end:aggregate]

  /// `GET /<id>` — fetches one record.
  // --8<-- [start:getOne]
  Future<Response> getOne(Request request, String id) async {
    _requireView(request);
    final record = await service.getOne(_coerceId(id), scope: _scope(request));
    return _json(200, record.toJson());
  }
  // --8<-- [end:getOne]

  /// `POST /` — creates a record from flat field values.
  // --8<-- [start:create]
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
  // --8<-- [end:create]

  /// `PATCH /<id>` — partially updates a record.
  // --8<-- [start:update]
  Future<Response> update(Request request, String id) async {
    final Object recordId = _coerceId(id);
    _require(
      request,
      policy.canUpdate(beakPrincipal(request), service.model.table, recordId),
      'update',
    );
    final record = await _readRecord(request);
    final updated = await service.update(
      recordId,
      record,
      scope: _scope(request),
      expectedUpdatedAt: _expectedUpdatedAt(request),
    );
    return _json(200, updated.toJson());
  }
  // --8<-- [end:update]

  /// `DELETE /<id>?force=` — soft-deletes (or force-deletes) a record.
  // --8<-- [start:delete]
  Future<Response> delete(Request request, String id) async {
    final Object recordId = _coerceId(id);
    _require(
      request,
      policy.canDelete(beakPrincipal(request), service.model.table, recordId),
      'delete',
    );
    final force = request.url.queryParameters['force'] == 'true';
    await service.delete(recordId, force: force, scope: _scope(request));
    return Response(204);
  }
  // --8<-- [end:delete]

  /// The `updated_at` an `If-Unmodified-Since` header claims the caller read.
  ///
  /// Opt-in: a request that sends no header updates unconditionally, which is
  /// what a script or a one-writer panel wants. The header is the HTTP way of
  /// spelling "only if nobody beat me to it", so a browser cache, a proxy and
  /// a human all read it the same way.
  DateTime? _expectedUpdatedAt(Request request) {
    final String? raw = request.headers['if-unmodified-since'];
    if (raw == null) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw BeakValidationException(
        '"if-unmodified-since" must be an ISO-8601 timestamp, got "$raw".',
      );
    }
    return parsed;
  }

  /// `POST /<id>/restore` — clears a record's soft-delete marker.
  Future<Response> restore(Request request, String id) async {
    final Object recordId = _coerceId(id);
    // Restoring is an update of the row's lifecycle, so it needs update
    // rights rather than delete rights: bringing a record back is not the
    // inverse permission of removing it.
    _require(
      request,
      policy.canUpdate(beakPrincipal(request), service.model.table, recordId),
      'restore',
    );
    final restored = await service.restore(recordId, scope: _scope(request));
    return _json(200, restored.toJson());
  }

  /// `POST /batch` — fetches the records named by `{"ids": [...]}` in one
  /// query.
  // --8<-- [start:batch]
  Future<Response> batch(Request request) async {
    _requireView(request);
    final records = await service.batchGet(
      await _readIds(request),
      scope: _scope(request),
    );
    return _json(200, [for (final record in records) record.toJson()]);
  }
  // --8<-- [end:batch]

  /// `POST /<id>/relations/<relationKey>/attach` — links related ids.
  // --8<-- [start:attach]
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
    await service.attach(
      recordId,
      relationKey,
      await _readIds(request),
      scope: _scope(request),
    );
    return Response(204);
  }
  // --8<-- [end:attach]

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
    await service.detach(
      recordId,
      relationKey,
      await _readIds(request),
      scope: _scope(request),
    );
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
