/// Shelf server for Beak — auto CRUD, uploads, auth, search, and export on
/// top of the source-agnostic data layer.
library;

export 'src/config/beak_backend_config.dart';
export 'src/config/env_loader.dart';
export 'src/data/beak_data_source.dart';
export 'src/data/worm/column_type_mapper.dart';
export 'src/data/worm/query_translator.dart';
export 'src/data/worm/worm_bootstrap.dart';
export 'src/data/worm/worm_data_source.dart';
export 'src/data/worm/worm_record_model.dart';
export 'src/server/beak_server.dart';
export 'src/server/middleware/auth_middleware.dart';
export 'src/server/middleware/cors_middleware.dart';
export 'src/server/middleware/error_mapping_middleware.dart';
export 'src/server/middleware/json_middleware.dart';
export 'src/server/middleware/request_log_middleware.dart';

/// The version of the `beak_backend` package.
const String beakBackendVersion = '0.0.1';
