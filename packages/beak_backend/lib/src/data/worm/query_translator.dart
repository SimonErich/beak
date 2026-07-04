import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import 'column_type_mapper.dart';
import 'worm_record_model.dart';

/// Translates Beak's serializable query language into worm query builders.
///
/// The translator is fully generic: it works off [BeakModel] metadata and
/// the registry alone, so a single code path serves every registered model.
/// Filters become predicate trees, searches become case-insensitive OR
/// groups, relation loads become batched eager-load paths, and soft-deleting
/// models are scoped with worm's [SoftDeleteScope] (lifted by
/// `withTrashed`).
///
/// It is the engine behind [WormDataSource]; you rarely construct it
/// directly, but it is exported for tools that need to inspect the worm
/// query a spec produces.
///
/// ```dart
/// final translator = WormQueryTranslator(registry);
/// final builder = translator.builderFor(
///   BeakQuerySpec(
///     table: 'products',
///     filter: BeakFieldFilter.forKey(
///       'price',
///       BeakOperator.gte,
///       BeakValue.of(10),
///     ),
///     relationLoads: [BeakRelationLoad('category')],
///   ),
///   adapter,
/// );
/// final rows = await builder.get();
/// ```
final class WormQueryTranslator {
  /// Creates a translator resolving tables through [registry].
  const WormQueryTranslator(this.registry);

  /// The models the translator may be asked to query.
  final BeakModelRegistry registry;

  /// Builds the worm query for [spec] against [adapter], including filter,
  /// search, ordering, relation loads, soft-delete scoping, and the paging
  /// window.
  QueryBuilder<WormRecordModel> builderFor(
    BeakQuerySpec spec,
    DatabaseAdapter adapter,
  ) {
    final model = registry.byTableOrThrow(spec.table);
    var builder = QueryBuilder<WormRecordModel>.from(
      contextFor(model, adapter),
    );
    if (spec.withTrashed) {
      builder = builder.withTrashed();
    }
    final PredicateTree? filter = predicateFor(spec.filter, model);
    if (filter != null) {
      builder = builder.where(filter);
    }
    final PredicateTree? search = _searchPredicate(spec.search, model);
    if (search != null) {
      builder = builder.where(search);
    }
    for (final sort in spec.sorts) {
      builder = builder.orderBy(
        wormFieldForColumn(columnOrThrow(model, sort.columnKey)),
        descending: sort.descending,
      );
    }
    builder = _applyRelationLoads(builder, model, spec.relationLoads);
    builder = builder.limit(spec.pagination.perPage);
    final int offsetRows = (spec.pagination.page - 1) * spec.pagination.perPage;
    if (offsetRows > 0) {
      builder = builder.offset(offsetRows);
    }
    return builder;
  }

  /// Builds the scoped, filtered worm query behind [spec]; the data source
  /// picks the aggregate terminal (count/sum/avg).
  QueryBuilder<WormRecordModel> aggregateBuilderFor(
    BeakAggregateSpec spec,
    DatabaseAdapter adapter,
  ) {
    final model = registry.byTableOrThrow(spec.table);
    var builder = QueryBuilder<WormRecordModel>.from(
      contextFor(model, adapter),
    );
    if (spec.withTrashed) {
      builder = builder.withTrashed();
    }
    final PredicateTree? filter = predicateFor(spec.filter, model);
    if (filter != null) {
      builder = builder.where(filter);
    }
    return builder;
  }

  /// The worm query context for [model]: generic hydration into
  /// [WormRecordModel], the model's primary key, its soft-delete scope, and
  /// every relation reachable from it (so nested dot-paths resolve).
  QueryContext<WormRecordModel> contextFor(
    BeakModel model,
    DatabaseAdapter adapter,
  ) => QueryContext<WormRecordModel>(
    adapter: adapter,
    table: model.table,
    primaryKey: model.primaryKey.key,
    hydrate: _hydratorForTable(model.table),
    globalScopes: model.softDeletes
        ? const [SoftDeleteScope<Model>()]
        : const [],
    relations: _relationsFor(model),
  );

  /// Translates [filter] into a worm predicate tree for [model], or `null`
  /// for an absent/empty filter.
  ///
  /// Throws a [BeakConfigurationException] when the filter references an
  /// unknown column or carries an operand its operator cannot use.
  PredicateTree? predicateFor(BeakFilter? filter, BeakModel model) =>
      switch (filter) {
        null => null,
        final BeakFieldFilter field => _leafFor(field, model),
        final BeakAndFilter and => _composite(and.filters, model, isAnd: true),
        final BeakOrFilter or => _composite(or.filters, model, isAnd: false),
      };

  /// The column of [model] under [columnKey].
  ///
  /// Throws a [BeakConfigurationException] for unknown keys, naming both
  /// sides.
  BeakColumn columnOrThrow(BeakModel model, String columnKey) =>
      model.columnByKey(columnKey) ??
      (throw BeakConfigurationException(
        'Model "${model.table}" has no column "$columnKey".',
      ));

  PredicateTree? _composite(
    List<BeakFilter> children,
    BeakModel model, {
    required bool isAnd,
  }) {
    final trees = <PredicateTree>[
      for (final child in children)
        if (predicateFor(child, model) case final PredicateTree tree) tree,
    ];
    if (trees.isEmpty) {
      return null;
    }
    if (trees.length == 1) {
      return trees.single;
    }
    var combined = trees.first;
    for (final tree in trees.skip(1)) {
      combined = isAnd ? combined.and(tree) : combined.or(tree);
    }
    return combined.group();
  }

  PredicateTree _leafFor(BeakFieldFilter filter, BeakModel model) {
    final String columnKey = columnOrThrow(model, filter.columnKey).key;
    Predicate predicate(Operator operator, Object? value) =>
        Predicate(fieldName: columnKey, operator: operator, value: value);
    return LeafNode(switch (filter.operator) {
      BeakOperator.eq => predicate(Operator.eq, filter.value.raw),
      BeakOperator.neq => predicate(Operator.neq, filter.value.raw),
      BeakOperator.gt => predicate(Operator.gt, filter.value.raw),
      BeakOperator.gte => predicate(Operator.gte, filter.value.raw),
      BeakOperator.lt => predicate(Operator.lt, filter.value.raw),
      BeakOperator.lte => predicate(Operator.lte, filter.value.raw),
      BeakOperator.like => predicate(Operator.like, _stringOperand(filter)),
      BeakOperator.ilike => predicate(Operator.ilike, _stringOperand(filter)),
      BeakOperator.contains => predicate(
        Operator.ilike,
        '%${_stringOperand(filter)}%',
      ),
      BeakOperator.startsWith => predicate(
        Operator.ilike,
        '${_stringOperand(filter)}%',
      ),
      BeakOperator.endsWith => predicate(
        Operator.ilike,
        '%${_stringOperand(filter)}',
      ),
      BeakOperator.isNull => predicate(Operator.isNull, null),
      BeakOperator.isNotNull => predicate(Operator.isNotNull, null),
      BeakOperator.inList => predicate(Operator.inList, _listOperand(filter)),
      BeakOperator.notInList => predicate(
        Operator.notInList,
        _listOperand(filter),
      ),
      BeakOperator.between => predicate(
        Operator.between,
        _boundsOperand(filter),
      ),
      BeakOperator.notBetween => predicate(
        Operator.notBetween,
        _boundsOperand(filter),
      ),
    });
  }

  String _stringOperand(BeakFieldFilter filter) => switch (filter.value.raw) {
    final String value => value,
    final Object? other => throw BeakConfigurationException(
      'Operator "${filter.operator.name}" on "${filter.columnKey}" needs a '
      'string operand, got $other.',
    ),
  };

  List<Object?> _listOperand(BeakFieldFilter filter) => switch (filter.value) {
    final BeakListValue list => list.raw,
    final BeakValue other => throw BeakConfigurationException(
      'Operator "${filter.operator.name}" on "${filter.columnKey}" needs a '
      'list operand, got $other.',
    ),
  };

  (Object?, Object?) _boundsOperand(BeakFieldFilter filter) =>
      switch (filter.value) {
        BeakListValue(:final values) when values.length == 2 => (
          values.first.raw,
          values.last.raw,
        ),
        final BeakValue other => throw BeakConfigurationException(
          'Operator "${filter.operator.name}" on "${filter.columnKey}" needs '
          'exactly two bounds, got $other.',
        ),
      };

  PredicateTree? _searchPredicate(BeakSearch? search, BeakModel model) {
    if (search == null) {
      return null;
    }
    final String term = search.term.trim();
    if (term.isEmpty || search.columnKeys.isEmpty) {
      return null;
    }
    final String pattern = '%$term%';
    final leaves = <PredicateTree>[
      for (final columnKey in search.columnKeys)
        LeafNode(
          Predicate(
            fieldName: columnOrThrow(model, columnKey).key,
            operator: Operator.ilike,
            value: pattern,
          ),
        ),
    ];
    var combined = leaves.first;
    for (final leaf in leaves.skip(1)) {
      combined = combined.or(leaf);
    }
    return combined.group();
  }

  QueryBuilder<WormRecordModel> _applyRelationLoads(
    QueryBuilder<WormRecordModel> builder,
    BeakModel model,
    List<BeakRelationLoad> loads,
  ) {
    var result = builder;
    for (final load in loads) {
      final relationship = relationshipOrThrow(model, load.relationKey);
      if (load.filter != null) {
        if (load.nested.isNotEmpty) {
          throw BeakConfigurationException(
            'Relation load "${load.relationKey}" cannot combine a '
            'constraint with nested loads.',
          );
        }
        final related = registry.byTableOrThrow(relationship.relatedTable);
        result = result.withRelation(
          RelationField<Model, Model>(
            relationship.key,
            foreignKey: _relationForeignKey(relationship),
          ),
          predicateFor(load.filter, related),
        );
        continue;
      }
      result = result.withRelationPaths(_pathsFor(model, load));
    }
    return result;
  }

  List<String> _pathsFor(BeakModel owner, BeakRelationLoad load) {
    final relationship = relationshipOrThrow(owner, load.relationKey);
    if (load.filter != null) {
      throw BeakConfigurationException(
        'Nested relation load "${load.relationKey}" cannot carry a '
        'constraint.',
      );
    }
    if (load.nested.isEmpty) {
      return [relationship.key];
    }
    final related = registry.byTableOrThrow(relationship.relatedTable);
    return [
      for (final child in load.nested)
        for (final tail in _pathsFor(related, child))
          '${relationship.key}.$tail',
    ];
  }

  /// The relationship named [relationKey] on [model].
  ///
  /// Throws a [BeakConfigurationException] when the model declares none —
  /// the single relation-or-throw lookup both the translator and the data
  /// source use.
  BeakRelationship relationshipOrThrow(BeakModel model, String relationKey) =>
      model.relationshipByKey(relationKey) ??
      (throw BeakConfigurationException(
        'Model "${model.table}" has no relation "$relationKey".',
      ));

  String _relationForeignKey(BeakRelationship relationship) =>
      switch (relationship) {
        BeakBelongsTo(:final foreignKey) => foreignKey,
        BeakHasOne(:final foreignKey) => foreignKey,
        BeakHasMany(:final foreignKey) => foreignKey,
        BeakBelongsToMany(:final foreignPivotKey) => foreignPivotKey,
      };

  Map<String, Relation<Model, Model>> _relationsFor(BeakModel root) {
    final relations = <String, Relation<Model, Model>>{};
    final visitedTables = <String>{};
    void collect(BeakModel model) {
      if (!visitedTables.add(model.table)) {
        return;
      }
      for (final relationship in model.relationships) {
        relations.putIfAbsent(
          relationship.key,
          () => _wormRelationFor(model, relationship),
        );
        final related = registry.byTable(relationship.relatedTable);
        if (related != null) {
          collect(related);
        }
      }
    }

    collect(root);
    return relations;
  }

  Relation<Model, Model> _wormRelationFor(
    BeakModel owner,
    BeakRelationship relationship,
  ) => switch (relationship) {
    BeakBelongsTo(:final key, :final relatedTable, :final foreignKey) =>
      BelongsToRelation<Model, Model>(
        name: key,
        parentTable: relatedTable,
        foreignKey: foreignKey,
        hydrateParent: _hydratorForTable(relatedTable),
        ownerKey: primaryKeyKeyOf(relatedTable),
      ),
    BeakHasOne(:final key, :final relatedTable, :final foreignKey) =>
      HasOneRelation<Model, Model>(
        name: key,
        childTable: relatedTable,
        foreignKey: foreignKey,
        hydrateChild: _hydratorForTable(relatedTable),
        localKey: owner.primaryKey.key,
      ),
    BeakHasMany(:final key, :final relatedTable, :final foreignKey) =>
      HasManyRelation<Model, Model>(
        name: key,
        childTable: relatedTable,
        foreignKey: foreignKey,
        hydrateChild: _hydratorForTable(relatedTable),
        localKey: owner.primaryKey.key,
      ),
    BeakBelongsToMany(
      :final key,
      :final relatedTable,
      :final pivotTable,
      :final foreignPivotKey,
      :final relatedPivotKey,
    ) =>
      BelongsToManyRelation<Model, Model>(
        name: key,
        relatedTable: relatedTable,
        pivotTable: pivotTable,
        parentPivotKey: foreignPivotKey,
        relatedPivotKey: relatedPivotKey,
        hydrateRelated: _hydratorForTable(relatedTable),
        parentKey: owner.primaryKey.key,
        relatedKey: primaryKeyKeyOf(relatedTable),
      ),
  };

  WormRecordModel Function(Map<String, Object?> row) _hydratorForTable(
    String table,
  ) {
    final String primaryKeyColumn = primaryKeyKeyOf(table);
    return (row) => WormRecordModel.fromRow(table, primaryKeyColumn, row);
  }

  /// The primary-key column of [table], `'id'` for unregistered tables —
  /// the single pk-name lookup both the translator and the data source use.
  String primaryKeyKeyOf(String table) =>
      registry.byTable(table)?.primaryKey.key ?? 'id';
}
