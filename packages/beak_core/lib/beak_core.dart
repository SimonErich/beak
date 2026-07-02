/// Core, source-agnostic building blocks for Beak admin panels: typed
/// columns, relationships, serializable query specs, and storage
/// abstractions.
library;

export 'src/common/beak_color.dart';
export 'src/common/beak_exception.dart';
export 'src/common/beak_result.dart';
export 'src/context/beak_context.dart';
export 'src/context/beak_render_intent.dart';
export 'src/query/beak_operator.dart';

/// The version of the `beak_core` package.
const String beakCoreVersion = '0.0.1';
