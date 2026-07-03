import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import '../beak_data_source.dart';
import 'column_type_mapper.dart';
import 'query_translator.dart';
import 'worm_record_model.dart';

/// The default [BeakDataSource]: translates every operation to worm against
/// an injected adapter, honoring model metadata (primary keys, soft
/// deletes, relationships) without any per-model code.
final class WormDataSource implements BeakDataSource {
  /// Creates a data source over [registry] executing on [adapter].
  ///
  /// [now] injects the clock stamped into soft-delete markers (defaults to
  /// [DateTime.now]).
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
  final DateTime Function() _now;
  final WormQueryTranslator _translator;

  /// The column worm's soft-delete scope filters on.
  static const String softDeleteColumnKey = 'deleted_at';

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    final builder = _translator.builderFor(spec, _adapter);
    final int total = await builder.count();
    final models = await builder.get();
    return BeakPage(
      items: [
        for (final model in models)
          model.toBeakRecord(loads: spec.relationLoads),
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
    return found?.toBeakRecord();
  }

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    registry.byTableOrThrow(table);
    final row = await _adapter.insert(
      InsertDescriptor(table: table, values: data.toRow()),
    );
    return BeakRecord.fromRow(row);
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    final model = registry.byTableOrThrow(table);
    final values = {...data.toRow()}..remove(model.primaryKey.key);
    final int affected = await _adapter.update(
      UpdateDescriptor(
        table: table,
        values: values,
        where: _visibleRowPredicate(model, id),
      ),
    );
    if (affected == 0) {
      throw BeakNotFoundException(_missingRecord(model, id));
    }
    final updated = await getOne(table, id);
    return updated ?? (throw BeakNotFoundException(_missingRecord(model, id)));
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
    return [for (final found in models) found.toBeakRecord()];
  }

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    final relation = _pivotRelation(table, relationKey);
    if (relatedIds.isEmpty) {
      return;
    }
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

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    final relation = _pivotRelation(table, relationKey);
    if (relatedIds.isEmpty) {
      return;
    }
    await _adapter.delete(
      DeleteDescriptor(
        table: relation.pivotTable,
        where: _pivotPredicate(relation, id, relatedIds),
      ),
    );
  }

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

  BeakBelongsToMany _pivotRelation(String table, String relationKey) {
    final model = registry.byTableOrThrow(table);
    return switch (model.relationshipByKey(relationKey)) {
      final BeakBelongsToMany pivot => pivot,
      null => throw BeakConfigurationException(
        'Model "$table" has no relation "$relationKey".',
      ),
      final BeakRelationship other => throw BeakConfigurationException(
        'Relation "$relationKey" of "$table" is a ${other.runtimeType}; '
        'attach/detach need a belongs-to-many relation.',
      ),
    };
  }

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
