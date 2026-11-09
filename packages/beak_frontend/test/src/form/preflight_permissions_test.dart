import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  testWidgets('failed initial loads do not schedule write validation', (
    tester,
  ) async {
    final source = _PermissionSource()..release.complete();
    final session = BeakFormSession(
      model: const _Child(),
      dataSource: source,
      recordId: 'missing',
      layout: BeakFormLayout(children: [_Child.name.input()]),
    );
    addTearDown(session.dispose);
    await session.load();
    expect(session.error.value, isA<BeakNotFoundException>());
    await tester.pump(const Duration(milliseconds: 400));
    expect(source.requests, isEmpty);
  });

  testWidgets('read-only owned rows do not request write validation', (
    tester,
  ) async {
    final source = _PermissionSource(childWritable: false)..release.complete();
    final session = _session(source);
    addTearDown(session.dispose);
    await session.load();
    await tester.pump(const Duration(milliseconds: 400));
    expect(source.requests, isEmpty);
  });

  testWidgets('owned-row preflight waits for all loaded field permissions', (
    tester,
  ) async {
    final source = _PermissionSource();
    final session = _session(source);
    addTearDown(session.dispose);
    final loading = session.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(source.requests, isEmpty);
    source.release.complete();
    await loading;
    await tester.pump(const Duration(milliseconds: 400));
    expect(source.requests, hasLength(9));
    expect(source.maxPending, lessThanOrEqualTo(4));
    for (final request in source.requests) {
      expect(request.record.values.keys, ['name']);
      expect(request.recordId, isNotNull);
    }
  });
}

BeakFormSession _session(_PermissionSource source) => BeakFormSession(
  model: const _Parent(),
  dataSource: source,
  recordId: 'parent',
  layout: BeakFormLayout(
    children: [
      _Parent.rows.tableForm(
        children: [_Child.name.input(), _Child.counter.input(readOnly: true)],
      ),
    ],
  ),
);

final class _Parent extends BeakModel {
  const _Parent();
  static const rows = BeakToManyField(
    model: _Parent(),
    target: _Child(),
    relation: BeakHasMany(
      key: 'rows',
      label: 'Rows',
      relatedTable: 'permission_children',
      displayColumnKey: 'name',
      foreignKey: 'parent_id',
      owned: true,
    ),
  );
  @override
  String get table => 'permission_parents';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];
  @override
  List<BeakRelationship> get relationships => [rows.relation];
}

final class _Child extends BeakModel {
  const _Child();
  static const name = BeakScalarField<String>(
    model: _Child(),
    column: BeakStringColumn(key: 'name', label: 'Name', unique: true),
  );
  static const counter = BeakScalarField<int>(
    model: _Child(),
    column: BeakIntColumn(key: 'counter', label: 'Counter', defaultValue: 3),
  );
  @override
  String get table => 'permission_children';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    const BeakStringColumn(key: 'parent_id', label: 'Parent'),
    name.column,
    counter.column,
  ];
}

final class _PermissionSource extends FakeDataSource
    implements BeakCapabilityDataSource, BeakValidationDataSource {
  _PermissionSource({this.childWritable = true})
    : super(
        models: const [_Parent(), _Child()],
        records: {
          'permission_parents': {
            'parent': BeakRecord.fromRow({'id': 'parent'}),
          },
          'permission_children': {
            for (var index = 0; index < 9; index++)
              'child-$index': BeakRecord.fromRow({
                'id': 'child-$index',
                'parent_id': 'parent',
                'name': 'Row $index',
                'counter': 3,
              }),
          },
        },
      );
  final release = Completer<void>();
  final bool childWritable;
  final requests = <BeakValidationRequest>[];
  int pending = 0, maxPending = 0;
  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async {
    pending++;
    if (pending > maxPending) maxPending = pending;
    await release.future;
    pending--;
    return BeakAccessCapabilities(
      writableFields: table == 'permission_children'
          ? {if (childWritable) 'name'}
          : null,
    );
  }

  @override
  Future<BeakValidationReport> validateRecord(
    BeakValidationRequest request,
  ) async {
    requests.add(request);
    return const BeakValidationReport();
  }
}
