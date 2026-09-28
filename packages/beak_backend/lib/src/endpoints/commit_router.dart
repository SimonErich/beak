import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../server/middleware/auth_middleware.dart';
import '../server/middleware/json_middleware.dart';
import '../service/beak_graph_commit_service.dart';

/// Mounts graph writes and durable receipt lookup before per-resource routes.
void registerBeakCommitRoutes(Router router, BeakGraphCommitService service) {
  router.post('/api/commits', (Request request) async {
    final plan = readBeakSpec(
      await readJsonObject(request),
      BeakSavePlan.fromJson,
    );
    final result = await service.commit(
      plan,
      principal: beakPrincipal(request),
    );
    return Response.ok(jsonEncode(result.toJson()));
  });
  router.get('/api/commits/<saveId>', (Request request, String saveId) async {
    final result = await service.recover(
      saveId,
      principal: beakPrincipal(request),
    );
    return Response.ok(jsonEncode(result.toJson()));
  });
}
