/// Exception thrown when a model lookup fails.
library;

import 'model_exception.dart';

/// Thrown when a model with a given [id] cannot
/// be found.
class ModelNotFoundException extends ModelException {
  /// Creates a [ModelNotFoundException].
  const ModelNotFoundException({
    required this.model,
    required this.id,
    required String message,
  }) : super(message);

  /// Name of the model that was not found.
  final String model;

  /// Primary key value that was looked up.
  final Object id;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'model': model,
    'id': id,
  };

  @override
  String toString() =>
      'ModelNotFoundException: $message (model: $model, id: $id)';
}
