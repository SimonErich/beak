/// Shared fixtures for QueryBuilder / relation tests.
library;

import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/relation/belongs_to.dart';
import 'package:worm/src/relation/has_many.dart';
import 'package:worm/src/relation/relation_base.dart';

T _read<T>(Map<String, Object?> row, String key, T fallback) {
  final value = row[key];
  if (value is T) return value;
  return fallback;
}

T? _readNullable<T>(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is T) return value;
  return null;
}

/// Simple test user model.
final class TestUser extends Model {
  /// Creates a [TestUser].
  TestUser({
    required this.userId,
    required this.name,
    required this.age,
    this.deletedAt,
  });

  /// Hydrate from a raw row using pattern matching.
  factory TestUser.fromRow(Map<String, Object?> row) => TestUser(
    userId: _read<int>(row, 'id', 0),
    name: _read<String>(row, 'name', ''),
    age: _read<int>(row, 'age', 0),
    deletedAt: _readNullable<String>(row, 'deleted_at'),
  );

  /// Integer primary key.
  final int userId;

  /// User name.
  final String name;

  /// User age.
  final int age;

  /// Soft-deleted timestamp string, or null.
  final String? deletedAt;

  @override
  Object get id => userId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': userId,
    'name': name,
    'age': age,
    'deleted_at': deletedAt,
  };
}

/// Simple test post model.
final class TestPost extends Model {
  /// Creates a [TestPost].
  TestPost({
    required this.postId,
    required this.userId,
    required this.title,
    required this.views,
  });

  /// Hydrate from a raw row using pattern matching.
  factory TestPost.fromRow(Map<String, Object?> row) => TestPost(
    postId: _read<int>(row, 'id', 0),
    userId: _read<int>(row, 'user_id', 0),
    title: _read<String>(row, 'title', ''),
    views: _read<int>(row, 'views', 0),
  );

  /// Integer primary key.
  final int postId;

  /// FK to users.
  final int userId;

  /// Post title.
  final String title;

  /// Number of views.
  final int views;

  @override
  Object get id => postId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': postId,
    'user_id': userId,
    'title': title,
    'views': views,
  };
}

/// Build an adapter pre-loaded with users + posts.
Future<InMemoryAdapter> seededAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'posts'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'users',
      rows: <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'name': 'Alice',
          'age': 30,
          'deleted_at': null,
        },
        <String, Object?>{
          'id': 2,
          'name': 'Bob',
          'age': 25,
          'deleted_at': null,
        },
        <String, Object?>{
          'id': 3,
          'name': 'Carol',
          'age': 40,
          'deleted_at': '2024-01-01',
        },
        <String, Object?>{
          'id': 4,
          'name': 'Dave',
          'age': 35,
          'deleted_at': null,
        },
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'posts',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 10, 'user_id': 1, 'title': 'A1', 'views': 100},
        <String, Object?>{'id': 11, 'user_id': 1, 'title': 'A2', 'views': 200},
        <String, Object?>{'id': 12, 'user_id': 2, 'title': 'B1', 'views': 50},
        <String, Object?>{'id': 13, 'user_id': 4, 'title': 'D1', 'views': 0},
      ],
    ),
  );
  return adapter;
}

/// Build a QueryContext for [TestUser].
QueryContext<TestUser> userContext(
  InMemoryAdapter adapter, {
  Map<String, Relation<Model, Model>> relations =
      const <String, Relation<Model, Model>>{},
}) => QueryContext<TestUser>(
  adapter: adapter,
  table: 'users',
  hydrate: TestUser.fromRow,
  relations: relations,
);

/// Build a QueryContext for [TestPost].
QueryContext<TestPost> postContext(InMemoryAdapter adapter) =>
    QueryContext<TestPost>(
      adapter: adapter,
      table: 'posts',
      hydrate: TestPost.fromRow,
    );

/// Build a HasMany relation: User -> posts.
HasManyRelation<Model, Model> userPostsRelation() =>
    const HasManyRelation<Model, Model>(
      name: 'posts',
      childTable: 'posts',
      foreignKey: 'user_id',
      hydrateChild: TestPost.fromRow,
    );

/// Build a BelongsTo relation: Post -> user.
BelongsToRelation<Model, Model> postUserRelation() =>
    const BelongsToRelation<Model, Model>(
      name: 'user',
      parentTable: 'users',
      foreignKey: 'user_id',
      hydrateParent: TestUser.fromRow,
    );
