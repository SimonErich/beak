/// Tests that a single [Worm.morphRegistry] resolves polymorphic
/// morph-type strings ↔ Dart model types for multiple relations
/// sharing the same registry instance.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '_fixtures.dart';

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('Worm.morphRegistry', () {
    test('returns a process-wide registry', () {
      expect(Worm.morphRegistry, isA<MorphRegistry>());
      expect(Worm.morphRegistry, same(Worm.morphRegistry));
    });

    test("resolves 'post' to TPost and TPost to 'post'", () {
      Worm.morphRegistry.register<TPost>(
        const MorphRegistration<TPost>(
          morphType: 'post',
          type: TPost,
          table: 'posts',
        ),
      );

      expect(Worm.morphRegistry.typeFor('post'), TPost);
      expect(Worm.morphRegistry.morphTypeFor(TPost), 'post');
    });

    test('two distinct relations resolve the same morph binding', () {
      Worm.morphRegistry.register<TPost>(
        const MorphRegistration<TPost>(
          morphType: 'post',
          type: TPost,
          table: 'posts',
        ),
      );
      Worm.morphRegistry.register<TVideo>(
        const MorphRegistration<TVideo>(
          morphType: 'video',
          type: TVideo,
          table: 'videos',
        ),
      );

      // First "relation" (e.g. commentable) resolves through the
      // shared registry…
      final commentableType = Worm.morphRegistry.typeFor('post');
      // …and a second "relation" (e.g. taggable) resolves the same
      // way, proving the registry is shared.
      final taggableType = Worm.morphRegistry.typeFor('post');
      expect(commentableType, TPost);
      expect(taggableType, TPost);

      // The other model also resolves through the same registry.
      expect(Worm.morphRegistry.typeFor('video'), TVideo);
      expect(Worm.morphRegistry.tableMap, <String, String>{
        'post': 'posts',
        'video': 'videos',
      });
    });

    test('duplicate morph type registration throws', () {
      Worm.morphRegistry.register<TPost>(
        const MorphRegistration<TPost>(
          morphType: 'post',
          type: TPost,
          table: 'posts',
        ),
      );
      expect(
        () => Worm.morphRegistry.register<TVideo>(
          const MorphRegistration<TVideo>(
            morphType: 'post',
            type: TVideo,
            table: 'videos',
          ),
        ),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('Worm.reset clears the registry', () async {
      Worm.morphRegistry.register<TPost>(
        const MorphRegistration<TPost>(
          morphType: 'post',
          type: TPost,
          table: 'posts',
        ),
      );
      expect(Worm.morphRegistry.typeFor('post'), TPost);
      await Worm.reset();
      // Re-initialize so the registry is accessible again — accessing
      // Worm.morphRegistry on an uninitialized runtime throws.
      final reopened = InMemoryAdapter();
      await reopened.connect();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': reopened},
      );
      expect(Worm.morphRegistry.typeFor('post'), isNull);
    });
  });
}
