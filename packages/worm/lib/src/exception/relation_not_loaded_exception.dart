/// Exception for accessing unloaded relations.
library;

import 'model_exception.dart';

/// Thrown when a relation is accessed before it
/// has been eagerly loaded.
class RelationNotLoadedException extends ModelException {
  /// Creates a [RelationNotLoadedException].
  const RelationNotLoadedException({
    required this.model,
    required this.relationName,
    required String message,
  }) : super(message);

  /// The model that owns the relation.
  final String model;

  /// The relation that was not loaded.
  final String relationName;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'model': model,
    'relation': relationName,
  };

  @override
  String toString() =>
      'RelationNotLoadedException: $message '
      '(model: $model, relation: $relationName)';
}
