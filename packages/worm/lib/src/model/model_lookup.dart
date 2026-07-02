/// Helpers for resolving runtime metadata from a [Model].
library;

import '../exception/configuration_exception.dart';
import '../registry/worm.dart';
import 'model.dart';

/// Resolves table names and primary-key metadata for [Model]
/// instances.
///
/// Prefers `Model.tableName` when the subclass overrides it; falls
/// back to the [Worm] registry lookup keyed by `runtimeType`.
/// Throws [ConfigurationException] with key
/// `'model.tableName.missing'` when neither source produces a
/// value.
abstract final class ModelLookup {
  /// Returns the table name for [model].
  static String tableNameOf(Model model) {
    final declared = model.tableName;
    if (declared != null) return declared;
    if (Worm.isInitialized) {
      try {
        return Worm.registrationForType(model.runtimeType).tableName;
      } on ConfigurationException {
        // Fall through to the unified error below.
      }
    }
    throw ConfigurationException(
      key: 'model.tableName.missing',
      message:
          'Could not resolve a table name for ${model.runtimeType} — '
          'override tableName or register the model via Worm.initialize',
    );
  }
}
