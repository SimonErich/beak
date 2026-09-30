import 'package:beak_core/beak_core.dart';

/// What a column stores, as far as a filter operand is concerned.
enum _Storage {
  integer('an integer'),
  number('a numeric'),
  boolean('a boolean'),
  timestamp('a timestamp'),
  text('a text'),
  any('any');

  const _Storage(this.phrase);

  /// The article and noun a refusal message puts before "operand".
  final String phrase;

  bool accepts(BeakValue operand) => switch (this) {
    _Storage.integer => operand is BeakIntValue,
    _Storage.number => operand is BeakIntValue || operand is BeakDoubleValue,
    _Storage.boolean => operand is BeakBoolValue,
    _Storage.timestamp => operand is BeakDateTimeValue,
    _Storage.text => operand is BeakStringValue,
    _Storage.any => true,
  };
}

/// The storage type of [column], which is what the database compares an
/// operand with: a semantic that changes the value type (`money` stores
/// integer units, `calendarDate` stores ISO text) decides over the column
/// class.
_Storage _storageOf(BeakColumn column) => switch (column.semantic.kind) {
  BeakSemanticKind.calendarDate ||
  BeakSemanticKind.time ||
  BeakSemanticKind.primitiveList ||
  BeakSemanticKind.object => _Storage.text,
  BeakSemanticKind.duration ||
  BeakSemanticKind.exactDecimal ||
  BeakSemanticKind.money => _Storage.integer,
  _ => switch (column) {
    BeakIntColumn() => _Storage.integer,
    BeakDecimalColumn() => _Storage.number,
    BeakBoolColumn() => _Storage.boolean,
    BeakDateTimeColumn() => _Storage.timestamp,
    BeakJsonColumn() || BeakCustomColumn() => _Storage.any,
    BeakStringColumn() ||
    BeakTextColumn() ||
    BeakRichTextColumn() ||
    BeakColorColumn() ||
    BeakFileColumn() ||
    BeakImageColumn() ||
    BeakEnumColumn() => _Storage.text,
  },
};

/// How much of a refused text operand a message quotes: an operand can be as
/// large as the request body, and an error should not echo it all.
const int _quotedOperandInCharacters = 40;

/// Throws a [BeakValidationException] when [filter]'s operand cannot be
/// compared with [column] by its operator.
///
/// A database either refuses such a comparison (PostgreSQL answers a type
/// error) or quietly compares across types (SQLite), so the same spec would
/// mean different things per database and, on PostgreSQL, fail as a 500 for a
/// mistake that is the caller's. Naming it here gives every database the same
/// answer, a 422 that says what was expected.
///
/// The pattern operators (`like`, `ilike`, `contains`, `startsWith`,
/// `endsWith`) apply to text columns only. Comparison operators need a single
/// value of the column's storage type (an integer column takes integers, a
/// decimal column integers and finite fractions, a timestamp column a
/// [BeakDateTimeValue]); list and range operators check every element. A
/// `null` operand always passes, and text may not contain NUL, which no
/// database stores.
void requireFittingOperand(BeakColumn column, BeakFieldFilter filter) {
  final _Storage storage = _storageOf(column);
  final BeakOperator operator = filter.operator;
  switch (operator) {
    case BeakOperator.isNull || BeakOperator.isNotNull:
      return;
    case BeakOperator.like ||
        BeakOperator.ilike ||
        BeakOperator.contains ||
        BeakOperator.startsWith ||
        BeakOperator.endsWith:
      if (storage != _Storage.text && storage != _Storage.any) {
        throw BeakValidationException(
          'Operator "${operator.name}" on "${filter.columnKey}" only applies '
          'to text fields.',
        );
      }
      _requireNoNul(filter, filter.value);
    case BeakOperator.eq ||
        BeakOperator.neq ||
        BeakOperator.gt ||
        BeakOperator.gte ||
        BeakOperator.lt ||
        BeakOperator.lte:
      _requireOperand(storage, filter, filter.value);
    case BeakOperator.inList || BeakOperator.notInList:
      if (filter.value case BeakListValue(:final values)) {
        for (final BeakValue element in values) {
          _requireOperand(storage, filter, element);
        }
      }
    case BeakOperator.between || BeakOperator.notBetween:
      if (filter.value case BeakListValue(:final values)) {
        for (final BeakValue bound in values) {
          _requireOperand(storage, filter, bound);
        }
      }
  }
}

void _requireOperand(
  _Storage storage,
  BeakFieldFilter filter,
  BeakValue operand,
) {
  if (operand is BeakNullValue) return;
  if (operand is BeakListValue) {
    throw BeakValidationException(
      'Operator "${filter.operator.name}" on "${filter.columnKey}" needs a '
      'single value, got a list.',
    );
  }
  if (!storage.accepts(operand)) {
    throw BeakValidationException(
      'Operator "${filter.operator.name}" on "${filter.columnKey}" needs '
      '${storage.phrase} operand, got ${_quote(operand)}.',
    );
  }
  if (operand case BeakDoubleValue(:final value) when !value.isFinite) {
    throw BeakValidationException(
      'Operator "${filter.operator.name}" on "${filter.columnKey}" needs a '
      'finite number.',
    );
  }
  _requireNoNul(filter, operand);
}

void _requireNoNul(BeakFieldFilter filter, BeakValue operand) {
  if (operand case BeakStringValue(
    :final value,
  ) when value.contains('\u0000')) {
    throw BeakValidationException(
      'Operator "${filter.operator.name}" on "${filter.columnKey}" cannot '
      'compare text that contains a NUL character.',
    );
  }
}

String _quote(BeakValue operand) => switch (operand) {
  BeakStringValue(:final value)
      when value.length > _quotedOperandInCharacters =>
    '"${value.substring(0, _quotedOperandInCharacters)}..."',
  BeakStringValue(:final value) => '"$value"',
  _ => '${operand.raw}',
};
