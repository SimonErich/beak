import 'package:beak_core/beak_core.dart';

/// Whether [image], the complete stored form of one record, satisfies [scope].
///
/// A row scope is a filter the database applies to what it reads. A write has
/// no stored row to read yet, so the same filter is decided here against the
/// values the write would leave behind: a create is judged on the record it
/// inserts, an update on the stored row with the changes applied. `null`
/// admits every record.
///
/// The comparison follows SQL: a missing or `null` field satisfies only
/// [BeakOperator.isNull], never an ordering or an inequality.
///
/// Throws a [BeakValidationException] when the scope holds a condition only
/// the database can decide (a relationship, a text pattern, a range), because a
/// write the server cannot vouch for is refused rather than let through.
bool beakScopeAdmits(BeakFilter? scope, BeakRecord image) => switch (scope) {
  null => true,
  BeakAndFilter(:final filters) => filters.every(
    (filter) => beakScopeAdmits(filter, image),
  ),
  BeakOrFilter(:final filters) => filters.any(
    (filter) => beakScopeAdmits(filter, image),
  ),
  BeakFieldFilter(:final columnKey, :final operator, :final value) =>
    _fieldAdmits(image[columnKey]?.raw, operator, value.raw),
  BeakRelationFilter() => throw _undecidable,
};

/// The column keys of the record itself that [scope] reads, so a write that
/// leaves them alone need not be re-judged.
///
/// A condition through a belongs-to relationship reads that relationship's
/// foreign key on the record, so it is reported as that key.
Set<String> beakScopeColumnKeys(BeakFilter? scope, BeakModel model) =>
    switch (scope) {
      null => const {},
      BeakAndFilter(:final filters) || BeakOrFilter(:final filters) => {
        for (final filter in filters) ...beakScopeColumnKeys(filter, model),
      },
      BeakFieldFilter(:final columnKey) => {
        _ownKey(model, columnKey.split('.').first),
      },
      BeakRelationFilter(:final relationKey) => {
        _ownKey(model, relationKey.split('.').first),
      },
    };

String _ownKey(BeakModel model, String key) =>
    switch (model.relationshipByKey(key)) {
      BeakBelongsTo(:final foreignKey) => foreignKey,
      _ => key,
    };

const BeakValidationException _undecidable = BeakValidationException(
  'The row scope of this resource cannot be checked against a record before '
  'it is written, so the write was refused.',
);

bool _fieldAdmits(Object? actual, BeakOperator operator, Object? expected) {
  if (operator == BeakOperator.isNull) return actual == null;
  if (operator == BeakOperator.isNotNull) return actual != null;
  if (actual == null) return false;
  return switch (operator) {
    BeakOperator.eq => _equal(actual, expected),
    BeakOperator.neq => !_equal(actual, expected),
    BeakOperator.inList => switch (expected) {
      final List<Object?> options => options.any(
        (option) => _equal(actual, option),
      ),
      _ => throw _undecidable,
    },
    BeakOperator.notInList => switch (expected) {
      final List<Object?> options => !options.any(
        (option) => _equal(actual, option),
      ),
      _ => throw _undecidable,
    },
    BeakOperator.gt => _ordered(actual, expected, (order) => order > 0),
    BeakOperator.gte => _ordered(actual, expected, (order) => order >= 0),
    BeakOperator.lt => _ordered(actual, expected, (order) => order < 0),
    BeakOperator.lte => _ordered(actual, expected, (order) => order <= 0),
    _ => throw _undecidable,
  };
}

bool _equal(Object actual, Object? expected) => switch ((actual, expected)) {
  (final DateTime a, final DateTime b) => a.isAtSameMomentAs(b),
  _ => actual == expected,
};

bool _ordered(Object actual, Object? expected, bool Function(int) holds) {
  final int? order = switch ((actual, expected)) {
    (final num a, final num b) => a.compareTo(b),
    (final String a, final String b) => a.compareTo(b),
    (final DateTime a, final DateTime b) => a.compareTo(b),
    _ => null,
  };
  return order != null && holds(order);
}
