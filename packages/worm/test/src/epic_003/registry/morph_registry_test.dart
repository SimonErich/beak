/// Unit tests for [Worm.morphRegistry] — bidirectional resolution,
/// null returns for unknown morph strings, error behavior for
/// unregistered Dart types, and pre-initialize access guard.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../_fixtures.dart';

Future<void> _initWorm() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, InMemoryAdapter>{'default': adapter},
  );
}

void _registerPost() {
  Worm.morphRegistry.register<TPost>(
    const MorphRegistration<TPost>(
      morphType: 'post',
      type: TPost,
      table: 'posts',
    ),
  );
}

void _registerVideo() {
  Worm.morphRegistry.register<TVideo>(
    const MorphRegistration<TVideo>(
      morphType: 'video',
      type: TVideo,
      table: 'videos',
    ),
  );
}

void main() {
  group('Worm.morphRegistry resolution', () {
    setUp(_initWorm);
    tearDown(Worm.reset);

    test('morphNameFor(TPost) returns "post" when TPost is registered', () {
      _registerPost();
      expect(Worm.morphRegistry.morphNameFor(TPost), 'post');
    });

    test('typeFor("post") returns TPost for the same registration', () {
      _registerPost();
      expect(Worm.morphRegistry.typeFor('post'), TPost);
    });

    test(
      'typeFor("video") returns TVideo when a second model is registered',
      () {
        _registerPost();
        _registerVideo();
        expect(Worm.morphRegistry.typeFor('video'), TVideo);
      },
    );

    test('typeFor("unknown") returns null without throwing', () {
      _registerPost();
      expect(Worm.morphRegistry.typeFor('unknown'), isNull);
    });

    test('morphNameFor(unregistered type) throws ConfigurationException with '
        'key "morph.unknown"', () {
      _registerPost();
      try {
        Worm.morphRegistry.morphNameFor(TUnregistered);
        fail('Expected ConfigurationException');
      } on ConfigurationException catch (e) {
        expect(e.key, 'morph.unknown');
      }
    });
  });

  group('Worm.morphRegistry initialization guard', () {
    test('accessing Worm.morphRegistry before Worm.initialize throws '
        'ConfigurationException with key "initialization"', () {
      try {
        Worm.morphRegistry;
        fail('Expected ConfigurationException');
      } on ConfigurationException catch (e) {
        expect(e.key, 'initialization');
      }
    });
  });
}
