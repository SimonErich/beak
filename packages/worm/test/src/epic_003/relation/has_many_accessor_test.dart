/// Runtime behavior tests for [HasManyAccessor] and [HasOneAccessor]:
/// add / list / dissociate (has-many) and set / clear (has-one).
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../_fixtures.dart';

const HasManyRelation<TUser, TArticle> _articlesRelation =
    HasManyRelation<TUser, TArticle>(
      name: 'articles',
      childTable: 'articles',
      foreignKey: 'author_id',
      hydrateChild: TArticle.fromRow,
    );

const HasOneRelation<TUser, TArticle> _profileRelation =
    HasOneRelation<TUser, TArticle>(
      name: 'profileArticle',
      childTable: 'articles',
      foreignKey: 'author_id',
      hydrateChild: TArticle.fromRow,
    );

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'users'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'articles'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('HasManyAccessor', () {
    test('add(child) sets FK and persists (child.exists is true)', () async {
      final user = TUser(userId: 1, name: 'Ada');
      await user.save();
      final accessor = HasManyAccessor<TUser, TArticle>(
        parent: user,
        relation: _articlesRelation,
      );

      final article = TArticle(articleId: 10, title: 'Notes');
      await accessor.add(article);

      expect(article.exists, isTrue);
      final rows = await adapter.select(
        const QueryDescriptor(table: 'articles'),
      );
      expect(rows.single['author_id'], 1);
      expect(rows.single['title'], 'Notes');
    });

    test('list() returns children with FK == parent.id', () async {
      final user = TUser(userId: 2, name: 'Grace');
      await user.save();
      final accessor = HasManyAccessor<TUser, TArticle>(
        parent: user,
        relation: _articlesRelation,
      );
      await accessor.add(TArticle(articleId: 20, title: 'A'));
      await accessor.add(TArticle(articleId: 21, title: 'B'));
      // Insert an orphan article with a different author so list()
      // proves it filters on author_id == user.id.
      final orphan = TArticle(articleId: 22, title: 'C', authorId: 999);
      await orphan.save();

      final list = await accessor.list();
      expect(list, hasLength(2));
      expect(list.map((a) => a.title), containsAll(<String>['A', 'B']));
      expect(list.every((a) => a.authorId == 2), isTrue);
    });

    test(
      'resolveAdapter override is invoked instead of Worm.adapter',
      () async {
        final user = TUser(userId: 4, name: 'Lovelace');
        await user.save();
        var resolverCalls = 0;
        final accessor = HasManyAccessor<TUser, TArticle>(
          parent: user,
          relation: _articlesRelation,
          resolveAdapter: () {
            resolverCalls += 1;
            return adapter;
          },
        );
        await accessor.add(TArticle(articleId: 40, title: 'Override'));

        // add() goes through Model.save which doesn't consume the
        // accessor's adapter, so list() is the call path that
        // exercises resolveAdapter.
        final list = await accessor.list();
        expect(list, hasLength(1));
        expect(resolverCalls, greaterThan(0));
      },
    );

    test('dissociate(child) nulls FK and saves', () async {
      final user = TUser(userId: 3, name: 'Hedy');
      await user.save();
      final accessor = HasManyAccessor<TUser, TArticle>(
        parent: user,
        relation: _articlesRelation,
      );
      final article = TArticle(articleId: 30, title: 'Detach');
      await accessor.add(article);

      await accessor.dissociate(article);

      // In-memory attribute reflects the null FK.
      expect(article.getAttribute('author_id'), isNull);
      // The DB row's author_id was updated to null.
      final rows = await adapter.select(
        const QueryDescriptor(table: 'articles'),
      );
      expect(rows.single['author_id'], isNull);
      // And list() now returns nothing for this parent.
      final list = await accessor.list();
      expect(list, isEmpty);
    });
  });

  group('HasOneAccessor', () {
    test('set(child) persists child with FK set', () async {
      final user = TUser(userId: 5, name: 'Margaret');
      await user.save();
      final accessor = HasOneAccessor<TUser, TArticle>(
        parent: user,
        relation: _profileRelation,
      );

      final profile = TArticle(articleId: 50, title: 'Bio');
      await accessor.set(profile);

      expect(profile.exists, isTrue);
      final found = await accessor.get();
      expect(found, isNotNull);
      expect(found!.articleId, 50);
      expect(found.authorId, 5);
    });

    test('clear() nulls FK on the existing child', () async {
      final user = TUser(userId: 6, name: 'Katherine');
      await user.save();
      final accessor = HasOneAccessor<TUser, TArticle>(
        parent: user,
        relation: _profileRelation,
      );
      await accessor.set(TArticle(articleId: 60, title: 'Bio'));

      await accessor.clear();

      // Re-load: HasOne with FK nulled returns null.
      final found = await accessor.get();
      expect(found, isNull);
      // The row still exists, just with author_id == null.
      final rows = await adapter.select(
        const QueryDescriptor(table: 'articles'),
      );
      expect(rows, hasLength(1));
      expect(rows.single['author_id'], isNull);
    });

    test('clear() is a no-op when no child is associated', () async {
      final user = TUser(userId: 7, name: 'Solo');
      await user.save();
      final accessor = HasOneAccessor<TUser, TArticle>(
        parent: user,
        relation: _profileRelation,
      );
      await accessor.clear();
      final rows = await adapter.select(
        const QueryDescriptor(table: 'articles'),
      );
      expect(rows, isEmpty);
    });
  });
}
