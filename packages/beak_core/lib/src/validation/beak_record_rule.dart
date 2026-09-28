import '../model/beak_field_ref.dart';
import '../query/beak_filter.dart';
import '../query/beak_record.dart';
import '../query/beak_relation_load.dart';
import '../rules/beak_rule.dart';
import '../columns/beak_semantic_values.dart';
import '../common/beak_exception.dart';

/// A typed condition reusable in shared model validation rules.
final class BeakWhen {
  const BeakWhen._(this._matches, this.fields);

  /// Matches the typed value of [field], including an explicit null.
  static BeakWhen equals<T extends Object>(BeakFieldRef<T> field, T? value) =>
      BeakWhen._((record) => field.readFrom(record) == value, [field]);

  /// Matches a present, non-empty value.
  factory BeakWhen.present(BeakFieldRef<Object> field) => BeakWhen._(
    (record) => const BeakRequired().validate(field.readFrom(record)) == null,
    [field],
  );

  /// Requires every condition to match.
  factory BeakWhen.all(List<BeakWhen> conditions) => BeakWhen._(
    (record) => conditions.every((condition) => condition.matches(record)),
    [for (final condition in conditions) ...condition.fields],
  );

  /// Requires at least one condition to match.
  factory BeakWhen.any(List<BeakWhen> conditions) => BeakWhen._(
    (record) => conditions.any((condition) => condition.matches(record)),
    [for (final condition in conditions) ...condition.fields],
  );

  final bool Function(BeakRecord) _matches;

  /// References read by this condition, used to load authoritative state.
  final List<BeakFieldRef<Object>> fields;

  /// Evaluates the condition against the complete candidate record.
  bool matches(BeakRecord record) => _matches(record);

  /// The opposite of this condition.
  BeakWhen get not => BeakWhen._((record) => !matches(record), fields);
}

/// A shared, typed model rule; presentation placements need not repeat it.
abstract class BeakRecordRule {
  /// Enables constant declarations where all references are constants.
  const BeakRecordRule();

  /// Root-model fields read by this rule.
  List<BeakFieldRef<Object>> get fields;

  /// Errors indexed by typed field paths; an empty map means valid.
  Map<String, List<String>> validate(BeakRecord record);

  /// Relationships needed to evaluate this rule on authoritative state.
  List<BeakRelationLoad> get relationLoads => [
    for (final field in fields)
      if (_load(field) case final BeakRelationLoad load) load,
  ];

  static BeakRelationLoad _collectionLoad(
    BeakToManyField collection,
    BeakFieldRef<Object> child,
  ) {
    BeakRelationLoad? load = _load(child);
    for (final relation in [...collection.path, collection.relation].reversed) {
      load = BeakRelationLoad(relation.key, nested: [?load]);
    }
    return load!;
  }

  static BeakRelationLoad? _load(BeakFieldRef<Object> field) {
    final path = [
      ...field.path,
      if (field is BeakToManyField) field.relation,
      if (field is BeakToOneField) field.relation,
    ];
    BeakRelationLoad? load;
    for (final relation in path.reversed) {
      load = BeakRelationLoad(relation.key, nested: [?load]);
    }
    return load;
  }
}

/// Requires [field] whenever the shared [when] condition matches.
final class BeakRequiredIf extends BeakRecordRule {
  /// Creates a conditional presence constraint.
  const BeakRequiredIf(
    this.field, {
    required this.when,
    this.message = 'This field is required.',
  });

  /// Field whose presence is required.
  final BeakFieldRef<Object> field;

  /// Typed condition evaluated on the complete candidate record.
  final BeakWhen when;

  /// Human-readable field error.
  final String message;
  @override
  List<BeakFieldRef<Object>> get fields => [field, ...when.fields];
  @override
  Map<String, List<String>> validate(BeakRecord record) =>
      when.matches(record) &&
          const BeakRequired().validate(field.readFrom(record)) != null
      ? {
          field.qualifiedKey: [message],
        }
      : const {};
}

/// Requires two typed values to agree, for example a confirmation field.
final class BeakSameAs<T extends Object> extends BeakRecordRule {
  /// Creates an equality rule; absent optional values are compared normally.
  const BeakSameAs(this.field, this.other, {this.message});

  /// Field receiving the error.
  final BeakFieldRef<T> field;

  /// Field containing the expected value.
  final BeakFieldRef<T> other;

  /// Optional human-readable error.
  final String? message;
  @override
  List<BeakFieldRef<Object>> get fields => [field, other];
  @override
  Map<String, List<String>> validate(BeakRecord record) =>
      field.readFrom(record) == other.readFrom(record)
      ? const {}
      : {
          field.qualifiedKey: [message ?? 'Must match ${other.label}.'],
        };
}

/// Requires an ordered value to precede another value in the same model.
final class BeakBeforeField<T extends Object> extends BeakRecordRule {
  /// Creates a date, time, duration or numeric comparison; null values are left to presence rules.
  const BeakBeforeField(
    this.field,
    this.other, {
    this.inclusive = false,
    this.message,
  });

  /// Date receiving the error.
  final BeakFieldRef<T> field;

  /// Date used as the upper boundary.
  final BeakFieldRef<T> other;

  /// Whether equal dates are accepted.
  final bool inclusive;

  /// Optional human-readable error.
  final String? message;
  @override
  List<BeakFieldRef<Object>> get fields => [field, other];
  @override
  Map<String, List<String>> validate(BeakRecord record) {
    final value = field.readFrom(record);
    final bound = other.readFrom(record);
    return value == null ||
            bound == null ||
            _compare(value, bound) < 0 ||
            (inclusive && _compare(value, bound) == 0)
        ? const {}
        : {
            field.qualifiedKey: [
              message ??
                  'Must be ${inclusive ? 'on or ' : ''}before ${other.label}.',
            ],
          };
  }
}

/// Requires an ordered value to follow another value in the same model.
final class BeakAfterField<T extends Object> extends BeakRecordRule {
  /// Creates a date, time, duration or numeric comparison; null values are left to presence rules.
  const BeakAfterField(
    this.field,
    this.other, {
    this.inclusive = false,
    this.message,
  });

  /// Date receiving the error.
  final BeakFieldRef<T> field;

  /// Date used as the lower boundary.
  final BeakFieldRef<T> other;

  /// Whether equal dates are accepted.
  final bool inclusive;

  /// Optional human-readable error.
  final String? message;
  @override
  List<BeakFieldRef<Object>> get fields => [field, other];
  @override
  Map<String, List<String>> validate(BeakRecord record) {
    final value = field.readFrom(record);
    final bound = other.readFrom(record);
    return value == null ||
            bound == null ||
            _compare(value, bound) > 0 ||
            (inclusive && _compare(value, bound) == 0)
        ? const {}
        : {
            field.qualifiedKey: [
              message ??
                  'Must be ${inclusive ? 'on or ' : ''}after ${other.label}.',
            ],
          };
  }
}

/// Bounds the number of values or related rows in a collection.
final class BeakCount extends BeakRecordRule {
  /// Creates a collection size constraint.
  const BeakCount(this.field, {this.min, this.max})
    : assert(min == null || min >= 0),
      assert(max == null || max >= 0),
      assert(min == null || max == null || min <= max);

  /// A typed collection field or to-many relationship.
  final BeakFieldRef<Object> field;

  /// Minimum count, when bounded.
  final int? min;

  /// Maximum count, when bounded.
  final int? max;
  @override
  List<BeakFieldRef<Object>> get fields => [field];
  @override
  Map<String, List<String>> validate(BeakRecord record) {
    final count = switch (field.readFrom(record)) {
      final Iterable<Object?> values => values.length,
      null => 0,
      _ => -1,
    };
    final messages = [
      if (count < 0) 'Must be a collection.',
      if (min != null && count < min!) 'Add at least $min items.',
      if (max != null && count > max!) 'Use at most $max items.',
    ];
    return messages.isEmpty ? const {} : {field.qualifiedKey: messages};
  }
}

/// Prevents repeated typed values within related rows.
final class BeakDistinct<T extends Object> extends BeakRecordRule {
  /// Creates a uniqueness rule within the final collection, before persistence.
  const BeakDistinct(this.collection, this.by, {this.ignoreNull = true});

  /// Collection owning the rows.
  final BeakToManyField collection;

  /// Typed field read from each child row.
  final BeakFieldRef<T> by;

  /// Whether unset optional values may occur more than once.
  final bool ignoreNull;
  @override
  List<BeakFieldRef<Object>> get fields => [collection];
  @override
  List<BeakRelationLoad> get relationLoads => [
    BeakRecordRule._collectionLoad(collection, by),
  ];
  @override
  Map<String, List<String>> validate(BeakRecord record) {
    final seen = <T?>{};
    for (final row in collection.readFrom(record) ?? const <BeakRecord>[]) {
      final value = by.readFrom(row);
      if (value == null && ignoreNull) continue;
      if (!seen.add(value)) {
        return {
          collection.qualifiedKey: ['Each ${by.label} must be different.'],
        };
      }
    }
    return const {};
  }
}

/// Bounds the total of a typed numeric field across the final related rows.
final class BeakSum<T extends Object> extends BeakRecordRule {
  /// Creates an aggregate constraint, accepting either or both boundaries.
  const BeakSum(this.collection, this.value, {this.min, this.max});

  /// Collection owning the numeric values.
  final BeakToManyField collection;

  /// Child field to total.
  final BeakFieldRef<T> value;

  /// Lowest permitted sum.
  final T? min;

  /// Highest permitted sum.
  final T? max;
  @override
  List<BeakFieldRef<Object>> get fields => [collection];
  @override
  List<BeakRelationLoad> get relationLoads => [
    BeakRecordRule._collectionLoad(collection, value),
  ];
  @override
  Map<String, List<String>> validate(BeakRecord record) {
    final values = [
      for (final row in collection.readFrom(record) ?? const <BeakRecord>[])
        if (value.readFrom(row) case final Object amount) amount,
    ];
    final Object total;
    try {
      total = _sum(values);
    } on BeakValidationException catch (error) {
      return {
        collection.qualifiedKey: [error.message],
      };
    }
    final messages = [
      if (total is num && !total.isFinite) 'The total must be finite.',
      if (min != null && _compare(total, min!) < 0)
        'The total must be at least $min.',
      if (max != null && _compare(total, max!) > 0)
        'The total must be at most $max.',
    ];
    return messages.isEmpty ? const {} : {collection.qualifiedKey: messages};
  }
}

int _compare(Object a, Object b) => switch ((a, b)) {
  (final DateTime a, final DateTime b) => a.compareTo(b),
  (final BeakDate a, final BeakDate b) => a.compareTo(b),
  (final BeakTime a, final BeakTime b) => a.compareTo(b),
  (final Duration a, final Duration b) => a.compareTo(b),
  (final BeakDecimal a, final BeakDecimal b) => a.compareTo(b),
  (final num a, final num b) => a.compareTo(b),
  (0, final BeakDecimal b) => BeakDecimal(0, scale: b.scale).compareTo(b),
  _ => throw const BeakConfigurationException(
    'This validation comparison requires matching ordered field types.',
  ),
};

Object _sum(List<Object> values) {
  if (values.isEmpty) return 0;
  if (values.first is BeakDecimal) {
    final decimals = values.whereType<BeakDecimal>().toList(growable: false);
    if (decimals.length != values.length) {
      throw const BeakConfigurationException(
        'Aggregate fields must have one numeric type.',
      );
    }
    final scale = decimals.fold<int>(
      0,
      (scale, value) => value.scale > scale ? value.scale : scale,
    );
    final units = decimals.fold<BigInt>(
      BigInt.zero,
      (sum, value) =>
          sum +
          BigInt.from(value.units) * BigInt.from(10).pow(scale - value.scale),
    );
    if (units.abs() > BigInt.from(BeakDecimal.maxUnits)) {
      throw const BeakValidationException('The aggregate amount is too large.');
    }
    return BeakDecimal(units.toInt(), scale: scale);
  }
  return values.fold<num>(
    0,
    (sum, value) => switch (value) {
      final num number => sum + number,
      _ => throw const BeakConfigurationException(
        'Aggregate fields must be numeric.',
      ),
    },
  );
}

/// A rule requiring an authoritative query in addition to local validation.
sealed class BeakAsyncRecordRule extends BeakRecordRule {
  /// Creates a rule evaluated by the backend against trusted model metadata.
  const BeakAsyncRecordRule();
  @override
  Map<String, List<String>> validate(BeakRecord record) => const {};
}

/// Checks uniqueness with optional typed scope fields, excluding the edited id.
final class BeakUnique<T extends Object> extends BeakAsyncRecordRule {
  /// Creates a scoped uniqueness preflight. Database constraints remain final.
  const BeakUnique(this.field, {this.scope = const [], this.ignoreNull = true});

  /// Value whose uniqueness is checked.
  final BeakScalarField<T> field;

  /// Fields that must also match for an existing row to conflict.
  final List<BeakScalarField<Object>> scope;

  /// Whether unset optional values bypass the uniqueness check.
  final bool ignoreNull;
  @override
  List<BeakFieldRef<Object>> get fields => [field, ...scope];
}

/// Matches a candidate field against a target field for dependent eligibility.
final class BeakFieldMatch {
  /// Creates a typed equality join between the submitted and selected record.
  const BeakFieldMatch({required this.target, required this.source});

  /// Field belonging to the selected target model.
  final BeakScalarField<Object> target;

  /// Field belonging to the candidate model.
  final BeakScalarField<Object> source;
}

/// Requires a value to identify an existing, eligible record in another model.
final class BeakExists<T extends Object> extends BeakAsyncRecordRule {
  /// Creates an existence check with optional scope and dependent field matches.
  const BeakExists(
    this.field,
    this.target, {
    this.where,
    this.matching = const [],
  });

  /// Candidate field containing the selected value.
  final BeakScalarField<T> field;

  /// Referenced target field, usually the related primary key.
  final BeakScalarField<T> target;

  /// Additional trusted eligibility filter on the target model.
  final BeakFilter? where;

  /// Dependent equality constraints such as profile.customer = order.customer.
  final List<BeakFieldMatch> matching;
  @override
  List<BeakFieldRef<Object>> get fields => [
    field,
    for (final match in matching) match.source,
  ];
}
