/// Batched eager-loader for relation paths.
library;

import '../adapter/database_adapter.dart';
import '../exception/configuration_exception.dart';
import '../exception/unsupported_operation_exception.dart';
import '../model/model.dart';
import '../query/aggregate_descriptor.dart';
import '../query/eager_load.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_context.dart';
import '../query/query_descriptor.dart';
import '../registry/worm.dart';
import 'has_many.dart';
import 'has_one.dart';
import 'relation_base.dart';
import 'relation_definition.dart';

/// Resolver that turns [EagerLoad] paths into batched
/// queries that mutate parent models in place.
///
/// Executes exactly N+1 queries for N relationship
/// paths (one parent query + one query per relation),
/// avoiding the classic N+1 query explosion. Morph
/// and pivot relations are the only allowed
/// exceptions, documented in their implementations.
abstract final class EagerLoader {
  /// Run every entry in [loads] and [aggregates]
  /// against [parents].
  static Future<int> run<T extends Model>({
    required QueryContext<T> context,
    required List<T> parents,
    required List<EagerLoad> loads,
    required List<AggregateInjection> aggregates,
  }) async {
    if (parents.isEmpty) return 0;
    final modelParents = <Model>[...parents];

    // Each top-level relation load and aggregate is independent — it
    // reads its own child table and writes a distinct key on every
    // parent — so they can run concurrently. We only do so outside a
    // transaction: inside one, every operation shares a single
    // connection that cannot service overlapping queries.
    Future<int> loadTask(EagerLoad load) => _loadOne(
      adapter: context.adapter,
      relations: context.relations,
      parents: modelParents,
      load: load,
    );
    Future<int> aggregateTask(AggregateInjection aggregate) => _injectAggregate(
      adapter: context.adapter,
      relations: context.relations,
      parents: modelParents,
      aggregate: aggregate,
    );

    final taskCount = loads.length + aggregates.length;
    if (taskCount > 1 && Worm.currentTransaction == null) {
      final counts = await Future.wait(<Future<int>>[
        for (final load in loads) loadTask(load),
        for (final aggregate in aggregates) aggregateTask(aggregate),
      ]);
      return counts.fold<int>(0, (sum, count) => sum + count);
    }

    var queries = 0;
    for (final load in loads) {
      queries += await loadTask(load);
    }
    for (final aggregate in aggregates) {
      queries += await aggregateTask(aggregate);
    }
    return queries;
  }

  /// Batch-load the morph-to references for [children]
  /// described by [definition].
  ///
  /// Groups children by their morph type, then issues
  /// one `SELECT` per distinct type observed in
  /// [children] — explicitly the documented exception
  /// to the "1 query per relation path" baseline.
  ///
  /// Each child receives a sealed-union value `S?` under
  /// `child.relations[definition.name]`. Children whose
  /// morph type is null, missing from the hydrate map,
  /// or whose referenced row is absent receive `null`.
  static Future<int> loadMorphTo<Child extends Model, S extends Object>({
    required DatabaseAdapter adapter,
    required List<Child> children,
    required MorphToDefinition<Child, S> definition,
  }) => _loadMorphTo<Child, S>(
    adapter: adapter,
    children: children,
    definition: definition,
  );

  static Future<int> _loadMorphTo<Child extends Model, S extends Object>({
    required DatabaseAdapter adapter,
    required List<Child> children,
    required MorphToDefinition<Child, S> definition,
  }) async {
    final byType = <String, List<Child>>{};
    for (final child in children) {
      final type = child.toRow()[definition.morphTypeColumn];
      if (type is String) {
        byType.putIfAbsent(type, () => <Child>[]).add(child);
      }
    }
    final perChild = <Child, S>{};
    var queries = 0;
    for (final entry in byType.entries) {
      final binding = definition.hydrateMap[entry.key];
      if (binding == null) continue;
      final ids = <Object?>{
        for (final c in entry.value) c.toRow()[definition.morphIdColumn],
      }.whereType<Object>().toList();
      if (ids.isEmpty) continue;
      final field = Field<Object?>(binding.ownerKey);
      final rows = await adapter.select(
        QueryDescriptor(table: binding.table, where: field.inList(ids)),
      );
      queries++;
      final byOwner = <Object?, Model>{
        for (final row in rows) row[binding.ownerKey]: binding.hydrate(row),
      };
      for (final child in entry.value) {
        final ownerId = child.toRow()[definition.morphIdColumn];
        final parent = byOwner[ownerId];
        if (parent != null) {
          perChild[child] = binding.wrap(parent);
        }
      }
    }
    for (final child in children) {
      child.relations[definition.name] = perChild[child];
    }
    return queries;
  }

  static Future<int> _loadOne({
    required DatabaseAdapter adapter,
    required Map<String, Relation<Model, Model>> relations,
    required List<Model> parents,
    required EagerLoad load,
  }) async {
    final relation = _requireRelation(relations, load.head);
    final result = await relation.loadWithFilter(
      adapter,
      parents,
      extraFilter: load.constrain,
    );
    var queries = result.stats.queriesExecuted;
    for (final parent in parents) {
      result.setOnParent(parent);
    }
    final tail = load.tail;
    if (tail != null) {
      final children = <Model>[
        for (final parent in parents) ...?_childrenOf(parent, load.head),
      ];
      if (children.isNotEmpty) {
        queries += await _loadOne(
          adapter: adapter,
          relations: relations,
          parents: children,
          load: EagerLoad(tail),
        );
      }
    }
    return queries;
  }

  static Iterable<Model>? _childrenOf(Model parent, String name) {
    final value = parent.relations[name];
    if (value == null) return const <Model>[];
    if (value is Model) return <Model>[value];
    if (value is List<Model>) return value;
    return const <Model>[];
  }

  static Future<int> _injectAggregate({
    required DatabaseAdapter adapter,
    required Map<String, Relation<Model, Model>> relations,
    required List<Model> parents,
    required AggregateInjection aggregate,
  }) async {
    final relation = _requireRelation(relations, aggregate.relationName);
    final spec = _aggregateSpecFor(relation, aggregate);
    final parentIds = <Object?>{for (final p in parents) p.id}.toList();
    if (parentIds.isEmpty) return 0;
    final field = Field<Object?>(spec.foreignKey);
    final base = field.inList(parentIds);
    final filter = aggregate.filter;
    final where = filter == null ? base : base.and(filter);
    // Push the rollup into the database: one `GROUP BY foreignKey`
    // query returns a single value per parent instead of every child
    // row. `count` / `exists` use COUNT(*); `sum` uses SUM(column).
    final isSum =
        aggregate.kind == AggregateKind.sum && aggregate.column != null;
    final grouped = await adapter.aggregateGrouped(
      AggregateDescriptor(
        table: spec.childTable,
        function: isSum ? AggregateFunction.sum : AggregateFunction.count,
        column: isSum ? aggregate.column : null,
        where: where,
        groupBy: spec.foreignKey,
      ),
    );
    for (final parent in parents) {
      switch (aggregate.kind) {
        case AggregateKind.count:
          parent.injectedFields[aggregate.injectionKey] =
              (grouped[parent.id] ?? 0).toInt();
        case AggregateKind.sum:
          parent.injectedFields[aggregate.injectionKey] =
              grouped[parent.id] ?? 0;
        case AggregateKind.exists:
          parent.injectedFields[aggregate.injectionKey] = grouped.containsKey(
            parent.id,
          );
      }
    }
    return 1;
  }

  static _AggregateRelationSpec _aggregateSpecFor(
    Relation<Model, Model> relation,
    AggregateInjection aggregate,
  ) {
    if (relation is HasManyRelation<Model, Model>) {
      return _AggregateRelationSpec(
        childTable: relation.childTable,
        foreignKey: relation.foreignKey,
      );
    }
    if (relation is HasOneRelation<Model, Model>) {
      return _AggregateRelationSpec(
        childTable: relation.childTable,
        foreignKey: relation.foreignKey,
      );
    }
    throw UnsupportedOperationException(
      operation: 'aggregate.${aggregate.injectionKey}',
      message:
          'Aggregate "${aggregate.injectionKey}" is only supported for '
          'HasMany / HasOne relations',
    );
  }

  static Relation<Model, Model> _requireRelation(
    Map<String, Relation<Model, Model>> relations,
    String name,
  ) {
    final found = relations[name];
    if (found == null) {
      throw ConfigurationException(
        key: 'relation.unknown',
        message: 'No relation named "$name"',
      );
    }
    return found;
  }
}

final class _AggregateRelationSpec {
  const _AggregateRelationSpec({
    required this.childTable,
    required this.foreignKey,
  });
  final String childTable;
  final String foreignKey;
}
