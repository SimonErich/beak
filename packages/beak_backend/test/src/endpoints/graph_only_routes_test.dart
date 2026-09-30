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

  test(
    'an anonymous caller is refused before it learns the table is closed',
    () async {
      final registry = createApiRegistry();
      final adapter = Worm.adapter();
      final guarded = const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(
            beakApiRouter(
              registry: registry,
              dataSource: WormDataSource(registry, adapter: adapter),
              policy: BeakPolicies(
                rules: [
                  BeakModelRules(
                    const NoteModel(),
                    read: BeakAccess.authenticated,
                    write: const BeakAccess.role('editor'),
                    delete: const BeakAccess.role('editor'),
                  ),
                ],
              ),
              graphOnly: const [NoteModel()],
            ),
          );

      for (final entry in <(String, String)>[
        ('POST', '/api/notes/'),
        ('PATCH', '/api/notes/note'),
        ('DELETE', '/api/notes/note'),
        ('POST', '/api/notes/note/restore'),
        ('POST', '/api/notes/note/relations/comments/attach'),
        ('POST', '/api/notes/note/relations/comments/detach'),
      ]) {
        final response = await guarded(
          Request(
            entry.$1,
            Uri.parse('http://localhost${entry.$2}'),
            body: '{}',
          ),
        );
        expect(response.statusCode, 401, reason: entry.toString());
        expect(await response.readAsString(), isNot(contains('graph commit')));
      }
    },
  );

  group('without a preparer', () {
    late Handler bare;
    late DatabaseAdapter adapter;

    setUp(() {
      final registry = createApiRegistry();
      adapter = Worm.adapter();
      bare = const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(
            beakApiRouter(
              registry: registry,
              dataSource: WormDataSource(registry, adapter: adapter),
              graphOnly: const [NoteModel()],
            ),
          );
    });

    test('graphOnly closes the direct routes of a table by itself', () async {
      final response = await bare(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/'),
          body: jsonEncode({'title': 'Direct'}),
        ),
      );

      expect(response.statusCode, 422);
      expect(await response.readAsString(), contains('graph commit'));
    });

    test('the commit route still saves the table', () async {
      final commit = await bare(
        Request(
          'POST',
          Uri.parse('http://localhost/api/commits'),
          body: jsonEncode(
            BeakSavePlan(
              saveId: 'plain',
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
    });

    test('a table that is not registered is still refused', () {
      expect(
        () => beakApiRouter(
          registry: BeakModelRegistry(),
          dataSource: WormDataSource(BeakModelRegistry(), adapter: adapter),
          graphOnly: const [NoteModel()],
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}
