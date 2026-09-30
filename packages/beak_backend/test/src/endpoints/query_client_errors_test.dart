import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/endpoints/crud_handlers.dart';
import 'package:beak_backend/src/service/beak_resource_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// A mistake in a posted spec is the caller's, so every one of them answers
/// 422 with a precise message, never an opaque 500.
void main() {
  late Handler handler;
  late DatabaseAdapter adapter;

  setUp(() async {
    Worm.seedRandom(42);
    final registry = createApiRegistry();
    adapter = await createApiTestDatabase();
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

  Future<Response> post(String path, Object body) async => handler(
    Request('POST', Uri.parse('http://localhost$path'), body: jsonEncode(body)),
  );

  Future<Map<String, Object?>> expect422(
    String path,
    Object body, {
    String? mentions,
  }) async {
    final response = await post(path, body);
    final decoded = jsonDecode(await response.readAsString());
    final json = switch (decoded) {
      final Map<String, Object?> map => map,
      final Object? other => fail('Expected a JSON object, got $other.'),
    };
    expect(response.statusCode, 422, reason: '$json');
    expect(json['code'], 'validation');
    if (mentions != null) {
      expect(json['message'], contains(mentions));
    }
    return json;
  }

  Map<String, Object?> query({
    Map<String, Object?>? filter,
    List<Map<String, Object?>> sorts = const [],
    Map<String, Object?>? search,
    List<Map<String, Object?>> relations = const [],
    String table = 'notes',
  }) => {
    'table': table,
    'filter': filter,
    'sorts': sorts,
    'search': search,
    'relations': relations,
  };

  Map<String, Object?> field(String column, String operator, Object? value) => {
    'type': 'field',
    'column': column,
    'operator': operator,
    'value': value,
  };

  group('sorts', () {
    test('a dotted sort key is rejected before it reaches the database', () {
      return expect422(
        '/api/notes/query',
        query(
          sorts: [
            {'column': 'author.name', 'descending': false},
          ],
        ),
        mentions: 'author.name',
      );
    });

    test('an unknown sort column is rejected', () {
      return expect422(
        '/api/notes/query',
        query(
          sorts: [
            {'column': 'bogus', 'descending': false},
          ],
        ),
        mentions: 'bogus',
      );
    });
  });

  group('unknown tables', () {
    test('an unregistered table on /query is a spec error, not a 500', () {
      return expect422(
        '/api/notes/query',
        query(table: 'ghosts'),
        mentions: 'ghosts',
      );
    });

    test('an unregistered table on /aggregate is a spec error', () {
      return expect422('/api/notes/aggregate', {
        'table': 'ghosts',
        'function': 'count',
      }, mentions: 'ghosts');
    });

    test('an unregistered table on /summary is a spec error', () {
      return expect422('/api/notes/summary', {
        'table': 'ghosts',
        'measures': [
          {'key': 'n'},
        ],
      }, mentions: 'ghosts');
    });
  });

  group('filters', () {
    test('an unknown column is a spec error', () {
      return expect422(
        '/api/notes/query',
        query(filter: field('bogus', 'eq', 1)),
        mentions: 'bogus',
      );
    });

    test('a substring operator needs a string operand', () {
      return expect422(
        '/api/notes/query',
        query(filter: field('title', 'contains', 5)),
        mentions: 'string operand',
      );
    });

    test('a list operator needs a list operand', () {
      return expect422(
        '/api/notes/query',
        query(filter: field('rating', 'inList', 5)),
        mentions: 'list operand',
      );
    });

    test('a range operator needs exactly two bounds', () {
      return expect422(
        '/api/notes/query',
        query(filter: field('rating', 'between', [1])),
        mentions: 'two bounds',
      );
    });
  });

  group('search', () {
    test('an unknown search column is a spec error', () {
      return expect422(
        '/api/notes/query',
        query(
          search: {
            'term': 'x',
            'columns': ['bogus'],
          },
        ),
        mentions: 'bogus',
      );
    });

    test('an unknown search relation is a spec error', () {
      return expect422(
        '/api/notes/query',
        query(
          search: {
            'term': 'x',
            'columns': ['nobody.name'],
          },
        ),
        mentions: 'nobody',
      );
    });
  });

  group('aggregates', () {
    test('summing a text column is a spec error', () {
      return expect422('/api/notes/aggregate', {
        'table': 'notes',
        'function': 'sum',
        'column': 'title',
      }, mentions: 'title');
    });

    test('summing an unknown column is a spec error', () {
      return expect422('/api/notes/aggregate', {
        'table': 'notes',
        'function': 'sum',
        'column': 'bogus',
      }, mentions: 'bogus');
    });

    test('summing a related column is a spec error', () {
      return expect422('/api/notes/aggregate', {
        'table': 'notes',
        'function': 'sum',
        'column': 'author.name',
      }, mentions: 'author.name');
    });
  });

  group('paging', () {
    Future<Map<String, Object?>> page(int pageNumber, int perPage) async {
      final response = await post('/api/notes/query', {
        'table': 'notes',
        'pagination': {'page': pageNumber, 'perPage': perPage},
      });
      final decoded = jsonDecode(await response.readAsString());
      expect(response.statusCode, 200, reason: '$decoded');
      return switch (decoded) {
        final Map<String, Object?> map => map,
        final Object? other => fail('Expected a JSON object, got $other.'),
      };
    }

    test('a page size above the ceiling is served at the ceiling', () async {
      final body = await page(1, 5000);
      expect(body['perPage'], BeakPagination.maxPerPage);
      expect(BeakPagination.maxPerPage, 200);
    });

    test('a page size at the ceiling is left alone', () async {
      expect((await page(1, 200))['perPage'], 200);
      expect((await page(1, 25))['perPage'], 25);
    });

    test('a page whose offset no database can address is a spec error', () {
      return expect422('/api/notes/query', {
        'table': 'notes',
        'pagination': {'page': 9007199254740992, 'perPage': 200},
      }, mentions: 'out of range');
    });

    test('the ceiling is configurable on the authorizer', () {
      final authorizer = BeakQueryAuthorizer(
        registry: createApiRegistry(),
        policy: const BeakAllowAllPolicy(),
        principal: null,
        maxPerPage: 10,
      );
      final authorized = authorizer.authorizeQuery(
        const BeakQuerySpec(
          table: 'notes',
          pagination: BeakPagination(page: 2, perPage: 50),
        ),
      );
      expect(authorized.pagination, const BeakPagination(page: 2, perPage: 10));
    });

    test('the ceiling is configurable on the handlers', () async {
      final registry = createApiRegistry();
      final handlers = BeakCrudHandlers(
        BeakResourceService(
          const NoteModel(),
          WormDataSource(registry, adapter: adapter),
          registry: registry,
        ),
        registry: registry,
        maxPerPage: 7,
      );
      final response = await handlers.query(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/query'),
          body: jsonEncode({
            'table': 'notes',
            'pagination': {'page': 1, 'perPage': 50},
          }),
        ),
      );
      expect(
        jsonDecode(await response.readAsString()),
        containsPair('perPage', 7),
      );
    });
  });
}
