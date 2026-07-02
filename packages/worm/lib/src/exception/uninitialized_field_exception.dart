/// Exception for accessing uninitialized fields.
library;

import 'model_exception.dart';

/// Thrown when a model field is accessed before
/// it has been initialized.
class UninitializedFieldException extends ModelException {
  /// Creates an [UninitializedFieldException].
  const UninitializedFieldException({
    required this.model,
    required this.field,
    required String message,
  }) : super(message);

  /// The model containing the field.
  final String model;

  /// The field that was not initialized.
  final String field;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'model': model,
    'field': field,
  };

  @override
  String toString() =>
      'UninitializedFieldException: $message '
      '(model: $model, field: $field)';
}
