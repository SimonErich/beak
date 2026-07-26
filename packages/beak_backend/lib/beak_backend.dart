/// Shelf server for Beak — auto CRUD, uploads, auth, search, and export on
/// top of the source-agnostic data layer.
library;

export 'src/auth/auth_router.dart';
export 'src/auth/beak_auth_guard.dart';
export 'src/auth/beak_policy.dart';
export 'src/auth/token_session_store.dart';
export 'src/common/uuid_v4.dart';
export 'src/config/beak_backend_config.dart';
export 'src/config/env_loader.dart';
export 'src/data/worm/beak_blueprint.dart';
export 'src/data/worm/column_type_mapper.dart';
export 'src/data/worm/query_translator.dart';
export 'src/data/worm/worm_bootstrap.dart';
export 'src/data/worm/worm_data_source.dart';
export 'src/data/worm/worm_record_model.dart';
export 'src/endpoints/beak_resource_router.dart';
export 'src/endpoints/crud_handlers.dart';
export 'src/endpoints/health_router.dart';
export 'src/export/csv_export_service.dart';
export 'src/export/export_router.dart';
export 'src/search/global_search_service.dart';
export 'src/search/search_router.dart';
export 'src/server/beak_serve_host.dart';
export 'src/server/beak_server.dart';
export 'src/server/beak_storage_settings.dart';
export 'src/server/middleware/auth_middleware.dart';
export 'src/server/storage_wiring.dart';
export 'src/server/middleware/cors_middleware.dart';
export 'src/server/middleware/error_mapping_middleware.dart';
export 'src/server/middleware/json_middleware.dart';
export 'src/server/middleware/request_log_middleware.dart';
export 'src/service/beak_resource_service.dart';
export 'src/service/validation_service.dart';
export 'src/uploads/upload_handler.dart';
export 'src/uploads/upload_router.dart';
export 'src/uploads/upload_service.dart';

/// The version of the `beak_backend` package.
const String beakBackendVersion = '0.0.1';
