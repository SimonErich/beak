/// Very-complex query benchmark against a live MySQL service: multiple
/// relationships + nested eager load + grouped aggregates, proving the
/// SELECT count stays constant (no N+1) and measuring wall-clock.
///
/// Gated by `MYSQL_URL` and tagged `performance`.
@Tags(<String>['performance'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mysql/worm_mysql.dart';

/// Counts `select` / `selectOne` / `aggregateGrouped` calls reaching the
/// real adapter so the benchmark can prove query count stays constant as
/// the data set grows.
final class _CountingAdapter extends DatabaseAdapter with ExplainCapable {
  _CountingAdapter(this._inner) : super(capabilities: _inner.capabilities);
  final MysqlAdapter _inner;
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
  final url = Platform.environment['MYSQL_URL'];
  if (url == null || url.isEmpty) {
    test(
      'MysqlAdapter complex/perf suite skipped — MYSQL_URL unset',
      () {},
      skip:
          'Set MYSQL_URL (mysql://user:pass@host:port/db) to '
          'run the MySQL complex-query benchmark.',
    );
    return;
  }

  test('complex multi-relation + nested + grouped aggregates: constant '
      'SELECT count, measured timing', () async {
    const users = 500;
    const postsPerUser = 5;
    const commentsPerPost = 3;

    final inner = MysqlAdapter(pool: MysqlConnectionPool.fromUri(url));
    await inner.connect();
    for (final table in <String>['perf_comments', 'perf_posts', 'perf_users']) {
      await inner.executeSchema(
        SchemaDescriptor.dropTable(table: table, ifExists: true),
      );
    }
    for (final ddl in <SchemaDescriptor>[
      const SchemaDescriptor.createTable(
        table: 'perf_users',
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
        table: 'perf_posts',
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
        table: 'perf_comments',
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
        table: 'perf_users',
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
    await inner.insertMany(
      InsertManyDescriptor(table: 'perf_posts', rows: posts),
    );
    await inner.insertMany(
      InsertManyDescriptor(table: 'perf_comments', rows: comments),
    );

    final counting = _CountingAdapter(inner);
    final context = QueryContext<_User>(
      adapter: counting,
      table: 'perf_users',
      hydrate: _User.fromRow,
      relations: <String, Relation<Model, Model>>{
        'posts': const HasManyRelation<Model, Model>(
          name: 'posts',
          childTable: 'perf_posts',
          foreignKey: 'user_id',
          hydrateChild: _Post.fromRow,
        ),
        'comments': const HasManyRelation<Model, Model>(
          name: 'comments',
          childTable: 'perf_comments',
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
    expect(sw.elapsed, lessThan(const Duration(seconds: 60)));
    // ignore: avoid_print
    print(
      'MySQL complex query: $users users, ${posts.length} posts, '
      '${comments.length} comments → ${counting.selects} SELECTs in '
      '${sw.elapsedMilliseconds} ms',
    );

    for (final table in <String>['perf_comments', 'perf_posts', 'perf_users']) {
      await inner.executeSchema(
        SchemaDescriptor.dropTable(table: table, ifExists: true),
      );
    }
    await inner.disconnect();
  });
}
