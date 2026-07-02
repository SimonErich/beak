/// The central runtime for the worm ORM.
library;

import 'dart:async';
import 'dart:io';

import '../adapter/database_adapter.dart';
import '../config/strictness_config.dart';
import '../config/worm_config.dart';
import '../event/lifecycle_event.dart';
import '../exception/configuration_exception.dart';
import '../exception/unsupported_operation_exception.dart';
import '../factory/faker_service.dart';
import '../seeder/environment.dart';
import '../transaction/transaction_context.dart';
import 'model_registration.dart';
import 'morph_registry.dart';
import 'observer.dart';

/// Zone key flagging the dynamic scope of [Worm.unsafe].
///
/// Stored as a `bool` zone value; absence (or `false`) means the
/// current async region is outside an `unsafe` block.
const Symbol _unsafeZoneKey = #worm.unsafe;

/// Zone key carrying the active [TransactionContext] of the current
/// async region, or absent when no `Worm.transaction` is in scope.
const Symbol _txnZoneKey = #worm.transaction;

/// Zone key carrying the muted lifecycle events of the current async
/// region: either [_muteAllEvents] or a `Set<LifecycleEvent>`.
const Symbol _mutedEventsZoneKey = #worm.mutedEvents;

/// Sentinel stored under [_mutedEventsZoneKey] meaning every lifecycle
/// event is muted.
const Object _muteAllEvents = #worm.mutedEvents.all;

/// Central registry and lifecycle entry point for the worm ORM.
///
/// [initialize] must be called before any adapter access, model
/// lookup, or query execution. Any such call before initialization
/// throws [ConfigurationException] with key `'initialization'`.
///
/// Static-only — `Worm` cannot be instantiated. Declared `final`
/// so it cannot be subclassed.
final class Worm {
  // Private constructor prevents instantiation and subclassing.
  Worm._();

  static WormConfig? _config;
  static final Map<String, DatabaseAdapter> _adapters =
      <String, DatabaseAdapter>{};
  static final Map<Type, ModelRegistration> _models =
      <Type, ModelRegistration>{};
  static final Map<Type, List<Observer<Object>>> _observers =
      <Type, List<Observer<Object>>>{};
  static final List<Observer<Object>> _observerOrder = <Observer<Object>>[];
  static final MorphRegistry _morphRegistry = MorphRegistry();

  // Test-transaction suspension state. The completer holds the
  // callback-based `transaction` open; the future tracks the
  // suspended call so [rollbackTestTransaction] can await full
  // unwind. The adapter is the in-flight transactional handle
  // that overrides [adapter] for the default connection until
  // rollback.
  static DatabaseAdapter? _testTxnAdapter;
  static Completer<Never>? _testTxnCompleter;
  static Future<void>? _testTxnFuture;
  static TransactionContext? _testTxnContext;

  /// Whether [initialize] has been called and [reset] has not.
  static bool get isInitialized => _config != null;

  /// Initialize the runtime.
  ///
  /// Registers every supplied [adapters] entry under its connection
  /// name and stores [models] keyed by Dart type. Calling this twice
  /// without [reset] throws.
  static Future<void> initialize({
    required WormConfig config,
    required Map<String, DatabaseAdapter> adapters,
    List<ModelRegistration> models = const <ModelRegistration>[],
    List<Observer<Object>> observers = const <Observer<Object>>[],
  }) async {
    if (_config != null) {
      throw const ConfigurationException(
        key: 'initialization.duplicate',
        message: 'Worm has already been initialized',
      );
    }
    if (!adapters.containsKey(config.defaultConnection)) {
      throw ConfigurationException(
        key: 'adapter.missing',
        message:
            'No adapter registered for default connection '
            '"${config.defaultConnection}"',
      );
    }
    _config = config;
    _adapters
      ..clear()
      ..addAll(adapters);
    _models.clear();
    for (final m in models) {
      _models[m.type] = m;
    }
    _observers.clear();
    _observerOrder
      ..clear()
      ..addAll(observers);
    for (final o in observers) {
      _observers.putIfAbsent(o.modelType, () => <Observer<Object>>[]).add(o);
    }
    for (final adapter in adapters.values) {
      await adapter.connect();
    }
  }

  /// Reset the runtime to an uninitialized state.
  ///
  /// Intended for tests. Disconnects all adapters. Also rolls
  /// back any active test transaction so no completers are left
  /// dangling.
  static Future<void> reset() async {
    await rollbackTestTransaction();
    for (final adapter in _adapters.values) {
      await adapter.disconnect();
    }
    _adapters.clear();
    _models.clear();
    _observers.clear();
    _observerOrder.clear();
    _morphRegistry.clear();
    _config = null;
  }

  /// Shared morph-type registry resolving polymorphic type strings
  /// (e.g. `'post'`) to their Dart model types and tables.
  ///
  /// The registry is process-wide so multiple polymorphic relations
  /// can share a single source of truth; `reset()` clears it.
  ///
  /// Throws [ConfigurationException] with key `'initialization'` if
  /// [initialize] has not been called.
  static MorphRegistry get morphRegistry {
    _requireInitialized();
    return _morphRegistry;
  }

  /// The active configuration.
  ///
  /// Throws [ConfigurationException] with key `'initialization'` if
  /// [initialize] has not been called.
  static WormConfig get config => _requireInitialized();

  /// All registered models (unmodifiable view).
  ///
  /// Throws [ConfigurationException] with key `'initialization'` if
  /// [initialize] has not been called.
  static List<ModelRegistration> get models {
    _requireInitialized();
    return List<ModelRegistration>.unmodifiable(_models.values);
  }

  /// All registered observers in registration order (unmodifiable
  /// view).
  ///
  /// Throws [ConfigurationException] with key `'initialization'` if
  /// [initialize] has not been called.
  static List<Observer<Object>> get observers {
    _requireInitialized();
    return List<Observer<Object>>.unmodifiable(_observerOrder);
  }

  /// Resolve an adapter by connection name.
  ///
  /// Defaults to [WormConfig.defaultConnection]. Throws
  /// [ConfigurationException] with key `'initialization'` if the
  /// runtime is uninitialized, or key `'adapter.unknown'` if no
  /// adapter is registered under the requested name.
  static DatabaseAdapter adapter([String? connection]) {
    final current = _requireInitialized();
    final name = connection ?? current.defaultConnection;
    final testTxn = _testTxnAdapter;
    if (testTxn != null && name == current.defaultConnection) {
      return testTxn;
    }
    final zoneTxn = Zone.current[_txnZoneKey];
    if (zoneTxn is TransactionContext && zoneTxn.connectionName == name) {
      return zoneTxn.adapter;
    }
    final found = _adapters[name];
    if (found == null) {
      throw ConfigurationException(
        key: 'adapter.unknown',
        message: 'No adapter registered for connection "$name"',
      );
    }
    return found;
  }

  /// Look up registration metadata for [T].
  static ModelRegistration registrationOf<T>() {
    _requireInitialized();
    final found = _models[T];
    if (found == null) {
      throw ConfigurationException(
        key: 'model.unknown',
        message: 'No model registered for type $T',
      );
    }
    return found;
  }

  /// Look up registration metadata by model [type].
  static ModelRegistration registrationForType(Type type) {
    _requireInitialized();
    final found = _models[type];
    if (found == null) {
      throw ConfigurationException(
        key: 'model.unknown',
        message: 'No model registered for type $type',
      );
    }
    return found;
  }

  /// Names of all registered adapter connections.
  static List<String> get registeredConnections =>
      List<String>.unmodifiable(_adapters.keys);

  /// Active strictness flags.
  ///
  /// Returns [WormConfig.strictness] when initialized, otherwise
  /// the all-defaults [StrictnessConfig]. Safe to call before
  /// [initialize] — strictness gates rely on this falling back to
  /// the all-off defaults so the runtime stays usable in tests
  /// that never call [initialize].
  static StrictnessConfig get strictness =>
      _config?.strictness ?? const StrictnessConfig();

  /// Whether the current async region runs inside [unsafe].
  ///
  /// Strictness gates short-circuit on this flag, so callers can
  /// bypass `preventFullTableScans`, `preventLazyLoading`, and the
  /// destructive-write guard for the duration of an `unsafe`
  /// callback.
  static bool get isUnsafe => Zone.current[_unsafeZoneKey] == true;

  /// Run [body] with every strictness gate temporarily disabled.
  ///
  /// `unsafe` is the documented escape hatch for one-off operations
  /// that would otherwise be blocked by strict mode (a deliberate
  /// `DELETE` without `WHERE`, a maintenance script that touches an
  /// unloaded relation, etc.). The flag is propagated via a Dart
  /// [Zone] so it survives `await`s inside [body] and is restored
  /// automatically when [body] returns or throws.
  ///
  /// Nested `unsafe` calls are idempotent — entering an already-
  /// unsafe zone is a no-op.
  static Future<T> unsafe<T>(Future<T> Function() body) => runZoned<Future<T>>(
    body,
    zoneValues: <Object?, Object?>{_unsafeZoneKey: true},
  );

  /// The transaction active in the current async region, or `null`.
  ///
  /// Resolves the ambient `Worm.transaction` from the [Zone], falling
  /// back to an active [beginTestTransaction] context. Saves consult
  /// this to route writes and defer `afterCommit` callbacks.
  static TransactionContext? get currentTransaction {
    final zoneTxn = Zone.current[_txnZoneKey];
    if (zoneTxn is TransactionContext) return zoneTxn;
    return _testTxnContext;
  }

  /// Run [action] inside a database transaction.
  ///
  /// Opens a transaction on the [connection] (default connection when
  /// omitted), hands a [TransactionContext] to [action], and commits
  /// when it returns — draining every deferred `afterCommit` callback
  /// registered by saves/deletes inside it. Throwing from [action]
  /// rolls the transaction back and discards those callbacks, then
  /// rethrows.
  ///
  /// `Model.save()` / `delete()` performed inside [action] (without an
  /// explicit `transaction:`) automatically route through the
  /// transaction via the ambient [currentTransaction]. A nested
  /// `Worm.transaction` on the same connection **joins** the enclosing
  /// transaction (no second `BEGIN`); use `txn.savepoint(...)` for a
  /// real nested rollback boundary.
  ///
  /// Throws [UnsupportedOperationException] when the resolved adapter
  /// does not support transactions.
  static Future<T> transaction<T>(
    Future<T> Function(TransactionContext txn) action, {
    String? connection,
  }) async {
    final current = _requireInitialized();
    final name = connection ?? current.defaultConnection;
    final ambient = currentTransaction;
    if (ambient != null && ambient.connectionName == name) {
      return action(ambient);
    }
    final root = adapter(connection);
    if (!root.capabilities.supportsTransactions) {
      throw UnsupportedOperationException(
        operation: 'transaction',
        adapter: root.runtimeType.toString(),
        message: '${root.runtimeType} does not support transactions',
      );
    }
    late T result;
    late TransactionContext context;
    await root.transaction<void>((txAdapter) async {
      context = TransactionContext(adapter: txAdapter, connectionName: name);
      result = await runZoned<Future<T>>(
        () => action(context),
        zoneValues: <Object?, Object?>{_txnZoneKey: context},
      );
    });
    context.drainAfterCommit();
    return result;
  }

  /// Run [body] with model lifecycle events muted.
  ///
  /// With no [events], every lifecycle event is muted for the duration
  /// of [body]. With an explicit [events] list, only those events are
  /// skipped — unioned with any events already muted by an enclosing
  /// `withoutEvents`. Muting is propagated via a [Zone] so it survives
  /// `await`s inside [body].
  ///
  /// Muting suppresses observer / model lifecycle hooks only. It does
  /// **not** disable validation, which is a correctness gate rather
  /// than an event.
  static Future<T> withoutEvents<T>(
    Future<T> Function() body, {
    List<LifecycleEvent>? events,
  }) {
    final Object zoneValue;
    if (events == null || isMutingAll) {
      zoneValue = _muteAllEvents;
    } else {
      zoneValue = <LifecycleEvent>{...?mutedEvents, ...events};
    }
    return runZoned<Future<T>>(
      body,
      zoneValues: <Object?, Object?>{_mutedEventsZoneKey: zoneValue},
    );
  }

  /// The specifically-muted lifecycle events of the current region, or
  /// `null` when none are muted or all are muted (see [isMutingAll]).
  static Set<LifecycleEvent>? get mutedEvents {
    final raw = Zone.current[_mutedEventsZoneKey];
    return raw is Set<LifecycleEvent> ? raw : null;
  }

  /// Whether the current region mutes every lifecycle event.
  static bool get isMutingAll =>
      identical(Zone.current[_mutedEventsZoneKey], _muteAllEvents);

  /// Whether [event] is muted in the current async region.
  ///
  /// Reads only [Zone] state, so it is safe to call before
  /// [initialize].
  static bool isEventMuted(LifecycleEvent event) {
    if (isMutingAll) return true;
    final set = mutedEvents;
    return set != null && set.contains(event);
  }

  /// Observers registered for a model [type] (unmodifiable view).
  static List<Observer<Object>> observersFor(Type type) =>
      List<Observer<Object>>.unmodifiable(
        _observers[type] ?? const <Observer<Object>>[],
      );

  /// Seed the shared [FakerService] so factory data is reproducible.
  ///
  /// Forwards to [FakerService.seed]; subsequent helper calls
  /// (e.g. `FakerService.instance.firstName()`) draw from the
  /// same deterministic stream whenever the same [seed] is used.
  static void seedRandom(int seed) {
    FakerService.instance.seed(seed);
  }

  /// Begin a test-scoped transaction on the default adapter.
  ///
  /// While active, every call to [adapter] for the default
  /// connection returns the transactional handle, so any
  /// writes performed during the test are isolated and can be
  /// rolled back by [rollbackTestTransaction].
  ///
  /// Implementation note: the underlying [DatabaseAdapter.transaction]
  /// is callback-based; this helper keeps it open by awaiting a
  /// [Completer] of [Never] inside the callback — that completer
  /// is only ever completed with an error (rollback marker), so
  /// the suspended `await` always resolves by throwing and the
  /// adapter rolls back.
  ///
  /// **For test use only.** This mutates global static state on
  /// [Worm] and is not safe for concurrent production use.
  ///
  /// Throws [ConfigurationException] with key
  /// `'test_transaction.duplicate'` when a transaction is
  /// already active.
  static Future<void> beginTestTransaction() async {
    if (_testTxnCompleter != null) {
      throw const ConfigurationException(
        key: 'test_transaction.duplicate',
        message: 'A test transaction is already active',
      );
    }
    final root = adapter();
    final completer = Completer<Never>();
    final started = Completer<void>();
    _testTxnCompleter = completer;
    final defaultConnection = _requireInitialized().defaultConnection;
    _testTxnFuture = root
        .transaction<void>((tx) async {
          _testTxnAdapter = tx;
          _testTxnContext = TransactionContext(
            adapter: tx,
            connectionName: defaultConnection,
          );
          started.complete();
          await completer.future;
        })
        .then((_) {}, onError: (_) {});
    await started.future;
  }

  /// Roll back any active test transaction.
  ///
  /// No-op when no transaction is active. Completes once the
  /// underlying adapter has fully unwound the transaction so
  /// callers can immediately observe the pre-test state.
  static Future<void> rollbackTestTransaction() async {
    final completer = _testTxnCompleter;
    final future = _testTxnFuture;
    if (completer == null || future == null) return;
    _testTxnCompleter = null;
    _testTxnAdapter = null;
    _testTxnFuture = null;
    // Rollback discards deferred afterCommit callbacks without firing.
    _testTxnContext?.discardAfterCommit();
    _testTxnContext = null;
    completer.completeError(const _TestTransactionRollback());
    await future;
  }

  /// Current runtime environment.
  ///
  /// Reads `WORM_ENV` from the process environment; falls back to
  /// [WormConfig.environment] when that variable is unset or
  /// unparseable. Safe to call at any time — returns
  /// [Environment.development] when neither source is available.
  static Environment get environment {
    final raw = Platform.environment['WORM_ENV'];
    if (raw != null) {
      final parsed = _parseEnvironment(raw);
      if (parsed != null) return parsed;
    }
    return _config?.environment ?? Environment.development;
  }

  static WormConfig _requireInitialized() {
    final current = _config;
    if (current == null) {
      throw const ConfigurationException(
        key: 'initialization',
        message: 'Worm has not been initialized',
      );
    }
    return current;
  }

  static Environment? _parseEnvironment(String raw) {
    final lower = raw.trim().toLowerCase();
    for (final env in Environment.values) {
      if (env.name == lower) return env;
    }
    return null;
  }
}

/// Internal marker that signals a test-transaction rollback.
///
/// Thrown into the suspended `transaction` callback by
/// [Worm.rollbackTestTransaction]; the adapter sees the throw
/// and rolls back. The instance never surfaces to user code —
/// `beginTestTransaction` swallows it via the `onError` arm of
/// the tracked transaction future.
final class _TestTransactionRollback implements Exception {
  const _TestTransactionRollback();
}
