/// Live in-process integration tests for [SqliteAdapter]: error
/// mapping, transactions, and the worm-core eager-load path.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// Minimal row-backed model for eager-loading integration.
final class _EUser extends Model {
  _EUser.fromRow(this._row) {
    markPersisted();
  }
  final Map<String, Object?> _row;
  @override
  Object get id => _row['id'] ?? 0;
  @override
  Map<String, Object?> toRow() => Map<String, Object?>.unmodifiable(_row);
}

final class _EPost extends Model {
  _EPost.fromRow(this._row) {
    markPersisted();
  }
  final Map<String, Object?> _row;
  @override
  Object get id => _row['id'] ?? 0;
  @override
  Map<String, Object?> toRow() => Map<String, Object?>.unmodifiable(_row);
}

Future<SqliteAdapter> _seeded() async {
  final adapter = SqliteAdapter.memory();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
        SchemaColumn(name: 'name', type: ColumnType.string),
      ],
    ),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'posts',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
        SchemaColumn(name: 'user_id', type: ColumnType.integer),
        SchemaColumn(name: 'views', type: ColumnType.integer),
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'users',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Alice'},
        <String, Object?>{'id': 2, 'name': 'Bob'},
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'posts',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 10, 'user_id': 1, 'views': 100},
        <String, Object?>{'id': 11, 'user_id': 1, 'views': 50},
        <String, Object?>{'id': 12, 'user_id': 2, 'views': 7},
      ],
    ),
  );
  return adapter;
}

void main() {
  test(
    'unique constraint violation maps to UniqueConstraintException',
    () async {
      final adapter = SqliteAdapter.memory();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'widgets',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
          ],
        ),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 1},
        ),
      );
      await expectLater(
        adapter.insert(
          const InsertDescriptor(
            table: 'widgets',
            values: <String, Object?>{'id': 1},
          ),
        ),
        throwsA(isA<UniqueConstraintException>()),
      );
      await adapter.disconnect();
    },
  );

  test('transaction rolls back writes on throw', () async {
    final adapter = await _seeded();
    await expectLater(
      adapter.transaction((tx) async {
        await tx.insert(
          const InsertDescriptor(
            table: 'users',
            values: <String, Object?>{'id': 3, 'name': 'Carol'},
          ),
        );
        throw StateError('boom');
      }),
      throwsA(isA<StateError>()),
    );
    final count = await adapter.count(
      const AggregateDescriptor.count(table: 'users'),
    );
    expect(count, 2);
    await adapter.disconnect();
  });

  test('eager load + grouped count/sum aggregates resolve correctly', () async {
    final adapter = await _seeded();
    final context = QueryContext<_EUser>(
      adapter: adapter,
      table: 'users',
      hydrate: _EUser.fromRow,
      relations: <String, Relation<Model, Model>>{
        'posts': const HasManyRelation<Model, Model>(
          name: 'posts',
          childTable: 'posts',
          foreignKey: 'user_id',
          hydrateChild: _EPost.fromRow,
        ),
      },
    );

    final users = await QueryBuilder<_EUser>.from(context)
        .orderBy(const Field<int>('id'))
        .withRelationPaths(const <String>['posts'])
        .withCount('posts')
        .withSum('posts', 'views')
        .get();

    expect(users, hasLength(2));
    expect(users.first.getRelation<List<Model>>('posts'), hasLength(2));
    expect(users.first.getInjected<int>('postsCount'), 2);
    expect(users.first.getInjected<num>('postsSum'), 150);
    expect(users[1].getInjected<int>('postsCount'), 1);
    await adapter.disconnect();
  });
}
