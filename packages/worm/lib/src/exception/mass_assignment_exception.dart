/// Exception for mass assignment violations.
library;

import 'model_exception.dart';

/// Thrown when a mass assignment operation targets guarded or
/// non-fillable fields.
///
/// Carries the offending field via [field] (kept for backwards
/// compatibility) plus every offending key collected during a
/// `fill()` call via [extraFields]; the combined view is exposed
/// through [fields].
class MassAssignmentException extends ModelException {
  /// Creates a [MassAssignmentException] for a single offending
  /// [field].
  const MassAssignmentException({
    required this.model,
    required this.field,
    this.extraFields = const <String>[],
    required String message,
  }) : super(message);

  /// Creates a [MassAssignmentException] for one or more offending
  /// [fields]. The first entry becomes [field]; any remaining
  /// entries land in [extraFields].
  factory MassAssignmentException.forFields({
    required String model,
    required List<String> fields,
    required String message,
  }) {
    assert(
      fields.isNotEmpty,
      'MassAssignmentException.forFields requires at least one field',
    );
    return MassAssignmentException(
      model: model,
      field: fields.first,
      extraFields: List<String>.unmodifiable(fields.skip(1)),
      message: message,
    );
  }

  /// Name of the model with the guarded field.
  final String model;

  /// Name of the first offending field. Kept for backwards
  /// compatibility — prefer [fields] for the complete list.
  final String field;

  /// Offending keys beyond [field].
  final List<String> extraFields;

  /// Every offending key collected during the failing operation.
  ///
  /// Always contains [field] followed by [extraFields] in the order
  /// they were observed.
  List<String> get fields => <String>[field, ...extraFields];

  @override
  Map<String, Object?> get context => <String, Object?>{
    'model': model,
    'field': field,
    'fields': fields,
  };

  @override
  String toString() {
    if (extraFields.isEmpty) {
      return 'MassAssignmentException: $message '
          '(model: $model, field: $field)';
    }
    return 'MassAssignmentException: $message '
        '(model: $model, fields: ${fields.join(', ')})';
  }
}
