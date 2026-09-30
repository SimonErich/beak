import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import 'beak_record_keys.dart';
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
  ///
  /// [authorizeRead] is set on the transaction-bound source a graph commit
  /// hands to `preparePlan` and `finalizePlan`; see [authorizeRead].
  WormDataSource(
    this.registry, {
    required DatabaseAdapter adapter,
    DateTime Function()? now,
    this.authorizeRead,
  }) : _adapter = adapter,
       _now = now ?? DateTime.now,
       _translator = WormQueryTranslator(registry);

  /// The models this data source serves.
  final BeakModelRegistry registry;

  /// Checks that the principal a graph commit runs for may read the record
  /// [BeakRecordRef], or throws a `BeakException` if not.
  ///
  /// `null` on an ordinary source. On the transaction-bound source a graph
  /// commit passes to `preparePlan` and `finalizePlan` it applies the policy's
  /// `canView` and the principal's row scope. Reads on this source are not
  /// scoped (a preparer may count rows the caller cannot see), so pass it to
  /// the one place that loads records the *plan* names:
  ///
  /// ```dart
  /// final graph = await BeakCandidateGraph.open(
  ///   plan: plan,
  ///   source: transaction,
  ///   registry: registry,
  ///   authorizeRead: transaction.authorizeRead,
  /// );
  /// ```
  final Future<void> Function(BeakRecordRef ref)? authorizeRead;

  final DatabaseAdapter _adapter;

  /// Adapter used by graph transactions and their durable receipt store.
  DatabaseAdapter get adapter => _adapter;
  final DateTime Function() _now;
  final WormQueryTranslator _translator;

  /// The column worm's soft-delete scope filters on.
  static const String softDeleteColumnKey = 'deleted_at';

  @override
  // --8<-- [start:query]
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) => _read(() async {
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
  });
  // --8<-- [end:query]

  @override
  Future<BeakRecord?> getOne(String table, Object id) => _read(() async {
    final model = registry.byTableOrThrow(table);
    if (_keyValue(model, id) == null) {
      return null;
    }
    final found = await _scopedBuilder(
      model,
    ).where(_primaryKeyPredicate(model, id)).first();
    return found?.toBeakRecord(model: model, registry: registry);
  });

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    final model = registry.byTableOrThrow(table);
    final keys = beakRecordKeys(model);
    // A primary key the caller left empty is the database's to assign (a
    // serial integer): sending `id = NULL` instead makes some drivers read
    // the new row back by that NULL and answer without its generated key.
    final values = data.toRow();
    if (values[model.primaryKey.key] == null) {
      values.remove(model.primaryKey.key);
    }
    final row = await _write(
      model,
      () => _adapter.insert(
        InsertDescriptor(
          table: table,
          values: values,
          // Never `RETURNING *`: an undeclared column stays in the database.
          returning: keys.toList(growable: false),
        ),
      ),
    );
    return BeakRecord.fromRow({
      for (final MapEntry(:key, :value) in row.entries)
        if (keys.contains(key)) key: value,
    });
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    final model = registry.byTableOrThrow(table);
    final values = {...data.toRow()}..remove(model.primaryKey.key);
    if (values.isEmpty) {
      // Nothing to change (an empty body, or one that only repeats the key):
      // an UPDATE with no columns is not SQL, and the record is what the
      // caller gets back either way.
      return await getOne(table, id) ??
          (throw BeakNotFoundException(_missingRecord(model, id)));
    }
    final int affected = await _write(
      model,
      () => _adapter.update(
        UpdateDescriptor(
          table: table,
          values: values,
          where: _visibleRowPredicate(model, id),
        ),
      ),
    );
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
    final int affected = await _write(
      model,
      () => _adapter.update(
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
      affected = await _write(
        model,
        () => _adapter.update(
          UpdateDescriptor(
            table: table,
            values: {softDeleteColumnKey: _now().toUtc()},
            where: _visibleRowPredicate(model, id),
          ),
        ),
      );
    } else {
      affected = await _write(
        model,
        () => _adapter.delete(
          DeleteDescriptor(
            table: table,
            where: _primaryKeyPredicate(model, id),
          ),
        ),
        removing: true,
      );
    }
    if (affected == 0) {
      throw BeakNotFoundException(_missingRecord(model, id));
    }
  }

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) =>
      _read(() async {
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
      });

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    final model = registry.byTableOrThrow(table);
    switch (_relationshipOf(table, relationKey)) {
      case final BeakBelongsToMany pivot:
        if (relatedIds.isEmpty) {
          return;
        }
        await _requireOwner(model, id);
        await _write(model, () => _attachThroughPivot(pivot, id, relatedIds));
      case final BeakHasMany children:
        if (relatedIds.isEmpty) {
          return;
        }
        await _requireOwner(model, id);
        await _write(
          model,
          () => _adapter.update(
            UpdateDescriptor(
              table: children.relatedTable,
              values: {children.foreignKey: id},
              where: _relatedIdsPredicate(children.relatedTable, relatedIds),
            ),
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
        await _write(
          registry.byTableOrThrow(table),
          () => _adapter.delete(
            DeleteDescriptor(
              table: pivot.pivotTable,
              where: _pivotPredicate(pivot, id, relatedIds),
            ),
          ),
        );
      case final BeakHasMany children:
        if (relatedIds.isEmpty) {
          return;
        }
        await _write(
          registry.byTableOrThrow(table),
          () => _adapter.update(
            UpdateDescriptor(
              table: children.relatedTable,
              values: {children.foreignKey: null},
              where: _relatedIdsPredicate(children.relatedTable, relatedIds)
                  .and(
                    LeafNode(
                      Predicate(
                        fieldName: children.foreignKey,
                        operator: Operator.eq,
                        value: id,
                      ),
                    ),
                  ),
            ),
          ),
        );
      case final BeakRelationship other:
        _throwNotToMany(table, relationKey, other);
    }
  }

  /// Runs one read and answers a value the database cannot compare (an
  /// integer outside the column's range, text that is not a valid value of its
  /// type) as the mistake in the request it is, a [BeakValidationException],
  /// instead of an opaque failure.
  Future<T> _read<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on DataException {
      throw const BeakValidationException(
        'A value in the request does not fit the field it is compared with.',
      );
    }
  }

  /// Throws a [BeakNotFoundException] unless the record [id] of [model] exists
  /// (a trashed one does: it can be restored): linking records to an owner
  /// that is not there would leave links nothing points at, on a database that
  /// declares no foreign key to refuse them.
  Future<void> _requireOwner(BeakModel model, Object id) async {
    if (_keyValue(model, id) == null) {
      throw BeakNotFoundException(_missingRecord(model, id));
    }
    final found = await _scopedBuilder(
      model,
    ).withTrashed().where(_primaryKeyPredicate(model, id)).first();
    if (found == null) {
      throw BeakNotFoundException(_missingRecord(model, id));
    }
  }

  /// Runs one write and answers a refusal by the database with what the
  /// caller should hear, instead of the opaque failure an unexpected error
  /// becomes:
  ///
  /// - a value that must be unique is taken: a [BeakConflictException];
  /// - a foreign key: when [removing] a row, the row is still referenced (a
  ///   [BeakConflictException]); otherwise the record written points at one
  ///   that does not exist (a [BeakValidationException]);
  /// - a NOT NULL or CHECK rule, a value too long or out of range for its
  ///   column: a [BeakValidationException], naming the column when the driver
  ///   names one that belongs to [model].
  ///
  /// The database's own message is never passed on: it quotes table and
  /// constraint names the client has no use for.
  Future<T> _write<T>(
    BeakModel model,
    Future<T> Function() write, {
    bool removing = false,
  }) async {
    try {
      return await write();
    } on UniqueConstraintException {
      throw const BeakConflictException(
        'A value that must be unique is already in use.',
      );
    } on ForeignKeyException catch (error) {
      throw removing
          ? BeakConflictException(
              'This "${model.table}" record is still referenced by other '
              'records.',
            )
          : _refusal(
              model,
              error.column,
              'A record this one refers to does not exist.',
              'This record does not exist.',
            );
    } on CheckConstraintException catch (error) {
      throw _refusal(
        model,
        error.column,
        'A value is missing or not allowed.',
        'This value is missing or not allowed.',
      );
    } on DataException catch (error) {
      throw _refusal(
        model,
        error.column,
        'A value is too long or out of range for its column.',
        'This value is too long or out of range.',
      );
    }
  }

  BeakValidationException _refusal(
    BeakModel model,
    String? column,
    String message,
    String fieldMessage,
  ) => BeakValidationException(
    message,
    fieldErrors: {
      if (column != null && beakRecordKeys(model).contains(column))
        column: [fieldMessage],
    },
  );

  Future<void> _attachThroughPivot(
    BeakBelongsToMany relation,
    Object id,
    List<Object> relatedIds,
  ) async {
    final existingRows = await _adapter.select(
      QueryDescriptor(
        table: relation.pivotTable,
        columns: [relation.relatedPivotKey],
        where: _pivotPredicate(relation, id, relatedIds),
      ),
    );
    final existing = {
      for (final row in existingRows) row[relation.relatedPivotKey],
    };
    // `add` is false for an id already linked or already named in this call,
    // so each related record gets one pivot row however often it is listed.
    final missing = [
      for (final relatedId in relatedIds)
        if (existing.add(relatedId)) relatedId,
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
  Future<num> aggregate(BeakAggregateSpec spec) => _read(() async {
    final model = registry.byTableOrThrow(spec.table);
    final builder = _translator.aggregateBuilderFor(spec, _adapter);
    return switch (spec.function) {
      BeakAggregateFunction.count => await builder.count(),
      BeakAggregateFunction.sum =>
        await builder.sum(_numericField(model, spec)) ?? 0,
      BeakAggregateFunction.avg =>
        await builder.avg(_numericField(model, spec)) ?? 0,
    };
  });

  @override
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) =>
      _read(() => _summarize(spec));

  Future<BeakSummaryResult> _summarize(BeakSummarySpec spec) async {
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
      _translator.projectedBuilder(model, _adapter);

  /// [id] in the primary key's own type, or `null` when no record can have
  /// it. A route delivers ids as text, so an integer key parses here rather
  /// than reaching the adapter as a string it would compare, or cast,
  /// differently.
  Object? _keyValue(BeakModel model, Object id) => switch (id) {
    final String text when model.primaryKey is BeakIntColumn => int.tryParse(
      text,
    ),
    _ => id,
  };

  PredicateTree _primaryKeyPredicate(BeakModel model, Object id) => LeafNode(
    Predicate(
      fieldName: model.primaryKey.key,
      operator: Operator.eq,
      value:
          _keyValue(model, id) ??
          (throw BeakNotFoundException(_missingRecord(model, id))),
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
