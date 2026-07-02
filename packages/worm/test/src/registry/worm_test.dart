import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/configuration_exception.dart';
import 'package:worm/src/registry/model_registration.dart';
import 'package:worm/src/registry/observer.dart';
import 'package:worm/src/registry/worm.dart';
import 'package:worm/src/schema/primary_key_type.dart';
import 'package:worm/src/seeder/environment.dart';

class _User {}

class _Post {}

class _UserObserver extends Observer<_User> {
  const _UserObserver();
}

class _PostObserver extends Observer<_Post> {
  const _PostObserver();
}

Matcher _configExceptionWithKey(String key) => predicate<Object?>(
  (e) => e is ConfigurationException && e.key == key,
  'ConfigurationException with key "$key"',
);

void main() {
  tearDown(Worm.reset);

  group('Worm.initialize', () {
    test('registers default adapter and becomes initialized', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
      expect(Worm.isInitialized, isTrue);
      expect(Worm.adapter(), same(adapter));
      expect(adapter.isConnected, isTrue);
    });

    test('registers named adapters and resolves them by name', () async {
      final primary = InMemoryAdapter();
      final analytics = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{
          'default': primary,
          'analytics': analytics,
        },
      );
      expect(Worm.adapter('analytics'), same(analytics));
      expect(Worm.registeredConnections, containsAll(['default', 'analytics']));
    });

    test('throws when default connection has no adapter', () async {
      expect(
        () => Worm.initialize(
          config: const WormConfig(),
          adapters: const <String, InMemoryAdapter>{},
        ),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('throws when initializing twice', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
      expect(
        () => Worm.initialize(
          config: const WormConfig(),
          adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
        ),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('registers models by type', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
        models: const <ModelRegistration>[
          ModelRegistration(type: _User, tableName: 'users'),
          ModelRegistration(
            type: _Post,
            tableName: 'posts',
            primaryKeyType: PrimaryKeyType.integer,
          ),
        ],
      );
      expect(Worm.registrationOf<_User>().tableName, 'users');
      expect(
        Worm.registrationForType(_Post).primaryKeyType,
        PrimaryKeyType.integer,
      );
      expect(Worm.models, hasLength(2));
    });

    test('registers observers keyed by model type', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
        observers: const <Observer<Object>>[_UserObserver(), _PostObserver()],
      );
      expect(Worm.observersFor(_User), hasLength(1));
      expect(Worm.observersFor(_Post), hasLength(1));
      expect(Worm.observers, hasLength(2));
    });
  });

  group('Worm.models and Worm.observers', () {
    test('return unmodifiable views that reject mutation', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
        models: const <ModelRegistration>[
          ModelRegistration(type: _User, tableName: 'users'),
        ],
        observers: const <Observer<Object>>[_UserObserver()],
      );
      expect(
        () => Worm.models.add(
          const ModelRegistration(type: _Post, tableName: 'posts'),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => Worm.observers.add(const _UserObserver()),
        throwsUnsupportedError,
      );
    });
  });

  group('Worm gating when uninitialized', () {
    test(
      'adapter() throws ConfigurationException with key "initialization"',
      () {
        expect(
          Worm.adapter,
          throwsA(_configExceptionWithKey('initialization')),
        );
      },
    );

    test('config throws ConfigurationException', () {
      expect(() => Worm.config, throwsA(isA<ConfigurationException>()));
    });

    test('models throws ConfigurationException', () {
      expect(() => Worm.models, throwsA(isA<ConfigurationException>()));
    });

    test('observers throws ConfigurationException', () {
      expect(() => Worm.observers, throwsA(isA<ConfigurationException>()));
    });

    test('registrationOf throws ConfigurationException', () {
      expect(
        () => Worm.registrationOf<_User>(),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });

  group('Worm adapter lookup errors', () {
    test('unknown connection name throws with key "adapter.unknown"', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
      expect(
        () => Worm.adapter('does-not-exist'),
        throwsA(_configExceptionWithKey('adapter.unknown')),
      );
    });

    test('unknown model type throws', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
      expect(
        () => Worm.registrationOf<_User>(),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });

  group('Worm.environment', () {
    test('returns an Environment value before initialize()', () {
      // When uninitialized and no WORM_ENV, falls back to development.
      if (Platform.environment['WORM_ENV'] == null) {
        expect(Worm.environment, Environment.development);
      } else {
        // WORM_ENV present: the getter still returns a valid value.
        expect(Worm.environment, isA<Environment>());
      }
    });

    test('falls back to config.environment when WORM_ENV unset', () async {
      if (Platform.environment['WORM_ENV'] != null) {
        return; // Runtime env vars dominate; skip gracefully.
      }
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(environment: Environment.testing),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
      expect(Worm.environment, Environment.testing);
    });

    test('honors WORM_ENV when set', () async {
      final envValue = Platform.environment['WORM_ENV'];
      if (envValue == null) return; // only runs under harness-set WORM_ENV
      final parsed = Environment.values
          .where((e) => e.name == envValue.toLowerCase())
          .toList();
      if (parsed.isEmpty) return;
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(environment: Environment.development),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
      expect(Worm.environment, parsed.single);
    });

    test('defaults to development when uninitialized and WORM_ENV unset', () {
      if (Platform.environment['WORM_ENV'] != null) return;
      expect(Worm.environment, Environment.development);
    });
  });

  group('Worm.reset', () {
    test('disconnects adapters and clears all state', () async {
      final adapter = InMemoryAdapter();
      await Worm.initialize(
        config: const WormConfig(),
        adapters: <String, InMemoryAdapter>{'default': adapter},
        models: const <ModelRegistration>[
          ModelRegistration(type: _User, tableName: 'users'),
        ],
        observers: const <Observer<Object>>[_UserObserver()],
      );
      await Worm.reset();
      expect(Worm.isInitialized, isFalse);
      expect(adapter.isConnected, isFalse);
      expect(() => Worm.models, throwsA(isA<ConfigurationException>()));
      expect(() => Worm.observers, throwsA(isA<ConfigurationException>()));
    });
  });
}
