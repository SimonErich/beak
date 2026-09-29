import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/candidate_graph_fixture.dart';

const _note = NoteModel();
const _title = BeakScalarField<String>(model: _note, column: NoteColumns.title);
const _id = BeakScalarField<String>(
  model: _note,
  column: BeakStringColumn(key: 'id', label: 'ID'),
);

void main() {
  late MemorySource source;
  setUp(() => source = MemorySource(createApiRegistry()));

  test('insert stores a record built from typed values', () async {
    final stored = await source.insert(_note, [
      _id.to('a'),
      _title.to('First'),
      totalField.to(1),
    ]);
    expect(_title.readFrom(stored), 'First');
    expect(_title.readFrom((await source.find(_note, 'a'))!), 'First');
  });

  test('patch changes only the given typed values', () async {
    await source.insert(_note, [_id.to('a'), _title.to('A'), totalField.to(1)]);
    final changed = await source.patch(_note, 'a', [totalField.to(2)]);
    expect(totalField.readFrom(changed), 2);
    expect(_title.readFrom(changed), 'A');
  });
}
