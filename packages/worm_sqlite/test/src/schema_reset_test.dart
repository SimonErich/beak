import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  late SqliteAdapter adapter;
  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    // Forward declarations and cycles are valid SQLite schema definitions.
    await adapter.rawExecute(
      'CREATE TABLE children (id TEXT PRIMARY KEY, '
      'parent_id TEXT REFERENCES parents(id) ON DELETE RESTRICT)',
      const [],
    );
    await adapter.rawExecute(
      'CREATE TABLE parents (id TEXT PRIMARY KEY)',
      const [],
    );
    await adapter.rawExecute("INSERT INTO parents VALUES ('parent')", const []);
    await adapter.rawExecute(
      "INSERT INTO children VALUES ('child', 'parent')",
      const [],
    );
  });
  tearDown(() => adapter.disconnect());

  Future<void> checksAreImmediate() async {
    expect(
      (await adapter.rawQuery(
        'PRAGMA foreign_keys',
        const [],
      )).single.values.single,
      1,
    );
    expect(
      (await adapter.rawQuery(
        'PRAGMA defer_foreign_keys',
        const [],
      )).single.values.single,
      0,
    );
    await expectLater(
      adapter.rawExecute(
        "INSERT INTO children VALUES ('orphan', 'missing')",
        const [],
      ),
      throwsA(isA<ForeignKeyException>()),
    );
  }

  test('reset drops referenced tables and restores immediate checks', () async {
    await adapter.resetSchema((tx) async {
      await tx.rawExecute('DROP TABLE parents', const []);
      await tx.rawExecute('DROP TABLE children', const []);
      await tx.rawExecute(
        'CREATE TABLE parents (id TEXT PRIMARY KEY)',
        const [],
      );
      await tx.rawExecute(
        'CREATE TABLE children (id TEXT PRIMARY KEY, '
        'parent_id TEXT REFERENCES parents(id))',
        const [],
      );
    });
    expect(await adapter.rawQuery('SELECT * FROM children', const []), isEmpty);
    await checksAreImmediate();
  });

  test(
    'failed reset rolls back dropped tables and restores checking',
    () async {
      await expectLater(
        adapter.resetSchema((tx) async {
          await tx.rawExecute('DROP TABLE parents', const []);
          throw StateError('Broken replacement migration');
        }),
        throwsStateError,
      );
      expect(
        (await adapter.rawQuery(
          'SELECT * FROM parents',
          const [],
        )).single['id'],
        'parent',
      );
      expect(
        (await adapter.rawQuery(
          'SELECT * FROM children',
          const [],
        )).single['id'],
        'child',
      );
      await checksAreImmediate();
    },
  );

  test(
    'unmigrated external references prevent reset commit and preserve data',
    () async {
      await expectLater(
        adapter.resetSchema((tx) async {
          await tx.rawExecute('DROP TABLE parents', const []);
          await tx.rawExecute(
            'CREATE TABLE parents (id TEXT PRIMARY KEY)',
            const [],
          );
        }),
        throwsA(isA<Exception>()),
      );
      expect(
        (await adapter.rawQuery(
          'SELECT * FROM parents',
          const [],
        )).single['id'],
        'parent',
      );
      await checksAreImmediate();
    },
  );

  test('ordinary transactions never defer foreign-key checks', () async {
    await adapter.transaction((tx) async {
      await expectLater(
        tx.rawExecute('DELETE FROM parents', const []),
        throwsA(
          isA<ForeignKeyException>().having(
            (error) => error.message,
            'message',
            contains('FOREIGN KEY'),
          ),
        ),
      );
      expect(
        (await tx.rawQuery('SELECT * FROM parents', const [])).single['id'],
        'parent',
      );
    });
    await checksAreImmediate();
  });
}
