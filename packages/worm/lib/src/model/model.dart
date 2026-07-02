/// Base class for ORM-managed models.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import '../cast/cast_manager.dart';
import '../exception/lazy_loading_exception.dart';
import '../exception/mass_assignment_exception.dart';
import '../exception/relation_not_loaded_exception.dart';
import '../exception/uninitialized_field_exception.dart';
import '../exception/unsupported_operation_exception.dart';
import '../query/field.dart';
import '../registry/worm.dart';
import '../relation/orm_cascade.dart';
import '../serialization/serializable.dart';
import '../serialization/serializer.dart';
import '../transaction/transaction_context.dart';
import '../validation/validation_rule.dart';
import 'active_record.dart';
import 'model_hooks.dart';
import 'model_state.dart';

/// Base class for ORM-managed models.
///
/// Provides the attribute store, dirty tracking, timestamp
/// management, mass-assignment protection, lifecycle hooks, and
/// the Active Record `save` / `delete` / `refresh` API.
///
/// Concrete models override [id] and [toRow] (consumed by the
/// query builder, eager loader, and serializer). Optional
/// overrides cover [tableName], [primaryKeyColumn], [fillable],
/// [guarded], timestamp columns, and lifecycle hooks.
abstract class Model with ModelHooks implements Serializable {
  /// Creates a [Model].
  Model();

  /// Stores eager-loaded relations keyed by name.
  ///
  /// Mutated by the eager loader and read back through [getRelation].
  /// Internal to the package — consumers use [getRelation] / generated
  /// relation accessors rather than touching this map directly.
  @internal
  final Map<String, Object?> relations = <String, Object?>{};

  /// Stores aggregate values populated by `withCount`, `withSum`,
  /// and similar query builder methods. Use [getInjected] for typed
  /// access with a typed [UninitializedFieldException] on miss.
  @internal
  final Map<String, Object?> injectedFields = <String, Object?>{};

  /// Tracked per-instance state (attributes, dirty set, original
  /// snapshot, persisted flag, `withoutTimestamps` flag, and
  /// `afterCommit` callbacks). Internal to the package; mutate it
  /// through [setAttribute] / [hydrateAttribute] / [fill].
  @internal
  final ModelState state = ModelState();

  /// The primary key value of this model.
  Object get id;

  /// Serializes the model to a database row.
  Map<String, Object?> toRow();

  /// Database table this model is persisted in.
  ///
  /// Returns `null` to defer to the runtime registration; Active
  /// Record then looks the value up via the `Worm` registry.
  String? get tableName => null;

  /// Connection name to use for this model.
  String get connectionName => 'default';

  /// Primary-key column name.
  String get primaryKeyColumn => 'id';

  /// `created_at` column name.
  String get createdAtColumn => 'created_at';

  /// `updated_at` column name.
  String get updatedAtColumn => 'updated_at';

  /// Whether this model maintains [createdAtColumn] /
  /// [updatedAtColumn] automatically.
  bool get usesTimestamps => true;

  /// Mass-assignment whitelist; empty means "no whitelist".
  ///
  /// Generated overrides emit `@Fillable(['…'])` values here.
  List<String> get fillable => const <String>[];

  /// Fields rejected by [fill] regardless of [fillable].
  ///
  /// Generated overrides emit `@Guarded(['…'])` values here.
  List<String> get guarded => const <String>[];

  /// When `true`, [fill] throws [MassAssignmentException] on a
  /// guarded / non-fillable field instead of silently skipping it.
  bool get strictMassAssignment => false;

  /// Field names hidden from [toMap] / [toJson] output.
  ///
  /// Generated overrides emit `@Hidden`-annotated columns here.
  Set<String> get hiddenFromSerialization => const <String>{};

  /// Extra attributes appended to [toMap] / [toJson] output that do
  /// not correspond to a database column.
  ///
  /// Generated overrides emit `@Computed`- and `@Appended`-annotated
  /// getters here; both annotations share runtime semantics — the
  /// value appears in the serialized output but never in [toRow].
  Map<String, Object?> get computedAttributes => const <String, Object?>{};

  /// Casts to apply on persistence and hydration.
  ///
  /// Generated overrides emit `@CastAs`-annotated columns here. The
  /// default returns an empty manager so untouched models pay no
  /// per-call cost.
  CastManager get castManager => CastManager();

  /// ORM-side cascade specs consulted by `ActiveRecord.delete` when
  /// a parent is deleted under `OnDelete.ormCascade`.
  ///
  /// Generated overrides emit one entry per relation annotated with
  /// `OnDelete.ormCascade`. Defaults to empty so models without
  /// ormCascade relations behave exactly as before.
  List<OrmCascadeSpec> get ormCascadeSpecs => const <OrmCascadeSpec>[];

  /// Validation rules applied automatically on [save], keyed by the
  /// typed [Field] they validate.
  ///
  /// Declared with generated companion fields, e.g.
  /// `{User$.email: [Required(), Email()]}`. A `save` collects the
  /// current attribute values, runs every rule, and throws
  /// `ValidationException` (cancelling the write) when any rule fails.
  /// Defaults to empty so models without rules pay no validation cost.
  Map<Field<Object?>, List<ValidationRule>> get rules =>
      const <Field<Object?>, List<ValidationRule>>{};

  /// Validation rules applied on the update path instead of [rules].
  ///
  /// Defaults to [rules]; only the rules whose field is dirty are run
  /// on an update, so an unchanged-but-legacy column never blocks an
  /// unrelated edit. Override to narrow or widen the update rule set.
  Map<Field<Object?>, List<ValidationRule>> get updateRules => rules;

  /// Whether this instance has been persisted at least once.
  bool get exists => state.exists;

  /// Whether any tracked attribute has been mutated since the last
  /// sync. Pass a [field] name to test just that key.
  bool isDirty([String? field]) {
    if (field == null) return state.dirty.isNotEmpty;
    return state.dirty.contains(field);
  }

  /// Set of keys mutated since the last save / sync (unmodifiable).
  Set<String> get dirtyFields => Set<String>.unmodifiable(state.dirty);

  /// Apply [value] to attribute [name] and mark it dirty.
  void setAttribute(String name, Object? value) {
    state.setAttribute(name, value);
  }

  /// Read the live value of attribute [name].
  Object? getAttribute(String name) => state.attributes[name];

  /// Pre-modification value of [name], or `null` if untouched.
  Object? getOriginal(String name) => state.original[name];

  /// Typed pre-modification value for [field].
  ///
  /// Returns the original value snapshotted at the last save/hydrate
  /// when it is a [T], or `null` when the field is untouched or the
  /// stored value is not a [T].
  T? getOriginalValue<T>(Field<T> field) {
    final value = state.original[field.name];
    return value is T ? value : null;
  }

  /// Seed an attribute without marking it dirty.
  ///
  /// Hydrators call this for every column, then call [markPersisted]
  /// once to snapshot the original values and flag the row as
  /// persisted.
  void hydrateAttribute(String name, Object? value) {
    state.seedAttribute(name, value);
  }

  /// Snapshot the current attributes as original and mark the row
  /// as persisted.
  void markPersisted() {
    state
      ..exists = true
      ..syncOriginal();
  }

  /// Mass-assigns [data] honoring [fillable] / [guarded].
  ///
  /// In strict mode every offending key is collected and reported
  /// together via [MassAssignmentException.fields]; in non-strict
  /// mode offending keys are silently skipped.
  void fill(Map<String, Object?> data) {
    // Strict when the model opts in, or when the global
    // `preventSilentMassAssignment` policy is active outside an
    // `unsafe` block.
    final strict =
        strictMassAssignment ||
        (Worm.strictness.preventSilentMassAssignment && !Worm.isUnsafe);
    final offending = <String>[];
    for (final entry in data.entries) {
      if (!_isFillable(entry.key)) {
        if (strict) {
          offending.add(entry.key);
        }
        continue;
      }
      setAttribute(entry.key, entry.value);
    }
    if (offending.isEmpty) return;
    throw MassAssignmentException.forFields(
      model: '$runtimeType',
      fields: offending,
      message: offending.length == 1
          ? 'Field "${offending.first}" is not fillable on $runtimeType'
          : 'Fields ${offending.join(', ')} are not fillable on $runtimeType',
    );
  }

  bool _isFillable(String field) {
    if (guarded.contains(field)) return false;
    if (fillable.isEmpty) return true;
    return fillable.contains(field);
  }

  /// Suspend automatic timestamp maintenance for [callback].
  Future<T> withoutTimestamps<T>(Future<T> Function() callback) async {
    final previous = state.withoutTimestamps;
    state.withoutTimestamps = true;
    try {
      return await callback();
    } finally {
      state.withoutTimestamps = previous;
    }
  }

  /// Queue [callback] to fire after the current operation commits.
  ///
  /// Outside a transaction this fires immediately after the
  /// surrounding save / delete completes successfully — the
  /// no-op wrapper case documented in the spec.
  void afterCommit(void Function() callback) {
    state.afterCommitCallbacks.add(callback);
  }

  /// Typed accessor for an eager-loaded relation.
  ///
  /// Returns the value stored under [name] in [relations] when it
  /// matches [T]. When no value has been loaded, behaviour depends
  /// on strict mode:
  ///
  /// - Inside `Worm.unsafe(...)` the call returns `null` so callers
  ///   that opted into the bypass can probe for unloaded relations
  ///   without exceptions.
  /// - With `StrictnessConfig.preventLazyLoading` enabled the call
  ///   throws [LazyLoadingException] so accidental lazy loads surface
  ///   as a deliberate policy violation.
  /// - Otherwise the call throws [RelationNotLoadedException], which
  ///   signals an accidental access on a relation that was never
  ///   eagerly loaded — silently returning `null` would hide the
  ///   missing eager load.
  T? getRelation<T>(String name) {
    if (relations.containsKey(name)) {
      final value = relations[name];
      if (value is T) return value;
      return null;
    }
    if (Worm.isUnsafe) return null;
    if (Worm.strictness.preventLazyLoading) {
      throw LazyLoadingException(
        modelName: '$runtimeType',
        relationName: name,
        message:
            'Relation "$name" on $runtimeType was accessed without an '
            'eager load. Strict mode (preventLazyLoading) forbids '
            'implicit lazy loads; add the relation to .withRelations '
            'or wrap the access in Worm.unsafe(() async { ... }).',
      );
    }
    throw RelationNotLoadedException(
      model: '$runtimeType',
      relationName: name,
      message:
          'Relation "$name" on $runtimeType has not been eagerly '
          'loaded. Add the relation to .withRelations before access.',
    );
  }

  /// Typed accessor for a virtual aggregate field populated by
  /// `withCount` / `withSum` / `withExists`.
  ///
  /// Throws [UninitializedFieldException] when the field was not
  /// populated by a prior aggregate injection.
  T getInjected<T>(String name) {
    if (!injectedFields.containsKey(name)) {
      throw UninitializedFieldException(
        model: '$runtimeType',
        field: name,
        message:
            'Field "$name" was not populated. Call withCount / withSum / '
            'withExists in your query before accessing $name.',
      );
    }
    final value = injectedFields[name];
    if (value is T) return value;
    throw UninitializedFieldException(
      model: '$runtimeType',
      field: name,
      message: 'Field "$name" was populated with an incompatible type for $T.',
    );
  }

  /// Serialize this model to a JSON-shaped map.
  ///
  /// Built from [describe]: starts from `descriptor.fields` (the
  /// column-backed representation supplied by [toRow] in the base
  /// implementation), drops every name in `descriptor.hidden`, then
  /// appends every entry from `descriptor.appended`. Subclasses
  /// customize the source shape by overriding [describe]; overriding
  /// [toMap] directly is unsupported because the `Serializer` pipeline
  /// reads [describe], not [toMap], and the two would drift.
  ///
  /// Optional parameters refine the output per call:
  /// - [includeRelations] walks loaded relations via the cycle-aware
  ///   [Serializer], capped at [maxDepth] nested levels.
  /// - [hidden] removes additional keys beyond `descriptor.hidden`.
  /// - [only] restricts the output to the named keys (a whitelist).
  Map<String, Object?> toMap({
    Set<String>? only,
    Set<String>? hidden,
    bool includeRelations = false,
    int maxDepth = 2,
  }) {
    final Map<String, Object?> out;
    if (includeRelations) {
      out = Serializer(maxDepth: maxDepth).toMap(this);
    } else {
      final descriptor = describe();
      out = <String, Object?>{...descriptor.fields};
      for (final key in descriptor.hidden) {
        out.remove(key);
      }
      out.addAll(descriptor.appended);
    }
    if (hidden != null) {
      for (final key in hidden) {
        out.remove(key);
      }
    }
    if (only != null) {
      out.removeWhere((key, _) => !only.contains(key));
    }
    return out;
  }

  /// Serialize this model to a JSON string. Defers to [toMap], which
  /// itself is built from [describe] — overriding [describe] is the
  /// supported customization point.
  String toJson() => jsonEncode(toMap());

  /// Stable identifier used by the cycle-detecting [Serializable]
  /// pipeline. Two model instances with the same id are treated as
  /// the same graph node.
  @override
  String get serializationId => '$id';

  /// Stable type tag used by the [Serializable] pipeline when
  /// collapsing cycles. Defaults to the Dart runtime type name; the
  /// generator may override this to a stable string when an obfuscated
  /// build would otherwise erase it.
  @override
  String get serializationType => '$runtimeType';

  /// Build the snapshot the `Serializer` consumes. Defaults to the
  /// same shape [toRow] / [hiddenFromSerialization] /
  /// [computedAttributes] already expose, so the JSON output matches
  /// [toMap] for the no-override case.
  ///
  /// Generated overrides extend this to wire `@Hidden`, `@Computed`,
  /// `@Appended`, and relation accessors into the serialized output.
  @override
  SerializationDescriptor describe() => SerializationDescriptor(
    fields: toRow(),
    hidden: hiddenFromSerialization,
    appended: computedAttributes,
  );

  /// Persist this model.
  ///
  /// Inserts when [exists] is `false`, updates otherwise. Returns
  /// `true` on success; returns `false` when any `before*` hook
  /// cancels.
  ///
  /// Pass [transaction] to enlist the write in an explicit
  /// [TransactionContext]; otherwise the save automatically joins any
  /// ambient `Worm.transaction`.
  Future<bool> save({TransactionContext? transaction}) =>
      ActiveRecord.save(this, transaction: transaction);

  /// Delete this model. Returns `true` on success; `false` when
  /// [beforeDelete] cancels.
  ///
  /// Pass [transaction] to enlist the delete in an explicit
  /// [TransactionContext]; otherwise it joins any ambient
  /// `Worm.transaction`.
  Future<bool> delete({TransactionContext? transaction}) =>
      ActiveRecord.delete(this, transaction: transaction);

  /// Hard-delete this model, bypassing soft-delete.
  ///
  /// On a plain model this is identical to [delete]'s database effect;
  /// models mixing in `SoftDeletes` override this to issue a real
  /// `DELETE` instead of setting `deleted_at`.
  Future<bool> forceDelete({TransactionContext? transaction}) =>
      ActiveRecord.delete(this, transaction: transaction);

  /// Mass-assign [data] (honoring `fillable` / `guarded`) and persist.
  ///
  /// A convenience for `fill(data)` then `save()`; propagates the same
  /// `MassAssignmentException` / `ValidationException` those calls
  /// raise. Returns the [save] result.
  Future<bool> update(
    Map<String, Object?> data, {
    TransactionContext? transaction,
  }) {
    fill(data);
    return save(transaction: transaction);
  }

  /// Re-read this model from the database.
  Future<void> refresh() => ActiveRecord.refresh(this);

  /// Build the attribute map for a [replicate] clone.
  ///
  /// Copies the live attributes minus the primary key, timestamp
  /// columns, and any [except] names — the shared core overriding
  /// models reuse when constructing a fresh, unsaved instance.
  @protected
  Map<String, Object?> replicatedAttributes({
    List<String> except = const <String>[],
  }) {
    final excluded = <String>{
      primaryKeyColumn,
      createdAtColumn,
      updatedAtColumn,
      ...except,
    };
    return <String, Object?>{
      for (final entry in state.attributes.entries)
        if (!excluded.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// Create an unsaved copy of this model with a fresh primary key.
  ///
  /// The clone carries every attribute except the primary key,
  /// timestamps, and any [except] columns (see [replicatedAttributes])
  /// and has `exists == false`, so the next [save] inserts a new row.
  ///
  /// Because Dart cannot construct a subtype generically, the worm
  /// generator emits a concrete override per model; this default throws
  /// [UnsupportedOperationException] to flag a hand-written model that
  /// must provide its own implementation.
  Model replicate({List<String> except = const <String>[]}) {
    throw UnsupportedOperationException(
      operation: 'replicate',
      message:
          'replicate() on $runtimeType requires generated code or an '
          'override. Run the worm generator, or override replicate() '
          'using replicatedAttributes(except: ...).',
    );
  }
}
