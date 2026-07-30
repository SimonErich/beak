/// Core, source-agnostic building blocks for Beak admin panels: typed
/// columns, relationships, serializable query specs, and storage
/// abstractions.
library;

export 'src/client/beak_client.dart';
export 'src/client/beak_session.dart';
export 'src/columns/beak_column.dart';
export 'src/columns/beak_json.dart';
export 'src/columns/beak_render_config.dart';
export 'src/common/beak_color.dart';
export 'src/common/beak_exception.dart';
export 'src/common/beak_result.dart';
export 'src/context/beak_context.dart';
export 'src/context/beak_render_intent.dart';
export 'src/data/beak_data_source.dart';
export 'src/data/beak_upload_client.dart';
export 'src/model/beak_model.dart';
export 'src/model/beak_model_registry.dart';
export 'src/query/beak_aggregate_spec.dart';
export 'src/query/beak_filter.dart';
export 'src/query/beak_operator.dart';
export 'src/query/beak_page.dart';
export 'src/query/beak_pagination.dart';
export 'src/query/beak_query_spec.dart';
export 'src/query/beak_record.dart';
export 'src/query/beak_relation_load.dart';
export 'src/query/beak_sort.dart';
export 'src/query/beak_table_ref.dart';
export 'src/query/beak_value.dart';
export 'src/relations/beak_on_delete.dart';
export 'src/relations/beak_relationship.dart';
export 'src/rules/beak_rule.dart';
export 'src/search/beak_search_hit.dart';
export 'src/storage/beak_storage_config.dart';
export 'src/storage/beak_storage_driver.dart';
export 'src/storage/beak_storage_key.dart';
export 'src/storage/beak_storage_registry.dart';
export 'src/storage/beak_stored_file.dart';
export 'src/storage/beak_upload.dart';
export 'src/storage/beak_upload_validator.dart';
// The local-disk driver imports dart:io and lives in `package:beak_core/io.dart`
// so this barrel — and every Flutter panel that imports it — stays web-safe.
export 'src/storage/drivers/beak_memory_storage_driver.dart';
export 'src/storage/file_rules/beak_dimensions.dart';
export 'src/storage/file_rules/beak_file_type.dart';
export 'src/storage/transforms/beak_image_transform.dart';
export 'src/storage/transforms/beak_transform_runner.dart';

/// The version of the `beak_core` package.
const String beakCoreVersion = '0.0.1';
