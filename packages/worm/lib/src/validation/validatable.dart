/// Contract for objects participating in model-level validation.
library;

import 'validation_rule.dart';

/// Implemented by models that opt into the worm validation pipeline.
///
/// Implementers expose the rule set, the current attribute values,
/// the primary key (used by rules like `Unique` to exclude the
/// current row on update), and the backing table name.
///
/// The interface intentionally has no concrete state so generated
/// model code can mix it into class hierarchies without surprise.
abstract interface class Validatable {
  /// Rules keyed by field name. The same field may declare multiple
  /// rules; the engine accumulates every failure.
  Map<String, List<ValidationRule>> validationRules();

  /// Current attribute values keyed by field name.
  ///
  /// Returning a typed `Map<String, Object?>` keeps the public API
  /// free of `dynamic` while still allowing heterogenous values.
  Map<String, Object?> validationValues();

  /// Primary-key value of the row, when known.
  ///
  /// Null on inserts; non-null on updates. Database-aware rules use
  /// it to exclude the current row from uniqueness checks.
  Object? get primaryKeyValue;

  /// Backing table the model is persisted in.
  String get tableName;
}
