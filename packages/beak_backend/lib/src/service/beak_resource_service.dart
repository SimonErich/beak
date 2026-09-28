import 'package:beak_core/beak_core.dart';

import '../common/uuid_v4.dart';
import 'beak_revision_timestamp.dart';
import 'validation_service.dart';

/// The per-model logic layer between the generated handlers and the data
/// source: validation, create-time defaults (minted uuid ids, timestamps),
/// and relation-kind gating — handlers stay parse-and-route thin.
///
/// Internal to `beak_backend`: `beakApiRouter` builds one per registered
/// model, and the graph commit service one per table a commit writes, so both
/// write paths share one set of defaults. Omitting a string primary key lets
/// the service mint a uuid, and it stamps `created_at`/`updated_at` when the
/// model declares them.
final class BeakResourceService {
  /// Creates the service for [model] over [dataSource].
  ///
  /// [now] and [generateId] inject the clock and id mint so tests can pin the
  /// stamped timestamps and minted primary keys; both default to real
  /// implementations ([DateTime.now] and a v4 uuid generator).
  BeakResourceService(
    this.model,
    this.dataSource, {
    this.deferRecordRules = false,
    this.registry,
    DateTime Function()? now,
    String Function()? generateId,
  }) : _now = now ?? DateTime.now,
       _generateId = generateId ?? generateUuidV4;

  /// The model this service exposes.
  final BeakModel model;

  /// The source the service reads and writes through.
  final BeakDataSource dataSource;

  /// Graph operations defer cross-record checks until all rows exist atomically.
  final bool deferRecordRules;

  /// Optional registry for nonstandard related primary keys.
  final BeakModelRegistry? registry;

  final DateTime Function() _now;
  final String Function() _generateId;

  /// The validation boundary run before every write.
  static const ValidationService _validation = ValidationService();

  /// The column key the service stamps on create.
  static const String createdAtColumnKey = 'created_at';

  /// The column key the service stamps on create and update.
  static const String updatedAtColumnKey = 'updated_at';

  /// Validates a complete candidate while preserving partial-update semantics.
  /// The query seam applies caller policy to asynchronous checks and relation loads.
  Future<void> validateCandidate(
    BeakRecord input, {
    Object? recordId,
    BeakFilter? scope,
    BeakValidationQuery? validationQuery,
    bool asynchronousOnly = false,
  }) async {
    final query = validationQuery ?? dataSource.query;
    BeakRecord? initial;
    if (recordId != null &&
        !deferRecordRules &&
        model.validationRules.isNotEmpty) {
      // Model rules are trusted invariants over complete persisted state.
      // Root scope still gates identity; related read filters must not conceal
      // siblings from count, distinct or aggregate constraints.
      final page = await dataSource.query(
        _scopedQuery(
          model.query(
            filter: BeakFieldFilter(
              column: model.primaryKey,
              operator: BeakOperator.eq,
              value: BeakValue.of(recordId),
            ),
            relationLoads: [
              if (!asynchronousOnly)
                for (final rule in model.validationRules) ...rule.relationLoads,
            ],
            pagination: const BeakPagination(perPage: 1),
          ),
          scope,
        ),
      );
      initial = page.items.firstOrNull;
      if (initial == null) {
        throw const BeakNotFoundException('The record no longer exists.');
      }
    } else if (recordId != null && !deferRecordRules) {
      initial = await getOne(recordId, scope: scope);
    }
    _validation.validate(
      model,
      input,
      isCreate: recordId == null && !asynchronousOnly,
      initial: initial,
      includeRecordRules: !deferRecordRules && !asynchronousOnly,
    );
    if (deferRecordRules) return;
    final candidate = BeakRecord(
      values: {...?initial?.values, ...input.values},
      relations: {...?initial?.relations, ...input.relations},
    );
    final report = await const BeakAsyncValidation().validate(
      model,
      candidate,
      recordId: recordId,
      query: query,
      registry: registry,
    );
    if (!report.valid) {
      throw BeakValidationException(
        'Validation failed for "${model.table}".',
        fieldErrors: report.fieldErrors,
      );
    }
  }

  /// Runs [spec] against the data source.
  ///
  /// The handler authorizes [spec] first — a row policy's scope is folded
  /// into its filter by `BeakQueryAuthorizer` — so this only checks the
  /// target. Throws a [BeakValidationException] when the spec targets another
  /// table than this service's model.
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    _requireSpecTargets(spec.table, 'Query');
    return dataSource.query(spec);
  }

  /// Computes [spec]'s aggregate against the data source, authorized like
  /// [query].
  ///
  /// Throws a [BeakValidationException] when the spec targets another table
  /// than this service's model.
  Future<num> aggregate(BeakAggregateSpec spec) {
    _requireSpecTargets(spec.table, 'Aggregate');
    return dataSource.aggregate(spec);
  }

  /// Executes a full-population summary through an explicit source capability.
  ///
  /// Throws a [BeakConfigurationException] when the data source cannot
  /// summarise.
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) {
    _requireSpecTargets(spec.table, 'Summary');
    return switch (dataSource) {
      final BeakSummaryDataSource summaries => summaries.summary(spec),
      _ => throw const BeakConfigurationException(
        'This data source does not support summaries.',
      ),
    };
  }

  /// [spec] narrowed by [scope], or [spec] unchanged when there is none.
  static BeakQuerySpec _scopedQuery(BeakQuerySpec spec, BeakFilter? scope) =>
      scope == null
      ? spec
      : BeakQuerySpec(
          table: spec.table,
          filter: _intersect(spec.filter, scope),
          sorts: spec.sorts,
          search: spec.search,
          relationLoads: spec.relationLoads,
          pagination: spec.pagination,
          withTrashed: spec.withTrashed,
        );

  /// [left] and [right] as one filter, dropping either when it is absent.
  ///
  /// Nesting two ANDs would still be correct, but flattening keeps the SQL —
  /// and anything reading a logged spec — legible.
  static BeakFilter? _intersect(BeakFilter? left, BeakFilter? right) =>
      switch ((left, right)) {
        (null, final BeakFilter? only) ||
        (final BeakFilter? only, null) => only,
        (final BeakFilter a, final BeakFilter b) => BeakAndFilter([
          if (a case final BeakAndFilter and) ...and.filters else a,
          if (b case final BeakAndFilter and) ...and.filters else b,
        ]),
      };

  /// Rejects specs aimed at another table than this service's model — the
  /// one wording every spec-accepting endpoint shares.
  void _requireSpecTargets(String table, String specKind) {
    if (table != model.table) {
      throw BeakValidationException(
        '$specKind spec targets "$table" but this endpoint serves '
        '"${model.table}".',
      );
    }
  }

  /// The record with primary key [id], within [scope].
  ///
  /// A record outside the scope reports as missing rather than forbidden:
  /// telling an unauthorised caller that a record exists is itself a leak,
  /// and "not found" is the honest answer for a row they cannot address.
  ///
  /// Throws a [BeakNotFoundException] when it does not exist.
  Future<BeakRecord> getOne(Object id, {BeakFilter? scope}) async =>
      await _findInScope(id, scope) ??
      (throw BeakNotFoundException(
        'No record of "${model.table}" with id "$id".',
      ));

  /// The record with primary key [id] if [scope] admits it, else `null`.
  Future<BeakRecord?> _findInScope(Object id, BeakFilter? scope) async {
    if (scope == null) {
      return dataSource.getOne(model.table, id);
    }
    final page = await dataSource.query(
      BeakQuerySpec(
        table: model.table,
        filter: _intersect(
          BeakFieldFilter.forKey(
            model.primaryKey.key,
            BeakOperator.eq,
            BeakValue.of(id),
          ),
          scope,
        ),
        pagination: const BeakPagination(perPage: 1),
      ),
    );
    return page.items.isEmpty ? null : page.items.first;
  }

  /// Validates and stores [input], minting a uuid primary key (for
  /// string-keyed models) and stamping `created_at`/`updated_at` when the
  /// model declares them and the caller did not.
  Future<BeakRecord> create(
    BeakRecord input, {
    BeakValidationQuery? validationQuery,
  }) async {
    final prepared = prepareCreate(input);
    await validateCandidate(prepared, validationQuery: validationQuery);
    return dataSource.create(model.table, prepared);
  }

  /// Validates the provided fields of [input] (partial semantics), stamps
  /// `updated_at` when the model declares it, and applies the update.
  Future<BeakRecord> update(
    Object id,
    BeakRecord input, {
    BeakFilter? scope,
    DateTime? expectedUpdatedAt,
    BeakValidationQuery? validationQuery,
  }) async {
    // Read first when scoped or when checking the version: an update whose
    // WHERE the client controls is the same hole as a query whose filter it
    // controls.
    await _requireInScope(id, scope);
    final stampsRevision =
        model.columnByKey(updatedAtColumnKey) is BeakDateTimeColumn;
    final current = stampsRevision || expectedUpdatedAt != null
        ? await getOne(id)
        : null;
    if (expectedUpdatedAt != null) {
      _requireUnchangedSince(expectedUpdatedAt, current!, id);
    }
    final prepared = const BeakValidation().applyDefaults(
      model,
      input,
      includeMissing: false,
    );
    await validateCandidate(
      prepared,
      recordId: id,
      scope: scope,
      validationQuery: validationQuery,
    );
    var values = prepared.values;
    if (stampsRevision) {
      values = {
        ...values,
        updatedAtColumnKey: BeakDateTimeValue(
          beakRevisionTimestamp(
            _now(),
            previous: switch (current?[updatedAtColumnKey]) {
              BeakDateTimeValue(:final value) => value,
              _ => null,
            },
          ),
        ),
      };
    }
    return dataSource.update(model.table, id, BeakRecord(values: values));
  }

  /// Throws a [BeakConflictException] when the stored `updated_at` has moved
  /// past [expected].
  ///
  /// Two people editing the same record is normal in an admin panel, and the
  /// default — last write wins, silently — is how the first person's work
  /// disappears. A 409 lets the panel say so instead.
  void _requireUnchangedSince(
    DateTime expected,
    BeakRecord current,
    Object id,
  ) {
    final DateTime? stored = switch (current[updatedAtColumnKey]) {
      final BeakDateTimeValue value => value.value,
      _ => null,
    };
    if (stored == null) {
      throw BeakValidationException(
        'Model "${model.table}" does not stamp "$updatedAtColumnKey", so a '
        'record cannot be updated conditionally.',
      );
    }
    if (!beakRevisionMatches(expected, stored)) {
      throw BeakConflictException(
        'Record "$id" of "${model.table}" changed since it was read '
        '(expected $expected, found $stored).',
      );
    }
  }

  /// Deletes the record with primary key [id] — softly for soft-deleting
  /// models unless [force], and only if [scope] admits it.
  Future<void> delete(
    Object id, {
    bool force = false,
    BeakFilter? scope,
  }) async {
    // A force delete may target an already soft-deleted record — that is the
    // whole point of emptying a trash — so the scope check reads through it.
    await _requireInScope(id, scope, withTrashed: force);
    return dataSource.delete(model.table, id, force: force);
  }

  /// Clears the soft-delete marker on the record with primary key [id],
  /// if [scope] admits it.
  ///
  /// The scope check reads through the trash, since a scoped principal must
  /// still be able to restore their own deleted rows.
  Future<BeakRecord> restore(Object id, {BeakFilter? scope}) async {
    await _requireInScope(id, scope, withTrashed: true);
    return dataSource.restore(model.table, id);
  }

  /// Throws a [BeakNotFoundException] when [scope] excludes the record with
  /// primary key [id]. Does nothing when there is no scope.
  ///
  /// Deliberately a no-op rather than a read when unscoped: an unscoped write
  /// must not pay for a lookup, and — the reason this exists at all — must
  /// not inherit the soft-delete visibility rules of one. Force-deleting an
  /// already-trashed record is legitimate, and a `getOne` in the way of it is
  /// a 404 for something that plainly exists.
  Future<void> _requireInScope(
    Object id,
    BeakFilter? scope, {
    bool withTrashed = false,
  }) async {
    if (scope == null) {
      return;
    }
    final page = await dataSource.query(
      BeakQuerySpec(
        table: model.table,
        filter: _intersect(
          BeakFieldFilter.forKey(
            model.primaryKey.key,
            BeakOperator.eq,
            BeakValue.of(id),
          ),
          scope,
        ),
        pagination: const BeakPagination(perPage: 1),
        withTrashed: withTrashed,
      ),
    );
    if (page.items.isEmpty) {
      throw BeakNotFoundException(
        'No record of "${model.table}" with id "$id".',
      );
    }
  }

  /// The records whose primary keys appear in [ids], in one query, narrowed
  /// by [scope].
  Future<List<BeakRecord>> batchGet(
    List<Object> ids, {
    BeakFilter? scope,
  }) async {
    if (scope == null) {
      return dataSource.batchGet(model.table, ids);
    }
    final page = await dataSource.query(
      BeakQuerySpec(
        table: model.table,
        filter: _intersect(
          BeakFieldFilter.forKey(
            model.primaryKey.key,
            BeakOperator.inList,
            BeakValue.of(ids),
          ),
          scope,
        ),
        pagination: BeakPagination(perPage: ids.length.clamp(1, 1000)),
      ),
    );
    return page.items;
  }

  /// Links [relatedIds] through the to-many relation [relationKey], if
  /// [scope] admits the owning record.
  Future<void> attach(
    Object id,
    String relationKey,
    List<Object> relatedIds, {
    BeakFilter? scope,
  }) async {
    _attachableRelation(relationKey);
    await _requireInScope(id, scope);
    return dataSource.attach(model.table, id, relationKey, relatedIds);
  }

  /// Unlinks [relatedIds] from the to-many relation [relationKey], if [scope]
  /// admits the owning record.
  Future<void> detach(
    Object id,
    String relationKey,
    List<Object> relatedIds, {
    BeakFilter? scope,
  }) async {
    _attachableRelation(relationKey);
    await _requireInScope(id, scope);
    return dataSource.detach(model.table, id, relationKey, relatedIds);
  }

  BeakRelationship _attachableRelation(String relationKey) {
    final relationship = model.relationshipByKey(relationKey);
    if (relationship == null) {
      throw BeakNotFoundException(
        'Model "${model.table}" has no relation "$relationKey".',
      );
    }
    if (relationship is! BeakBelongsToMany && relationship is! BeakHasMany) {
      throw BeakValidationException(
        'Relation "$relationKey" of "${model.table}" is a '
        '${relationship.runtimeType}; attach/detach need a to-many relation.',
      );
    }
    return relationship;
  }

  /// Applies declared enum defaults, generated identities and timestamps once.
  /// Graph writes use this before their authorization and validation checks.
  /// Explicit nulls remain null for enum validation; only omissions default.
  BeakRecord prepareCreate(BeakRecord input) {
    final values = {
      ...const BeakValidation().applyDefaults(model, input).values,
    };
    final primaryKey = model.primaryKey;
    if (primaryKey is BeakStringColumn && _isUnset(values[primaryKey.key])) {
      values[primaryKey.key] = BeakStringValue(_generateId());
    }
    final stamp = BeakDateTimeValue(beakRevisionTimestamp(_now()));
    for (final columnKey in const [createdAtColumnKey, updatedAtColumnKey]) {
      if (model.columnByKey(columnKey) is BeakDateTimeColumn &&
          _isUnset(values[columnKey])) {
        values[columnKey] = stamp;
      }
    }
    return BeakRecord(values: values, relations: input.relations);
  }

  /// Whether the caller provided no usable value: absent entirely, or an
  /// explicit JSON `null` ([BeakNullValue]) — e.g. an empty create-form
  /// field — which must not defeat id minting or timestamp stamping.
  static bool _isUnset(BeakValue? value) =>
      value == null || value is BeakNullValue;
}
