import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

const _body = BeakScalarField<String>(model: _Note(), column: _Note.body);
const _time = BeakScalarField<DateTime>(model: _Note(), column: _Note.time);
const _notes = BeakToManyField(
  model: _Order(),
  relation: _Order.notes,
  target: _Note(),
);

BeakFormSession _session(_Source source) => BeakFormSession(
  model: const _Order(),
  dataSource: source,
  recordId: 'o1',
  layout: const BeakFormLayout(
    children: [BeakFormTimeline(field: _notes, title: _body, time: _time)],
  ),
);

void main() {
  test('command refresh preserves hidden unsubmitted relation edits', () async {
    final source = _Source();
    final session = BeakFormSession(
      model: const _Order(),
      dataSource: source,
      recordId: 'o1',
      layout: BeakFormLayout(
        children: [
          _notes.tableForm(
            visibleIf: (_) => false,
            children: [_body.inputText()],
          ),
        ],
      ),
    );
    addTearDown(session.dispose);
    await session.load();
    final hiddenNote = session.root.rows(_notes).single;
    hiddenNote.set(_body, 'Unsubmitted edit');

    expect((await session.executeAction(_Order.addNote))?.complete, isTrue);

    expect(session.root.rows(_notes).single, same(hiddenNote));
    expect(hiddenNote.read(_body), 'Unsubmitted edit');
    expect(session.isDirty, isTrue);
    expect(source.queryCalls.length, 1);
  });

  test(
    'completed commands hydrate server-created history in the same session',
    () async {
      final source = _Source();
      final session = _session(source);
      addTearDown(session.dispose);
      await session.load();
      expect(session.root.snapshot.relations['notes']!.length, 1);

      final receipt = await session.executeAction(_Order.addNote);

      expect(receipt?.complete, isTrue);
      expect(session.root.snapshot.relations['notes']!.map(_body.readFrom), [
        'Before',
        'After',
      ]);
      expect(session.isDirty, isFalse);
      expect(session.canLeave, isTrue);
      expect(source.commitCount, 1);
    },
  );

  test(
    'receipt recovery hydrates history without repeating the command',
    () async {
      final source = _Source()..uncertain = true;
      final session = _session(source);
      addTearDown(session.dispose);
      await session.load();
      expect((await session.executeAction(_Order.addNote))?.hasUnknown, isTrue);
      expect(session.root.snapshot.relations['notes']!.length, 1);

      await session.recover();

      expect(session.saveResult.value?.complete, isTrue);
      expect(session.root.snapshot.relations['notes']!.map(_body.readFrom), [
        'Before',
        'After',
      ]);
      expect(source.commitCount, 1);
    },
  );

  test(
    'failed refresh preserves known history and a confirmed save receipt',
    () async {
      final source = _Source()..failRefresh = true;
      final session = _session(source);
      addTearDown(session.dispose);
      await session.load();

      final receipt = await session.executeAction(_Order.addNote);

      expect(receipt?.complete, isTrue);
      expect(session.saveResult.value?.complete, isTrue);
      expect(session.error.value, isA<BeakStorageException>());
      expect(session.root.snapshot.relations['notes']!.map(_body.readFrom), [
        'Before',
      ]);
      expect(source.commitCount, 1);
    },
  );
}

final class _Order extends BeakModel {
  const _Order();
  static const addNote = BeakModelAction(name: 'addNote', label: 'Add note');
  static const notes = BeakHasMany(
    key: 'notes',
    label: 'Notes',
    relatedTable: 'command_notes',
    foreignKey: 'order_id',
    displayColumnKey: 'body',
  );
  @override
  String get table => 'command_orders';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
  ];
  @override
  List<BeakRelationship> get relationships => const [notes];
  @override
  List<BeakModel> get relatedModels => const [_Note()];
  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(actions: [addNote]);
}

final class _Note extends BeakModel {
  const _Note();
  static const body = BeakStringColumn(key: 'body', label: 'Body');
  static const time = BeakDateTimeColumn(key: 'time', label: 'Time');
  @override
  String get table => 'command_notes';
  @override
  String get displayColumnKey => 'body';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'order_id', label: 'Order'),
    body,
    time,
  ];
}

final class _Source extends FakeDataSource implements BeakCommitDataSource {
  _Source()
    : super(
        models: const [_Order(), _Note()],
        records: {
          'command_orders': {
            'o1': BeakRecord.fromRow({'id': 'o1'}),
          },
          'command_notes': {
            'n1': BeakRecord.fromRow({
              'id': 'n1',
              'order_id': 'o1',
              'body': 'Before',
              'time': DateTime.utc(2026),
            }),
          },
        },
      );
  bool uncertain = false;
  bool failRefresh = false;
  int commitCount = 0;
  late BeakSaveResult receipt;

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    if (failRefresh && commitCount > 0) {
      throw const BeakStorageException('Refresh unavailable');
    }
    return super.query(spec);
  }

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commitCount++;
    await create(
      'command_notes',
      BeakRecord.fromRow({
        'id': 'n2',
        'order_id': 'o1',
        'body': 'After',
        'time': DateTime.utc(2026, 2),
      }),
    );
    receipt = BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final op in plan.operations)
          BeakOperationResult(
            id: op.id,
            status: BeakWriteOutcome.applied,
            resolvedId: 'o1',
            record: BeakRecord.fromRow({'id': 'o1'}),
          ),
      ],
    );
    if (!uncertain) return receipt;
    return BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final op in plan.operations)
          BeakOperationResult(id: op.id, status: BeakWriteOutcome.unknown),
      ],
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async => receipt;
}
