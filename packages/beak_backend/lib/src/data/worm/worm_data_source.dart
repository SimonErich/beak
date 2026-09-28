import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import 'column_type_mapper.dart';
import 'query_translator.dart';
import 'worm_record_model.dart';

/// The default [BeakDataSource]: translates every operation to worm against
/// an injected adapter, honoring model metadata (primary keys, soft
/// deletes, relationships) without any per-model code.
///
/// This is the implementation the generated host serves through; any other
/// source satisfies the same [BeakDataSource] interface without touching
/// `beak_core` or `beak_backend`. Wire one over any worm [DatabaseAdapter] —
/// an [InMemoryAdapter] in tests, the adapter `adapterFromUrl` opens in
/// production — and hand it to a `BeakServer` or to `beakApiRouter`.
///
/// ```dart
/// final registry = buildBeakRegistry();
/// final dataSource = WormDataSource(registry, adapter: InMemoryAdapter());
///
/// final page = await dataSource.query(const ProductModel().query());
/// ```
final class WormDataSource implements BeakDataSource, BeakSummaryDataSource {
  /// Creates a data source over [registry] executing on [adapter].
  ///
  /// [registry] resolves every table name to its [BeakModel] metadata, so one
  /// instance serves every registered model. [now] injects the clock stamped
  /// into soft-delete markers (defaults to [DateTime.now]) — override it for
  /// deterministic tests.
  WormDataSource(
    this.registry, {
    required DatabaseAdapter adapter,
    DateTime Function()? now,
  }) : _adapter = adapter,
       _now = now ?? DateTime.now,
       _translator = WormQueryTranslator(registry);

  /// The models this data source serves.
  final BeakModelRegistry registry;

  final DatabaseAdapter _adapter;

  /// Adapter used by graph transactions and their durable receipt store.
  DatabaseAdapter get adapter => _adapter;
  final DateTime Function() _now;
  final WormQueryTranslator _translator;

  /// The column worm's soft-delete scope filters on.
  static const String softDeleteColumnKey = 'deleted_at';

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    final BeakModel beakModel = registry.byTableOrThrow(spec.table);
    final builder = _translator.builderFor(spec, _adapter);
    final int total = await builder.count();
    final rows = await builder.get();
    return BeakPage(
      items: [
        for (final row in rows)
          row.toBeakRecord(
            loads: spec.relationLoads,
            model: beakModel,
            registry: registry,
          ),
      ],
      total: total,
      page: spec.pagination.page,
      perPage: spec.pagination.perPage,
    );
  }

  @override
  Future<BeakRecord?> getOne(String table, Object id) async {
    final model = registry.byTableOrThrow(table);
    final found = await _scopedBuilder(
      model,
    ).where(_primaryKeyPredicate(model, id)).first();
    return found?.toBeakRecord(model: model, registry: registry);
  }

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    registry.byTableOrThrow(table);
    try {
      final row = await _adapter.insert(
        InsertDescriptor(table: table, values: data.toRow()),
      );
      return BeakRecord.fromRow(row);
    } on UniqueConstraintException {
      throw const BeakConflictException(
        'A value that must be unique is already in use.',
      );
    }
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    final model = registry.byTableOrThrow(table);
    final values = {...data.toRow()}..remove(model.primaryKey.key);
    final int affected;
    try {
      affected = await _adapter.update(
        UpdateDescriptor(
          table: table,
          values: values,
          where: _visibleRowPredicate(model, id),
        ),
      );
    } on UniqueConstraintException {
      throw const BeakConflictException(
        'A value that must be unique is already in use.',
      );
    }
    if (affected == 0) {
      throw BeakNotFoundException(_missingRecord(model, id));
    }
    final updated = await getOne(table, id);
    return updated ?? (throw BeakNotFoundException(_missingRecord(model, id)));
  }

  @override
  Future<BeakRecord> restore(String table, Object id) async {
    final model = registry.byTableOrThrow(table);
    if (!model.softDeletes) {
      throw BeakValidationException(
        'Model "$table" does not soft-delete, so there is nothing to restore.',
      );
    }
    final int affected = await _adapter.update(
      UpdateDescriptor(
        table: table,
        values: const {softDeleteColumnKey: null},
        // Deliberately the trashed rows only: restoring a live record would
        // report success for something that never happened.
        where: _primaryKeyPredicate(model, id).and(
          const LeafNode(
            Predicate(
              fieldName: softDeleteColumnKey,
              operator: Operator.isNotNull,
            ),
          ),
        ),
      ),
    );
    if (affected == 0) {
      throw BeakNotFoundException(
        'No soft-deleted record of "$table" with id "$id".',
      );
    }
    return await getOne(table, id) ??
        (throw BeakNotFoundException(_missingRecord(model, id)));
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {
    final model = registry.byTableOrThrow(table);
    final int affected;
    if (model.softDeletes && !force) {
      affected = await _adapter.update(
        UpdateDescriptor(
          table: table,
          values: {softDeleteColumnKey: _now()},
          where: _visibleRowPredicate(model, id),
        ),
      );
    } else {
      affected = await _adapter.delete(
        DeleteDescriptor(table: table, where: _primaryKeyPredicate(model, id)),
      );
    }
    if (affected == 0) {
      throw BeakNotFoundException(_missingRecord(model, id));
    }
  }

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    if (ids.isEmpty) {
      return const [];
    }
    final model = registry.byTableOrThrow(table);
    final models = await _scopedBuilder(model)
        .where(
          LeafNode(
            Predicate(
              fieldName: model.primaryKey.key,
              operator: Operator.inList,
              value: [...ids],
            ),
          ),
        )
        .get();
    return [
      for (final found in models)
        found.toBeakRecord(model: model, registry: registry),
    ];
  }

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    switch (_relationshipOf(table, relationKey)) {
      case final BeakBelongsToMany pivot:
        if (relatedIds.isEmpty) {
          return;
        }
        await _attachThroughPivot(pivot, id, relatedIds);
      case final BeakHasMany children:
        if (relatedIds.isEmpty) {
          return;
        }
        await _adapter.update(
          UpdateDescriptor(
            table: children.relatedTable,
            values: {children.foreignKey: id},
            where: _relatedIdsPredicate(children.relatedTable, relatedIds),
          ),
        );
      case final BeakRelationship other:
        _throwNotToMany(table, relationKey, other);
    }
  }

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    switch (_relationshipOf(table, relationKey)) {
      case final BeakBelongsToMany pivot:
        if (relatedIds.isEmpty) {
          return;
        }
        await _adapter.delete(
          DeleteDescriptor(
            table: pivot.pivotTable,
            where: _pivotPredicate(pivot, id, relatedIds),
          ),
        );
      case final BeakHasMany children:
        if (relatedIds.isEmpty) {
          return;
        }
        await _adapter.update(
          UpdateDescriptor(
            table: children.relatedTable,
            values: {children.foreignKey: null},
            where: _relatedIdsPredicate(children.relatedTable, relatedIds).and(
              LeafNode(
                Predicate(
                  fieldName: children.foreignKey,
                  operator: Operator.eq,
                  value: id,
                ),
              ),
            ),
          ),
        );
      case final BeakRelationship other:
        _throwNotToMany(table, relationKey, other);
    }
  }

  Future<void> _attachThroughPivot(
    BeakBelongsToMany relation,
    Object id,
    List<Object> relatedIds,
  ) async {
    final existingRows = await _adapter.select(
      QueryDescriptor(
        table: relation.pivotTable,
        where: _pivotPredicate(relation, id, relatedIds),
      ),
    );
    final existing = {
      for (final row in existingRows) row[relation.relatedPivotKey],
    };
    final missing = [
      for (final relatedId in relatedIds)
        if (!existing.contains(relatedId)) relatedId,
    ];
    if (missing.isEmpty) {
      return;
    }
    await _adapter.insertMany(
      InsertManyDescriptor(
        table: relation.pivotTable,
        rows: [
          for (final relatedId in missing)
            {relation.foreignPivotKey: id, relation.relatedPivotKey: relatedId},
        ],
      ),
    );
  }

  PredicateTree _relatedIdsPredicate(
    String relatedTable,
    List<Object> relatedIds,
  ) => LeafNode(
    Predicate(
      fieldName: _translator.primaryKeyKeyOf(relatedTable),
      operator: Operator.inList,
      value: [...relatedIds],
    ),
  );

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async {
    final model = registry.byTableOrThrow(spec.table);
    final builder = _translator.aggregateBuilderFor(spec, _adapter);
    return switch (spec.function) {
      BeakAggregateFunction.count => await builder.count(),
      BeakAggregateFunction.sum =>
        await builder.sum(_numericField(model, spec)) ?? 0,
      BeakAggregateFunction.avg =>
        await builder.avg(_numericField(model, spec)) ?? 0,
    };
  }

  @override
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) async {
    final model = registry.byTableOrThrow(spec.table);
    final group = spec.groupByKey == null
        ? null
        : model.columnByKey(spec.groupByKey!);
    if (spec.groupByKey != null && group == null) {
      throw BeakValidationException(
        'Unknown summary group "${spec.groupByKey}".',
      );
    }
    if (group is BeakJsonColumn || group is BeakCustomColumn) {
      throw const BeakValidationException(
        'Summary groups must be scalar columns.',
      );
    }
    for (final measure in spec.measures) {
      if (measure.columnKey case final key?) {
        final column = model.columnByKey(key);
        if (column is! BeakIntColumn && column is! BeakDecimalColumn) {
          throw BeakValidationException(
            'Summary measure "$key" must be numeric.',
          );
        }
      }
    }
    final filter = BeakFilter.allOf([
      ?spec.filter,
      ?beakSearchFilter(spec.search, model, registry),
    ]);
    if (group == null) {
      return BeakSummaryResult(
        rows: [
          BeakSummaryRow(
            group: const BeakNullValue(),
            values: {
              for (final measure in spec.measures)
                measure.key: await aggregate(
                  BeakAggregateSpec.forKey(
                    table: spec.table,
                    function: measure.columnKey == null
                        ? BeakAggregateFunction.count
                        : BeakAggregateFunction.sum,
                    columnKey: measure.columnKey,
                    filter: BeakFilter.allOf([?filter, ?measure.filter]),
                    withTrashed: spec.withTrashed,
                  ),
                ),
            },
          ),
        ],
      );
    }
    final values = <Object?, Map<String, num>>{};
    for (final measure in spec.measures) {
      var predicate = _translator.predicateFor(
        BeakFilter.allOf([?filter, ?measure.filter]),
        model,
      );
      if (model.softDeletes && !spec.withTrashed) {
        const visible = LeafNode(
          Predicate(fieldName: softDeleteColumnKey, operator: Operator.isNull),
        );
        predicate = predicate == null ? visible : predicate.and(visible);
      }
      final groups = await _adapter.aggregateGrouped(
        AggregateDescriptor(
          table: spec.table,
          function: measure.columnKey == null
              ? AggregateFunction.count
              : AggregateFunction.sum,
          column: measure.columnKey,
          groupBy: group.key,
          where: predicate,
        ),
      );
      for (final entry in groups.entries) {
        (values[entry.key] ??= {})[measure.key] = entry.value;
      }
    }
    final keys = values.keys.toList()
      ..sort((a, b) {
        if (a == null) return b == null ? 0 : -1;
        if (b == null) return 1;
        if (a is num && b is num) return a.compareTo(b);
        return a.toString().compareTo(b.toString());
      });
    return BeakSummaryResult(
      truncated: keys.length > spec.limit,
      rows: [
        for (final key in keys.take(spec.limit))
          BeakSummaryRow(
            group: beakValueForColumn(group, key),
            values: {
              for (final measure in spec.measures)
                measure.key: values[key]?[measure.key] ?? 0,
            },
          ),
      ],
    );
  }

  QueryBuilder<WormRecordModel> _scopedBuilder(BeakModel model) =>
      QueryBuilder<WormRecordModel>.from(
        _translator.contextFor(model, _adapter),
      );

  PredicateTree _primaryKeyPredicate(BeakModel model, Object id) => LeafNode(
    Predicate(
      fieldName: model.primaryKey.key,
      operator: Operator.eq,
      value: id,
    ),
  );

  PredicateTree _visibleRowPredicate(BeakModel model, Object id) {
    final byId = _primaryKeyPredicate(model, id);
    if (!model.softDeletes) {
      return byId;
    }
    return byId.and(
      const LeafNode(
        Predicate(fieldName: softDeleteColumnKey, operator: Operator.isNull),
      ),
    );
  }

  PredicateTree _pivotPredicate(
    BeakBelongsToMany relation,
    Object id,
    List<Object> relatedIds,
  ) =>
      LeafNode(
        Predicate(
          fieldName: relation.foreignPivotKey,
          operator: Operator.eq,
          value: id,
        ),
      ).and(
        LeafNode(
          Predicate(
            fieldName: relation.relatedPivotKey,
            operator: Operator.inList,
            value: [...relatedIds],
          ),
        ),
      );

  BeakRelationship _relationshipOf(String table, String relationKey) =>
      _translator.relationshipOrThrow(
        registry.byTableOrThrow(table),
        relationKey,
      );

  Never _throwNotToMany(
    String table,
    String relationKey,
    BeakRelationship found,
  ) => throw BeakConfigurationException(
    'Relation "$relationKey" of "$table" is a ${found.runtimeType}; '
    'attach/detach need a to-many relation.',
  );

  Field<num> _numericField(BeakModel model, BeakAggregateSpec spec) {
    final String columnKey =
        spec.columnKey ??
        (throw const BeakConfigurationException(
          'Aggregate spec is missing its column key.',
        ));
    return wormNumericFieldForColumn(
      _translator.columnOrThrow(model, columnKey),
    );
  }

  String _missingRecord(BeakModel model, Object id) =>
      'No record of "${model.table}" with ${model.primaryKey.key} "$id".';
}
