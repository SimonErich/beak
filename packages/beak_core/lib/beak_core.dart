/// Core, source-agnostic building blocks for Beak admin panels: typed
/// columns, relationships, serializable query specs, and storage
/// abstractions.
library;

export 'src/behavior/beak_model_behavior.dart';
export 'src/data/beak_candidate_graph.dart';
export 'src/data/beak_candidate_node_changes.dart';
export 'src/data/beak_record_duplicator.dart';
export 'src/client/beak_client.dart';
export 'src/client/beak_session.dart';
export 'src/columns/beak_column.dart';
export 'src/columns/beak_json.dart';
export 'src/columns/beak_semantic.dart';
export 'src/columns/beak_semantic_values.dart';
export 'src/formatting/beak_format_policy.dart';
export 'src/columns/beak_render_config.dart';
export 'src/common/beak_color.dart';
export 'src/common/beak_exception.dart';
export 'src/common/beak_result.dart';
export 'src/context/beak_context.dart';
export 'src/context/beak_render_intent.dart';
export 'src/data/beak_data_source.dart';
export 'src/data/beak_data_source_lookup.dart';
export 'src/data/beak_data_source_writes.dart';
export 'src/data/beak_access_capabilities.dart';
export 'src/data/beak_commit.dart';
export 'src/data/beak_staged_commit_data_source.dart';
export 'src/data/beak_edit_data_source.dart';
export 'src/data/beak_upload_client.dart';
export 'src/model/beak_model.dart';
export 'src/model/beak_attribute_definition.dart';
export 'src/model/beak_variant_matrix.dart';
export 'src/model/beak_field_ref.dart';
export 'src/model/beak_field_value.dart';
export 'src/model/beak_model_registry.dart';
export 'src/model/beak_permissions.dart';
export 'src/query/beak_aggregate_spec.dart';
export 'src/query/beak_summary_spec.dart';
export 'src/query/beak_filter.dart';
export 'src/query/beak_like_pattern.dart';
export 'src/query/beak_operator.dart';
export 'src/query/beak_page.dart';
export 'src/query/beak_pagination.dart';
export 'src/query/beak_search_filter.dart';
export 'src/query/beak_query_spec.dart';
export 'src/query/beak_record.dart';
export 'src/query/beak_relation_load.dart';
export 'src/query/beak_sort.dart';
export 'src/query/beak_table_ref.dart';
export 'src/query/beak_value.dart';
export 'src/relations/beak_on_delete.dart';
export 'src/relations/beak_relationship.dart';
export 'src/rules/beak_rule.dart';
export 'src/validation/beak_validation.dart';
export 'src/validation/beak_record_rule.dart';
export 'src/validation/beak_validation_data_source.dart';
export 'src/validation/beak_async_validation.dart';
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

export 'src/data/beak_export_data_source.dart';

/// The version of the `beak_core` package.
const String beakCoreVersion = '0.9.0';
