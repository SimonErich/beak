import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';

import '../auth/beak_policy.dart';
import '../auth/beak_field_policy.dart';
import '../auth/beak_query_authorizer.dart';
import '../server/middleware/auth_middleware.dart';
import 'global_search_service.dart';

/// The thin handler behind `GET /api/search?q=…`: parses the query,
/// narrows to policy-viewable tables, and returns hits grouped per table.
final class BeakSearchHandlers {
  /// Creates the search handler over [service], gated by [policy].
  const BeakSearchHandlers({
    required this.service,
    this.policy = const BeakAllowAllPolicy(),
  });

  /// The search engine.
  final GlobalSearchService service;

  /// The visibility gate per table.
  final BeakPolicy policy;

  /// `GET /api/search?q=…&perModel=…&tables=a,b`.
  Future<Response> search(Request request) async {
    final String term = request.url.queryParameters['q'] ?? '';
    if (term.trim().isEmpty) {
      throw const BeakValidationException(
        'The query parameter "q" is required.',
      );
    }
    final int perModel = _perModelOf(request);
    final principal = beakPrincipal(request);
    final List<String>? requestedTables = switch (request
        .url
        .queryParameters['tables']) {
      null => null,
      final String csv => csv.split(',').map((table) => table.trim()).toList(),
    };
    final viewableTables = [
      for (final model in service.registry.all)
        if (policy.canView(principal, model.table) &&
            (requestedTables == null || requestedTables.contains(model.table)))
          model.table,
    ];
    // A row scope must narrow global search too, or a search box becomes a
    // way to read titles of rows the caller cannot open.
    final hits = await service.search(
      term,
      perModel: perModel,
      tables: viewableTables,
      canReadField: BeakFieldAccess(
        registry: service.registry,
        policy: policy,
        principal: principal,
      ).canRead,
      authorizeQuery: BeakQueryAuthorizer(
        registry: service.registry,
        policy: policy,
        principal: principal,
      ).authorizeQuery,
    );
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final hit in hits) {
      grouped.putIfAbsent(hit.table, () => []).add(hit.toJson());
    }
    return Response.ok(jsonEncode({'results': grouped}));
  }

  int _perModelOf(Request request) {
    final String? raw = request.url.queryParameters['perModel'];
    if (raw == null) {
      return 5;
    }
    final int? perModel = int.tryParse(raw);
    if (perModel == null || perModel < 1) {
      throw BeakValidationException(
        'The query parameter "perModel" must be a positive integer, '
        'got "$raw".',
      );
    }
    return perModel;
  }
}
