/// A row scope must hold on every endpoint, not just the obvious one.
///
/// `BeakPolicy` is table-level: it answers "may this principal read notes",
/// which does not stop `POST /api/notes/query` carrying whatever filter the
/// caller likes. These tests pin the endpoints where that used to leak.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/auth/beak_policy.dart' show beakRowScope;
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Every principal sees only the notes of author `a1`.
final class _OwnNotesOnly extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _OwnNotesOnly();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel ? NoteModel.authorId.eq('a1') : null;
}

void main() {
  late Handler handler;
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  late String mine;
  late String theirs;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    registry = createApiRegistry();
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
            policy: const _OwnNotesOnly(),
          ),
        );

    final source = WormDataSource(registry, adapter: adapter);
    Future<String> insert(String title, String authorId) async {
      final record = await source.create(
        'notes',
        BeakRecord(
          values: {
            'id': BeakValue.of('$title-id'),
            'title': BeakValue.of(title),
            'author_id': BeakValue.of(authorId),
          },
        ),
      );
      return '${record['id']?.raw}';
    }

    mine = await insert('mine', 'a1');
    theirs = await insert('theirs', 'a2');
  });

  tearDown(Worm.reset);

  Future<Response> call(String method, String path, {Object? body}) async =>
      await handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<Object?> jsonOf(Response response) async =>
      jsonDecode(await response.readAsString());

  test('a query cannot widen past the scope with its own filter', () async {
    // The exact bypass: ask for everything and see what comes back.
    final response = await call(
      'POST',
      '/api/notes/query',
      body: {'table': 'notes'},
    );

    expect(response.statusCode, 200);
    if (await jsonOf(response) case {'items': final List<Object?> items}) {
      expect(items, hasLength(1));
      expect(jsonEncode(items), contains('mine'));
      expect(jsonEncode(items), isNot(contains('theirs')));
    } else {
      fail('expected a page');
    }
  });

  test(
    'a filter naming another owner returns nothing, not their row',
    () async {
      final response = await call(
        'POST',
        '/api/notes/query',
        body: {
          'table': 'notes',
          'filter': NoteModel.authorId.eq('a2').toJson(),
        },
      );

      if (await jsonOf(response) case {'items': final List<Object?> items}) {
        expect(items, isEmpty);
      } else {
        fail('expected a page');
      }
    },
  );

  test('an aggregate counts only scoped rows', () async {
    // A count that disagrees with the query it mirrors leaks the row's
    // existence just as surely as returning it.
    final response = await call(
      'POST',
      '/api/notes/aggregate',
      body: {'table': 'notes', 'function': 'count'},
    );

    expect(await jsonOf(response), {'value': 1});
  });

  test('summary groups only the authorized population', () async {
    final response = await call(
      'POST',
      '/api/notes/summary',
      body: BeakSummarySpec(
        table: 'notes',
        groupBy: NoteColumns.authorId,
        measures: const [BeakSummaryMeasure.count('count')],
      ).toJson(),
    );
    expect(response.statusCode, 200);
    final result = BeakSummaryResult.fromJson(
      (await jsonOf(response) as Map).cast<String, Object?>(),
    );
    expect(result.rows.single.group.raw, 'a1');
    expect(result.rows.single.values['count'], 1);
    expect(
      (await call(
        'POST',
        '/api/notes/summary',
        body: BeakSummarySpec(
          table: 'authors',
          measures: const [BeakSummaryMeasure.count('count')],
        ).toJson(),
      )).statusCode,
      422,
    );
  });

  test('get-one reports an out-of-scope record as missing', () async {
    // Not 403: telling an unauthorised caller that a record exists is itself
    // a leak.
    expect((await call('GET', '/api/notes/$mine')).statusCode, 200);
    expect((await call('GET', '/api/notes/$theirs')).statusCode, 404);
  });

  test('update and delete refuse an out-of-scope record', () async {
    expect(
      (await call(
        'PATCH',
        '/api/notes/$theirs',
        body: {'title': 'hijacked'},
      )).statusCode,
      404,
    );
    expect((await call('DELETE', '/api/notes/$theirs')).statusCode, 404);

    // And the row is untouched.
    final source = WormDataSource(registry, adapter: adapter);
    final record = await source.getOne('notes', theirs);
    expect(record?['title']?.raw, 'theirs');
  });

  test('batch returns only the scoped ids', () async {
    final response = await call(
      'POST',
      '/api/notes/batch',
      body: {
        'ids': [mine, theirs],
      },
    );

    if (await jsonOf(response) case final List<Object?> records) {
      expect(records, hasLength(1));
      expect(jsonEncode(records), contains('mine'));
    } else {
      fail('expected a list');
    }
  });

  test('attach refuses an out-of-scope owner', () async {
    expect(
      (await call(
        'POST',
        '/api/notes/$theirs/relations/tags/attach',
        body: {'ids': <String>[]},
      )).statusCode,
      404,
    );
  });

  test('CSV export carries the scope', () async {
    // Export is a query that returns a file; unscoped, it is the easiest
    // bypass in the API.
    final response = await call(
      'POST',
      '/api/notes/export',
      body: {'table': 'notes'},
    );

    expect(response.statusCode, 200);
    final String csv = await response.readAsString();
    expect(csv, contains('mine'));
    expect(csv, isNot(contains('theirs')));
  });

  test('a plain policy declares no scope, so nothing is narrowed', () async {
    final open = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
          ),
        );

    final response = await open(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes/query'),
        body: jsonEncode({'table': 'notes'}),
      ),
    );

    if (jsonDecode(await response.readAsString()) case {
      'items': final List<Object?> items,
    }) {
      expect(items, hasLength(2));
    } else {
      fail('expected a page');
    }
  });

  test('restore refuses an out-of-scope record', () async {
    await call('DELETE', '/api/notes/$mine');
    expect((await call('POST', '/api/notes/$mine/restore')).statusCode, 200);
    expect((await call('POST', '/api/notes/$theirs/restore')).statusCode, 404);
  });

  test('beakRowScope reads a scope only from a row policy', () {
    expect(
      beakRowScope(const BeakAllowAllPolicy(), null, const NoteModel()),
      isNull,
    );
    expect(
      beakRowScope(const _OwnNotesOnly(), null, const NoteModel()),
      isNotNull,
    );
    expect(
      beakRowScope(const _OwnNotesOnly(), null, const AuthorModel()),
      isNull,
    );
  });
}
