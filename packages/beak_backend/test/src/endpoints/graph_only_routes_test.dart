import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  setUp(() async {
    final registry = createApiRegistry();
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    handler = const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
            preparePlan: (plan, source, principal) async => plan,
            graphOnly: const [NoteModel()],
          ),
        );
  });
  tearDown(Worm.reset);

  test(
    'protected resources retain reads but reject direct mutation bypasses',
    () async {
      for (final entry in <(String, String)>[
        ('POST', '/api/notes/'),
        ('PATCH', '/api/notes/note'),
        ('DELETE', '/api/notes/note'),
        ('POST', '/api/notes/note/restore'),
        ('POST', '/api/notes/note/relations/comments/attach'),
        ('POST', '/api/notes/note/relations/comments/detach'),
      ]) {
        final response = await handler(
          Request(
            entry.$1,
            Uri.parse('http://localhost${entry.$2}'),
            body: '{}',
          ),
        );
        expect(response.statusCode, 422, reason: entry.toString());
        expect(await response.readAsString(), contains('graph commit'));
      }
      final query = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/query'),
          body: jsonEncode({'table': 'notes'}),
        ),
      );
      expect(query.statusCode, 200);
      final commit = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/commits'),
          body: jsonEncode(
            BeakSavePlan(
              saveId: 'native',
              root: const BeakRecordRef.draft('notes', 'note'),
              operations: [
                BeakSaveOperation(
                  id: 'note',
                  kind: BeakSaveOperationKind.create,
                  target: const BeakRecordRef.draft('notes', 'note'),
                  values: BeakRecord.fromRow({'title': 'Via graph'}),
                ),
              ],
            ).toJson(),
          ),
        ),
      );
      expect(commit.statusCode, 200);
      expect(await commit.readAsString(), contains('Via graph'));
    },
  );

  test('graph-only tables cannot silently run without their preparer', () {
    expect(
      () => beakApiRouter(
        registry: createApiRegistry(),
        dataSource: WormDataSource(
          createApiRegistry(),
          adapter: Worm.adapter(),
        ),
        graphOnly: const [NoteModel()],
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}
