import 'dart:async';
import 'dart:convert';

import 'beak_data_changes.dart';

import 'package:beak_core/beak_core.dart';

/// Routes panel operations to model-owned transports, with one error boundary.
///
/// An explicit panel source replaces all bindings (useful for tests). Otherwise
/// each bound model uses its source and unbound models use the HTTP fallback.
final class ModelBeakDataSource
    implements
        BeakDataSource,
        BeakCapabilityDataSource,
        BeakSummaryDataSource,
        BeakExportDataSource,
        BeakEditDataSource,
        BeakValidationDataSource,
        BeakManagedUploadClient,
        BeakUploadUrlClient,
        BeakCommitDataSource,
        BeakMutationSource {
  /// Captures sources once so a request never reconstructs a transport.
  ModelBeakDataSource({
    required BeakModelRegistry registry,
    BeakDataSource? fallback,
    bool overrideBindings = false,
    this.mapException,
    this.onUnauthorized,
    this.refreshPolicy,
  }) : _registry = registry,
       _fallback = fallback,
       _sources = {
         for (final model in registry.all)
           model.table: overrideBindings
               ? fallback
               : model.dataSource ?? fallback,
       } {
    if (refreshPolicy?.interval case final Duration interval
        when interval <= Duration.zero) {
      throw const BeakConfigurationException(
        'A refresh interval must be positive.',
      );
    }
    _changes = StreamController.broadcast(
      sync: true,
      onListen: _startRefresh,
      onCancel: _stopRefresh,
    );
  }

  /// Shared refresh cadence, opt-in for backends without a push change feed.
  final BeakRefreshPolicy? refreshPolicy;

  /// Maps recognized host exceptions to safe, localized Beak errors.
  final BeakException? Function(Exception exception, StackTrace stackTrace)?
  mapException;

  /// Called after a request fails with a [BeakAuthenticationException], the
  /// failure of a session the server no longer accepts. The panel uses it to
  /// end the session, so the person lands on the sign-in page instead of
  /// reading a message inside a panel that can no longer load anything.
  final void Function()? onUnauthorized;

  final Map<String, BeakDataSource?> _sources;
  final BeakDataSource? _fallback;
  final BeakModelRegistry _registry;
  late final BeakStagedCommitDataSource _staged = BeakStagedCommitDataSource(
    source: this,
    registry: _registry,
  );
  final Map<String, BeakCommitDataSource> _commitSources = {};
  final Map<String, String> _commitPlans = {};
  final Map<String, BeakSavePlan> _savePlans = {};
  late final StreamController<BeakDataChange> _changes;
  Timer? _refreshTimer;
  bool _foreground = true;

  void _startRefresh() {
    if (_changes.isClosed ||
        !_changes.hasListener ||
        !_foreground ||
        _refreshTimer != null) {
      return;
    }
    if (refreshPolicy?.interval case final Duration interval) {
      _refreshTimer = Timer.periodic(
        interval,
        (_) => _changed(_registry.all.map((model) => model.table)),
      );
    }
  }

  void _stopRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Called by the panel lifecycle; background windows do not poll.
  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (!value) {
      _stopRefresh();
      return;
    }
    if (refreshPolicy?.onResume == true &&
        _changes.hasListener &&
        !_changes.isClosed) {
      _changed(_registry.all.map((model) => model.table));
    }
    _startRefresh();
  }

  final Set<String> _pendingChanges = {};
  int _commitDepth = 0;
  int _writeSequence = 0;
  final Map<String, BeakSavePlan> _pendingWrites = {};

  @override
  Stream<BeakDataChange> get changes => _changes.stream;

  /// Releases this panel's mutation stream without closing host-owned sources.
  Future<void> dispose() {
    _stopRefresh();
    return _changes.close();
  }

  // --8<-- [start:changed]
  void _changed(Iterable<String> tables) {
    _pendingChanges.addAll(tables);
    if (_commitDepth > 0 || _changes.isClosed || _pendingChanges.isEmpty) {
      return;
    }
    final affected = {..._pendingChanges};
    _pendingChanges.clear();
    var grew = true;
    while (grew) {
      grew = false;
      for (final model in _registry.all) {
        if (!affected.contains(model.table) &&
            model.relationships.any(
              (relation) => affected.contains(relation.relatedTable),
            )) {
          grew = affected.add(model.table) || grew;
        }
      }
    }
    _changes.add(BeakDataChange(affected));
  }
  // --8<-- [end:changed]

  // --8<-- [start:committed]
  void _committed(BeakSavePlan? plan, BeakSaveResult result) {
    final applied = {
      for (final outcome in result.outcomes)
        if (outcome.status == BeakWriteOutcome.applied) outcome.id,
    };
    _changed({
      for (final outcome in result.outcomes)
        if (outcome.status == BeakWriteOutcome.applied && outcome.table != null)
          outcome.table!,
      for (final operation in plan?.operations ?? const <BeakSaveOperation>[])
        if (applied.contains(operation.id)) ...[
          operation.target.table,
          if (operation.owner case final BeakRecordRef owner) owner.table,
          if (operation.related case final BeakRecordRef related) related.table,
        ],
    });
  }
  // --8<-- [end:committed]

  Future<T> _mutate<T>(
    Iterable<String> tables,
    Future<T> Function() operation,
  ) => _run(() async {
    final result = await operation();
    _changed(tables);
    return result;
  });

  @override
  BeakCommitCapabilities get commitCapabilities {
    final sources = _sources.values.whereType<BeakDataSource>().toSet();
    if (sources.singleOrNull case final BeakCommitDataSource source) {
      return source.commitCapabilities;
    }
    return const BeakCommitCapabilities();
  }

  @override
  // --8<-- [start:commit]
  Future<BeakSaveResult> commit(BeakSavePlan plan) => _run(() async {
    final encoded = jsonEncode(plan.toJson());
    if (_commitPlans[plan.saveId] case final String previous
        when previous != encoded) {
      throw const BeakConflictException(
        'Save identity was reused with different content.',
      );
    }
    plan.orderedOperations(_registry);
    final sources = <BeakDataSource>{
      _source(plan.root.table),
      for (final operation in plan.operations) ...[
        _source(operation.target.table),
        for (final ref in operation.requiredReferences) _source(ref.table),
      ],
    };
    final BeakCommitDataSource selected;
    if (sources.singleOrNull case final BeakCommitDataSource source) {
      selected = source;
    } else {
      selected = _staged;
    }
    _commitPlans[plan.saveId] = encoded;
    _commitSources[plan.saveId] = selected;
    _savePlans[plan.saveId] = plan;
    _commitDepth++;
    try {
      final result = await selected.commit(plan);
      _committed(plan, result);
      return result;
    } finally {
      _commitDepth--;
      _changed(const []);
    }
  });
  // --8<-- [end:commit]

  @override
  Future<BeakSaveResult> recover(String saveId) => _run(() async {
    final selected = _commitSources[saveId];
    if (selected != null) {
      final result = await selected.recover(saveId);
      if (_savePlans[saveId] case final BeakSavePlan plan) {
        _committed(plan, result);
      }
      return result;
    }
    final sources = _sources.values.whereType<BeakDataSource>().toSet();
    if (sources.singleOrNull case final BeakCommitDataSource source) {
      final result = await source.recover(saveId);
      _committed(null, result);
      return result;
    }
    throw BeakNotFoundException('No session receipt for save "$saveId".');
  });

  BeakDataSource _source(String table) =>
      _sources[table] ??
      _fallback ??
      (throw BeakConfigurationException('No data source for "$table".'));

  // --8<-- [start:run]
  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on BeakException catch (error) {
      _reportUnauthorized(error);
      rethrow;
    } on Exception catch (error, stack) {
      final mapped = mapException?.call(error, stack);
      if (mapped != null) {
        _reportUnauthorized(mapped);
        Error.throwWithStackTrace(mapped, stack);
      }
      rethrow;
    }
  }

  void _reportUnauthorized(BeakException error) {
    if (error is BeakAuthenticationException) onUnauthorized?.call();
  }
  // --8<-- [end:run]

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) =>
      _run(() => _source(spec.table).query(spec));

  @override
  Future<BeakRecord?> getOne(String table, Object id) =>
      _run(() => _source(table).getOne(table, id));

  @override
  Future<BeakAccessCapabilities> capabilities(String table, {Object? id}) =>
      _run(() async {
        final source = _source(table);
        if (source case final BeakCapabilityDataSource capable) {
          return capable.capabilities(table, id: id);
        }
        return const BeakAccessCapabilities();
      });

  @override
  Future<BeakValidationReport> validateRecord(BeakValidationRequest request) =>
      _run(() async {
        final source = _source(request.table);
        if (source case final BeakValidationDataSource validation) {
          return validation.validateRecord(request);
        }
        return const BeakAsyncValidation().validate(
          _registry.byTableOrThrow(request.table),
          request.record,
          recordId: request.recordId,
          query: query,
          registry: _registry,
        );
      });

  @override
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) => _run(() {
    final source = _source(table);
    if (source case final BeakUploadClient uploads) {
      return uploads.upload(table, columnKey, file);
    }
    throw BeakConfigurationException(
      'The data source for "$table" does not support uploads.',
    );
  });

  @override
  Future<void> discardUpload(
    String table,
    String columnKey,
    BeakStoredFile file,
  ) => _run(() {
    final source = _source(table);
    if (source case final BeakManagedUploadClient uploads) {
      return uploads.discardUpload(table, columnKey, file);
    }
    throw BeakConfigurationException(
      'The data source for "$table" cannot discard staged uploads.',
    );
  });

  @override
  Future<Uri> uploadUrl(String table, String columnKey, String key) => _run(() {
    final source = _source(table);
    if (source case final BeakUploadUrlClient uploads) {
      return uploads.uploadUrl(table, columnKey, key);
    }
    throw BeakConfigurationException(
      'The data source for "$table" cannot resolve upload URLs.',
    );
  });

  @override
  Future<BeakRecord> loadEditValues(String table, Object id) => _run(() async {
    final source = _source(table);
    if (source case final BeakEditDataSource editSource) {
      return editSource.loadEditValues(table, id);
    }
    return await source.getOne(table, id) ??
        (throw const BeakNotFoundException('The record no longer exists.'));
  });

  @override
  Future<BeakRecord> create(String table, BeakRecord data) => _run(() async {
    final source = _source(table);
    if (_commitDepth > 0 || source is! BeakCommitDataSource) {
      return _mutate([table], () => source.create(table, data));
    }
    final draft = BeakRecordRef.draft(table, 'created');
    final result = await _writeThroughGraph(
      key: 'create:$table:${jsonEncode(data.toJson())}',
      plan: () => BeakSavePlan(
        saveId: _nextWriteId('create'),
        root: draft,
        operations: [
          BeakSaveOperation(
            id: 'create',
            kind: BeakSaveOperationKind.create,
            target: draft,
            values: data,
          ),
        ],
      ),
      unconfirmed: 'The record was not saved for certain. Retry to recover it.',
      failed: 'The record could not be created.',
    );
    return _writtenRecord(table, result, 'create');
  });

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      _run(() async {
        final source = _source(table);
        if (_commitDepth > 0 || source is! BeakCommitDataSource) {
          return _mutate([table], () => source.update(table, id, data));
        }
        final target = BeakRecordRef.existing(table, id);
        final result = await _writeThroughGraph(
          key: 'update:$table:$id:${jsonEncode(data.toJson())}',
          plan: () => BeakSavePlan(
            saveId: _nextWriteId('update'),
            root: target,
            operations: [
              BeakSaveOperation(
                id: 'update',
                kind: BeakSaveOperationKind.update,
                target: target,
                values: data,
              ),
            ],
          ),
          unconfirmed:
              'The change was not saved for certain. Retry to recover it.',
          failed: 'The change could not be saved.',
        );
        return _writtenRecord(table, result, 'update', id: id);
      });

  @override
  Future<void> delete(String table, Object id, {bool force = false}) => _run(
    () async {
      final source = _source(table);
      // The graph protocol deliberately preserves configured soft deletion.
      // Explicit force-deletes retain the transport's separate operation.
      if (force || _commitDepth > 0 || source is! BeakCommitDataSource) {
        return _mutate([table], () => source.delete(table, id, force: force));
      }
      final target = BeakRecordRef.existing(table, id);
      await _writeThroughGraph(
        key: 'delete:$table:$id',
        plan: () => BeakSavePlan(
          saveId: _nextWriteId('delete'),
          root: target,
          operations: [
            BeakSaveOperation(
              id: 'delete',
              kind: BeakSaveOperationKind.delete,
              target: target,
            ),
          ],
        ),
        unconfirmed: 'Deletion is not confirmed. Retry to recover its result.',
        failed: 'The deletion could not be completed.',
      );
    },
  );

  String _nextWriteId(String kind) =>
      '$kind-${DateTime.now().microsecondsSinceEpoch}-${++_writeSequence}';

  /// Commits one single-operation plan, keeping an uncertain identity: a
  /// repeated identical call recovers its receipt and never submits the write
  /// again under a new identity.
  Future<BeakSaveResult> _writeThroughGraph({
    required String key,
    required BeakSavePlan Function() plan,
    required String unconfirmed,
    required String failed,
  }) async {
    final pending = _pendingWrites[key];
    final effective = pending ?? plan();
    _pendingWrites[key] = effective;
    final result = pending == null
        ? await commit(effective)
        : await recover(effective.saveId);
    if (result.complete) {
      _pendingWrites.remove(key);
      return result;
    }
    if (result.hasUnknown) throw BeakConflictException(unconfirmed);
    _pendingWrites.remove(key);
    final error = result.outcomes
        .map((outcome) => outcome.error)
        .nonNulls
        .firstOrNull;
    throw switch (error?.code) {
      'validation' => BeakValidationException(
        error!.message,
        fieldErrors: error.fieldErrors,
      ),
      'authorization' => BeakAuthorizationException(error!.message),
      'authentication' => BeakAuthenticationException(error!.message),
      'not_found' => BeakNotFoundException(error!.message),
      'configuration' => BeakConfigurationException(error!.message),
      'storage' => BeakStorageException(error!.message),
      _ => BeakConflictException(error?.message ?? failed),
    };
  }

  /// The canonical record a confirmed single write produced: the receipt's own
  /// copy when it carries one, otherwise a read of the row.
  Future<BeakRecord> _writtenRecord(
    String table,
    BeakSaveResult result,
    String operationId, {
    Object? id,
  }) async {
    final outcome = result.outcomes
        .where((outcome) => outcome.id == operationId)
        .firstOrNull;
    if (outcome?.record case final BeakRecord record) return record;
    final written = id ?? outcome?.resolvedId;
    if (written != null) {
      final record = await _source(table).getOne(table, written);
      if (record != null) return record;
    }
    throw BeakNotFoundException(
      'The saved record of "$table" could not be read back.',
    );
  }

  @override
  Future<BeakRecord> restore(String table, Object id) =>
      _mutate([table], () => _source(table).restore(table, id));

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) =>
      _run(() => _source(table).batchGet(table, ids));

  @override
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) => _run(() {
    return switch (_source(spec.table)) {
      final BeakSummaryDataSource source => source.summary(spec),
      _ => throw const BeakConfigurationException(
        'This data source does not support summaries.',
      ),
    };
  });

  @override
  Future<String> export(
    BeakQuerySpec spec, {
    List<BeakColumn>? columns,
    Map<String, BeakExportFormat> formats = const {},
    BeakFormatPolicy? formatting,
    bool raw = false,
  }) => _run(() {
    final source = _source(spec.table);
    if (source case final BeakExportDataSource exports) {
      return exports.export(
        spec,
        columns: columns,
        formats: formats,
        formatting: formatting,
        raw: raw,
      );
    }
    throw const BeakConfigurationException(
      'This data source does not support CSV exports.',
    );
  });

  @override
  Future<num> aggregate(BeakAggregateSpec spec) =>
      _run(() => _source(spec.table).aggregate(spec));

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _mutate([
    table,
    if (_registry.byTable(table)?.relationshipByKey(relationKey)
        case final BeakRelationship relation)
      relation.relatedTable,
  ], () => _source(table).attach(table, id, relationKey, relatedIds));

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _mutate([
    table,
    if (_registry.byTable(table)?.relationshipByKey(relationKey)
        case final BeakRelationship relation)
      relation.relatedTable,
  ], () => _source(table).detach(table, id, relationKey, relatedIds));
}
