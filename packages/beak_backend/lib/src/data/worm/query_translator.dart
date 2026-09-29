import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import 'beak_record_keys.dart';
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
  // --8<-- [start:builderFor]
  QueryBuilder<WormRecordModel> builderFor(
    BeakQuerySpec spec,
    DatabaseAdapter adapter,
  ) {
    final model = registry.byTableOrThrow(spec.table);
    var builder = projectedBuilder(model, adapter);
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
  // --8<-- [end:builderFor]

  /// A scoped query over [model] that reads only [beakRecordKeys]: the
  /// declared columns and belongs-to foreign keys, never `SELECT *`.
  QueryBuilder<WormRecordModel> projectedBuilder(
    BeakModel model,
    DatabaseAdapter adapter,
  ) => QueryBuilder<WormRecordModel>.from(
    contextFor(model, adapter),
  ).select([for (final key in beakRecordKeys(model)) Field<Object?>(key)]);

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
  ///
  /// Relations are handed over twice: once flat (compatibility fallback)
  /// and once scoped by owning table, so the eager loader resolves each
  /// nested path segment against the table it actually belongs to — two
  /// models sharing a relation key (e.g. two self-referential `parent`
  /// relations) can never cross-wire.
  QueryContext<WormRecordModel> contextFor(
    BeakModel model,
    DatabaseAdapter adapter,
  ) {
    final relations = _relationsFor(model);
    return QueryContext<WormRecordModel>(
      adapter: adapter,
      table: model.table,
      primaryKey: model.primaryKey.key,
      hydrate: _hydratorForTable(model.table),
      globalScopes: model.softDeletes
          ? const [SoftDeleteScope<Model>()]
          : const [],
      relations: relations.flat,
      relationsByTable: relations.byTable,
    );
  }

  /// Translates [filter] into a worm predicate tree for [model], or `null`
  /// for an absent/empty filter.
  ///
  /// Throws a [BeakValidationException] when the filter references an
  /// unknown column or relation or carries an operand its operator cannot
  /// use: those are mistakes in the spec, which a server answers with a 422.
  // --8<-- [start:predicateFor]
  PredicateTree? predicateFor(
    BeakFilter? filter,
    BeakModel model, {
    String? qualifier,
    int depth = 0,
  }) => switch (filter) {
    null => null,
    final BeakFieldFilter field => _leafFor(field, model, qualifier, depth),
    final BeakAndFilter and => _composite(
      and.filters,
      model,
      isAnd: true,
      qualifier: qualifier,
      depth: depth,
    ),
    final BeakOrFilter or => _composite(
      or.filters,
      model,
      isAnd: false,
      qualifier: qualifier,
      depth: depth,
    ),
    BeakRelationFilter(:final relationKey, :final filter) => _relationPredicate(
      model,
      relationKey,
      filter,
      qualifier,
      depth,
    ),
  };
  // --8<-- [end:predicateFor]

  /// The column of [model] under [columnKey].
  ///
  /// Throws a [BeakValidationException] for unknown keys, naming both sides.
  BeakColumn columnOrThrow(BeakModel model, String columnKey) =>
      model.columnByKey(columnKey) ??
      (throw BeakValidationException(
        'Model "${model.table}" has no column "$columnKey".',
      ));

  PredicateTree? _composite(
    List<BeakFilter> children,
    BeakModel model, {
    required bool isAnd,
    String? qualifier,
    int depth = 0,
  }) {
    final trees = <PredicateTree>[
      for (final child in children)
        if (predicateFor(child, model, qualifier: qualifier, depth: depth)
            case final PredicateTree tree)
          tree,
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

  PredicateTree _leafFor(
    BeakFieldFilter filter,
    BeakModel model,
    String? qualifier,
    int depth,
  ) {
    final separator = filter.columnKey.indexOf('.');
    if (separator >= 0) {
      return _relationPredicate(
        model,
        filter.columnKey.substring(0, separator),
        BeakFieldFilter.forKey(
          filter.columnKey.substring(separator + 1),
          filter.operator,
          filter.value,
        ),
        qualifier,
        depth,
      );
    }
    final String columnKey = columnOrThrow(model, filter.columnKey).key;
    Predicate predicate(Operator operator, Object? value) => Predicate(
      fieldName: columnKey,
      tableName: qualifier,
      operator: operator,
      value: value,
    );
    // Every pattern states its escape character, so `\%` is a literal `%` on
    // every database (see [beakLikeEscape]).
    Predicate pattern(Operator operator, String value) => Predicate(
      fieldName: columnKey,
      tableName: qualifier,
      operator: operator,
      value: value,
      escape: beakLikeEscape,
    );
    return LeafNode(switch (filter.operator) {
      BeakOperator.eq => predicate(Operator.eq, filter.value.raw),
      BeakOperator.neq => predicate(Operator.neq, filter.value.raw),
      BeakOperator.gt => predicate(Operator.gt, filter.value.raw),
      BeakOperator.gte => predicate(Operator.gte, filter.value.raw),
      BeakOperator.lt => predicate(Operator.lt, filter.value.raw),
      BeakOperator.lte => predicate(Operator.lte, filter.value.raw),
      BeakOperator.like => pattern(Operator.like, _stringOperand(filter)),
      BeakOperator.ilike => pattern(Operator.ilike, _stringOperand(filter)),
      // --8<-- [start:substringOperators]
      BeakOperator.contains => pattern(
        Operator.ilike,
        '%${beakEscapeLike(_stringOperand(filter))}%',
      ),
      // --8<-- [end:substringOperators]
      BeakOperator.startsWith => pattern(
        Operator.ilike,
        '${beakEscapeLike(_stringOperand(filter))}%',
      ),
      BeakOperator.endsWith => pattern(
        Operator.ilike,
        '%${beakEscapeLike(_stringOperand(filter))}',
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

  PredicateTree _relationPredicate(
    BeakModel owner,
    String relationKey,
    BeakFilter filter,
    String? qualifier,
    int depth,
  ) {
    if (depth >= _maxRelationFilterDepth) {
      throw const BeakValidationException(
        'Relationship filter exceeds $_maxRelationFilterDepth levels.',
      );
    }
    final relation = _relationOrReject(owner, relationKey);
    final related = registry.byTableOrThrow(relation.relatedTable);
    final alias = 'beak_relation_$depth';
    final ownerAlias = qualifier ?? owner.table;
    PredicateTree? condition = predicateFor(
      filter,
      related,
      qualifier: alias,
      depth: depth + 1,
    );
    if (related.softDeletes) {
      final visible = LeafNode(
        Predicate(
          fieldName: 'deleted_at',
          tableName: alias,
          operator: Operator.isNull,
          value: null,
        ),
      );
      condition = condition == null ? visible : condition.and(visible).group();
    }
    PredicateTree correlate(
      String leftField,
      String leftTable,
      String rightField,
      String rightTable,
    ) => ColumnNode(
      leftField: leftField,
      leftTable: leftTable,
      rightField: rightField,
      rightTable: rightTable,
      operator: Operator.eq,
    );
    if (relation case BeakBelongsToMany(
      :final pivotTable,
      :final foreignPivotKey,
      :final relatedPivotKey,
    )) {
      final pivotAlias = 'beak_pivot_$depth';
      final targetLink = correlate(
        related.primaryKey.key,
        alias,
        relatedPivotKey,
        pivotAlias,
      );
      final target = ExistsNode(
        QueryDescriptor(
          table: related.table,
          tableAlias: alias,
          where: condition == null
              ? targetLink
              : targetLink.and(condition).group(),
        ),
      );
      return ExistsNode(
        QueryDescriptor(
          table: pivotTable,
          tableAlias: pivotAlias,
          where: correlate(
            foreignPivotKey,
            pivotAlias,
            owner.primaryKey.key,
            ownerAlias,
          ).and(target).group(),
        ),
      );
    }
    final link = switch (relation) {
      BeakBelongsTo(:final foreignKey) => correlate(
        related.primaryKey.key,
        alias,
        foreignKey,
        ownerAlias,
      ),
      BeakHasMany(:final foreignKey) || BeakHasOne(:final foreignKey) =>
        correlate(foreignKey, alias, owner.primaryKey.key, ownerAlias),
      BeakBelongsToMany() => throw StateError(
        'Pivot relation already handled.',
      ),
    };
    return ExistsNode(
      QueryDescriptor(
        table: related.table,
        tableAlias: alias,
        where: condition == null ? link : link.and(condition).group(),
      ),
    );
  }

  /// How many relationships deep a filter may reach.
  static const int _maxRelationFilterDepth = 16;

  String _stringOperand(BeakFieldFilter filter) => switch (filter.value.raw) {
    final String value => value,
    final Object? other => throw BeakValidationException(
      'Operator "${filter.operator.name}" on "${filter.columnKey}" needs a '
      'string operand, got $other.',
    ),
  };

  List<Object?> _listOperand(BeakFieldFilter filter) => switch (filter.value) {
    final BeakListValue list => list.raw,
    final BeakValue other => throw BeakValidationException(
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
        final BeakValue other => throw BeakValidationException(
          'Operator "${filter.operator.name}" on "${filter.columnKey}" needs '
          'exactly two bounds, got $other.',
        ),
      };

  PredicateTree? _searchPredicate(BeakSearch? search, BeakModel model) {
    final tree = predicateFor(beakSearchFilter(search, model, registry), model);
    return tree is GroupNode ? tree : tree?.group();
  }

  QueryBuilder<WormRecordModel> _applyRelationLoads(
    QueryBuilder<WormRecordModel> builder,
    BeakModel model,
    List<BeakRelationLoad> loads,
  ) {
    var result = builder;
    for (final load in loads) {
      result = result.withEagerLoad(_eagerLoad(model, load));
    }
    return result;
  }

  EagerLoad _eagerLoad(BeakModel owner, BeakRelationLoad load) {
    final relation = _relationOrReject(owner, load.relationKey);
    final related = registry.byTableOrThrow(relation.relatedTable);
    return EagerLoad(
      relation.key,
      constrain: predicateFor(load.filter, related),
      nested: [for (final child in load.nested) _eagerLoad(related, child)],
    );
  }

  /// The relationship a spec names by [relationKey] on [model].
  ///
  /// Throws a [BeakValidationException] when the model declares none: the
  /// spec is what is wrong.
  BeakRelationship _relationOrReject(BeakModel model, String relationKey) =>
      model.relationshipByKey(relationKey) ??
      (throw BeakValidationException(
        'Model "${model.table}" has no relation "$relationKey".',
      ));

  /// The relationship named [relationKey] on [model].
  ///
  /// Throws a [BeakConfigurationException] when the model declares none —
  /// the lookup the data source uses for attach and detach, where the caller
  /// is trusted code naming a relation it was wired with.
  BeakRelationship relationshipOrThrow(BeakModel model, String relationKey) =>
      model.relationshipByKey(relationKey) ??
      (throw BeakConfigurationException(
        'Model "${model.table}" has no relation "$relationKey".',
      ));

  ({
    Map<String, Relation<Model, Model>> flat,
    Map<String, Map<String, Relation<Model, Model>>> byTable,
  })
  _relationsFor(BeakModel root) {
    final flat = <String, Relation<Model, Model>>{};
    final byTable = <String, Map<String, Relation<Model, Model>>>{};
    final visitedTables = <String>{};
    void collect(BeakModel model) {
      if (!visitedTables.add(model.table)) {
        return;
      }
      final scoped = byTable.putIfAbsent(
        model.table,
        () => <String, Relation<Model, Model>>{},
      );
      for (final relationship in model.relationships) {
        final relation = _wormRelationFor(model, relationship);
        scoped[relationship.key] = relation;
        // First-wins fallback only: scoped resolution above takes
        // precedence whenever the owning table is known.
        flat.putIfAbsent(relationship.key, () => relation);
        final related = registry.byTable(relationship.relatedTable);
        if (related != null) {
          collect(related);
        }
      }
    }

    collect(root);
    return (flat: flat, byTable: byTable);
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
