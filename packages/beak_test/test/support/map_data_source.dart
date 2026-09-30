import 'package:beak_core/beak_core.dart';

// --8<-- [start:MapDataSource]
/// A [BeakDataSource] over plain maps, one per table.
///
/// Not supported, and refused loudly: relations, soft deletes, range operators
/// (`gt`, `between`, ...), `like`, and transactions of any kind.
final class MapDataSource implements BeakDataSource {
  MapDataSource(this.registry);

  final BeakModelRegistry registry;
  final Map<String, Map<Object, BeakRecord>> _tables = {};
  static const _noRelations = BeakConfigurationException(
    'MapDataSource has no relations.',
  );

  Map<Object, BeakRecord> _rows(String table) {
    registry.byTableOrThrow(table);
    return _tables.putIfAbsent(table, () => {});
  }

  Object _idOf(String table, BeakRecord record) =>
      registry.byTableOrThrow(table).primaryKeyOf(record) ??
      (throw const BeakValidationException('A record needs an id.'));

  /// Puts [records] into [table]; the contract suite seeds through this.
  void seed(String table, List<BeakRecord> records) {
    for (final record in records) {
      _rows(table)[_idOf(table, record)] = record;
    }
  }

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    if (spec.relationLoads.isNotEmpty) {
      throw _noRelations;
    }
    final rows = [
      for (final row in _rows(spec.table).values)
        if (_matches(spec.filter, row) && _searched(spec.search, row)) row,
    ];
    rows.sort((a, b) {
      for (final sort in spec.sorts) {
        final order = _compare(a[sort.columnKey]?.raw, b[sort.columnKey]?.raw);
        if (order != 0) return sort.descending ? -order : order;
      }
      return 0;
    });
    final BeakPagination(:page, :perPage) = spec.pagination;
    return BeakPage(
      items: rows.skip((page - 1) * perPage).take(perPage).toList(),
      total: rows.length,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<BeakRecord?> getOne(String table, Object id) async => _rows(table)[id];

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    final id = _idOf(table, data);
    if (_rows(table).containsKey(id)) {
      throw BeakConflictException('$table $id already exists.');
    }
    return _rows(table)[id] = data;
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    final current = _rows(table)[id];
    if (current == null) throw BeakNotFoundException('$table $id not found.');
    final key = registry.byTableOrThrow(table).primaryKey.key;
    return _rows(table)[id] = BeakRecord(
      values: {...current.values, ...data.values, key: current.values[key]!},
    );
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {
    if (_rows(table).remove(id) == null) {
      throw BeakNotFoundException('$table $id not found.');
    }
  }

  @override
  Future<BeakRecord> restore(String table, Object id) =>
      throw BeakValidationException('$table does not soft-delete.');

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async => [
    for (final id in ids.toSet()) ?_rows(table)[id],
  ];

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => throw _noRelations;

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => throw _noRelations;

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async {
    final rows = [
      for (final row in _rows(spec.table).values)
        if (_matches(spec.filter, row)) row,
    ];
    final numbers = [
      for (final row in rows)
        if (row[spec.columnKey ?? '']?.raw case final num value) value,
    ];
    final sum = numbers.fold<num>(0, (total, value) => total + value);
    return switch (spec.function) {
      BeakAggregateFunction.count => rows.length,
      BeakAggregateFunction.sum => sum,
      BeakAggregateFunction.avg => numbers.isEmpty ? 0 : sum / numbers.length,
    };
  }

  bool _matches(BeakFilter? filter, BeakRecord row) => switch (filter) {
    null => true,
    BeakAndFilter(:final filters) => filters.every((f) => _matches(f, row)),
    BeakOrFilter(:final filters) => filters.any((f) => _matches(f, row)),
    BeakFieldFilter(:final columnKey, :final operator, :final value) => _test(
      row[columnKey]?.raw,
      operator,
      value.raw,
    ),
    BeakRelationFilter() => throw _noRelations,
  };

  bool _test(Object? actual, BeakOperator operator, Object? operand) {
    final text = '$actual'.toLowerCase();
    final needle = '$operand'.toLowerCase();
    return switch (operator) {
      BeakOperator.eq => actual == operand,
      BeakOperator.neq => actual != operand,
      BeakOperator.isNull => actual == null,
      BeakOperator.isNotNull => actual != null,
      BeakOperator.inList =>
        operand is List<Object?> && operand.contains(actual),
      BeakOperator.notInList =>
        operand is List<Object?> && !operand.contains(actual),
      BeakOperator.contains => text.contains(needle),
      BeakOperator.startsWith => text.startsWith(needle),
      BeakOperator.endsWith => text.endsWith(needle),
      _ => throw BeakConfigurationException(
        'MapDataSource does not support ${operator.name}.',
      ),
    };
  }

  bool _searched(BeakSearch? search, BeakRecord row) =>
      search == null ||
      search.columnKeys.any(
        (key) => _test(row[key]?.raw, BeakOperator.contains, search.term),
      );

  int _compare(Object? a, Object? b) => switch ((a, b)) {
    (null, null) => 0,
    (null, _) => -1,
    (_, null) => 1,
    (final Comparable<Object> x, final Object y) => x.compareTo(y),
    _ => 0,
  };
}
// --8<-- [end:MapDataSource]
