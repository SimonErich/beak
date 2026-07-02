/// Typed relation accessors.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';
import 'package:worm/src/relation/belongs_to_many.dart';
import 'package:worm/src/relation/has_many.dart';
import 'package:worm/src/relation/relation_accessors.dart';

import '_fixtures.dart';

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'users'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'posts'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'roles'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'role_user'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('HasMany accessor: user.posts.add', () {
    test('add(post) persists with FK set and reload reflects it', () async {
      final user = TUser(userId: 1, name: 'Ada')..hydrateAttribute('id', 1);
      await user.save();

      final accessor = HasManyAccessor<TUser, TPost>(
        parent: user,
        relation: const HasManyRelation<TUser, TPost>(
          name: 'posts',
          childTable: 'posts',
          foreignKey: 'user_id',
          hydrateChild: TPost.fromRow,
        ),
      );

      final post = TPost(postId: 10, userId: 0, title: 'Hello');
      await accessor.add(post);

      // Foreign key was set on the child to the parent's id.
      final rows = await adapter.select(const QueryDescriptor(table: 'posts'));
      expect(rows, hasLength(1));
      expect(rows.single['user_id'], 1);
      expect(rows.single['title'], 'Hello');

      // user.posts list reflects the new post on next access.
      final loaded = await accessor.get();
      expect(loaded, hasLength(1));
      expect(loaded.single.postId, 10);
    });

    test('addAll persists every child with FK set', () async {
      final user = TUser(userId: 2, name: 'Grace');
      await user.save();
      final accessor = HasManyAccessor<TUser, TPost>(
        parent: user,
        relation: const HasManyRelation<TUser, TPost>(
          name: 'posts',
          childTable: 'posts',
          foreignKey: 'user_id',
          hydrateChild: TPost.fromRow,
        ),
      );
      await accessor.addAll(<TPost>[
        TPost(postId: 20, userId: 0, title: 'A'),
        TPost(postId: 21, userId: 0, title: 'B'),
      ]);
      final loaded = await accessor.get();
      expect(loaded, hasLength(2));
      expect(loaded.map((p) => p.title), containsAll(<String>['A', 'B']));
    });
  });

  group('BelongsToMany accessor: user.roles.sync', () {
    test('sync([1,2,3]) leaves exactly those pivot rows and removes '
        'previous rows for 4', () async {
      final user = TUser(userId: 7, name: 'Margaret');
      await user.save();

      final accessor = BelongsToManyAccessor<TUser, TRole>(
        parent: user,
        relation: const BelongsToManyRelation<TUser, TRole>(
          name: 'roles',
          relatedTable: 'roles',
          pivotTable: 'role_user',
          parentPivotKey: 'user_id',
          relatedPivotKey: 'role_id',
          hydrateRelated: TRole.fromRow,
        ),
      );

      // Seed initial pivot rows including role 4.
      await accessor.attachAll(<Object>[1, 2, 4]);

      await accessor.sync(<Object>[1, 2, 3]);

      final pivots = await adapter.select(
        const QueryDescriptor(table: 'role_user'),
      );
      final pivotRoles = pivots
          .map((r) => r['role_id'])
          .whereType<int>()
          .toSet();
      expect(pivotRoles, <int>{1, 2, 3});
      expect(pivotRoles.contains(4), isFalse);
      expect(pivots.every((r) => r['user_id'] == 7), isTrue);
    });

    test('attach + detach affect pivot state observably', () async {
      final user = TUser(userId: 8, name: 'Hedy');
      await user.save();
      final accessor = BelongsToManyAccessor<TUser, TRole>(
        parent: user,
        relation: const BelongsToManyRelation<TUser, TRole>(
          name: 'roles',
          relatedTable: 'roles',
          pivotTable: 'role_user',
          parentPivotKey: 'user_id',
          relatedPivotKey: 'role_id',
          hydrateRelated: TRole.fromRow,
        ),
      );

      await accessor.attach(11);
      await accessor.attach(12);
      var rows = await adapter.select(
        const QueryDescriptor(table: 'role_user'),
      );
      expect(rows, hasLength(2));

      final removed = await accessor.detach(11);
      expect(removed, 1);
      rows = await adapter.select(const QueryDescriptor(table: 'role_user'));
      expect(rows.single['role_id'], 12);
    });
  });
}
