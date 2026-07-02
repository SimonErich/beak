/// Exception for attribute cast failures.
library;

import 'model_exception.dart';

/// Thrown when an attribute cast between types
/// fails.
class CastException extends ModelException {
  /// Creates a [CastException].
  const CastException({
    required this.field,
    required this.fromType,
    required this.toType,
    required String message,
    this.model,
  }) : super(message);

  /// The field being cast.
  final String field;

  /// The source type name.
  final String fromType;

  /// The target type name.
  final String toType;

  /// The model that owns the field, when known.
  final String? model;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'model': model,
    'field': field,
    'from': fromType,
    'to': toType,
  };

  @override
  String toString() {
    final parts = <String>[];
    final modelName = model;
    if (modelName != null) parts.add('model: $modelName');
    parts
      ..add('field: $field')
      ..add('from: $fromType')
      ..add('to: $toType');
    return 'CastException: $message (${parts.join(', ')})';
  }
}
