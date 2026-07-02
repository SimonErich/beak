/// `Model.getRelation` strictness gates and unsafe-zone bypass.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/lazy_loading_exception.dart';
import 'package:worm/src/exception/relation_not_loaded_exception.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/registry/worm.dart';

final class _User extends Model {
  _User(this.userId);

  final int userId;

  @override
  Object get id => userId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': userId};
}

final class _Post extends Model {
  _Post(this.postId);

  final int postId;

  @override
  Object get id => postId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': postId};
}

void main() {
  tearDown(Worm.reset);

  group('Model.getRelation in strict mode', () {
    test('throws LazyLoadingException when relation is not loaded', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventLazyLoading: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final user = _User(1);
      expect(
        () => user.getRelation<List<_Post>>('posts'),
        throwsA(
          isA<LazyLoadingException>()
              .having((e) => e.relationName, 'relationName', 'posts')
              .having((e) => e.modelName, 'modelName', '_User'),
        ),
      );
    });

    test('returns loaded relation in strict mode without throwing', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventLazyLoading: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final user = _User(1)..relations['posts'] = <_Post>[_Post(10)];
      final posts = user.getRelation<List<_Post>>('posts');
      expect(posts, hasLength(1));
      expect(posts!.single.postId, 10);
    });

    test('Worm.unsafe bypasses the strict-mode throw', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventLazyLoading: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final user = _User(1);
      final value = await Worm.unsafe<List<_Post>?>(
        () async => user.getRelation<List<_Post>>('posts'),
      );
      expect(value, isNull);
    });
  });

  group('Model.getRelation in non-strict mode', () {
    test('throws RelationNotLoadedException (not LazyLoadingException) when '
        'preventLazyLoading is false', () async {
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final user = _User(1);
      expect(
        () => user.getRelation<List<_Post>>('posts'),
        throwsA(
          isA<RelationNotLoadedException>()
              .having((e) => e.relationName, 'relationName', 'posts')
              .having((e) => e.model, 'model', '_User'),
        ),
      );
      expect(
        () => user.getRelation<List<_Post>>('posts'),
        isNot(throwsA(isA<LazyLoadingException>())),
      );
    });

    test('returns loaded relation when present', () async {
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final user = _User(1)..relations['posts'] = <_Post>[_Post(7), _Post(8)];
      final posts = user.getRelation<List<_Post>>('posts');
      expect(posts, hasLength(2));
    });
  });
}
