import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late InMemoryQueryLogger logger;
  late Handler handler;

  final fixedNow = DateTime.utc(2026, 7, 3, 12);
  var currentNow = DateTime.utc(2026, 7, 3, 12);
  var mintedIds = 0;

  setUp(() async {
    Worm.seedRandom(42);
    currentNow = fixedNow;
    final inner = await createApiTestDatabase();
    logger = InMemoryQueryLogger();
    final registry = createApiRegistry();
    mintedIds = 0;
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(
              registry,
              adapter: LoggingAdapter(
                inner: inner,
                logger: logger,
                strictness: const StrictnessConfig(),
                adapterName: 'InMemory',
              ),
              now: () => currentNow,
            ),
            now: () => currentNow,
            generateId: () => 'minted-${++mintedIds}',
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

  Map<String, Object?> decodeObject(String body) => switch (jsonDecode(body)) {
    final Map<String, Object?> map => map,
    final Object? other => throw StateError('expected JSON object: $other'),
  };

  Future<Map<String, Object?>> bodyOf(Response response) async =>
      decodeObject(await response.readAsString());

  Map<String, Object?> valuesOf(Map<String, Object?> recordJson) =>
      switch (recordJson['values']) {
        final Map<String, Object?> values => values,
        final Object? other => throw StateError('expected values map: $other'),
      };

  group('create', () {
    test('returns 201 with a minted id and stamped timestamps', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {'title': 'Grocery run', 'rating': 4},
      );

      expect(response.statusCode, 201);
      final values = valuesOf(await bodyOf(response));
      expect(values['id'], 'minted-1');
      expect(values['title'], 'Grocery run');
      expect(values['created_at'], {
        'type': 'dateTime',
        'value': fixedNow.toIso8601String(),
      });
      expect(values['updated_at'], {
        'type': 'dateTime',
        'value': fixedNow.toIso8601String(),
      });
    });

    test('keeps a caller-supplied id', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {'id': 'note-7', 'title': 'Fixed id'},
      );
      expect(valuesOf(await bodyOf(response))['id'], 'note-7');
    });

    test('an invalid create returns 422 with typed field errors', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {'rating': 0, 'bogus': true},
      );

      expect(response.statusCode, 422);
      final body = await bodyOf(response);
      expect(body['code'], 'validation');
      expect(body['fieldErrors'], {
        'title': ['This field is required.'],
        'rating': ['Must be at least 1.'],
        'bogus': ['Unknown field "bogus" on "notes".'],
      });
    });

    test('a malformed value encoding returns 422, not 500', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {
          'title': 'Ok',
          'created_at': {'type': 'dateTime', 'value': 'not-a-date'},
        },
      );
      expect(response.statusCode, 422);
    });

    test('an explicit null id still mints one, and null timestamps '
        'still stamp', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {
          'id': null,
          'title': 'Blank pk field',
          'rating': 3,
          'created_at': null,
        },
      );

      expect(response.statusCode, 201);
      final values = valuesOf(await bodyOf(response));
      expect(values['id'], 'minted-1');
      expect(values['created_at'], {
        'type': 'dateTime',
        'value': fixedNow.toIso8601String(),
      });
    });
  });

  group('getOne', () {
    test('returns the record with 200', () async {
      await call('POST', '/api/notes', body: {'id': 'n1', 'title': 'One'});
      final response = await call('GET', '/api/notes/n1');
      expect(response.statusCode, 200);
      expect(valuesOf(await bodyOf(response))['title'], 'One');
    });

    test('404s for a missing id', () async {
      final response = await call('GET', '/api/notes/ghost');
      expect(response.statusCode, 404);
      expect((await bodyOf(response))['code'], 'not_found');
    });
  });

  group('query', () {
    setUp(() async {
      for (final (index, title) in ['Alpha', 'Beam', 'Gamma'].indexed) {
        await call(
          'POST',
          '/api/notes',
          body: {'id': 'n${index + 1}', 'title': title, 'rating': index + 1},
        );
      }
    });

    test('runs a posted spec and returns the page envelope', () async {
      final spec = const BeakQuerySpec(table: 'notes')
          .withFilter(
            const BeakFieldFilter(
              column: NoteColumns.rating,
              operator: BeakOperator.gte,
              value: BeakIntValue(2),
            ),
          )
          .orderBy(NoteColumns.rating, descending: true)
          .paginate(page: 1, perPage: 1);

      final response = await call(
        'POST',
        '/api/notes/query',
        body: spec.toJson(),
      );

      expect(response.statusCode, 200);
      final body = await bodyOf(response);
      expect(body['total'], 2);
      expect(body['page'], 1);
      expect(body['perPage'], 1);
      final items = switch (body['items']) {
        final List<Object?> list => list,
        final Object? other => throw StateError('expected items list: $other'),
      };
      expect(items, hasLength(1));
    });

    test('honors search from the spec', () async {
      final spec = const BeakQuerySpec(
        table: 'notes',
      ).searching('bea', [NoteColumns.title]);
      final response = await call(
        'POST',
        '/api/notes/query',
        body: spec.toJson(),
      );
      final body = await bodyOf(response);
      expect(body['total'], 1);
    });

    test('rejects a spec whose table mismatches the route', () async {
      final response = await call(
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(table: 'labels').toJson(),
      );
      expect(response.statusCode, 422);
    });

    test('a malformed query spec returns 422, not 500', () async {
      final response = await call(
        'POST',
        '/api/notes/query',
        body: const <String, Object?>{},
      );
      expect(response.statusCode, 422);
      expect((await bodyOf(response))['code'], 'validation');
    });
  });

  group('patch', () {
    setUp(() async {
      await call(
        'POST',
        '/api/notes',
        body: {'id': 'n1', 'title': 'Before', 'rating': 2},
      );
    });

    test('updates only the provided fields and re-stamps updated_at', () async {
      // Advance the injected clock past the create so a missing re-stamp
      // (updated_at still at the create time) fails the assertion.
      final later = fixedNow.add(const Duration(hours: 1));
      currentNow = later;
      final response = await call(
        'PATCH',
        '/api/notes/n1',
        body: {'rating': 5},
      );

      expect(response.statusCode, 200);
      final values = valuesOf(await bodyOf(response));
      expect(values['title'], 'Before');
      expect(values['rating'], 5);
      expect(values['updated_at'], {
        'type': 'dateTime',
        'value': later.toIso8601String(),
      });
    });

    test('validates provided fields', () async {
      final response = await call(
        'PATCH',
        '/api/notes/n1',
        body: {'rating': 99},
      );
      expect(response.statusCode, 422);
    });

    test('404s for a missing id', () async {
      final response = await call(
        'PATCH',
        '/api/notes/ghost',
        body: {'rating': 3},
      );
      expect(response.statusCode, 404);
    });
  });

  group('delete', () {
    setUp(() async {
      await call('POST', '/api/notes', body: {'id': 'n1', 'title': 'Doomed'});
    });

    test('soft-deletes by default and query hides the record', () async {
      final response = await call('DELETE', '/api/notes/n1');
      expect(response.statusCode, 204);

      final page = await bodyOf(
        await call(
          'POST',
          '/api/notes/query',
          body: const BeakQuerySpec(table: 'notes').toJson(),
        ),
      );
      expect(page['total'], 0);

      final trashed = await bodyOf(
        await call(
          'POST',
          '/api/notes/query',
          body: const BeakQuerySpec(table: 'notes', withTrashed: true).toJson(),
        ),
      );
      expect(trashed['total'], 1);
    });

    test('force removes the record for good', () async {
      await call('DELETE', '/api/notes/n1?force=true');
      final trashed = await bodyOf(
        await call(
          'POST',
          '/api/notes/query',
          body: const BeakQuerySpec(table: 'notes', withTrashed: true).toJson(),
        ),
      );
      expect(trashed['total'], 0);
    });

    test('force also empties the trash — a soft delete then a hard one', () {
      // Emptying a trash is the whole reason force exists, and it targets
      // records the ordinary read path deliberately cannot see.
      expect(() async {
        await call('DELETE', '/api/notes/n1');
        final response = await call('DELETE', '/api/notes/n1?force=true');
        expect(response.statusCode, 204);
        final trashed = await bodyOf(
          await call(
            'POST',
            '/api/notes/query',
            body: const BeakQuerySpec(
              table: 'notes',
              withTrashed: true,
            ).toJson(),
          ),
        );
        expect(trashed['total'], 0);
      }(), completes);
    });

    test('restore brings a soft-deleted record back', () async {
      await call('DELETE', '/api/notes/n1');
      expect((await call('GET', '/api/notes/n1')).statusCode, 404);

      final response = await call('POST', '/api/notes/n1/restore');

      expect(response.statusCode, 200);
      expect((await bodyOf(response))['values'], containsPair('id', 'n1'));
      expect((await call('GET', '/api/notes/n1')).statusCode, 200);
    });

    test('restoring a live record is a 404, not a silent success', () async {
      expect((await call('POST', '/api/notes/n1/restore')).statusCode, 404);
    });
  });

  group('batch', () {
    test('returns the requested records from a single query', () async {
      for (final id in ['n1', 'n2', 'n3']) {
        await call('POST', '/api/notes', body: {'id': id, 'title': id});
      }
      logger.clear();

      final response = await call(
        'POST',
        '/api/notes/batch',
        body: {
          'ids': ['n1', 'n3'],
        },
      );

      expect(response.statusCode, 200);
      expect(logger.entries, hasLength(1));
      final items = switch (jsonDecode(await response.readAsString())) {
        final List<Object?> list => list,
        final Object? other => throw StateError('expected a list: $other'),
      };
      expect(items, hasLength(2));
    });

    test('rejects a body without an id list', () async {
      final response = await call(
        'POST',
        '/api/notes/batch',
        body: {'ids': 'n1'},
      );
      expect(response.statusCode, 422);
    });
  });

  group('data-driven surface', () {
    test(
      'a second registered model gets the same surface with no new code',
      () async {
        final created = await call(
          'POST',
          '/api/labels',
          body: {'name': 'urgent'},
        );
        expect(created.statusCode, 201);
        final id = valuesOf(await bodyOf(created))['id'];
        expect(id, 'minted-1');

        final fetched = await call('GET', '/api/labels/$id');
        expect(fetched.statusCode, 200);
        expect(valuesOf(await bodyOf(fetched))['name'], 'urgent');

        final invalid = await call('POST', '/api/labels', body: {'name': ''});
        expect(invalid.statusCode, 422);
      },
    );

    test('unknown tables 404', () async {
      final response = await call('GET', '/api/unicorns/1');
      expect(response.statusCode, 404);
    });
  });

  group('aggregate', () {
    test('computes count and sum over the posted spec', () async {
      await call(
        'POST',
        '/api/notes',
        body: {'id': 'n1', 'title': 'One', 'rating': 2},
      );
      await call(
        'POST',
        '/api/notes',
        body: {'id': 'n2', 'title': 'Two', 'rating': 3},
      );

      final countResponse = await call(
        'POST',
        '/api/notes/aggregate',
        body: const BeakAggregateSpec.count(table: 'notes').toJson(),
      );
      expect(countResponse.statusCode, 200);
      expect(await bodyOf(countResponse), {'value': 2});

      final sumResponse = await call(
        'POST',
        '/api/notes/aggregate',
        body: const BeakAggregateSpec.sum(
          table: 'notes',
          column: NoteColumns.rating,
        ).toJson(),
      );
      expect(await bodyOf(sumResponse), {'value': 5});
    });

    test('a spec for another table is a 422', () async {
      final response = await call(
        'POST',
        '/api/notes/aggregate',
        body: const BeakAggregateSpec.count(table: 'labels').toJson(),
      );

      expect(response.statusCode, 422);
    });

    test('a malformed aggregate spec returns 422, not 500', () async {
      final response = await call(
        'POST',
        '/api/notes/aggregate',
        body: const <String, Object?>{},
      );
      expect(response.statusCode, 422);
      expect((await bodyOf(response))['code'], 'validation');
    });
  });

  group('query counts', () {
    test(
      'a paged list with a pivot relation load stays at four queries',
      () async {
        await call('POST', '/api/notes', body: {'id': 'n1', 'title': 'One'});
        await call('POST', '/api/labels', body: {'id': 'l1', 'name': 'hot'});
        await call(
          'POST',
          '/api/notes/n1/relations/labels/attach',
          body: {
            'ids': ['l1'],
          },
        );
        logger.clear();

        const spec = BeakQuerySpec(
          table: 'notes',
          relationLoads: [BeakRelationLoad('labels')],
        );
        await call('POST', '/api/notes/query', body: spec.toJson());

        // count + parent select + pivot select + related select.
        expect(logger.entries, hasLength(4));
      },
    );
  });
}
