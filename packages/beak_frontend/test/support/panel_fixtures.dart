/// Fixtures for the panel widget suites: two tiny models and an in-memory
/// fake data source, so widget tests never touch a network.
library;

import 'package:beak_core/beak_core.dart';

/// The notes fixture model.
final class NoteModel extends BeakModel {
  /// Creates the notes model.
  const NoteModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title', searchable: true),
  ];
}

/// The labels fixture model.
final class LabelModel extends BeakModel {
  /// Creates the labels model.
  const LabelModel();

  @override
  String get table => 'labels';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

/// An in-memory [BeakDataSource] that records calls and serves canned
/// records — enough for panel, cache, and optimism tests (extend it to
/// override single operations).
base class FakeDataSource implements BeakDataSource {
  /// Creates a fake serving [records] keyed by table then id.
  FakeDataSource({Map<String, Map<Object, BeakRecord>>? records})
    : _recordsByTable = records ?? {};

  final Map<String, Map<Object, BeakRecord>> _recordsByTable;

  /// Every `batchGet` invocation, as `(table, ids)` pairs.
  final List<(String, List<Object>)> batchGetCalls = [];

  /// Every `query` invocation.
  final List<BeakQuerySpec> queryCalls = [];

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    queryCalls.add(spec);
    final records = (_recordsByTable[spec.table] ?? {}).values.toList();
    return BeakPage(
      items: records,
      total: records.length,
      page: spec.pagination.page,
      perPage: spec.pagination.perPage,
    );
  }

  @override
  Future<BeakRecord?> getOne(String table, Object id) async =>
      _recordsByTable[table]?[id];

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async => data;

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async =>
      data;

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {}

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    batchGetCalls.add((table, ids));
    return [
      for (final id in ids)
        if (_recordsByTable[table]?[id] case final BeakRecord record) record,
    ];
  }

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {}

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {}

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async => 0;
}
