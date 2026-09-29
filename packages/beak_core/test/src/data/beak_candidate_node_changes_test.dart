import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/candidate_graph_fixture.dart';

const _note = NoteModel();
const _title = BeakScalarField<String>(model: _note, column: NoteColumns.title);

void main() {
  late MemorySource source;
  setUp(() async {
    source = MemorySource(createApiRegistry());
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'a', 'title': 'A', 'total': 1}),
    );
  });

  Future<BeakCandidateNode> edited(List<BeakFieldValue> values) async {
    final graph = await BeakCandidateGraph.open(
      plan: BeakSavePlan(
        saveId: 'changes',
        root: BeakRecordRef.of(_note, 'a'),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: BeakRecordRef.of(_note, 'a'),
            values: _note.record(values),
          ),
        ],
      ),
      source: source,
      registry: createApiRegistry(),
    );
    return graph.load(BeakRecordRef.of(_note, 'a'));
  }

  test(
    'lists the columns whose proposed value differs, in model order',
    () async {
      final node = await edited([totalField.to(2), _title.to('B')]);
      expect(node.changedColumns().map((column) => column.key), [
        'title',
        'total',
      ]);
    },
  );

  test('leaves out excepted fields and unchanged values', () async {
    final node = await edited([totalField.to(2), _title.to('A')]);
    expect(node.changedColumns().map((column) => column.key), ['total']);
    expect(node.changedColumns(except: [totalField]), isEmpty);
  });
}
