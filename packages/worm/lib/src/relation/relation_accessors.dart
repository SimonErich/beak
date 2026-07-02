/// Typed runtime accessors exposing relation operations on Model
/// instances (`user.posts.add(post)`, `user.roles.sync([…])`).
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_descriptor.dart';
import '../registry/worm.dart';
import 'belongs_to_many.dart';
import 'has_many.dart';
import 'has_one.dart';
import 'pivot.dart';

/// Resolves the adapter for [model] from the [Worm] registry.
DatabaseAdapter _adapterFor(Model model) => Worm.adapter(model.connectionName);

/// Runtime accessor for a `HasMany` / `HasOne` relation pair.
///
/// Operates as a thin wrapper around the relation's child-side FK so
/// callers can write `user.posts.add(post)` and have the child rows
/// persisted with the parent's primary key automatically.
final class HasManyAccessor<Parent extends Model, Child extends Model> {
  /// Creates a [HasManyAccessor].
  ///
  /// [resolveAdapter] is an optional lazy hook that lets generated
  /// code pass `Worm.adapter` explicitly so the accessor never has to
  /// look the runtime up implicitly. When omitted the accessor falls
  /// back to `Worm.adapter(parent.connectionName)` at call time.
  const HasManyAccessor({
    required this.parent,
    required this.relation,
    this.resolveAdapter,
  });

  /// Parent model owning the relation.
  final Parent parent;

  /// HasMany relation metadata.
  final HasManyRelation<Parent, Child> relation;

  /// Optional adapter resolver supplied by generated code. When non-
  /// null, used in lieu of the implicit `Worm.adapter` lookup.
  final DatabaseAdapter Function()? resolveAdapter;

  DatabaseAdapter _adapter() => resolveAdapter?.call() ?? _adapterFor(parent);

  /// Append [child] to this relation.
  ///
  /// Sets the FK column on [child] to the parent's primary key and
  /// persists via [Model.save]. The cached list under
  /// `parent.relations[name]` is invalidated so the next read
  /// refetches from the adapter.
  Future<void> add(Child child) async {
    child.setAttribute(relation.foreignKey, parent.id);
    await child.save();
    parent.relations.remove(relation.name);
  }

  /// Append every [children] entry. Equivalent to calling [add] for
  /// each, but skips clearing the cache between rows.
  Future<void> addAll(Iterable<Child> children) async {
    for (final child in children) {
      child.setAttribute(relation.foreignKey, parent.id);
      await child.save();
    }
    parent.relations.remove(relation.name);
  }

  /// Reload this relation from the adapter, replacing any cached
  /// list under `parent.relations[name]`.
  Future<List<Child>> get() async {
    final adapter = _adapter();
    final field = Field<Object?>(relation.foreignKey);
    final rows = await adapter.select(
      QueryDescriptor(table: relation.childTable, where: field.eq(parent.id)),
    );
    final hydrated = <Child>[
      for (final row in rows) relation.hydrateChild(row),
    ];
    parent.relations[relation.name] = hydrated;
    return hydrated;
  }

  /// Spec-vocabulary alias for [get] — returns the children whose
  /// foreign key matches the parent's primary key from the adapter.
  Future<List<Child>> list() => get();

  /// Detach [child] from this relation by nulling its FK column and
  /// re-saving it. The child row remains in the database with a null
  /// foreign key.
  Future<void> dissociate(Child child) async {
    child.setAttribute(relation.foreignKey, null);
    await child.save();
    parent.relations.remove(relation.name);
  }
}

/// Runtime accessor for a `HasOne` relation.
final class HasOneAccessor<Parent extends Model, Child extends Model> {
  /// Creates a [HasOneAccessor].
  ///
  /// [resolveAdapter] mirrors [HasManyAccessor.resolveAdapter] — an
  /// optional lazy hook so generated code can pass `Worm.adapter`
  /// explicitly. Falls back to `Worm.adapter(parent.connectionName)`
  /// when omitted.
  const HasOneAccessor({
    required this.parent,
    required this.relation,
    this.resolveAdapter,
  });

  /// Parent model owning the relation.
  final Parent parent;

  /// HasOne relation metadata.
  final HasOneRelation<Parent, Child> relation;

  /// Optional adapter resolver supplied by generated code. When non-
  /// null, used in lieu of the implicit `Worm.adapter` lookup.
  final DatabaseAdapter Function()? resolveAdapter;

  DatabaseAdapter _adapter() => resolveAdapter?.call() ?? _adapterFor(parent);

  /// Set the relation's child to [child], persisting it.
  Future<void> associate(Child child) async {
    child.setAttribute(relation.foreignKey, parent.id);
    await child.save();
    parent.relations.remove(relation.name);
  }

  /// Reload the related child from the adapter.
  Future<Child?> get() async {
    final adapter = _adapter();
    final field = Field<Object?>(relation.foreignKey);
    final row = await adapter.selectOne(
      QueryDescriptor(
        table: relation.childTable,
        where: field.eq(parent.id),
        limit: 1,
      ),
    );
    if (row == null) {
      parent.relations[relation.name] = null;
      return null;
    }
    final hydrated = relation.hydrateChild(row);
    parent.relations[relation.name] = hydrated;
    return hydrated;
  }

  /// Spec-vocabulary alias for [associate].
  Future<void> set(Child child) => associate(child);

  /// Disassociate the current child by nulling its foreign key.
  ///
  /// Loads the current row through [get] so the child's
  /// `beforeSave` / `afterSave` hooks run on the save that nulls
  /// the FK. No-op when no child is currently associated.
  Future<void> clear() async {
    final current = await get();
    if (current == null) return;
    // [get] hydrates a fresh instance from the row; mark it as
    // persisted so the subsequent [Model.save] takes the UPDATE
    // branch rather than re-INSERTing the row.
    current
      ..markPersisted()
      ..setAttribute(relation.foreignKey, null);
    await current.save();
    parent.relations.remove(relation.name);
  }
}

/// Runtime accessor for a `BelongsToMany` relation via its pivot
/// table. Exposes `attach` / `detach` / `sync` mirroring the spec
/// vocabulary.
final class BelongsToManyAccessor<Parent extends Model, Related extends Model> {
  /// Creates a [BelongsToManyAccessor].
  const BelongsToManyAccessor({required this.parent, required this.relation});

  /// Parent model owning the relation.
  final Parent parent;

  /// BelongsToMany metadata describing the pivot.
  final BelongsToManyRelation<Parent, Related> relation;

  PivotManager _manager() => PivotManager(
    adapter: _adapterFor(parent),
    pivotTable: relation.pivotTable,
    parentPivotKey: relation.parentPivotKey,
    relatedPivotKey: relation.relatedPivotKey,
    parentId: parent.id,
  );

  /// Attach [relatedId] (with optional [pivotData]).
  Future<void> attach(
    Object relatedId, {
    Map<String, Object?> pivotData = const <String, Object?>{},
  }) async {
    await _manager().attach(relatedId, pivotData: pivotData);
    parent.relations.remove(relation.name);
  }

  /// Attach every [ids] entry.
  Future<void> attachAll(Iterable<Object> ids) async {
    final manager = _manager();
    for (final id in ids) {
      await manager.attach(id);
    }
    parent.relations.remove(relation.name);
  }

  /// Detach [relatedId]. Returns the number of pivot rows removed.
  Future<int> detach(Object relatedId) async {
    final removed = await _manager().detach(relatedId);
    parent.relations.remove(relation.name);
    return removed;
  }

  /// Detach every [ids] entry. Returns the total number of pivot
  /// rows removed.
  Future<int> detachAll(Iterable<Object> ids) async {
    final manager = _manager();
    var total = 0;
    for (final id in ids) {
      total += await manager.detach(id);
    }
    parent.relations.remove(relation.name);
    return total;
  }

  /// Replace the parent's pivot rows so they reference exactly
  /// [relatedIds].
  Future<PivotSyncResult> sync(List<Object> relatedIds) async {
    final result = await _manager().sync(relatedIds);
    parent.relations.remove(relation.name);
    return result;
  }
}
