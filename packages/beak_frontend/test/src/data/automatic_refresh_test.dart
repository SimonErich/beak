import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource storage;
  late ModelBeakDataSource source;
  late BeakModelRegistry registry;
  setUp(() {
    registry = BeakModelRegistry()
      ..register(const NoteModel())
      ..register(const LabelModel());
    storage = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Original'}),
        },
        'labels': {
          'l1': BeakRecord.fromRow({'id': 'l1', 'name': 'Old label'}),
        },
      },
    );
    source = ModelBeakDataSource(registry: registry, fallback: storage);
  });
  tearDown(() => source.dispose());

  test('successful writes refresh mounted lists', () async {
    final table = BeakTableViewModel(const NoteModel(), source);
    await table.refresh();
    final queries = storage.queryCalls.length;
    await source.update(
      'labels',
      'l1',
      BeakRecord.fromRow({'name': 'Fresh label'}),
    );
    await pumpEventQueue();
    expect(storage.queryCalls.length, queries + 1);
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'n2', 'title': 'Created'}),
    );
    await pumpEventQueue();
    expect(table.page.value?.total, 2);
    await source.delete('notes', 'n1');
    await pumpEventQueue();
    expect(table.page.value?.items.single['title']?.raw, 'Created');
    table.dispose();
    final before = storage.queryCalls.length;
    await source.update(
      'notes',
      'n2',
      BeakRecord.fromRow({'title': 'After dispose'}),
    );
    await pumpEventQueue();
    expect(storage.queryCalls, hasLength(before));
  });

  test('a failed mutation announces no change', () async {
    final changes = <BeakDataChange>[];
    final subscription = source.changes.listen(changes.add);
    addTearDown(subscription.cancel);
    await expectLater(
      source.update('notes', 'missing', BeakRecord.fromRow({'title': 'No'})),
      throwsA(isA<BeakNotFoundException>()),
    );
    await pumpEventQueue();
    expect(changes, isEmpty);
  });

  test(
    'one graph save emits one combined refresh after confirmed writes',
    () async {
      final changes = <BeakDataChange>[];
      final subscription = source.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      final result = await source.commit(
        BeakSavePlan(
          saveId: 'refresh-once',
          root: const BeakRecordRef.existing('notes', 'n1'),
          operations: [
            BeakSaveOperation(
              id: 'note',
              kind: BeakSaveOperationKind.update,
              target: const BeakRecordRef.existing('notes', 'n1'),
              values: BeakRecord.fromRow({'title': 'Updated'}),
            ),
            BeakSaveOperation(
              id: 'label',
              kind: BeakSaveOperationKind.update,
              target: const BeakRecordRef.existing('labels', 'l1'),
              values: BeakRecord.fromRow({'name': 'Updated label'}),
            ),
          ],
        ),
      );
      expect(result.complete, true);
      expect(changes, hasLength(1));
      expect(changes.single.tables, {'notes', 'labels'});
    },
  );

  test(
    'clean forms refresh but dirty draft values survive external updates',
    () async {
      final title = BeakScalarField<String>(
        model: const NoteModel(),
        column: const NoteModel().columns[1],
      );
      final session = BeakFormSession(
        model: const NoteModel(),
        dataSource: source,
        recordId: 'n1',
        layout: BeakFormLayout(children: [title.inputText()]),
      );
      addTearDown(session.dispose);
      await session.load();
      await source.update(
        'notes',
        'n1',
        BeakRecord.fromRow({'title': 'Remote'}),
      );
      await pumpEventQueue();
      expect(session.root.read(title), 'Remote');
      session.root.set(title, 'Local draft');
      await source.update(
        'notes',
        'n1',
        BeakRecord.fromRow({'title': 'Another writer'}),
      );
      await pumpEventQueue();
      expect(session.root.read(title), 'Local draft');
      expect(session.isDirty, true);
    },
  );
}
