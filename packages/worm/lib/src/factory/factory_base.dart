/// Base class for model factories.
///
/// Factories produce typed `Model` instances for tests and
/// seeders. The type bound is `Model` (not `Object`) so the
/// fluent persistence helpers (`create`, `count`, `sequence`,
/// `has`, `for_`) can call `save()` on every produced instance.
/// This is a 0.x breaking change relative to earlier revisions
/// where `Factory<T extends Object>` was permitted.
library;

import '../exception/factory_exception.dart';
import '../model/model.dart';
import '../relation/relation_field.dart';
import 'faker_service.dart';

/// A state variation: derives a new instance from a base one.
///
/// State variations let callers compose named tweaks on top of
/// the canonical `definition()` output (e.g. an `admin` state on
/// a `UserFactory`) without subclassing the factory.
typedef FactoryState<T> = T Function(T base);

/// Callback executed once per persisted parent to materialize a
/// nested `has`-relation. The parent's primary key is forwarded
/// to the child producer as a foreign-key override.
typedef _HasRelationRunner = Future<void> Function(Object parentId);

/// Pre-bound parent reference applied by `for_()` to every
/// instance the plan produces.
typedef _ForBinding = ({Object parentId, String foreignKey});

/// Internal protocol shared by [Factory] and [_FactoryPlan] so
/// `has()` can accept either type without forcing them into an
/// inheritance relationship (their `create()` methods have
/// incompatible return types).
abstract base class _ModelProducer<T extends Model> {
  const _ModelProducer();

  /// Persist all planned instances, applying [extraOverrides]
  /// to each. Plain factories produce a single-element list;
  /// `_FactoryPlan` produces N elements.
  Future<List<T>> _persist(Map<String, Object?> extraOverrides);
}

/// Base class every model factory extends.
///
/// Factories produce typed instances of [T] for tests and seeders.
/// [definition] returns a fresh blueprint each call; [make] builds
/// one instance; [makeMany] builds N instances.
///
/// Named state variations are registered via [stateVariations] and
/// composed via [state]. Each call to [state] returns a new factory
/// that applies the named transform after `definition()`.
///
/// Persistence helpers ([create], [count], [sequence], [has],
/// [for_]) require `Worm.initialize` to have been called; they
/// obtain the active adapter through `Model.save()`.
abstract base class Factory<T extends Model> extends _ModelProducer<T> {
  /// Const constructor for subclasses.
  const Factory();

  /// Named state variations declared on this factory.
  ///
  /// Override and return a const map of state name → transform.
  /// The default is an empty map (no states registered).
  Map<String, FactoryState<T>> get stateVariations =>
      <String, FactoryState<T>>{};

  /// Produce a fresh blueprint for one instance.
  T definition();

  /// Build a single instance.
  T make() => definition();

  /// Build [count] instances.
  List<T> makeMany(int count) => <T>[for (var i = 0; i < count; i++) make()];

  /// Shared [FakerService] singleton — convenient access to
  /// deterministic fake data inside `definition()` overrides.
  FakerService get faker => FakerService.instance;

  /// Build one instance, apply [overrides], and persist it.
  ///
  /// Returns the saved model. Requires `Worm.initialize` to
  /// have run; otherwise `Model.save()` throws
  /// `ConfigurationException`.
  Future<T> create({
    Map<String, Object?> overrides = const <String, Object?>{},
  }) async {
    final instance = make();
    if (overrides.isNotEmpty) {
      instance.fill(overrides);
    }
    await instance.save();
    return instance;
  }

  @override
  Future<List<T>> _persist(Map<String, Object?> extraOverrides) async {
    final one = await create(overrides: extraOverrides);
    return <T>[one];
  }

  /// Plan that will produce and persist [n] instances on `create()`.
  // ignore: library_private_types_in_public_api
  _FactoryPlan<T> count(int n) => _FactoryPlan<T>(factory: this, count: n);

  /// Plan that cycles through [patterns] one per instance on
  /// `create()`. Combine with [count] to control how many
  /// instances are produced.
  // ignore: library_private_types_in_public_api
  _FactoryPlan<T> sequence(List<Map<String, Object?>> patterns) =>
      _FactoryPlan<T>(factory: this, count: 1, sequence: patterns);

  /// Plan that, after persisting each parent, runs [childFactory]
  /// with the parent's primary key bound to the relation's
  /// foreign-key column. Multiple `has` calls register
  /// independent nested-creation steps.
  // ignore: library_private_types_in_public_api
  _FactoryPlan<T> has<R extends Model>(
    // ignore: library_private_types_in_public_api
    _ModelProducer<R> childFactory,
    RelationField<T, R> relation,
  ) => _FactoryPlan<T>(
    factory: this,
    count: 1,
    hasRelations: <_HasRelationRunner>[_hasRunner(childFactory, relation)],
  );

  /// Plan that pre-fills the relation's foreign-key column on
  /// every produced instance to point at [parent].
  // ignore: library_private_types_in_public_api
  _FactoryPlan<T> for_<P extends Model>(
    P parent,
    RelationField<P, T> relation,
  ) => _FactoryPlan<T>(
    factory: this,
    count: 1,
    forBinding: (parentId: parent.id, foreignKey: relation.foreignKey),
  );

  /// Returns a derived factory that applies the [name] state
  /// to every produced instance.
  ///
  /// Throws [FactoryException] when [name] is not present in
  /// [stateVariations].
  Factory<T> state(String name) {
    final variation = stateVariations[name];
    if (variation == null) {
      throw FactoryException(
        factoryState: name,
        message: 'No state named "$name" defined on $runtimeType',
      );
    }
    return _StatefulFactory<T>(this, <FactoryState<T>>[variation]);
  }

  /// Returns a derived factory that applies [transform] after
  /// `definition()`.
  ///
  /// Use for inline, unnamed state variations.
  Factory<T> withTransform(FactoryState<T> transform) =>
      _StatefulFactory<T>(this, <FactoryState<T>>[transform]);
}

/// Builds a single `has` relation runner closure that captures
/// the child producer and foreign key column.
_HasRelationRunner _hasRunner<P extends Model, C extends Model>(
  _ModelProducer<C> childFactory,
  RelationField<P, C> relation,
) {
  final foreignKey = relation.foreignKey;
  return (parentId) async {
    await childFactory._persist(<String, Object?>{foreignKey: parentId});
  };
}

/// Derived factory that applies one or more transforms on top
/// of a parent factory's `definition()`.
final class _StatefulFactory<T extends Model> extends Factory<T> {
  _StatefulFactory(this._parent, this._transforms);

  final Factory<T> _parent;
  final List<FactoryState<T>> _transforms;

  @override
  Map<String, FactoryState<T>> get stateVariations => _parent.stateVariations;

  @override
  T definition() {
    var current = _parent.definition();
    for (final transform in _transforms) {
      current = transform(current);
    }
    return current;
  }

  @override
  Factory<T> state(String name) {
    final variation = stateVariations[name];
    if (variation == null) {
      throw FactoryException(
        factoryState: name,
        message:
            'No state named "$name" defined on '
            '${_parent.runtimeType}',
      );
    }
    return _StatefulFactory<T>(_parent, <FactoryState<T>>[
      ..._transforms,
      variation,
    ]);
  }

  @override
  Factory<T> withTransform(FactoryState<T> transform) => _StatefulFactory<T>(
    _parent,
    <FactoryState<T>>[..._transforms, transform],
  );
}

/// Internal plan returned by [Factory.count] / [Factory.sequence]
/// / [Factory.has] / [Factory.for_].
///
/// Intentionally not exported from `lib/src/factory/factory.dart`
/// — callers should chain via the public fluent methods and call
/// [create] to materialize the plan.
final class _FactoryPlan<T extends Model> extends _ModelProducer<T> {
  _FactoryPlan({
    required Factory<T> factory,
    required int count,
    List<Map<String, Object?>>? sequence,
    List<_HasRelationRunner> hasRelations = const <_HasRelationRunner>[],
    _ForBinding? forBinding,
  }) : _factory = factory,
       _count = count,
       _sequence = sequence,
       _hasRelations = hasRelations,
       _forBinding = forBinding;

  final Factory<T> _factory;
  final int _count;
  final List<Map<String, Object?>>? _sequence;
  final List<_HasRelationRunner> _hasRelations;
  final _ForBinding? _forBinding;

  /// Returns a new plan that persists [n] instances instead.
  _FactoryPlan<T> count(int n) => _copy(count: n);

  /// Returns a new plan that cycles through [patterns] one per
  /// instance on `create()`.
  _FactoryPlan<T> sequence(List<Map<String, Object?>> patterns) =>
      _copy(sequence: patterns);

  /// Registers a nested `has`-relation; persists [childFactory]
  /// (with the parent's PK bound to the relation's foreign key)
  /// once per parent during `create()`. Multiple calls compose.
  _FactoryPlan<T> has<R extends Model>(
    // ignore: library_private_types_in_public_api
    _ModelProducer<R> childFactory,
    RelationField<T, R> relation,
  ) => _copy(
    hasRelations: <_HasRelationRunner>[
      ..._hasRelations,
      _hasRunner(childFactory, relation),
    ],
  );

  /// Pre-fills the relation's foreign-key column on every
  /// produced instance to point at [parent]. Last `for_` wins.
  _FactoryPlan<T> for_<P extends Model>(
    P parent,
    RelationField<P, T> relation,
  ) =>
      _copy(forBinding: (parentId: parent.id, foreignKey: relation.foreignKey));

  /// Persist all planned instances.
  ///
  /// For each instance: builds via the parent factory's `make()`,
  /// merges the `for_` binding, cycled sequence pattern, and
  /// [overrides] (later sources win), saves, then runs any
  /// registered `has`-relation runners with the persisted parent's
  /// id. Returns the list of persisted models in production order.
  Future<List<T>> create({
    Map<String, Object?> overrides = const <String, Object?>{},
  }) async {
    final results = <T>[];
    for (var i = 0; i < _count; i++) {
      final instance = await _persistOne(i, overrides);
      for (final run in _hasRelations) {
        await run(instance.id);
      }
      results.add(instance);
    }
    return results;
  }

  @override
  Future<List<T>> _persist(Map<String, Object?> extraOverrides) =>
      create(overrides: extraOverrides);

  Future<T> _persistOne(int index, Map<String, Object?> overrides) async {
    final instance = _factory.make();
    final merged = _mergedOverrides(index, overrides);
    if (merged.isNotEmpty) {
      instance.fill(merged);
    }
    await instance.save();
    return instance;
  }

  Map<String, Object?> _mergedOverrides(int index, Map<String, Object?> extra) {
    final forMap = _forOverride();
    final pattern = _patternAt(index);
    if (forMap.isEmpty && pattern.isEmpty) return extra;
    return <String, Object?>{...forMap, ...pattern, ...extra};
  }

  Map<String, Object?> _forOverride() {
    final binding = _forBinding;
    if (binding == null) return const <String, Object?>{};
    return <String, Object?>{binding.foreignKey: binding.parentId};
  }

  Map<String, Object?> _patternAt(int index) {
    final seq = _sequence;
    if (seq == null || seq.isEmpty) return const <String, Object?>{};
    return seq[index % seq.length];
  }

  _FactoryPlan<T> _copy({
    int? count,
    List<Map<String, Object?>>? sequence,
    List<_HasRelationRunner>? hasRelations,
    _ForBinding? forBinding,
  }) => _FactoryPlan<T>(
    factory: _factory,
    count: count ?? _count,
    sequence: sequence ?? _sequence,
    hasRelations: hasRelations ?? _hasRelations,
    forBinding: forBinding ?? _forBinding,
  );
}
