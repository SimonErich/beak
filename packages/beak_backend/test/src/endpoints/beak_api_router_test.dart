import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// A model no registry in this suite knows about.
final class _UnregisteredModel extends BeakModel {
  const _UnregisteredModel();

  @override
  String get table => 'ghosts';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];
}

void main() {
  late BeakModelRegistry registry;
  late WormDataSource source;
  final frozen = DateTime.utc(2030, 1, 2, 3, 4, 5);

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
  });
  tearDown(Worm.reset);

  Handler handlerFor(Handler router) => const Pipeline()
      .addMiddleware(beakJsonMiddleware())
      .addMiddleware(beakErrorMappingMiddleware())
      .addHandler(router);

  Future<Map<String, Object?>> bodyOf(Response response) async =>
      switch (jsonDecode(await response.readAsString())) {
        final Map<String, Object?> map => map,
        final Object? other => throw StateError('expected an object: $other'),
      };

  test('no longer routes the removed global search endpoint', () async {
    // The panel searches per model through `globalSearchSources`; the
    // cross-model endpoint had no remaining caller.
    final handler = handlerFor(
      beakApiRouter(registry: registry, dataSource: source),
    );

    final response = await handler(
      Request('GET', Uri.parse('http://localhost/api/search?q=a')),
    );

    expect(response.statusCode, 404);
  });

  group('graph commits share the injected seams', () {
    Future<BeakSaveResult> commit(Handler handler) async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/commits'),
          body: jsonEncode(
            BeakSavePlan(
              saveId: 'seams',
              root: const BeakRecordRef.draft('notes', 'draft'),
              operations: [
                BeakSaveOperation(
                  id: 'create',
                  kind: BeakSaveOperationKind.create,
                  target: const BeakRecordRef.draft('notes', 'draft'),
                  values: BeakRecord.fromRow({'title': 'Frozen'}),
                ),
              ],
            ).toJson(),
          ),
        ),
      );
      expect(response.statusCode, 200);
      return BeakSaveResult.fromJson(await bodyOf(response));
    }

    test('a commit stamps timestamps from the injected clock', () async {
      final result = await commit(
        handlerFor(
          beakApiRouter(
            registry: registry,
            dataSource: source,
            now: () => frozen,
          ),
        ),
      );

      expect(
        NoteColumns.createdAt.readFrom(result.rootRecord!),
        frozen,
        reason: 'a frozen-clock test must see the same instant on both paths',
      );
    });

    test('a commit mints primary keys from the injected generator', () async {
      final result = await commit(
        handlerFor(
          beakApiRouter(
            registry: registry,
            dataSource: source,
            generateId: () => 'minted-by-test',
          ),
        ),
      );

      expect(NoteColumns.id.readFrom(result.rootRecord!), 'minted-by-test');
    });
  });

  group('graphOnly', () {
    Handler graphOnly(List<BeakModel> models) => handlerFor(
      beakApiRouter(
        registry: registry,
        dataSource: source,
        preparePlan: (plan, source, principal) async => plan,
        graphOnly: models,
      ),
    );

    test('names protected resources by model, not by table string', () async {
      final handler = graphOnly(const [NoteModel()]);

      final response = await handler(
        Request('POST', Uri.parse('http://localhost/api/notes'), body: '{}'),
      );
      final open = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/labels'),
          body: jsonEncode({'id': 'l1', 'name': 'hot'}),
        ),
      );

      expect(response.statusCode, 422);
      expect(await response.readAsString(), contains('graph commit'));
      expect(open.statusCode, 201, reason: 'only the named model is closed');
    });

    test('rejects a model the registry does not serve', () {
      expect(
        () => graphOnly(const [_UnregisteredModel()]),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('ghosts'),
          ),
        ),
      );
    });

    test('tolerates the same model listed twice', () async {
      final handler = graphOnly(const [NoteModel(), NoteModel()]);

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/query'),
          body: jsonEncode(const BeakQuerySpec(table: 'notes').toJson()),
        ),
      );

      expect(response.statusCode, 200);
    });
  });
}
