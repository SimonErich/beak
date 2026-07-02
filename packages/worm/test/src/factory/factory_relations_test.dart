/// Relationship helpers (`has` / `for_`) on Factory and _FactoryPlan.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/factory/factory.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';
import 'package:worm/src/relation/relation_field.dart';

final class _User extends Model {
  _User({required int id}) {
    setAttribute('id', id);
  }

  @override
  String get tableName => 'users';

  @override
  Object get id => getAttribute('id') ?? 0;

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};
}

final class _Post extends Model {
  _Post({required int id, int? userId}) {
    setAttribute('id', id);
    if (userId != null) setAttribute('user_id', userId);
  }

  @override
  String get tableName => 'posts';

  @override
  Object get id => getAttribute('id') ?? 0;

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};

  int? get userId {
    final value = getAttribute('user_id');
    return value is int ? value : null;
  }
}

final class _Comment extends Model {
  _Comment({required int id, int? userId}) {
    setAttribute('id', id);
    if (userId != null) setAttribute('user_id', userId);
  }

  @override
  String get tableName => 'comments';

  @override
  Object get id => getAttribute('id') ?? 0;

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};

  int? get userId {
    final value = getAttribute('user_id');
    return value is int ? value : null;
  }
}

abstract final class _User$ {
  _User$._();
  static const RelationField<_User, _Post> posts = RelationField<_User, _Post>(
    'posts',
    foreignKey: 'user_id',
  );
  static const RelationField<_User, _Comment> comments =
      RelationField<_User, _Comment>('comments', foreignKey: 'user_id');
}

int _nextUserId = 0;
int _nextPostId = 0;
int _nextCommentId = 0;

final class _UserFactory extends Factory<_User> {
  _UserFactory();

  @override
  _User definition() {
    _nextUserId++;
    return _User(id: _nextUserId);
  }
}

final class _PostFactory extends Factory<_Post> {
  _PostFactory();

  @override
  _Post definition() {
    _nextPostId++;
    return _Post(id: _nextPostId);
  }
}

final class _CommentFactory extends Factory<_Comment> {
  _CommentFactory();

  @override
  _Comment definition() {
    _nextCommentId++;
    return _Comment(id: _nextCommentId);
  }
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    _nextUserId = 0;
    _nextPostId = 0;
    _nextCommentId = 0;
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'users'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'posts'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'comments'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('Factory.has(...)', () {
    test('persists 1 parent + child plan with FK linked to parent', () async {
      final users = await _UserFactory()
          .has(_PostFactory().count(3), _User$.posts)
          .create();
      expect(users, hasLength(1));
      final parentId = users.single.id;

      final postRows = await adapter.select(
        const QueryDescriptor(table: 'posts'),
      );
      expect(postRows, hasLength(3));
      for (final row in postRows) {
        expect(row['user_id'], parentId);
      }
    });

    test('multiple has() calls register independent relationships', () async {
      final users = await _UserFactory()
          .has(_PostFactory().count(2), _User$.posts)
          .has(_CommentFactory().count(4), _User$.comments)
          .create();
      expect(users, hasLength(1));
      final parentId = users.single.id;

      final postRows = await adapter.select(
        const QueryDescriptor(table: 'posts'),
      );
      final commentRows = await adapter.select(
        const QueryDescriptor(table: 'comments'),
      );
      expect(postRows, hasLength(2));
      expect(commentRows, hasLength(4));
      expect(postRows.every((r) => r['user_id'] == parentId), isTrue);
      expect(commentRows.every((r) => r['user_id'] == parentId), isTrue);
    });

    test('count(N).has() persists N parents and N*childCount children with '
        'correct FKs per parent', () async {
      final users = await _UserFactory()
          .count(2)
          .has(_PostFactory().count(3), _User$.posts)
          .create();
      expect(users, hasLength(2));
      final parentIds = users.map((u) => u.id).toList();

      final postRows = await adapter.select(
        const QueryDescriptor(table: 'posts'),
      );
      expect(postRows, hasLength(6));

      // Each parent should own exactly 3 posts.
      for (final parentId in parentIds) {
        final owned = postRows.where((r) => r['user_id'] == parentId).toList();
        expect(owned, hasLength(3));
      }
    });
  });

  group('Factory.for_(...)', () {
    test('pre-fills the FK column on every produced instance', () async {
      final parent = await _UserFactory().create();
      final posts = await _PostFactory()
          .for_(parent, _User$.posts)
          .count(3)
          .create();
      expect(posts, hasLength(3));
      for (final post in posts) {
        expect(post.userId, parent.id);
      }
      final postRows = await adapter.select(
        const QueryDescriptor(table: 'posts'),
      );
      expect(postRows, hasLength(3));
      expect(postRows.every((r) => r['user_id'] == parent.id), isTrue);
    });
  });

  group('Plan chaining', () {
    test('has() chained on a count() plan keeps the parent count', () async {
      final users = await _UserFactory()
          .count(2)
          .has(_PostFactory().count(2), _User$.posts)
          .create();
      expect(users, hasLength(2));
      final postRows = await adapter.select(
        const QueryDescriptor(table: 'posts'),
      );
      expect(postRows, hasLength(4));
    });
  });
}
