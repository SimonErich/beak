/// Core, source-agnostic building blocks for Beak admin panels: typed
/// columns, relationships, serializable query specs, and storage
/// abstractions.
library;

export 'src/columns/beak_column.dart';
export 'src/columns/beak_json.dart';
export 'src/columns/beak_render_config.dart';
export 'src/columns/file_support.dart';
export 'src/common/beak_color.dart';
export 'src/common/beak_exception.dart';
export 'src/common/beak_result.dart';
export 'src/context/beak_context.dart';
export 'src/context/beak_render_intent.dart';
export 'src/model/beak_model.dart';
export 'src/model/beak_model_registry.dart';
export 'src/query/beak_filter.dart';
export 'src/query/beak_operator.dart';
export 'src/query/beak_page.dart';
export 'src/query/beak_pagination.dart';
export 'src/query/beak_query_spec.dart';
export 'src/query/beak_relation_load.dart';
export 'src/query/beak_sort.dart';
export 'src/query/beak_value.dart';
export 'src/relations/beak_on_delete.dart';
export 'src/relations/beak_relationship.dart';
export 'src/rules/beak_rule.dart';

/// The version of the `beak_core` package.
const String beakCoreVersion = '0.0.1';
