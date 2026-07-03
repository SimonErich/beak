import 'dart:collection';

import 'package:meta/meta.dart';

import '../common/json_support.dart';
import '../common/list_equality.dart';
import '../common/map_equality.dart';
import 'beak_value.dart';

/// A typed row: the shape data sources return and accept instead of a raw
/// `Map<String, dynamic>`.
///
/// Values are held as [BeakValue]s keyed by column key; eager-loaded
/// relations hold nested records keyed by relation key ([BeakRelationLoad]
/// declares what loads — a record never lazy-loads). Round-trips both to
/// plain Dart rows ([fromRow]/[toRow], the ORM boundary) and to JSON
/// ([fromJson]/[toJson], the wire boundary).
@immutable
final class BeakRecord {
  /// Creates a record over typed [values] and eager-loaded [relations].
  const BeakRecord({
    required Map<String, BeakValue> values,
    Map<String, List<BeakRecord>> relations = const {},
  }) : _values = values,
       _relations = relations;

  /// Wraps every value of a plain Dart [row] via [BeakValue.of].
  ///
  /// Throws a [BeakConfigurationException] when the row holds a value type
  /// [BeakValue] does not support.
  factory BeakRecord.fromRow(Map<String, Object?> row) => BeakRecord(
    values: {
      for (final MapEntry(:key, :value) in row.entries)
        key: BeakValue.of(value),
    },
  );

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakRecord fromJson(Map<String, Object?> json) {
    final Map<String, Object?> values = requireJsonMap(
      json,
      'values',
      _context,
    );
    final Map<String, Object?> relations = requireJsonMap(
      json,
      'relations',
      _context,
    );
    return BeakRecord(
      values: {
        for (final MapEntry(:key, :value) in values.entries)
          key: BeakValue.fromJson(value),
      },
      relations: {
        for (final MapEntry(:key, :value) in relations.entries)
          key: [
            for (final child in requireJsonMapList(value, key, _context))
              BeakRecord.fromJson(child),
          ],
      },
    );
  }

  static const String _context = 'BeakRecord';

  final Map<String, BeakValue> _values;
  final Map<String, List<BeakRecord>> _relations;

  /// The typed column values by column key, unmodifiable.
  Map<String, BeakValue> get values => UnmodifiableMapView(_values);

  /// The eager-loaded records by relation key, deeply unmodifiable.
  Map<String, List<BeakRecord>> get relations => UnmodifiableMapView({
    for (final MapEntry(:key, :value) in _relations.entries)
      key: UnmodifiableListView(value),
  });

  /// The typed value stored under [key], or `null` when the record has no
  /// such column.
  BeakValue? operator [](String key) => _values[key];

  /// This record's values as a plain Dart row (the inverse of [fromRow]).
  Map<String, Object?> toRow() => {
    for (final MapEntry(:key, :value) in _values.entries) key: value.raw,
  };

  /// This record as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'values': {
      for (final MapEntry(:key, :value) in _values.entries) key: value.toJson(),
    },
    'relations': {
      for (final MapEntry(:key, :value) in _relations.entries)
        key: [for (final record in value) record.toJson()],
    },
  };

  @override
  bool operator ==(Object other) =>
      other is BeakRecord &&
      mapEquals(other._values, _values) &&
      mapEquals(
        other._relations,
        _relations,
        valueEquals: listEquals<BeakRecord>,
      );

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in _values.entries)
        Object.hash(key, value),
    ]),
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in _relations.entries)
        Object.hash(key, Object.hashAll(value)),
    ]),
  );

  @override
  String toString() =>
      'BeakRecord(values: ${_values.keys.toList()}, '
      'relations: ${_relations.keys.toList()})';
}
