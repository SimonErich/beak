import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/api_models.dart';

/// Naming a related record twice links it once: a pivot row is a fact, and a
/// second copy of it is a duplicate the first `detach` would leave behind.
void main() {
  late InMemoryAdapter adapter;
  late WormDataSource source;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    source = WormDataSource(createApiRegistry(), adapter: adapter);
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'n1', 'title': 'Note'}),
    );
    for (final id in ['l1', 'l2']) {
      await source.create('labels', BeakRecord.fromRow({'id': id, 'name': id}));
    }
  });

  tearDown(Worm.reset);

  Future<List<Map<String, Object?>>> pivotRows() =>
      adapter.select(const QueryDescriptor(table: 'note_label'));

  test(
    'attaching the same id twice in one call writes one pivot row',
    () async {
      await source.attach('notes', 'n1', 'labels', ['l1', 'l1', 'l2']);
      final rows = await pivotRows();
      expect(rows.map((row) => row['label_id']).toList()..sort(), ['l1', 'l2']);
    },
  );

  test('attaching an id that is already linked writes nothing', () async {
    await source.attach('notes', 'n1', 'labels', ['l1']);
    await source.attach('notes', 'n1', 'labels', ['l1', 'l2']);
    expect(await pivotRows(), hasLength(2));
  });

  test('one detach removes the link', () async {
    await source.attach('notes', 'n1', 'labels', ['l1', 'l1']);
    await source.detach('notes', 'n1', 'labels', ['l1']);
    expect(await pivotRows(), isEmpty);
  });
}
