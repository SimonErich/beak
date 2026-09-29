import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';
import 'package:beak_image/beak_image.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_router.dart';
import '../auth/beak_policy.dart';
import '../data/worm/worm_data_source.dart';
import '../export/csv_export_service.dart';
import '../export/export_router.dart';
import '../server/middleware/error_mapping_middleware.dart';
import '../service/beak_framework_tables.dart';
import '../service/beak_resource_service.dart';
import '../service/beak_graph_commit_service.dart';
import '../uploads/upload_router.dart';
import '../uploads/upload_service.dart';
import 'crud_handlers.dart';
import 'commit_router.dart';
import 'health_router.dart';
import 'local_uploads_router.dart';

/// The generated routes of one model's REST surface, relative to its mount
/// point (`/api/{table}`).
///
/// Wires the [BeakCrudHandlers] for [service] onto the query, aggregate,
/// batch, CRUD, and relation attach/detach routes, each gated by [policy].
/// Internal to `beak_backend`: [beakApiRouter] mounts one of these per
/// registered model.
// --8<-- [start:beakResourceRouter]
Router beakResourceRouter(
  BeakResourceService service, {
  BeakPolicy policy = const BeakAllowAllPolicy(),
  BeakModelRegistry? registry,
  bool graphOnly = false,
}) {
  final handlers = BeakCrudHandlers(
    service,
    policy: policy,
    registry: registry,
  );
  Response requireGraph(Request request) => throw const BeakValidationException(
    'This resource must be saved through a graph commit.',
  );
  Response requireGraphId(Request request, String id) => requireGraph(request);
  Response requireGraphRelation(
    Request request,
    String id,
    String relationKey,
  ) => requireGraph(request);
  return Router()
    ..get('/capabilities', handlers.capabilities)
    ..post('/query', handlers.query)
    ..post('/validate', handlers.validateRecord)
    ..post('/aggregate', handlers.aggregate)
    ..post('/summary', handlers.summary)
    ..post('/batch', handlers.batch)
    ..post('/', graphOnly ? requireGraph : handlers.create)
    ..get('/<id>', handlers.getOne)
    ..patch('/<id>', graphOnly ? requireGraphId : handlers.update)
    ..delete('/<id>', graphOnly ? requireGraphId : handlers.delete)
    ..post('/<id>/restore', graphOnly ? requireGraphId : handlers.restore)
    ..post(
      '/<id>/relations/<relationKey>/attach',
      graphOnly ? requireGraphRelation : handlers.attach,
    )
    ..post(
      '/<id>/relations/<relationKey>/detach',
      graphOnly ? requireGraphRelation : handlers.detach,
    );
}
// --8<-- [end:beakResourceRouter]

/// The full generated API: one resource router per registered model
/// (mounted under `/api/{table}`, with CSV export), the graph commit
/// endpoints, the health probes, the auth surface when [auth] is configured,
/// and per-column upload endpoints when [storage] is — registering a model is
/// all it takes to get its surface, and every operation consults [policy].
///
/// [now] and [generateId] are the clock and the id mint behind every write:
/// the per-record CRUD routes, the graph commits, and the upload storage keys
/// all use them, so a frozen-clock test sees one instant on every path.
/// [transformRunner] overrides the image pipeline behind the uploads (default:
/// the real `beak_image` runner).
///
/// [preparePlan] normalizes and validates complete graphs within a
/// transaction. [graphOnly] restricts those models to that write path,
/// rejecting direct CRUD and relationship mutations while retaining all read
/// operations; every model it names must be registered.
///
/// [commitReceipts] maps the graph-commit receipts onto a table (default:
/// Beak's own `_beak_commit_receipts`), for a host whose migrations Beak does
/// not own.
///
/// [onUnexpectedError] receives the failures the readiness probe swallows, so
/// `/readyz` can answer with a generic detail instead of the raw error.
///
/// `BeakServer` composes this with the full middleware stack, and a project
/// normally reaches it through the generated host. Call it directly to embed
/// Beak in a larger Shelf app: the result is a Shelf [Handler]; wrap it in a
/// [Pipeline] with Beak's JSON and error-mapping middleware so typed
/// exceptions become HTTP/JSON.
///
/// ```dart
/// final registry = buildBeakRegistry();
/// final handler = const Pipeline()
///     .addMiddleware(beakJsonMiddleware())
///     .addMiddleware(beakErrorMappingMiddleware())
///     .addHandler(
///       beakApiRouter(
///         registry: registry,
///         dataSource: WormDataSource(registry, adapter: Worm.adapter()),
///       ),
///     );
/// // POST /api/products/query, GET /api/products/<id>, ... are now live.
/// ```
Handler beakApiRouter({
  required BeakModelRegistry registry,
  required BeakDataSource dataSource,
  BeakPolicy policy = const BeakAllowAllPolicy(),
  BeakAuthSessions? auth,
  BeakStorageDriver? storage,
  BeakTransformRunner? transformRunner,
  DateTime Function()? now,
  String Function()? generateId,
  BeakSavePlanPreparer? preparePlan,
  BeakSavePlanFinalizer? finalizePlan,
  List<BeakModel> graphOnly = const [],
  BeakCommitReceiptTable commitReceipts = BeakCommitReceiptTable.beak,
  BeakUnexpectedErrorListener? onUnexpectedError,
}) {
  final graphOnlyTables = {
    for (final model in graphOnly) registry.byTableOrThrow(model.table).table,
  };
  if (graphOnlyTables.isNotEmpty && preparePlan == null) {
    throw const BeakConfigurationException(
      'Graph-only resources require an authoritative graph preparer.',
    );
  }
  if ((preparePlan != null || finalizePlan != null) &&
      dataSource is! WormDataSource) {
    throw const BeakConfigurationException(
      'Graph preparation requires a Worm data source.',
    );
  }
  final constrainedTables = <String>{
    ...graphOnlyTables,
    for (final model in registry.all)
      if (!model.behavior.isEmpty) model.table,
  };
  final protectedOwners = <String>{};
  void protectOwned(BeakModel model) {
    if (!protectedOwners.add(model.table)) return;
    constrainedTables.add(model.table);
    for (final relation in model.relationships) {
      if (relation is BeakHasMany && relation.owned ||
          relation is BeakHasOne && relation.owned) {
        protectOwned(registry.byTableOrThrow(relation.relatedTable));
      }
    }
  }

  for (final model in registry.all) {
    if (model.behavior.editableWhen != null) protectOwned(model);
  }
  void protect(BeakModel model, List<BeakRelationLoad> loads) {
    constrainedTables.add(model.table);
    for (final load in loads) {
      final relation = model.relationships
          .where((item) => item.key == load.relationKey)
          .first;
      protect(registry.byTableOrThrow(relation.relatedTable), load.nested);
    }
  }

  for (final model in registry.all) {
    final loads = [
      for (final rule in model.validationRules) ...rule.relationLoads,
      ...model.behavior.relationLoads,
    ];
    if (loads.isNotEmpty) protect(model, loads);
  }
  if (constrainedTables.length > graphOnlyTables.length &&
      dataSource is! WormDataSource) {
    throw const BeakConfigurationException(
      'Shared relationship validation requires an atomic graph data source.',
    );
  }
  final router = Router(
    notFoundHandler: (Request request) => throw BeakNotFoundException(
      'No handler for ${request.method} /${request.url.path}.',
    ),
  );
  // Outside `/api`, and mounted first: a platform's probes must not be
  // subject to the auth middleware that guards the API.
  router.mount(
    '/',
    beakHealthRouter(
      registry: registry,
      dataSource: dataSource,
      onUnexpectedError: onUnexpectedError,
    ).call,
  );
  // Files the local-disk driver wrote are served by this server, so an
  // upload's URL resolves with no CDN, bucket or proxy in front.
  if (storage case final BeakLocalDiskStorageDriver local) {
    router.mount('/', beakLocalUploadsRouter(local).call);
  }
  if (auth != null) {
    router.mount('/api/auth', beakAuthRouter(auth).call);
  }
  final exportService = CsvExportService(registry, dataSource);
  if (dataSource is WormDataSource) {
    registerBeakCommitRoutes(
      router,
      BeakGraphCommitService(
        registry: registry,
        source: dataSource,
        policy: policy,
        preparePlan: preparePlan,
        finalizePlan: finalizePlan,
        receipts: commitReceipts,
        now: now,
        generateId: generateId,
      ),
    );
  }
  final uploads = storage == null
      ? null
      : UploadService(
          registry: registry,
          storage: storage,
          transformRunner: transformRunner ?? const ImageTransformRunner(),
          generateKeyId: generateId,
        );
  for (final model in registry.all) {
    final service = BeakResourceService(
      model,
      dataSource,
      registry: registry,
      now: now,
      generateId: generateId,
    );
    final resourceRouter = beakResourceRouter(
      service,
      policy: policy,
      registry: registry,
      graphOnly: constrainedTables.contains(model.table),
    );
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
        dataSource: dataSource,
      );
    }
    router.mount('/api/${model.table}', resourceRouter.call);
  }
  return router.call;
}
