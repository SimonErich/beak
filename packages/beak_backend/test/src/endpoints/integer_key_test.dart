/// A table whose primary key is a serial integer the database assigns, the
/// shape of most legacy schemas: create must leave the id to the database,
/// and every id-taking route must accept it as a number.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../../support/test_models.dart';

void main() {
  late SqliteAdapter sqlite;
  late Handler handler;

  setUp(() async {
    sqlite = SqliteAdapter.memory();
    await sqlite.connect();
    await sqlite.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'categories',
        columns: [
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            autoIncrement: true,
          ),
          SchemaColumn(name: 'name', type: ColumnType.text),
        ],
      ),
    );
    await const BeakCommitReceiptsMigration().up(sqlite);
    final registry = createTestRegistry();
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: sqlite),
          ),
        );
  });
  tearDown(() => sqlite.disconnect());

  Future<Response> call(String method, String path, {Object? body}) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  /// The decoded JSON object of [response], failing with its text when the
  /// status is not [status].
  Future<Map<String, Object?>> jsonOf(Response response, {int? status}) async {
    final text = await response.readAsString();
    if (status != null) expect(response.statusCode, status, reason: text);
    return switch (jsonDecode(text)) {
      final Map<String, Object?> map => map,
      final Object? other => fail('Expected a JSON object, got $other.'),
    };
  }

  Future<int> createOptics() async {
    final response = await call(
      'POST',
      '/api/categories',
      body: {'name': 'Optics'},
    );
    final created = BeakRecord.fromJson(await jsonOf(response, status: 201));
    return switch (created['id']?.raw) {
      final int id => id,
      final Object? other => fail('Expected a generated int id, got $other.'),
    };
  }

  test('create leaves the id to the database and returns it', () async {
    final id = await createOptics();

    expect(id, 1);
    final stored = await sqlite.selectOne(
      const QueryDescriptor(table: 'categories'),
    );
    expect(stored?['id'], 1);
    expect(stored?['name'], 'Optics');
  });

  test('get, update and delete take the id as a number', () async {
    final id = await createOptics();

    expect((await call('GET', '/api/categories/$id')).statusCode, 200);
    final updated = await call(
      'PATCH',
      '/api/categories/$id',
      body: {'name': 'Lenses'},
    );
    expect(
      BeakRecord.fromJson(await jsonOf(updated, status: 200))['name']?.raw,
      'Lenses',
    );
    expect((await call('DELETE', '/api/categories/$id')).statusCode, 204);
    expect((await call('GET', '/api/categories/$id')).statusCode, 404);
  });

  test('a graph commit creates, edits and deletes by numeric id', () async {
    BeakSavePlan plan(String saveId, BeakSaveOperation operation) =>
        BeakSavePlan(
          saveId: saveId,
          root: operation.target,
          operations: [operation],
        );
    Future<BeakSaveResult> commit(BeakSavePlan plan) async {
      final response = await call('POST', '/api/commits', body: plan.toJson());
      return BeakSaveResult.fromJson(await jsonOf(response, status: 200));
    }

    final created = await commit(
      plan(
        'create',
        BeakSaveOperation(
          id: 'c',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('categories', 'draft'),
          values: BeakRecord.fromRow({'name': 'Optics'}),
        ),
      ),
    );
    expect(created.complete, isTrue, reason: '${created.toJson()}');
    final Object? id = created.outcomes.single.resolvedId;
    expect(id, isA<int>());

    final ref = BeakRecordRef.existing('categories', id!);
    final edited = await commit(
      plan(
        'edit',
        BeakSaveOperation(
          id: 'e',
          kind: BeakSaveOperationKind.update,
          target: ref,
          values: BeakRecord.fromRow({'name': 'Lenses'}),
        ),
      ),
    );
    expect(edited.complete, isTrue, reason: '${edited.toJson()}');
    expect(edited.rootRecord?['name']?.raw, 'Lenses');

    final deleted = await commit(
      plan(
        'delete',
        BeakSaveOperation(
          id: 'd',
          kind: BeakSaveOperationKind.delete,
          target: ref,
        ),
      ),
    );
    expect(deleted.complete, isTrue, reason: '${deleted.toJson()}');
  });

  test('a body that sends its own numeric id keeps it', () async {
    final response = await call(
      'POST',
      '/api/categories',
      body: {'id': 42, 'name': 'Chosen'},
    );

    expect(
      BeakRecord.fromJson(await jsonOf(response, status: 201))['id']?.raw,
      42,
    );
  });
}
