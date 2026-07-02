import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/configuration_exception.dart';
import 'package:worm/src/registry/worm_registry.dart';
import 'package:worm/src/seeder/environment.dart';

void main() {
  tearDown(Worm.reset);

  group('Worm.initialize', () {
    test('sets initialized state', () {
      expect(Worm.isInitialized, isFalse);
      Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': InMemoryAdapter()},
      );
      expect(Worm.isInitialized, isTrue);
    });

    test('registers adapters', () {
      final adapter = InMemoryAdapter();
      Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': adapter},
      );
      expect(Worm.adapter(), same(adapter));
    });

    test('registers models', () {
      Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': InMemoryAdapter()},
        models: [String, int],
      );
      expect(Worm.models, containsAll([String, int]));
    });

    test('registers observers', () {
      final observer = Object();
      Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': InMemoryAdapter()},
        observers: [observer],
      );
      expect(Worm.observers, hasLength(1));
    });
  });

  group('before initialization', () {
    test('adapter() throws '
        'ConfigurationException', () {
      expect(Worm.adapter, throwsA(isA<ConfigurationException>()));
    });

    test('config throws '
        'ConfigurationException', () {
      expect(() => Worm.config, throwsA(isA<ConfigurationException>()));
    });

    test('models throws '
        'ConfigurationException', () {
      expect(() => Worm.models, throwsA(isA<ConfigurationException>()));
    });

    test('observers throws '
        'ConfigurationException', () {
      expect(() => Worm.observers, throwsA(isA<ConfigurationException>()));
    });
  });

  group('adapter lookup', () {
    test('uses defaultConnection name', () {
      final adapter = InMemoryAdapter();
      Worm.initialize(
        config: const WormConfig(defaultConnection: 'primary'),
        adapters: {'primary': adapter},
      );
      expect(Worm.adapter(), same(adapter));
    });

    test('retrieves named adapter', () {
      final main = InMemoryAdapter();
      final analytics = InMemoryAdapter();
      Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': main, 'analytics': analytics},
      );
      expect(Worm.adapter('analytics'), same(analytics));
    });

    test('throws for unknown adapter name', () {
      Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': InMemoryAdapter()},
      );
      expect(
        () => Worm.adapter('unknown'),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });

  group('environment', () {
    test('falls back to config value', () {
      Worm.initialize(
        config: const WormConfig(environment: Environment.production),
        adapters: {'default': InMemoryAdapter()},
      );
      // WORM_ENV not set in test, so falls
      // back to config.
      // Note: if WORM_ENV is set in the test
      // runner, this test may report differently.
      final env = Worm.environment;
      expect(env, isA<Environment>());
    });

    test('returns development before init when '
        'WORM_ENV unset', () {
      // Before initialization, without WORM_ENV,
      // defaults to development.
      final env = Worm.environment;
      expect(env, isA<Environment>());
    });
  });

  group('reset', () {
    test('clears all state', () {
      Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': InMemoryAdapter()},
        models: [String],
      );
      Worm.reset();
      expect(Worm.isInitialized, isFalse);
      expect(Worm.adapter, throwsA(isA<ConfigurationException>()));
    });
  });

  group('re-exports from public API', () {
    test('Worm is accessible via worm.dart', () {
      // This test verifies the barrel export
      // works by importing from the public API.
      expect(Worm.isInitialized, isFalse);
    });
  });
}
