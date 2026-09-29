/// A [BeakPolicies] rule set enforced through the real router, one operation
/// at a time: what an anonymous request, a signed-in stranger and a permitted
/// role each get back, and which rows and fields the rules take away.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';
import '../../support/test_images.dart';

const _editor = BeakAccess.role('editor');
const _manager = BeakAccess.role('manager');

/// The authors the fixture notes belong to.
const _authorKeys = {'a1', 'a2'};

const _avatar = BeakScalarField<String>(
  model: NoteModel(),
  column: NoteColumns.avatar,
);

/// A note model that declares a command, for the action rules.
final class _ArchivableNote extends BeakModel {
  const _ArchivableNote();

  static const archive = BeakModelAction(name: 'archive', label: 'Archive');
  static const restore = BeakModelAction(name: 'restore', label: 'Restore');

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  bool get softDeletes => true;

  @override
  List<BeakColumn> get columns => NoteColumns.values;

  @override
  BeakModelBehavior get behavior =>
      const BeakModelBehavior(actions: [archive, restore]);
}

// --8<-- [start:policyRules]
/// Notes are readable by anyone signed in, writable by editors and deletable
/// by managers, and each principal sees only the notes of their own author.
BeakPolicies _policies({
  BeakModel notes = const NoteModel(),
  Set<BeakFieldRef<Object>> readOnly = const {},
  Map<BeakFieldRef<Object>, BeakAccess> hidden = const {},
  Map<BeakModelAction, BeakAccess> actions = const {},
}) => BeakPolicies(
  rules: [
    BeakModelRules(
      notes,
      read: BeakAccess.authenticated,
      write: _editor,
      delete: _manager,
      rowScope: (principal) => NoteModel.authorId.eq(principal.id),
      readOnlyFields: readOnly,
      hiddenFields: hidden,
      actions: actions,
    ),
    BeakModelRules(const AuthorModel(), read: BeakAccess.authenticated),
    BeakModelRules(
      const LabelModel(),
      read: BeakAccess.authenticated,
      write: _editor,
    ),
  ],
);
// --8<-- [end:policyRules]

Request _multipart(
  String path,
  String token, {
  String field = 'file',
  required List<int> bytes,
}) {
  const boundary = 'beak-policy-boundary';
  final body = BytesBuilder(copy: false)
    ..add(
      utf8.encode(
        '--$boundary\r\n'
        'content-disposition: form-data; name="$field"; filename="p.png"\r\n'
        'content-type: image/png\r\n\r\n',
      ),
    )
    ..add(bytes)
    ..add(utf8.encode('\r\n--$boundary--\r\n'));
  return Request(
    'POST',
    Uri.parse('http://localhost$path'),
    headers: {
      'content-type': 'multipart/form-data; boundary=$boundary',
      'authorization': 'Bearer $token',
    },
    body: body.takeBytes(),
  );
}

void main() {
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  late WormDataSource source;
  late BeakStorageDriver storage;
  late InMemoryTokenSessionStore store;
  late String readerToken;
  late String editorToken;
  late String managerToken;
  late String rivalToken;
  var minted = 0;

  Handler serve(BeakPolicy policy, {BeakModelRegistry? models}) =>
      const Pipeline()
          .addMiddleware(beakJsonMiddleware())
          .addMiddleware(beakErrorMappingMiddleware())
          .addMiddleware(
            beakAuthMiddleware(guard: TokenSessionAuthGuard(store)),
          )
          .addHandler(
            beakApiRouter(
              registry: models ?? registry,
              dataSource: source,
              storage: storage,
              policy: policy,
              generateId: () => 'minted-${++minted}',
            ),
          );

  late Handler handler;

  setUp(() async {
    Worm.seedRandom(42);
    minted = 0;
    adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
    storage = BeakMemoryStorageDriver.fromConfig(
      const BeakMemoryStorageConfig(),
    );
    store = InMemoryTokenSessionStore();
    readerToken = await store.createSession(const BeakPrincipal(id: 'r1'));
    editorToken = await store.createSession(
      const BeakPrincipal(id: 'a1', roles: {'editor'}),
    );
    managerToken = await store.createSession(
      const BeakPrincipal(id: 'a1', roles: {'editor', 'manager'}),
    );
    rivalToken = await store.createSession(
      const BeakPrincipal(id: 'a2', roles: {'editor'}),
    );
    for (final id in _authorKeys) {
      await source.create(
        'authors',
        BeakRecord.fromRow({'id': id, 'name': 'Author $id'}),
      );
    }
    await source.create(
      'labels',
      BeakRecord.fromRow({'id': 'l1', 'name': 'L'}),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'n1', 'title': 'Mine', 'author_id': 'a1'}),
    );
    await source.create(
      'notes',
      BeakRecord.fromRow({'id': 'n2', 'title': 'Theirs', 'author_id': 'a2'}),
    );
    handler = serve(_policies(readOnly: {NoteModel.rating}));
  });

  tearDown(Worm.reset);

  Future<Response> call(
    String method,
    String path, {
    Object? body,
    String? token,
    Handler? on,
  }) async => (on ?? handler)(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {if (token != null) 'authorization': 'Bearer $token'},
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<Map<String, Object?>> objectOf(Response response) async =>
      switch (jsonDecode(await response.readAsString())) {
        final Map<String, Object?> map => map,
        final Object? other => fail('Expected a JSON object, got $other.'),
      };

  Future<List<Object?>> itemsOf(Response response) async =>
      switch ((await objectOf(response))['items']) {
        final List<Object?> items => items,
        final Object? other => fail('Expected a page, got $other.'),
      };

  Future<String> denialCode(Response response) async =>
      '${(await objectOf(response))['code']}';

  final querySpec = const BeakQuerySpec(table: 'notes').toJson();

  group('a hidden field', () {
    // Editors are hidden from the rating; managers (who are editors too, but
    // are not hidden) still see and set it.
    late Handler hiding;

    setUp(() {
      hiding = serve(
        _policies(
          hidden: {
            NoteModel.rating: const BeakAccess.all([
              _editor,
              BeakAccess.not(_manager),
            ]),
          },
        ),
      );
    });

    Future<BeakRecord> note(String token, {Handler? on}) async =>
        BeakRecord.fromJson(
          await objectOf(
            await call('GET', '/api/notes/n1', token: token, on: on),
          ),
        );

    test('is left out of what it is hidden from', () async {
      await source.update('notes', 'n1', BeakRecord.fromRow({'rating': 4}));

      expect((await note(editorToken, on: hiding))['rating'], isNull);
      expect((await note(managerToken, on: hiding))['rating']?.raw, 4);
    });

    test('is refused in a sort or filter for who it is hidden from', () async {
      final response = await call(
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(
          table: 'notes',
          sorts: [BeakSort('rating')],
        ).toJson(),
        token: editorToken,
        on: hiding,
      );

      expect(response.statusCode, 403);
    });

    test('is refused on write for who it is hidden from', () async {
      final response = await call(
        'PATCH',
        '/api/notes/n1',
        body: {'rating': 5},
        token: editorToken,
        on: hiding,
      );

      expect(response.statusCode, 403);
    });

    test('can still be written by who it is not hidden from', () async {
      final response = await call(
        'PATCH',
        '/api/notes/n1',
        body: {'rating': 5},
        token: managerToken,
        on: hiding,
      );

      expect(response.statusCode, 200);
    });
  });

  group('a model with no rule is invisible', () {
    final unlisted = <(String, String, String, Object?)>[
      ('query', 'POST', '/api/comments/query', {'table': 'comments'}),
      ('get', 'GET', '/api/comments/c1', null),
      ('create', 'POST', '/api/comments', {'message': 'hi'}),
      ('delete', 'DELETE', '/api/comments/c1', null),
      ('capabilities', 'GET', '/api/comments/capabilities', null),
      ('export', 'POST', '/api/comments/export', {'table': 'comments'}),
    ];

    // --8<-- [start:unlistedModelTests]
    for (final (name, method, path, body) in unlisted) {
      test(
        '$name answers 401 anonymously and 403 to a signed-in caller',
        () async {
          expect((await call(method, path, body: body)).statusCode, 401);
          final denied = await call(
            method,
            path,
            body: body,
            token: managerToken,
          );
          expect(denied.statusCode, 403);
          expect(await denialCode(denied), 'authorization');
        },
      );
    }
    // --8<-- [end:unlistedModelTests]

    test('no relationship of a ruled model exposes it', () async {
      final response = await call(
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(
          table: 'notes',
          relationLoads: [BeakRelationLoad('comments')],
        ).toJson(),
        token: editorToken,
      );
      expect(response.statusCode, 403);
    });

    test(
      'its relationship is absent from the capabilities of a ruled model',
      () async {
        final response = await call(
          'GET',
          '/api/notes/capabilities',
          token: editorToken,
        );
        final access = BeakAccessCapabilities.fromJson(
          await objectOf(response),
        );
        expect(access.canRead('title'), isTrue);
        expect(access.canRead('comments'), isFalse);
        expect(access.canRead('labels'), isTrue);
      },
    );
  });

  group('the query family', () {
    // --8<-- [start:rowScopedQueryTests]
    test('query: 401 anonymous, then a page scoped to the caller', () async {
      expect(
        (await call('POST', '/api/notes/query', body: querySpec)).statusCode,
        401,
      );
      final mine = await call(
        'POST',
        '/api/notes/query',
        body: querySpec,
        token: editorToken,
      );
      expect(mine.statusCode, 200);
      final items = await itemsOf(mine);
      expect(items, hasLength(1));
      expect(jsonEncode(items), contains('Mine'));
      expect(jsonEncode(items), isNot(contains('Theirs')));
    });

    test(
      'query: a signed-in caller with no rows gets an empty page, not a 403',
      () async {
        final response = await call(
          'POST',
          '/api/notes/query',
          body: querySpec,
          token: readerToken,
        );
        expect(response.statusCode, 200);
        final page = await objectOf(response);
        expect(page['items'], isEmpty);
        expect(page['total'], 0);
      },
    );
    // --8<-- [end:rowScopedQueryTests]

    test('query: a filter aimed at another owner returns nothing', () async {
      final response = await call(
        'POST',
        '/api/notes/query',
        body: BeakQuerySpec(
          table: 'notes',
          filter: NoteModel.authorId.eq('a2'),
        ).toJson(),
        token: editorToken,
      );
      expect(await itemsOf(response), isEmpty);
    });

    test('get: 401, then own row 200 and a foreign row 404', () async {
      expect((await call('GET', '/api/notes/n1')).statusCode, 401);
      expect(
        (await call('GET', '/api/notes/n1', token: editorToken)).statusCode,
        200,
      );
      expect(
        (await call('GET', '/api/notes/n2', token: editorToken)).statusCode,
        404,
      );
      expect(
        (await call('GET', '/api/notes/n1', token: readerToken)).statusCode,
        404,
      );
    });

    test('batch: 401, then only the rows in scope', () async {
      final body = {
        'ids': ['n1', 'n2'],
      };
      expect(
        (await call('POST', '/api/notes/batch', body: body)).statusCode,
        401,
      );
      final response = await call(
        'POST',
        '/api/notes/batch',
        body: body,
        token: editorToken,
      );
      final records = switch (jsonDecode(await response.readAsString())) {
        final List<Object?> list => list,
        final Object? other => fail('Expected a list, got $other.'),
      };
      expect(records, hasLength(1));
      expect(jsonEncode(records), contains('Mine'));
    });

    test('aggregate: 401, then a count of the scoped rows only', () async {
      final body = const BeakAggregateSpec.count(table: 'notes').toJson();
      expect(
        (await call('POST', '/api/notes/aggregate', body: body)).statusCode,
        401,
      );
      expect(
        await objectOf(
          await call(
            'POST',
            '/api/notes/aggregate',
            body: body,
            token: editorToken,
          ),
        ),
        {'value': 1},
      );
      expect(
        await objectOf(
          await call(
            'POST',
            '/api/notes/aggregate',
            body: body,
            token: readerToken,
          ),
        ),
        {'value': 0},
      );
    });

    test('summary: 401, then groups of the scoped population only', () async {
      final body = const NoteModel()
          .summary(
            groupBy: NoteModel.authorId,
            measures: [const BeakSummaryMeasure.count('count')],
          )
          .toJson();
      expect(
        (await call('POST', '/api/notes/summary', body: body)).statusCode,
        401,
      );
      final mine = BeakSummaryResult.fromJson(
        await objectOf(
          await call(
            'POST',
            '/api/notes/summary',
            body: body,
            token: editorToken,
          ),
        ),
      );
      expect(mine.rows.single.group.raw, 'a1');
      expect(mine.rows.single.values['count'], 1);
      final stranger = BeakSummaryResult.fromJson(
        await objectOf(
          await call(
            'POST',
            '/api/notes/summary',
            body: body,
            token: readerToken,
          ),
        ),
      );
      expect(stranger.rows, isEmpty);
    });

    test('export: 401, then a CSV of the scoped rows only', () async {
      expect(
        (await call('POST', '/api/notes/export', body: querySpec)).statusCode,
        401,
      );
      final csv = await call(
        'POST',
        '/api/notes/export',
        body: querySpec,
        token: editorToken,
      );
      expect(csv.statusCode, 200);
      final text = await csv.readAsString();
      expect(text, contains('Mine'));
      expect(text, isNot(contains('Theirs')));
      final empty = await call(
        'POST',
        '/api/notes/export',
        body: querySpec,
        token: readerToken,
      );
      expect(empty.statusCode, 200);
      expect(await empty.readAsString(), isNot(contains('Mine')));
    });
  });

  group('writes need the write access', () {
    final writes = <(String, String, String, Object?)>[
      ('create', 'POST', '/api/notes', {'title': 'New', 'author_id': 'a1'}),
      ('update', 'PATCH', '/api/notes/n1', {'title': 'Renamed'}),
      ('restore', 'POST', '/api/notes/n1/restore', null),
      (
        'attach',
        'POST',
        '/api/notes/n1/relations/labels/attach',
        {
          'ids': ['l1'],
        },
      ),
      (
        'detach',
        'POST',
        '/api/notes/n1/relations/labels/detach',
        {
          'ids': ['l1'],
        },
      ),
      (
        'validate',
        'POST',
        '/api/notes/validate',
        BeakValidationRequest(
          table: 'notes',
          record: BeakRecord.fromRow({'title': 'x'}),
        ).toJson(),
      ),
    ];

    for (final (name, method, path, body) in writes) {
      test('$name: 401 anonymous, 403 for a reader', () async {
        final anonymous = await call(method, path, body: body);
        expect(anonymous.statusCode, 401);
        expect(await denialCode(anonymous), 'authentication');
        final reader = await call(method, path, body: body, token: readerToken);
        expect(reader.statusCode, 403);
        expect(await denialCode(reader), 'authorization');
      });
    }

    test('create stores the record for an editor', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {'title': 'New', 'author_id': 'a1'},
        token: editorToken,
      );
      expect(response.statusCode, 201);
    });

    test(
      'update changes an own row and reports a foreign one as missing',
      () async {
        final own = await call(
          'PATCH',
          '/api/notes/n1',
          body: {'title': 'Renamed'},
          token: editorToken,
        );
        expect(own.statusCode, 200);
        final foreign = await call(
          'PATCH',
          '/api/notes/n2',
          body: {'title': 'Hijacked'},
          token: editorToken,
        );
        expect(foreign.statusCode, 404);
        expect((await source.getOne('notes', 'n2'))?['title']?.raw, 'Theirs');
      },
    );

    test('delete needs the delete access, which an editor lacks', () async {
      expect((await call('DELETE', '/api/notes/n1')).statusCode, 401);
      final editor = await call('DELETE', '/api/notes/n1', token: editorToken);
      expect(editor.statusCode, 403);
      final reader = await call('DELETE', '/api/notes/n1', token: readerToken);
      expect(reader.statusCode, 403);
      final manager = await call(
        'DELETE',
        '/api/notes/n1',
        token: managerToken,
      );
      expect(manager.statusCode, 204);
    });

    test('a manager cannot delete a row outside the scope', () async {
      final response = await call(
        'DELETE',
        '/api/notes/n2',
        token: managerToken,
      );
      expect(response.statusCode, 404);
      expect(await source.getOne('notes', 'n2'), isNotNull);
    });

    test('restore brings back a deleted own row for an editor', () async {
      await call('DELETE', '/api/notes/n1', token: managerToken);
      final restored = await call(
        'POST',
        '/api/notes/n1/restore',
        token: editorToken,
      );
      expect(restored.statusCode, 200);
      final foreign = await call(
        'POST',
        '/api/notes/n2/restore',
        token: editorToken,
      );
      expect(foreign.statusCode, 404);
    });

    test('attach and detach link labels for an editor, within scope', () async {
      const body = {
        'ids': ['l1'],
      };
      expect(
        (await call(
          'POST',
          '/api/notes/n1/relations/labels/attach',
          body: body,
          token: editorToken,
        )).statusCode,
        204,
      );
      expect(
        (await call(
          'POST',
          '/api/notes/n1/relations/labels/detach',
          body: body,
          token: editorToken,
        )).statusCode,
        204,
      );
      expect(
        (await call(
          'POST',
          '/api/notes/n2/relations/labels/attach',
          body: body,
          token: editorToken,
        )).statusCode,
        404,
      );
    });

    test('a write may not reference a model the caller cannot see', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {'title': 'New', 'author_id': 'a1'},
        token: editorToken,
        on: serve(
          BeakPolicies(
            rules: [
              BeakModelRules(
                const NoteModel(),
                read: BeakAccess.authenticated,
                write: _editor,
              ),
            ],
          ),
        ),
      );
      expect(response.statusCode, 403);
    });
  });

  group('capabilities', () {
    test(
      'a reader may write nothing, an editor everything but read-only',
      () async {
        expect((await call('GET', '/api/notes/capabilities')).statusCode, 401);
        final reader = BeakAccessCapabilities.fromJson(
          await objectOf(
            await call('GET', '/api/notes/capabilities', token: readerToken),
          ),
        );
        expect(reader.canRead('title'), isTrue);
        expect(reader.canWrite('title'), isFalse);
        final editor = BeakAccessCapabilities.fromJson(
          await objectOf(
            await call('GET', '/api/notes/capabilities', token: editorToken),
          ),
        );
        expect(editor.canWrite('title'), isTrue);
        expect(editor.canWrite('rating'), isFalse);
        expect(editor.canRead('rating'), isTrue);
      },
    );
  });

  group('capabilities: create and delete', () {
    Future<BeakAccessCapabilities> capabilitiesOf(
      String token, {
      String query = '',
    }) async {
      final response = await call(
        'GET',
        '/api/notes/capabilities$query',
        token: token,
      );
      expect(response.statusCode, 200);
      return BeakAccessCapabilities.fromJson(await objectOf(response));
    }

    // The rules: read for anyone signed in, write for editors, delete for
    // managers (a manager here is also an editor).
    test('follow the policy of each role', () async {
      final reader = await capabilitiesOf(readerToken);
      final editor = await capabilitiesOf(editorToken);
      final manager = await capabilitiesOf(managerToken);

      expect((reader.canCreate, reader.canDelete), (false, false));
      expect((editor.canCreate, editor.canDelete), (true, false));
      expect((manager.canCreate, manager.canDelete), (true, true));
    });

    test('are asked about the record when one is named', () async {
      final editor = await capabilitiesOf(editorToken, query: '?id=n1');
      final manager = await capabilitiesOf(managerToken, query: '?id=n1');

      expect(editor.canDelete, isFalse);
      expect(manager.canDelete, isTrue);
    });

    test('agree with what the routes then do', () async {
      final editor = await capabilitiesOf(editorToken);
      final denied = await call('DELETE', '/api/notes/n1', token: editorToken);
      final created = await call(
        'POST',
        '/api/notes',
        body: {'title': 'New', 'author_id': 'a1'},
        token: editorToken,
      );

      expect(editor.canDelete, isFalse);
      expect(denied.statusCode, 403);
      expect(editor.canCreate, isTrue);
      expect(created.statusCode, 201);
    });

    test('an allow-all policy offers both', () async {
      final open = serve(const BeakAllowAllPolicy());

      final response = await call('GET', '/api/notes/capabilities', on: open);
      final capabilities = BeakAccessCapabilities.fromJson(
        await objectOf(response),
      );

      expect(capabilities.canCreate, isTrue);
      expect(capabilities.canDelete, isTrue);
    });
  });

  group('read-only fields', () {
    test('create rejects a supplied value as a 422 field error', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {'title': 'New', 'author_id': 'a1', 'rating': 5},
        token: editorToken,
      );
      expect(response.statusCode, 422);
      final body = await objectOf(response);
      expect(body['fieldErrors'], {
        'rating': ['This field is read-only.'],
      });
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        2,
      );
    });

    test('update rejects a supplied value and leaves the row alone', () async {
      final response = await call(
        'PATCH',
        '/api/notes/n1',
        body: {'title': 'Renamed', 'rating': 4},
        token: editorToken,
      );
      expect(response.statusCode, 422);
      final row = await source.getOne('notes', 'n1');
      expect(row?['title']?.raw, 'Mine');
      expect(row?['rating']?.raw, isNull);
    });

    test('an authorization failure outranks a read-only one', () async {
      final response = await call(
        'PATCH',
        '/api/notes/n1',
        body: {'rating': 4},
        token: readerToken,
      );
      expect(response.statusCode, 403);
    });

    test('a preflight validation is rejected the same way', () async {
      final response = await call(
        'POST',
        '/api/notes/validate',
        body: BeakValidationRequest(
          table: 'notes',
          recordId: 'n1',
          record: BeakRecord.fromRow({'rating': 3}),
        ).toJson(),
        token: editorToken,
      );
      expect(response.statusCode, 422);
    });

    test('a graph commit is rejected with the field error', () async {
      final response = await call(
        'POST',
        '/api/commits',
        body: BeakSavePlan(
          saveId: 'read-only',
          root: const BeakRecordRef.draft('notes', 'new'),
          operations: [
            BeakSaveOperation(
              id: 'new',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('notes', 'new'),
              values: BeakRecord.fromRow({
                'title': 'New',
                'author_id': 'a1',
                'rating': 5,
              }),
            ),
          ],
        ).toJson(),
        token: editorToken,
      );
      final result = BeakSaveResult.fromJson(await objectOf(response));
      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'validation');
      expect(result.outcomes.single.error?.fieldErrors.keys, ['rating']);
    });

    test('a relationship that is read-only rejects attach', () async {
      const labelsRelation = BeakBelongsToMany(
        key: 'labels',
        label: 'Labels',
        relatedTable: 'labels',
        displayColumnKey: 'name',
        pivotTable: 'note_label',
        foreignPivotKey: 'note_id',
        relatedPivotKey: 'label_id',
      );
      final response = await call(
        'POST',
        '/api/notes/n1/relations/labels/attach',
        body: {
          'ids': ['l1'],
        },
        token: editorToken,
        on: serve(
          _policies(
            readOnly: {
              const BeakToManyField(
                model: NoteModel(),
                relation: labelsRelation,
                target: LabelModel(),
              ),
            },
          ),
        ),
      );
      expect(response.statusCode, 422);
    });

    test('an upload to a read-only file column is rejected', () async {
      final response = await serve(_policies(readOnly: {_avatar}))(
        _multipart(
          '/api/notes/avatar/upload',
          editorToken,
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      expect(response.statusCode, 422);
    });
  });

  group('graph commits', () {
    BeakSavePlan create(String saveId, {String authorId = 'a1'}) =>
        BeakSavePlan(
          saveId: saveId,
          root: const BeakRecordRef.draft('notes', 'new'),
          operations: [
            BeakSaveOperation(
              id: 'new',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('notes', 'new'),
              values: BeakRecord.fromRow({
                'title': 'Committed',
                'author_id': authorId,
              }),
            ),
          ],
        );

    BeakSavePlan change(String saveId, BeakSaveOperationKind kind, String id) =>
        BeakSavePlan(
          saveId: saveId,
          root: BeakRecordRef.existing('notes', id),
          operations: [
            BeakSaveOperation(
              id: 'op',
              kind: kind,
              target: BeakRecordRef.existing('notes', id),
              values: kind == BeakSaveOperationKind.update
                  ? BeakRecord.fromRow({'title': 'Changed'})
                  : const BeakRecord(values: {}),
            ),
          ],
        );

    Future<BeakSaveResult> commit(BeakSavePlan plan, {String? token}) async =>
        BeakSaveResult.fromJson(
          await objectOf(
            await call(
              'POST',
              '/api/commits',
              body: plan.toJson(),
              token: token,
            ),
          ),
        );

    test('an anonymous commit is refused as unauthenticated', () async {
      final result = await commit(create('anon'));
      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authentication');
    });

    test('a reader commit is refused as unauthorized', () async {
      final result = await commit(create('reader'), token: readerToken);
      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authorization');
    });

    test('an editor commits a row in their own scope', () async {
      final result = await commit(create('mine'), token: editorToken);
      expect(result.complete, isTrue);
    });

    test('a commit cannot create a row outside the caller scope', () async {
      final result = await commit(
        create('foreign', authorId: 'a2'),
        token: editorToken,
      );
      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'authorization');
    });

    test('an update of a foreign row reports it missing', () async {
      final result = await commit(
        change('foreign-update', BeakSaveOperationKind.update, 'n2'),
        token: editorToken,
      );
      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'not_found');
    });

    test('a delete needs the delete access', () async {
      final refused = await commit(
        change('editor-delete', BeakSaveOperationKind.delete, 'n1'),
        token: editorToken,
      );
      expect(refused.outcomes.single.error?.code, 'authorization');
      final allowed = await commit(
        change('manager-delete', BeakSaveOperationKind.delete, 'n1'),
        token: managerToken,
      );
      expect(allowed.complete, isTrue);
    });

    test('a receipt is recoverable by its owner and no one else', () async {
      await commit(create('receipt'), token: editorToken);
      expect(
        (await call(
          'GET',
          '/api/commits/receipt',
          token: editorToken,
        )).statusCode,
        200,
      );
      expect(
        (await call(
          'GET',
          '/api/commits/receipt',
          token: rivalToken,
        )).statusCode,
        404,
      );
      expect((await call('GET', '/api/commits/receipt')).statusCode, 404);
    });

    test(
      'a detach on an owner outside the scope is reported missing',
      () async {
        final plan = BeakSavePlan(
          saveId: 'scoped-detach',
          root: const BeakRecordRef.existing('notes', 'n2'),
          operations: [
            BeakSaveOperation(
              id: 'detach',
              kind: BeakSaveOperationKind.detach,
              target: const BeakRecordRef.existing('notes', 'n2'),
              related: const BeakRecordRef.existing('labels', 'l1'),
              relationKey: 'labels',
            ),
          ],
        );
        final result = await commit(plan, token: editorToken);
        expect(result.complete, isFalse);
        expect(result.outcomes.single.error?.code, 'not_found');
      },
    );
  });

  group('uploads', () {
    Future<String> storedAvatar() async {
      final response = await handler(
        _multipart(
          '/api/notes/avatar/upload',
          editorToken,
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      expect(response.statusCode, 201);
      return BeakStoredFile.fromJson(await objectOf(response)).key;
    }

    test('upload: 401 anonymous, 403 reader, 201 editor', () async {
      final anonymous = await handler(
        Request('POST', Uri.parse('http://localhost/api/notes/avatar/upload')),
      );
      expect(anonymous.statusCode, 401);
      final reader = await handler(
        _multipart(
          '/api/notes/avatar/upload',
          readerToken,
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      expect(reader.statusCode, 403);
      expect(await storedAvatar(), startsWith('avatars/'));
    });

    test('an unknown column is a 404 and a plain column a 422', () async {
      final unknown = await handler(
        _multipart(
          '/api/notes/bogus/upload',
          editorToken,
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      expect(unknown.statusCode, 404);
      final plain = await handler(
        _multipart(
          '/api/notes/title/upload',
          editorToken,
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      expect(plain.statusCode, 422);
    });

    test('url: 401 anonymous, then only for a file on a visible row', () async {
      final key = await storedAvatar();
      await source.update('notes', 'n1', BeakRecord.fromRow({'avatar': key}));
      final path = Uri.http('localhost', '/api/notes/avatar/upload', {
        'key': key,
      });
      Future<int> read({String? token}) async => (await handler(
        Request(
          'GET',
          path,
          headers: {if (token != null) 'authorization': 'Bearer $token'},
        ),
      )).statusCode;
      expect(await read(), 401);
      expect(await read(token: editorToken), 200);
      expect(await read(token: readerToken), 404);
      expect(await read(token: rivalToken), 404);
    });

    test('remove: needs the delete access', () async {
      final key = await storedAvatar();
      Future<int> remove({String? token}) async => (await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/notes/avatar/upload'),
          headers: {if (token != null) 'authorization': 'Bearer $token'},
          body: jsonEncode({'key': key}),
        ),
      )).statusCode;
      expect(await remove(), 401);
      expect(await remove(token: readerToken), 403);
      expect(await remove(token: editorToken), 403);
      expect(await storage.exists(key), isTrue);
      expect(await remove(token: managerToken), 204);
      expect(await storage.exists(key), isFalse);
    });
  });

  group('actions', () {
    late Handler archiving;
    late BeakModelRegistry archiveRegistry;

    setUp(() {
      archiveRegistry = BeakModelRegistry()
        ..register(const _ArchivableNote())
        ..register(const LabelModel())
        ..register(const CommentModel())
        ..register(const AuthorModel());
      archiving = serve(
        _policies(
          notes: const _ArchivableNote(),
          actions: {_ArchivableNote.archive: _editor},
        ),
        models: archiveRegistry,
      );
    });

    BeakSavePlan archive(String saveId, String action) => BeakSavePlan(
      saveId: saveId,
      root: const BeakRecordRef.existing('notes', 'n1'),
      action: action,
      operations: [
        BeakSaveOperation(
          id: 'op',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('notes', 'n1'),
          values: BeakRecord.fromRow({'title': 'Archived'}),
        ),
      ],
    );

    Future<BeakSaveResult> run(
      String saveId,
      String action, {
      String? token,
    }) async => BeakSaveResult.fromJson(
      await objectOf(
        await call(
          'POST',
          '/api/commits',
          body: archive(saveId, action).toJson(),
          token: token,
          on: archiving,
        ),
      ),
    );

    test('a listed action runs for the role that may', () async {
      final result = await run('archive', 'archive', token: editorToken);
      expect(result.complete, isTrue);
    });

    test('a listed action is refused to anyone else', () async {
      final anonymous = await run('archive-anon', 'archive');
      expect(anonymous.outcomes.single.error?.code, 'authentication');
      final reader = await run('archive-reader', 'archive', token: readerToken);
      expect(reader.outcomes.single.error?.code, 'authorization');
    });

    test(
      'a declared action that no rule lists is refused to everyone',
      () async {
        final result = await run('restore', 'restore', token: managerToken);
        expect(result.complete, isFalse);
        expect(result.outcomes.single.error?.code, 'authorization');
      },
    );

    test('capabilities offer only the actions the principal may run', () async {
      Future<Set<String>?> offered(String token) async {
        final response = await call(
          'GET',
          '/api/notes/capabilities?id=n1',
          token: token,
          on: archiving,
        );
        return BeakAccessCapabilities.fromJson(
          await objectOf(response),
        ).executableActions;
      }

      final ownerWithoutRoles = await store.createSession(
        const BeakPrincipal(id: 'a1'),
      );
      expect(await offered(editorToken), {'archive'});
      expect(await offered(ownerWithoutRoles), isEmpty);
    });
  });

  group('an anonymous request under a public read rule', () {
    test('sees the unscoped rows but none of a scoped model', () async {
      final open = serve(
        BeakPolicies(
          rules: [
            BeakModelRules(const LabelModel(), read: BeakAccess.anyone),
            BeakModelRules(
              const NoteModel(),
              read: BeakAccess.anyone,
              rowScope: (principal) => NoteModel.authorId.eq(principal.id),
            ),
          ],
        ),
      );
      final labels = await call(
        'POST',
        '/api/labels/query',
        body: const BeakQuerySpec(table: 'labels').toJson(),
        on: open,
      );
      expect(await itemsOf(labels), hasLength(1));
      final notes = await call(
        'POST',
        '/api/notes/query',
        body: querySpec,
        on: open,
      );
      expect(notes.statusCode, 200);
      expect(await itemsOf(notes), isEmpty);
    });
  });
}
