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
import '../query/predicate_tree.dart';
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
/// Executes one query per distinct relation path
/// segment (one parent query + one query per relation
/// level, with paths sharing a head merged into a
/// single load), avoiding the classic N+1 query
/// explosion. Morph and pivot relations are the only
/// allowed exceptions, documented in their
/// implementations.
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

    // Paths sharing a head (e.g. 'items.product' and 'items.tax') must
    // resolve through ONE load of that head: independent loads would each
    // re-fetch fresh child instances and overwrite the parents' relation
    // slot, silently dropping every sibling's nested data but the last.
    final groups = _groupByHead(loads);

    // Each merged head-group and aggregate is independent — it reads its
    // own child table and writes a distinct key on every parent — so they
    // can run concurrently. We only do so outside a transaction: inside
    // one, every operation shares a single connection that cannot service
    // overlapping queries.
    Future<int> loadTask(_HeadLoad group) => _loadGroup(
      adapter: context.adapter,
      relations: context.relations,
      relationsByTable: context.relationsByTable,
      table: context.table,
      parents: modelParents,
      load: group,
    );
    Future<int> aggregateTask(AggregateInjection aggregate) => _injectAggregate(
      adapter: context.adapter,
      relations: context.relations,
      relationsByTable: context.relationsByTable,
      table: context.table,
      parents: modelParents,
      aggregate: aggregate,
    );

    final taskCount = groups.length + aggregates.length;
    if (taskCount > 1 && Worm.currentTransaction == null) {
      final counts = await Future.wait(<Future<int>>[
        for (final group in groups) loadTask(group),
        for (final aggregate in aggregates) aggregateTask(aggregate),
      ]);
      return counts.fold<int>(0, (sum, count) => sum + count);
    }

    var queries = 0;
    for (final group in groups) {
      queries += await loadTask(group);
    }
    for (final aggregate in aggregates) {
      queries += await aggregateTask(aggregate);
    }
    return queries;
  }

  /// Merges [loads] so every unconstrained head is loaded exactly once,
  /// carrying all of its sibling tails.
  ///
  /// Constrained loads keep their own entry: merging two different
  /// constraints under one head would change which child rows are
  /// selected. First-seen order is preserved.
  static List<_HeadLoad> _groupByHead(List<EagerLoad> loads) {
    final groups = <_HeadLoad>[];
    final byHead = <String, _HeadLoad>{};
    for (final load in loads) {
      final tail = load.tail;
      if (load.constrain != null) {
        groups.add(
          _HeadLoad(
            head: load.head,
            constrain: load.constrain,
            tails: [if (tail != null) EagerLoad(tail), ...load.nested],
          ),
        );
        continue;
      }
      final group = byHead.putIfAbsent(load.head, () {
        final created = _HeadLoad(head: load.head, tails: []);
        groups.add(created);
        return created;
      });
      if (tail != null) group.tails.add(EagerLoad(tail));
      group.tails.addAll(load.nested);
    }
    return groups;
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

  static Future<int> _loadGroup({
    required DatabaseAdapter adapter,
    required Map<String, Relation<Model, Model>> relations,
    required Map<String, Map<String, Relation<Model, Model>>> relationsByTable,
    required String? table,
    required List<Model> parents,
    required _HeadLoad load,
  }) async {
    final relation = _requireRelation(
      relations,
      relationsByTable,
      table,
      load.head,
    );
    final result = await relation.loadWithFilter(
      adapter,
      parents,
      extraFilter: load.constrain,
    );
    var queries = result.stats.queriesExecuted;
    for (final parent in parents) {
      result.setOnParent(parent);
    }
    if (load.tails.isEmpty) return queries;
    final children = <Model>[
      for (final parent in parents) ...?_childrenOf(parent, load.head),
    ];
    if (children.isEmpty) return queries;
    // Sibling tails write distinct keys onto the SAME child instances the
    // head-load just installed, so every nested relation survives. The next
    // level resolves against the loaded side's table so same-named
    // relations on different tables cannot cross-wire.
    for (final nested in _groupByHead(load.tails)) {
      queries += await _loadGroup(
        adapter: adapter,
        relations: relations,
        relationsByTable: relationsByTable,
        table: relation.targetTable,
        parents: children,
        load: nested,
      );
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
    required Map<String, Map<String, Relation<Model, Model>>> relationsByTable,
    required String? table,
    required List<Model> parents,
    required AggregateInjection aggregate,
  }) async {
    final relation = _requireRelation(
      relations,
      relationsByTable,
      table,
      aggregate.relationName,
    );
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
    Map<String, Map<String, Relation<Model, Model>>> relationsByTable,
    String? table,
    String name,
  ) {
    final scoped = table == null ? null : relationsByTable[table]?[name];
    final found = scoped ?? relations[name];
    if (found == null) {
      throw ConfigurationException(
        key: 'relation.unknown',
        message: 'No relation named "$name"',
      );
    }
    return found;
  }
}

/// One merged relation load: a single fetch of [head] (optionally
/// [constrain]ed) plus every sibling nested path under it, so all
/// tails attach to the same loaded child instances.
final class _HeadLoad {
  _HeadLoad({required this.head, required this.tails, this.constrain});
  final String head;
  final PredicateTree? constrain;
  final List<EagerLoad> tails;
}

final class _AggregateRelationSpec {
  const _AggregateRelationSpec({
    required this.childTable,
    required this.foreignKey,
  });
  final String childTable;
  final String foreignKey;
}
