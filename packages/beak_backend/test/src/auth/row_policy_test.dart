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

/// Every principal sees the notes whose title holds `keep`: a scope the
/// server can read from the database but cannot decide for a row that is not
/// stored yet.
final class _TitledKeepOnly extends BeakAllowAllPolicy
    implements BeakRowPolicy {
  const _TitledKeepOnly();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel
      ? const BeakFieldFilter.forKey(
          'title',
          BeakOperator.contains,
          BeakStringValue('keep'),
        )
      : null;
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
    for (final id in const ['a1', 'a2']) {
      await source.create(
        'authors',
        BeakRecord(
          values: {'id': BeakValue.of(id), 'name': BeakValue.of('Author $id')},
        ),
      );
    }
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
      body: const NoteModel()
          .summary(
            groupBy: NoteModel.authorId,
            measures: [const BeakSummaryMeasure.count('count')],
          )
          .toJson(),
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
        body: BeakSummarySpec.forKeys(
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

  test(
    'validate and capabilities report an out-of-scope record as missing',
    () async {
      // Both take a record id, and neither may confirm that another owner's
      // record exists.
      Future<Response> validate(String id) => call(
        'POST',
        '/api/notes/validate',
        body: {
          'table': 'notes',
          'recordId': id,
          'record': BeakRecord.fromRow({'title': 'x'}).toJson(),
        },
      );
      expect((await validate(theirs)).statusCode, 404);
      expect((await validate(mine)).statusCode, 200);
      expect(
        (await call('GET', '/api/notes/capabilities?id=$theirs')).statusCode,
        404,
      );
      expect(
        (await call('GET', '/api/notes/capabilities?id=$mine')).statusCode,
        200,
      );
    },
  );

  test('create refuses a record that would land outside the scope', () async {
    // The scope narrows every write, so a caller cannot plant a row in
    // another owner's slice of the table.
    final foreign = await call(
      'POST',
      '/api/notes',
      body: {'title': 'planted', 'author_id': 'a2'},
    );
    expect(foreign.statusCode, 403);

    final unowned = await call('POST', '/api/notes', body: {'title': 'orphan'});
    expect(unowned.statusCode, 403);

    final own = await call(
      'POST',
      '/api/notes',
      body: {'title': 'fresh', 'author_id': 'a1'},
    );
    expect(own.statusCode, 201);

    final source = WormDataSource(registry, adapter: adapter);
    final page = await source.query(const NoteModel().query());
    expect(
      page.items.map((record) => record['title']?.raw),
      unorderedEquals(<Object?>['mine', 'theirs', 'fresh']),
    );
  });

  test('update refuses a change that moves the row out of the scope', () async {
    final moved = await call(
      'PATCH',
      '/api/notes/$mine',
      body: {'author_id': 'a2'},
    );
    expect(moved.statusCode, 403);

    final source = WormDataSource(registry, adapter: adapter);
    expect((await source.getOne('notes', mine))?['author_id']?.raw, 'a1');

    final renamed = await call(
      'PATCH',
      '/api/notes/$mine',
      body: {'title': 'renamed', 'author_id': 'a1'},
    );
    expect(renamed.statusCode, 200);
    expect((await source.getOne('notes', mine))?['title']?.raw, 'renamed');
  });

  test(
    'a scope the server cannot decide refuses the writes it governs',
    () async {
      final text = WormDataSource(registry, adapter: adapter);
      final kept = await text.create(
        'notes',
        BeakRecord(
          values: {
            'id': BeakValue.of('kept-id'),
            'title': BeakValue.of('keep me'),
          },
        ),
      );
      final textScoped = const Pipeline()
          .addMiddleware(beakJsonMiddleware())
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(
            beakApiRouter(
              registry: registry,
              dataSource: text,
              policy: const _TitledKeepOnly(),
            ),
          );
      Future<Response> send(String method, String path, Object body) async =>
          await textScoped(
            Request(
              method,
              Uri.parse('http://localhost$path'),
              body: jsonEncode(body),
            ),
          );

      expect(
        (await send('POST', '/api/notes', {'title': 'keep this'})).statusCode,
        422,
      );
      expect(
        (await send('PATCH', '/api/notes/${kept['id']?.raw}', {
          'title': 'keep that',
        })).statusCode,
        422,
      );
      // A change to a field the scope does not read needs no verdict on it.
      expect(
        (await send('PATCH', '/api/notes/${kept['id']?.raw}', {
          'rating': 4,
        })).statusCode,
        200,
      );
    },
  );

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
