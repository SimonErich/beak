import 'package:beak_core/beak_core.dart';

/// A complete [BeakDataSource] backed by maps.
///
/// Complete is the operative word. Every hand-rolled fake in this repository
/// returned all rows regardless of the spec, which made a passing widget test
/// prove nothing about filtering, sorting, searching or paging. This one
/// honours the whole [BeakQuerySpec]: every [BeakOperator], nested and/or
/// filters, sorts, search, pagination, eager relation loads, soft deletes and
/// aggregates.
///
/// That completeness is not gold-plating — it is what lets the same object
/// serve unit tests, widget tests, a `BeakPanel` in a demo with no backend,
/// and the reference implementation the [runBeakDataSourceContract] suite
/// checks other sources against.
///
/// ```dart
/// final source = InMemoryBeakDataSource(registry: registry)
///   ..seed(const ProductModel(), [
///     BeakRecord.fromRow({'id': '1', 'name': 'Espresso', 'price': 12.5}),
///   ]);
///
/// await tester.pumpWidget(BeakPanel(config: config, dataSource: source));
/// ```
final class InMemoryBeakDataSource implements BeakDataSource {
  /// Creates an empty source over [registry].
  ///
  /// [registry] resolves relationships for eager loads and the soft-delete
  /// flag per model. [now] and [generateId] are seams so tests can pin
  /// timestamps and ids.
  InMemoryBeakDataSource({
    required this.registry,
    DateTime Function()? now,
    String Function()? generateId,
  }) : _now = now ?? DateTime.now,
       _generateId = generateId ?? _sequentialId;

  /// The models this source knows how to serve.
  final BeakModelRegistry registry;

  final DateTime Function() _now;
  final String Function() _generateId;

  /// Rows by table, then by stringified primary key. Insertion-ordered, so an
  /// unsorted query returns rows in the order they were seeded.
  final Map<String, Map<String, BeakRecord>> _rows = {};

  /// Pivot links by pivot table: each entry is an (owner id, related id) pair.
  final Map<String, Set<(String, String)>> _pivots = {};

  static int _idCounter = 0;

  static String _sequentialId() => 'id-${++_idCounter}';

  /// The column key holding the soft-delete marker.
  ///
  /// Matches `WormDataSource`, so a test against this source and a run
  /// against the real one agree about what "deleted" means.
  static const String softDeleteColumnKey = 'deleted_at';

  /// Replaces [model]'s rows with [records].
  ///
  /// Returns this source so seeding chains from the constructor.
  InMemoryBeakDataSource seed(BeakModel model, List<BeakRecord> records) {
    final table = _rows.putIfAbsent(model.table, () => {})..clear();
    for (final record in records) {
      final Object? id = model.primaryKeyOf(record);
      if (id == null) {
        throw BeakConfigurationException(
          'Seeded ${model.table} record has no "${model.primaryKey.key}" '
          'value; every seeded row needs its primary key.',
        );
      }
      table['$id'] = record;
    }
    return this;
  }

  /// Links [ownerId] to each of [relatedIds] across [relation].
  ///
  /// The seeding counterpart of [attach], for setting up many-to-many
  /// fixtures without going through the write path.
  InMemoryBeakDataSource seedPivot(
    BeakBelongsToMany relation,
    Object ownerId,
    List<Object> relatedIds,
  ) {
    final links = _pivots.putIfAbsent(relation.pivotTable, () => {});
    for (final relatedId in relatedIds) {
      links.add(('$ownerId', '$relatedId'));
    }
    return this;
  }

  /// Every row currently stored for [table], including soft-deleted ones.
  ///
  /// For assertions about what a write actually persisted.
  List<BeakRecord> rowsOf(String table) =>
      List.unmodifiable(_rows[table]?.values ?? const <BeakRecord>[]);

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    final BeakModel model = registry.byTableOrThrow(spec.table);
    final matched = _visibleRows(model, withTrashed: spec.withTrashed)
        .where((record) => _matchesFilter(model, record, spec.filter))
        .where((record) => _matchesSearch(model, record, spec.search))
        .toList();

    _sort(matched, spec.sorts);

    final int perPage = spec.pagination.perPage;
    final int page = spec.pagination.page;
    final int start = (page - 1) * perPage;
    final List<BeakRecord> window = start >= matched.length
        ? const []
        : matched.sublist(start, (start + perPage).clamp(0, matched.length));

    return BeakPage(
      items: [
        for (final record in window)
          await _withRelations(model, record, spec.relationLoads),
      ],
      total: matched.length,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<BeakRecord?> getOne(String table, Object id) async {
    final BeakModel model = registry.byTableOrThrow(table);
    final BeakRecord? record = _rows[table]?['$id'];
    if (record == null || _isTrashed(model, record)) {
      return null;
    }
    return record;
  }

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    final BeakModel model = registry.byTableOrThrow(table);
    final String key = model.primaryKey.key;
    final Object? supplied = data[key]?.raw;
    final String id = supplied == null || '$supplied'.isEmpty
        ? _generateId()
        : '$supplied';

    final rows = _rows.putIfAbsent(table, () => {});
    if (rows.containsKey(id)) {
      // A real source refuses a second row under the same key rather than
      // replacing the first.
      throw const BeakConflictException(
        'A value that must be unique is already in use.',
      );
    }
    final stored = BeakRecord(
      values: {
        ...data.values,
        key: BeakValue.of(id),
        ..._timestamps(model, isCreate: true),
      },
    );
    rows[id] = stored;
    return stored;
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    final BeakModel model = registry.byTableOrThrow(table);
    final BeakRecord? existing = _rows[table]?['$id'];
    if (existing == null || _isTrashed(model, existing)) {
      throw BeakNotFoundException('No $table record with id "$id".');
    }
    final updated = BeakRecord(
      values: {
        ...existing.values,
        ...data.values,
        // The primary key is not patchable; a payload carrying one is
        // ignored rather than silently re-keying the row.
        model.primaryKey.key: existing.values[model.primaryKey.key]!,
        ..._timestamps(model, isCreate: false),
      },
    );
    _rows[table]!['$id'] = updated;
    return updated;
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {
    final BeakModel model = registry.byTableOrThrow(table);
    final BeakRecord? existing = _rows[table]?['$id'];
    if (existing == null || (!force && _isTrashed(model, existing))) {
      throw BeakNotFoundException('No $table record with id "$id".');
    }
    if (!model.softDeletes || force) {
      _rows[table]!.remove('$id');
      return;
    }
    _rows[table]!['$id'] = BeakRecord(
      values: {...existing.values, softDeleteColumnKey: BeakValue.of(_now())},
    );
  }

  @override
  Future<BeakRecord> restore(String table, Object id) async {
    final BeakModel model = registry.byTableOrThrow(table);
    if (!model.softDeletes) {
      throw BeakValidationException(
        'Model "$table" does not soft-delete, so there is nothing to restore.',
      );
    }
    final BeakRecord? existing = _rows[table]?['$id'];
    if (existing == null || !_isTrashed(model, existing)) {
      throw BeakNotFoundException(
        'No soft-deleted $table record with id "$id".',
      );
    }
    final restored = BeakRecord(
      values: {...existing.values}..remove(softDeleteColumnKey),
      relations: existing.relations,
    );
    _rows[table]!['$id'] = restored;
    return restored;
  }

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    final BeakModel model = registry.byTableOrThrow(table);
    final rows = _rows[table] ?? const <String, BeakRecord>{};
    return [
      // A set: a record is returned once however often its id is listed.
      for (final id in <String>{for (final id in ids) '$id'})
        if (rows[id] case final BeakRecord record)
          if (!_isTrashed(model, record)) record,
    ];
  }

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    final BeakModel model = registry.byTableOrThrow(table);
    final relationMetadata = model.relationshipByKey(relationKey);
    if (relationMetadata is BeakHasMany) {
      _requireOwner(model, id);
      _linkChildren(relationMetadata, id, relatedIds, detach: false);
      return;
    }
    final relation = _pivotRelation(table, relationKey);
    _requireOwner(model, id);
    final links = _pivots.putIfAbsent(relation.pivotTable, () => {});
    for (final relatedId in relatedIds) {
      links.add(('$id', '$relatedId'));
    }
  }

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    final relationMetadata = registry
        .byTableOrThrow(table)
        .relationshipByKey(relationKey);
    if (relationMetadata is BeakHasMany) {
      _linkChildren(relationMetadata, id, relatedIds, detach: true);
      return;
    }
    final relation = _pivotRelation(table, relationKey);
    final links = _pivots[relation.pivotTable];
    if (links == null) {
      return;
    }
    for (final relatedId in relatedIds) {
      links.remove(('$id', '$relatedId'));
    }
  }

  /// Throws a [BeakNotFoundException] unless the record [id] of [model]
  /// exists (a trashed one does: it can be restored): a link to an owner that
  /// is not there would point at nothing.
  void _requireOwner(BeakModel model, Object id) {
    if (_rows[model.table]?['$id'] == null) {
      throw BeakNotFoundException('No ${model.table} record with id "$id".');
    }
  }

  void _linkChildren(
    BeakHasMany relation,
    Object ownerId,
    List<Object> ids, {
    required bool detach,
  }) {
    final rows = _rows[relation.relatedTable];
    if (rows == null) return;
    for (final id in ids) {
      final row = rows['$id'];
      if (row == null || (detach && row[relation.foreignKey]?.raw != ownerId)) {
        continue;
      }
      rows['$id'] = BeakRecord(
        values: {
          ...row.values,
          relation.foreignKey: BeakValue.of(detach ? null : ownerId),
        },
        relations: row.relations,
      );
    }
  }

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async {
    final BeakModel model = registry.byTableOrThrow(spec.table);
    final matched = _visibleRows(
      model,
      withTrashed: spec.withTrashed,
    ).where((record) => _matchesFilter(model, record, spec.filter)).toList();

    if (spec.function == BeakAggregateFunction.count) {
      return matched.length;
    }
    final String columnKey =
        spec.columnKey ??
        (throw BeakConfigurationException(
          'BeakAggregateFunction.${spec.function.name} requires a column key.',
        ));
    final values = <num>[
      for (final record in matched)
        if (_numberOf(record[columnKey]) case final num value) value,
    ];
    if (values.isEmpty) {
      // 0, never null: an aggregate over nothing is a number, and a caller
      // should not have to null-check it.
      return 0;
    }
    final num total = values.reduce((a, b) => a + b);
    return spec.function == BeakAggregateFunction.sum
        ? total
        : total / values.length;
  }

  /// The rows of [model] a query may see.
  Iterable<BeakRecord> _visibleRows(
    BeakModel model, {
    required bool withTrashed,
  }) {
    final rows = _rows[model.table]?.values ?? const <BeakRecord>[];
    return withTrashed
        ? rows
        : rows.where((record) => !_isTrashed(model, record));
  }

  /// Whether [record] carries a soft-delete marker on a soft-deleting model.
  bool _isTrashed(BeakModel model, BeakRecord record) =>
      model.softDeletes && record[softDeleteColumnKey]?.raw != null;

  /// The created/updated stamps [model] declares, for a write.
  Map<String, BeakValue> _timestamps(
    BeakModel model, {
    required bool isCreate,
  }) {
    final stamps = <String, BeakValue>{};
    final DateTime at = _now();
    if (isCreate && model.columnByKey('created_at') != null) {
      stamps['created_at'] = BeakValue.of(at);
    }
    if (model.columnByKey('updated_at') != null) {
      stamps['updated_at'] = BeakValue.of(at);
    }
    return stamps;
  }

  /// The many-to-many relationship [relationKey] names on [table].
  BeakBelongsToMany _pivotRelation(String table, String relationKey) {
    final BeakModel model = registry.byTableOrThrow(table);
    final BeakRelationship? relation = model.relationshipByKey(relationKey);
    if (relation is BeakBelongsToMany) {
      return relation;
    }
    throw BeakConfigurationException(
      relation == null
          ? 'Model "$table" has no relationship "$relationKey".'
          : 'Relationship "$relationKey" on "$table" is not a '
                'many-to-many, so it cannot be attached or detached.',
    );
  }

  /// [record] with each of [loads] resolved into its relations map.
  Future<BeakRecord> _withRelations(
    BeakModel model,
    BeakRecord record,
    List<BeakRelationLoad> loads,
  ) async {
    if (loads.isEmpty) {
      return record;
    }
    final relations = <String, List<BeakRecord>>{...record.relations};
    for (final load in loads) {
      final BeakRelationship? relation = model.relationshipByKey(
        load.relationKey,
      );
      if (relation == null) {
        throw BeakConfigurationException(
          'Model "${model.table}" has no relationship "${load.relationKey}".',
        );
      }
      final BeakModel related = registry.byTableOrThrow(relation.relatedTable);
      final List<BeakRecord> matched = _relatedRows(
        model,
        relation,
        record,
      ).where((row) => _matchesFilter(related, row, load.filter)).toList();
      relations[load.relationKey] = [
        for (final row in matched)
          await _withRelations(related, row, load.nested),
      ];
    }
    return BeakRecord(values: record.values, relations: relations);
  }

  /// The rows on the far side of [relation] from [record].
  Iterable<BeakRecord> _relatedRows(
    BeakModel owner,
    BeakRelationship relation,
    BeakRecord record,
  ) {
    final BeakModel related = registry.byTableOrThrow(relation.relatedTable);
    final Iterable<BeakRecord> candidates = _visibleRows(
      related,
      withTrashed: false,
    );
    final Object? ownerId = owner.primaryKeyOf(record);

    return switch (relation) {
      BeakBelongsTo(:final foreignKey) => () {
        final Object? target = record[foreignKey]?.raw;
        return target == null
            ? const <BeakRecord>[]
            : candidates.where(
                (row) => '${related.primaryKeyOf(row)}' == '$target',
              );
      }(),
      BeakHasOne(:final foreignKey) || BeakHasMany(:final foreignKey) =>
        candidates.where((row) => '${row[foreignKey]?.raw}' == '$ownerId'),
      BeakBelongsToMany(:final pivotTable) => () {
        final links = _pivots[pivotTable] ?? const <(String, String)>{};
        final relatedIds = <String>{
          for (final (owner, target) in links)
            if (owner == '$ownerId') target,
        };
        return candidates.where(
          (row) => relatedIds.contains('${related.primaryKeyOf(row)}'),
        );
      }(),
    };
  }

  /// Whether [record] satisfies [filter]; a null filter matches everything.
  bool _matchesFilter(BeakModel model, BeakRecord record, BeakFilter? filter) =>
      switch (filter) {
        null => true,
        BeakAndFilter(:final filters) => filters.every(
          (child) => _matchesFilter(model, record, child),
        ),
        BeakOrFilter(:final filters) => filters.any(
          (child) => _matchesFilter(model, record, child),
        ),
        BeakFieldFilter(:final columnKey, :final operator, :final value) =>
          _pathValues(
            model,
            record,
            columnKey,
          ).any((actual) => _matchesField(actual, operator, value)),
        BeakRelationFilter(:final relationKey, :final filter) =>
          _matchesRelated(model, record, relationKey, filter),
      };

  BeakRelationship _relationOf(BeakModel model, String key) =>
      model.relationshipByKey(key) ??
      (throw BeakConfigurationException(
        'Model "${model.table}" has no relationship "$key".',
      ));

  Iterable<BeakValue?> _pathValues(
    BeakModel model,
    BeakRecord record,
    String path,
  ) sync* {
    final split = path.indexOf('.');
    if (split < 0) {
      if (model.columnByKey(path) == null) {
        throw BeakConfigurationException(
          'Model "${model.table}" has no column "$path".',
        );
      }
      yield record[path];
      return;
    }
    final relation = _relationOf(model, path.substring(0, split));
    final target = registry.byTableOrThrow(relation.relatedTable);
    for (final row in _relatedRows(model, relation, record)) {
      yield* _pathValues(target, row, path.substring(split + 1));
    }
  }

  bool _matchesRelated(
    BeakModel model,
    BeakRecord record,
    String key,
    BeakFilter filter,
  ) {
    final relation = _relationOf(model, key);
    final target = registry.byTableOrThrow(relation.relatedTable);
    return _relatedRows(
      model,
      relation,
      record,
    ).any((row) => _matchesFilter(target, row, filter));
  }

  /// Whether [actual] satisfies [operator] against [operand].
  bool _matchesField(
    BeakValue? actual,
    BeakOperator operator,
    BeakValue operand,
  ) {
    final Object? left = actual?.raw;
    final Object? right = operand.raw;

    switch (operator) {
      case BeakOperator.isNull:
        return left == null;
      case BeakOperator.isNotNull:
        return left != null;
      case BeakOperator.eq:
        return _equals(left, right);
      case BeakOperator.neq:
        return !_equals(left, right);
      case BeakOperator.inList:
        return _asList(right).any((item) => _equals(left, item));
      case BeakOperator.notInList:
        return !_asList(right).any((item) => _equals(left, item));
      case BeakOperator.gt:
      case BeakOperator.gte:
      case BeakOperator.lt:
      case BeakOperator.lte:
        final int? order = _compare(left, right);
        return order != null &&
            switch (operator) {
              BeakOperator.gt => order > 0,
              BeakOperator.gte => order >= 0,
              BeakOperator.lt => order < 0,
              _ => order <= 0,
            };
      case BeakOperator.between:
      case BeakOperator.notBetween:
        final List<Object?> bounds = _asList(right);
        if (bounds.length != 2) {
          throw BeakConfigurationException(
            'BeakOperator.${operator.name} needs exactly two bounds, '
            'got ${bounds.length}.',
          );
        }
        final int? low = _compare(left, bounds.first);
        final int? high = _compare(left, bounds.last);
        final bool within =
            low != null && high != null && low >= 0 && high <= 0;
        return operator == BeakOperator.between ? within : !within;
      case BeakOperator.like:
        return _like(left, right, caseSensitive: true);
      // The substring operators ignore case, as a real source does (they are
      // `ILIKE` patterns there), so a test against this source finds what the
      // running panel finds.
      case BeakOperator.contains:
        return _text(left).toLowerCase().contains(_text(right).toLowerCase());
      case BeakOperator.ilike:
        return _like(left, right, caseSensitive: false);
      case BeakOperator.startsWith:
        return _text(left).toLowerCase().startsWith(_text(right).toLowerCase());
      case BeakOperator.endsWith:
        return _text(left).toLowerCase().endsWith(_text(right).toLowerCase());
    }
  }

  bool _like(Object? value, Object? pattern, {required bool caseSensitive}) {
    if (value == null || pattern == null) return false;
    return beakLikeRegExp(
      _text(pattern),
      caseSensitive: caseSensitive,
    ).hasMatch(_text(value));
  }

  /// Whether [record] matches [search] in any of its declared columns.
  bool _matchesSearch(BeakModel model, BeakRecord record, BeakSearch? search) =>
      _matchesFilter(model, record, beakSearchFilter(search, model, registry));

  /// Orders [records] by [sorts], first key first.
  void _sort(List<BeakRecord> records, List<BeakSort> sorts) {
    if (sorts.isEmpty) {
      return;
    }
    records.sort((a, b) {
      for (final sort in sorts) {
        // Nulls sort last regardless of direction: "no value" is not a value
        // that belongs at either end of a range.
        final Object? left = a[sort.columnKey]?.raw;
        final Object? right = b[sort.columnKey]?.raw;
        if (left == null && right == null) {
          continue;
        }
        if (left == null) {
          return 1;
        }
        if (right == null) {
          return -1;
        }
        final int order = _compare(left, right) ?? 0;
        if (order != 0) {
          return sort.descending ? -order : order;
        }
      }
      return 0;
    });
  }

  static bool _equals(Object? left, Object? right) {
    if (left is num && right is num) {
      return left == right;
    }
    if (left is DateTime && right is DateTime) {
      return left.isAtSameMomentAs(right);
    }
    return left == right;
  }

  /// Three-way comparison, or `null` when the two are not comparable.
  static int? _compare(Object? left, Object? right) {
    if (left is num && right is num) {
      return left.compareTo(right);
    }
    if (left is DateTime && right is DateTime) {
      return left.compareTo(right);
    }
    if (left is String && right is String) {
      return left.compareTo(right);
    }
    if (left is bool && right is bool) {
      return (left ? 1 : 0).compareTo(right ? 1 : 0);
    }
    return null;
  }

  static List<Object?> _asList(Object? value) =>
      value is List<Object?> ? value : [value];

  static String _text(Object? value) => value?.toString() ?? '';

  static num? _numberOf(BeakValue? value) => switch (value?.raw) {
    final num raw => raw,
    final String raw => num.tryParse(raw),
    _ => null,
  };
}
