/// Very-complex query benchmark against live (in-process) SQLite:
/// multiple relationships + nested eager load + grouped aggregates,
/// measuring SELECT count (no N+1) and wall-clock.
@Tags(<String>['performance'])
@TestOn('vm')
library;

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// Counts `select` / `selectOne` calls reaching the real adapter so the
/// benchmark can prove query count stays constant as data grows.
final class _CountingSqlite extends DatabaseAdapter with ExplainCapable {
  _CountingSqlite(this._inner) : super(capabilities: _inner.capabilities);
  final SqliteAdapter _inner;
  int selects = 0;

  @override
  AdapterType get adapterType => _inner.adapterType;
  @override
  Future<void> connect() => _inner.connect();
  @override
  Future<void> disconnect() => _inner.disconnect();
  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) {
    selects++;
    return _inner.select(d);
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) {
    selects++;
    return _inner.selectOne(d);
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) => _inner.insert(d);
  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      _inner.insertMany(d);
  @override
  Future<int> update(UpdateDescriptor d) => _inner.update(d);
  @override
  Future<int> delete(DeleteDescriptor d) => _inner.delete(d);
  @override
  Future<int> count(AggregateDescriptor d) => _inner.count(d);
  @override
  Future<num?> sum(AggregateDescriptor d) => _inner.sum(d);
  @override
  Future<double?> avg(AggregateDescriptor d) => _inner.avg(d);
  @override
  Future<Object?> min(AggregateDescriptor d) => _inner.min(d);
  @override
  Future<Object?> max(AggregateDescriptor d) => _inner.max(d);
  @override
  Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor d) {
    selects++;
    return _inner.aggregateGrouped(d);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String q, List<Object?> p) =>
      _inner.rawQuery(q, p);
  @override
  Future<int> rawExecute(String s, List<Object?> p) => _inner.rawExecute(s, p);
  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) a) =>
      _inner.transaction(a);
  @override
  Future<void> executeSchema(SchemaDescriptor d) => _inner.executeSchema(d);
  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _inner.introspectSchema();
  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) => _inner.stream(d);
  @override
  String compileToString(Object d) => _inner.compileToString(d);
  @override
  Future<ExplainResult> explain(QueryDescriptor d) => _inner.explain(d);
}

final class _User extends Model {
  _User.fromRow(this._row) {
    markPersisted();
  }
  final Map<String, Object?> _row;
  @override
  Object get id => _row['id'] ?? 0;
  @override
  Map<String, Object?> toRow() => Map<String, Object?>.unmodifiable(_row);
}

final class _Post extends Model {
  _Post.fromRow(this._row) {
    markPersisted();
  }
  final Map<String, Object?> _row;
  @override
  Object get id => _row['id'] ?? 0;
  @override
  Map<String, Object?> toRow() => Map<String, Object?>.unmodifiable(_row);
}

final class _Comment extends Model {
  _Comment.fromRow(this._row) {
    markPersisted();
  }
  final Map<String, Object?> _row;
  @override
  Object get id => _row['id'] ?? 0;
  @override
  Map<String, Object?> toRow() => Map<String, Object?>.unmodifiable(_row);
}

void main() {
  test('complex multi-relation + nested + grouped aggregates: constant '
      'SELECT count, measured timing', () async {
    const users = 500;
    const postsPerUser = 5;
    const commentsPerPost = 3;

    final inner = SqliteAdapter(sqlite3.openInMemory());
    await inner.connect();
    for (final ddl in <SchemaDescriptor>[
      const SchemaDescriptor.createTable(
        table: 'users',
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
          ),
          SchemaColumn(name: 'name', type: ColumnType.string),
        ],
      ),
      const SchemaDescriptor.createTable(
        table: 'posts',
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
          ),
          SchemaColumn(name: 'user_id', type: ColumnType.integer),
          SchemaColumn(name: 'views', type: ColumnType.integer),
        ],
      ),
      const SchemaDescriptor.createTable(
        table: 'comments',
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
          ),
          SchemaColumn(name: 'post_id', type: ColumnType.integer),
        ],
      ),
    ]) {
      await inner.executeSchema(ddl);
    }
    await inner.insertMany(
      InsertManyDescriptor(
        table: 'users',
        rows: <Map<String, Object?>>[
          for (var i = 1; i <= users; i++)
            <String, Object?>{'id': i, 'name': 'user-$i'},
        ],
      ),
    );
    var postId = 0;
    var commentId = 0;
    final posts = <Map<String, Object?>>[];
    final comments = <Map<String, Object?>>[];
    for (var u = 1; u <= users; u++) {
      for (var p = 0; p < postsPerUser; p++) {
        postId++;
        posts.add(<String, Object?>{
          'id': postId,
          'user_id': u,
          'views': p * 10,
        });
        for (var c = 0; c < commentsPerPost; c++) {
          commentId++;
          comments.add(<String, Object?>{'id': commentId, 'post_id': postId});
        }
      }
    }
    await inner.insertMany(InsertManyDescriptor(table: 'posts', rows: posts));
    await inner.insertMany(
      InsertManyDescriptor(table: 'comments', rows: comments),
    );

    final counting = _CountingSqlite(inner);
    final context = QueryContext<_User>(
      adapter: counting,
      table: 'users',
      hydrate: _User.fromRow,
      relations: <String, Relation<Model, Model>>{
        'posts': const HasManyRelation<Model, Model>(
          name: 'posts',
          childTable: 'posts',
          foreignKey: 'user_id',
          hydrateChild: _Post.fromRow,
        ),
        'comments': const HasManyRelation<Model, Model>(
          name: 'comments',
          childTable: 'comments',
          foreignKey: 'post_id',
          hydrateChild: _Comment.fromRow,
        ),
      },
    );

    final sw = Stopwatch()..start();
    final loaded = await QueryBuilder<_User>.from(context)
        .withPath(
          const RelationField<Model, Model>(
            'posts',
            foreignKey: 'user_id',
          ).include(const <RelationField<Model, Model>>[
            RelationField<Model, Model>('comments', foreignKey: 'post_id'),
          ]),
        )
        .withCount('posts')
        .withSum('posts', 'views')
        .get();
    sw.stop();

    expect(loaded, hasLength(users));
    // posts loaded on each user, comments nested on each post.
    final first = loaded.first;
    expect(first.getRelation<List<Model>>('posts'), hasLength(postsPerUser));
    expect(first.getInjected<int>('postsCount'), postsPerUser);

    // 1 users SELECT + 1 posts SELECT + 1 comments SELECT (nested,
    // batched) + 1 grouped count + 1 grouped sum = 5, regardless of the
    // ${users * postsPerUser * commentsPerPost} rows involved.
    expect(
      counting.selects,
      5,
      reason: 'complex query must stay at a constant SELECT count',
    );
    // Generous wall-clock budget for $users users / ${posts.length} posts
    // / ${comments.length} comments on in-process SQLite.
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    // ignore: avoid_print
    print(
      'SQLite complex query: $users users, ${posts.length} posts, '
      '${comments.length} comments → ${counting.selects} SELECTs in '
      '${sw.elapsedMilliseconds} ms',
    );
    await inner.disconnect();
  });

  test('hot loop reuses prepared statements (low miss rate, high '
      'throughput)', () async {
    const rows = 10000;
    final adapter = SqliteAdapter(sqlite3.openInMemory());
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'events',
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
          ),
          SchemaColumn(name: 'kind', type: ColumnType.string),
        ],
      ),
    );

    // Batched bulk insert.
    final insert = Stopwatch()..start();
    await adapter.insertMany(
      InsertManyDescriptor(
        table: 'events',
        rows: <Map<String, Object?>>[
          for (var i = 1; i <= rows; i++)
            <String, Object?>{'id': i, 'kind': 'k${i % 5}'},
        ],
      ),
    );
    insert.stop();

    // Hot loop of identical (differently-bound) selects: the SQL is the
    // same so the prepared statement is compiled once and reused.
    adapter.preparedStatementCache.clear();
    final select = Stopwatch()..start();
    for (var i = 1; i <= rows; i++) {
      await adapter.select(
        QueryDescriptor(
          table: 'events',
          where: const Field<int>('id').eq(i),
          limit: 1,
        ),
      );
    }
    select.stop();

    // One cold compile, then $rows - 1 reuses.
    expect(adapter.preparedStatementCache.missRate, lessThan(0.001));
    expect(adapter.preparedStatementCache.length, 1);
    final missRate = adapter.preparedStatementCache.missRate.toStringAsFixed(5);
    final insertMs = insert.elapsedMilliseconds;
    final selectMs = select.elapsedMilliseconds;
    // ignore: avoid_print
    print(
      'SQLite hot loop: bulk-insert $rows rows in $insertMs ms; '
      '$rows cached selects in $selectMs ms (miss rate $missRate)',
    );
    await adapter.disconnect();
  });
}
