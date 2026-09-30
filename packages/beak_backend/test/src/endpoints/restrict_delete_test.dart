/// A parent that a child restricts (`ON DELETE RESTRICT`) cannot be deleted.
/// The caller asked for something the data forbids, so both the direct
/// `DELETE` and a delete inside a graph commit answer with a conflict, never
/// with an opaque 500.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

final class _ShelfModel extends BeakModel {
  const _ShelfModel();

  @override
  String get table => 'shelves';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

final class _BookModel extends BeakModel {
  const _BookModel();

  @override
  String get table => 'books';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakStringColumn(key: 'shelf_id', label: 'Shelf'),
  ];
}

void main() {
  late SqliteAdapter sqlite;
  late Handler handler;

  setUp(() async {
    sqlite = SqliteAdapter.memory();
    await sqlite.connect();
    await sqlite.rawExecute(
      'CREATE TABLE shelves (id TEXT PRIMARY KEY, name TEXT)',
      const [],
    );
    await sqlite.rawExecute(
      'CREATE TABLE books (id TEXT PRIMARY KEY, title TEXT, shelf_id TEXT '
      'NOT NULL REFERENCES shelves (id) ON DELETE RESTRICT)',
      const [],
    );
    await sqlite.rawExecute(
      "INSERT INTO shelves (id, name) VALUES ('s1', 'Poetry')",
      const [],
    );
    await sqlite.rawExecute(
      "INSERT INTO books (id, title, shelf_id) VALUES ('b1', 'Odes', 's1')",
      const [],
    );
    await const BeakCommitReceiptsMigration().up(sqlite);
    final registry = BeakModelRegistry()
      ..register(const _ShelfModel())
      ..register(const _BookModel());
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

  test('a direct DELETE of a restricted parent is a 409', () async {
    final response = await call('DELETE', '/api/shelves/s1');

    expect(response.statusCode, 409);
    expect(
      jsonDecode(await response.readAsString()),
      containsPair('code', 'conflict'),
    );
    expect(
      await sqlite.selectOne(const QueryDescriptor(table: 'shelves')),
      isNotNull,
    );
  });

  test('a delete inside a graph commit is refused, not unknown', () async {
    final response = await call(
      'POST',
      '/api/commits',
      body: BeakSavePlan(
        saveId: 'restrict-delete',
        root: const BeakRecordRef.existing('shelves', 's1'),
        operations: [
          BeakSaveOperation(
            id: 'op',
            kind: BeakSaveOperationKind.delete,
            target: const BeakRecordRef.existing('shelves', 's1'),
          ),
        ],
      ).toJson(),
    );

    final text = await response.readAsString();
    expect(text, isNot(contains('could not be confirmed')));
    expect(text, contains('still referenced'));
    expect(
      await sqlite.selectOne(const QueryDescriptor(table: 'shelves')),
      isNotNull,
    );
  });
}
