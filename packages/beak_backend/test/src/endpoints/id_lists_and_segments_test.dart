/// The ids a request carries: how many a list may hold, and the path segments
/// that arrive percent-encoded.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  late WormDataSource source;

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    final registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(beakApiRouter(registry: registry, dataSource: source));
  });

  tearDown(Worm.reset);

  Future<Response> send(String method, String path, [Object? body]) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  List<String> ids(int count) => [for (var i = 0; i < count; i++) 'id-$i'];

  group('a list of ids', () {
    test('holds at most 1000 for batch', () async {
      expect(
        (await send('POST', '/api/notes/batch', {'ids': ids(1000)})).statusCode,
        200,
      );
      final over = await send('POST', '/api/notes/batch', {'ids': ids(1001)});
      expect(over.statusCode, 422);
      expect(await over.readAsString(), contains('1000'));
    });

    test('holds at most 1000 for attach and detach', () async {
      await source.create(
        'notes',
        BeakRecord.fromRow({'id': 'n1', 'title': 'Mine'}),
      );
      for (final verb in ['attach', 'detach']) {
        final response = await send(
          'POST',
          '/api/notes/n1/relations/labels/$verb',
          {'ids': ids(1001)},
        );
        expect(response.statusCode, 422, reason: verb);
      }
    });
  });

  group('a percent-encoded path segment', () {
    test('is decoded before it is read as a relationship key', () async {
      await source.create(
        'notes',
        BeakRecord.fromRow({'id': 'n1', 'title': 'Mine'}),
      );
      final response = await send(
        'POST',
        '/api/notes/n1/relations/${Uri.encodeComponent('labels')}/attach',
        {'ids': <String>[]},
      );
      expect(response.statusCode, 204);
    });

    test('a malformed encoding is a 404, not a crash', () async {
      final response = await send('GET', '/api/notes/100%zz');
      expect(response.statusCode, 404);
    });

    test('is decoded before a receipt is looked up by its save id', () async {
      const saveId = 'save 1/a?b';
      final operation = BeakSaveOperation(
        id: 'c',
        kind: BeakSaveOperationKind.create,
        target: const BeakRecordRef.draft('labels', 'draft'),
        values: BeakRecord.fromRow({'name': 'L'}),
      );
      final committed = await send(
        'POST',
        '/api/commits',
        BeakSavePlan(
          saveId: saveId,
          root: operation.target,
          operations: [operation],
        ).toJson(),
      );
      expect(committed.statusCode, 200);

      final recovered = await send(
        'GET',
        '/api/commits/${Uri.encodeComponent(saveId)}',
      );
      final text = await recovered.readAsString();
      expect(recovered.statusCode, 200, reason: text);
      expect(
        BeakSaveResult.fromJson(switch (jsonDecode(text)) {
          final Map<String, Object?> json => json,
          final Object? other => fail('Expected an object, got $other.'),
        }).saveId,
        saveId,
      );
    });
  });
}
