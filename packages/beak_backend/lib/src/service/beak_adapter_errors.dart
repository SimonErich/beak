import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import '../data/worm/beak_record_keys.dart';

/// The refusal a database's own refusal stands for, or `null` when [error] is
/// something else.
///
/// A constraint the database enforces (a unique index, a foreign key, a `NOT
/// NULL` or `CHECK`, a value that does not fit its column) says no before it
/// writes anything, so the write is a definite rejection the caller can act on
/// and not an unknown outcome. [WormDataSource] does the same for the writes it
/// makes; this is for the SQL a graph commit writes itself, a version
/// precondition. [removing] tells a foreign key that still holds rows from one
/// that points nowhere. The message never repeats the driver's, which names
/// tables, columns and constraints, and a field is named only when it is one
/// [model] carries.
BeakException? beakRefusalOf(
  Object error,
  BeakModel? model, {
  bool removing = false,
}) => switch (error) {
  UniqueConstraintException() => const BeakConflictException(
    'A value that must be unique is already in use.',
  ),
  ForeignKeyException(:final column) =>
    removing
        ? BeakConflictException(
            'This "${model?.table}" record is still referenced by other '
            'records.',
          )
        : _refusedValue(
            model,
            column,
            'A record this one refers to does not exist.',
            'This record does not exist.',
          ),
  CheckConstraintException(:final column) => _refusedValue(
    model,
    column,
    'A value is missing or not allowed.',
    'This value is missing or not allowed.',
  ),
  DataException(:final column) => _refusedValue(
    model,
    column,
    'A value is too long or out of range for its column.',
    'This value is too long or out of range.',
  ),
  _ => null,
};

BeakValidationException _refusedValue(
  BeakModel? model,
  String? column,
  String message,
  String fieldMessage,
) => BeakValidationException(
  message,
  fieldErrors: {
    if (column != null &&
        model != null &&
        beakRecordKeys(model).contains(column))
      column: [fieldMessage],
  },
);
