/// Shelf server for Beak — auto CRUD, uploads, auth, graph commits, the
/// outbox and CSV export on top of the source-agnostic data layer.
///
/// A project rarely composes this by hand: `beak prepare` writes a
/// `BeakServeHost` into `lib/beak/server.g.dart`, and `lib/server.dart`
/// customises the server it builds through `BeakServerDefaults.build`.
/// [beakApiRouter] and the middleware set remain public for embedding Beak
/// in a larger Shelf app.
library;

export 'src/auth/auth_router.dart';
export 'src/auth/beak_access.dart';
export 'src/auth/beak_auth_guard.dart';
export 'src/auth/beak_policies.dart';
export 'src/auth/beak_policy.dart' hide beakRowScope;
export 'src/auth/beak_action_policy.dart';
export 'src/auth/beak_field_policy.dart';
export 'src/auth/beak_query_authorizer.dart';
export 'src/auth/token_session_store.dart';
export 'src/config/beak_backend_config.dart';
export 'src/config/env_loader.dart';
export 'src/data/worm/beak_baseline_migration.dart';
export 'src/data/worm/beak_blueprint.dart';
export 'src/data/worm/worm_bootstrap.dart'
    show adapterFromUrl, initializeBeakDatabase;
export 'src/data/worm/worm_data_source.dart';
export 'src/endpoints/beak_resource_router.dart' show beakApiRouter;
export 'src/server/beak_serve_host.dart';
export 'src/server/beak_server.dart';
export 'src/server/beak_storage_settings.dart';
export 'src/server/middleware/auth_middleware.dart';
export 'src/server/storage_wiring.dart';
export 'src/server/middleware/cors_middleware.dart';
export 'src/server/middleware/error_mapping_middleware.dart';
export 'src/server/middleware/json_middleware.dart';
export 'src/server/middleware/request_log_middleware.dart';
export 'src/service/beak_graph_commit_service.dart';
export 'src/service/beak_commit_receipts_migration.dart';
export 'src/service/beak_framework_tables.dart';
export 'src/service/beak_outbox.dart';
export 'src/service/beak_revision_timestamp.dart' show beakRevisionTimestamp;

// The Shelf types a `lib/server.dart` names when it adds middleware or routes,
// so a project depending on `beak` alone never has to import `shelf` itself.
export 'package:shelf/shelf.dart'
    show Handler, Middleware, Pipeline, Request, Response;
export 'package:shelf_router/shelf_router.dart' show Router;

/// The version of the `beak_backend` package.
const String beakBackendVersion = '0.9.0';
