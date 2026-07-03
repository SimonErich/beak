import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  late InMemoryAdapter adapter;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    final registry = createApiRegistry();
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
          ),
        );
  });

  tearDown(Worm.reset);

  Future<Response> call(String method, String path, {Object? body}) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<List<String>> loadedNames(String relationKey) async {
    final response = await call(
      'POST',
      '/api/notes/query',
      body: BeakQuerySpec(
        table: 'notes',
        relationLoads: [BeakRelationLoad(relationKey)],
      ).toJson(),
    );
    final page = switch (jsonDecode(await response.readAsString())) {
      final Map<String, Object?> map => map,
      final Object? other => throw StateError('expected an object: $other'),
    };
    final items = switch (page['items']) {
      final List<Object?> list => list,
      final Object? other => throw StateError('expected items: $other'),
    };
    final record = BeakRecord.fromJson(switch (items.single) {
      final Map<String, Object?> map => map,
      final Object? other => throw StateError('expected a record: $other'),
    });
    return [
      for (final related
          in record.relations[relationKey] ?? const <BeakRecord>[])
        switch (related['name'] ?? related['message']) {
          final BeakStringValue value => value.value,
          final Object? other => throw StateError('expected a string: $other'),
        },
    ];
  }

  setUp(() async {
    // A note plus two labels and two loose comments to attach.
    await call('POST', '/api/notes', body: {'id': 'n1', 'title': 'One'});
    await adapter.insert(
      const InsertDescriptor(
        table: 'labels',
        values: {'id': 'l1', 'name': 'urgent'},
      ),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'labels',
        values: {'id': 'l2', 'name': 'later'},
      ),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'comments',
        values: {'id': 'c1', 'note_id': null, 'message': 'first'},
      ),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'comments',
        values: {'id': 'c2', 'note_id': null, 'message': 'second'},
      ),
    );
  });

  group('belongs-to-many', () {
    test('attach persists pivot rows and detach removes them', () async {
      final attach = await call(
        'POST',
        '/api/notes/n1/relations/labels/attach',
        body: {
          'ids': ['l1', 'l2'],
        },
      );
      expect(attach.statusCode, 204);
      expect(await loadedNames('labels'), unorderedEquals(['urgent', 'later']));

      final detach = await call(
        'POST',
        '/api/notes/n1/relations/labels/detach',
        body: {
          'ids': ['l1'],
        },
      );
      expect(detach.statusCode, 204);
      expect(await loadedNames('labels'), ['later']);
    });
  });

  group('has-many', () {
    test('attach repoints child foreign keys and detach clears them', () async {
      final attach = await call(
        'POST',
        '/api/notes/n1/relations/comments/attach',
        body: {
          'ids': ['c1', 'c2'],
        },
      );
      expect(attach.statusCode, 204);
      expect(
        await loadedNames('comments'),
        unorderedEquals(['first', 'second']),
      );

      final detach = await call(
        'POST',
        '/api/notes/n1/relations/comments/detach',
        body: {
          'ids': ['c1'],
        },
      );
      expect(detach.statusCode, 204);
      expect(await loadedNames('comments'), ['second']);
    });
  });

  group('rejections', () {
    test('attach on a belongs-to relation is rejected as invalid', () async {
      final response = await call(
        'POST',
        '/api/notes/n1/relations/author/attach',
        body: {
          'ids': ['a1'],
        },
      );
      expect(response.statusCode, 422);
    });

    test('an unknown relation key 404s', () async {
      final response = await call(
        'POST',
        '/api/notes/n1/relations/bogus/attach',
        body: {
          'ids': ['x'],
        },
      );
      expect(response.statusCode, 404);
    });
  });
}
