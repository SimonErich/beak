/// Worm initialization and registration system.
library;

import 'dart:io' show Platform;

import '../adapter/database_adapter.dart';
import '../config/worm_config.dart';
import '../exception/configuration_exception.dart';
import '../seeder/environment.dart';

/// Central registration point for the worm ORM.
///
/// [initialize] must be called before any query.
/// Accessing [adapter] or [config] before
/// initialization throws [ConfigurationException].
///
/// ```dart
/// Worm.initialize(
///   config: const WormConfig(),
///   adapters: {'default': InMemoryAdapter()},
/// );
/// ```
final class Worm {
  Worm._();

  static bool _initialized = false;
  static WormConfig _config = const WormConfig();
  static final Map<String, DatabaseAdapter> _adapters = {};
  static final Set<Type> _models = {};
  static final List<Object> _observers = [];

  /// Whether [initialize] has been called.
  static bool get isInitialized => _initialized;

  /// Registers configuration, adapters, models,
  /// and observers.
  ///
  /// Must be called exactly once before any
  /// database operation. Call [reset] first if
  /// re-initialization is needed (testing only).
  static void initialize({
    required WormConfig config,
    required Map<String, DatabaseAdapter> adapters,
    List<Type> models = const <Type>[],
    List<Object> observers = const <Object>[],
  }) {
    _config = config;
    _adapters
      ..clear()
      ..addAll(adapters);
    _models
      ..clear()
      ..addAll(models);
    _observers
      ..clear()
      ..addAll(observers);
    _initialized = true;
  }

  /// Returns the adapter registered under [name].
  ///
  /// Defaults to [WormConfig.defaultConnection].
  /// Throws [ConfigurationException] if not
  /// initialized or if no adapter is found.
  static DatabaseAdapter adapter([String? name]) {
    _ensureInitialized();
    final key = name ?? _config.defaultConnection;
    final adapter = _adapters[key];
    if (adapter == null) {
      throw ConfigurationException(
        key: 'adapter.$key',
        message: 'No adapter registered for "$key".',
      );
    }
    return adapter;
  }

  /// The current ORM configuration.
  ///
  /// Throws [ConfigurationException] if not
  /// initialized.
  static WormConfig get config {
    _ensureInitialized();
    return _config;
  }

  /// The set of registered model types.
  static Set<Type> get models {
    _ensureInitialized();
    return Set<Type>.unmodifiable(_models);
  }

  /// The list of registered observers.
  static List<Object> get observers {
    _ensureInitialized();
    return List<Object>.unmodifiable(_observers);
  }

  /// Resolves the active environment.
  ///
  /// Reads `WORM_ENV` environment variable first,
  /// then falls back to [WormConfig.environment].
  /// Works even before initialization when
  /// `WORM_ENV` is set.
  static Environment get environment {
    final envVar = Platform.environment['WORM_ENV'];
    if (envVar != null) {
      return _parseEnvironment(envVar);
    }
    if (_initialized) return _config.environment;
    return Environment.development;
  }

  /// Resets all state. For testing only.
  static void reset() {
    _adapters.clear();
    _models.clear();
    _observers.clear();
    _initialized = false;
    _config = const WormConfig();
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw const ConfigurationException(
        key: 'initialization',
        message:
            'Worm.initialize() must be '
            'called before any database operation.',
      );
    }
  }

  static Environment _parseEnvironment(String value) {
    for (final env in Environment.values) {
      if (env.name == value) return env;
    }
    return Environment.development;
  }
}
