import 'dart:async';
import 'dart:convert';

import '../common/beak_exception.dart';
import '../model/beak_model_registry.dart';
import '../query/beak_record.dart';
import '../query/beak_relation_load.dart';
import '../model/beak_model.dart';
import '../relations/beak_relationship.dart';
import 'beak_commit.dart';
import 'beak_data_source.dart';

/// Executes one operation using only confirmed dependency identities.
typedef BeakSaveOperationRunner =
    Future<BeakOperationResult> Function(
      BeakSaveOperation operation,
      Map<String, Object> identities,
    );

/// Receives an in-flight checkpoint before dispatch and a receipt afterward.
typedef BeakSaveCheckpointWriter = Future<void> Function(BeakSaveResult result);

/// Runs a save sequentially, stopping at the first failed or uncertain write.
///
/// [previous] may only come from trusted local/provider receipts. A remote
/// endpoint must never accept a client checkpoint as evidence of a write.
Future<BeakSaveResult> executeBeakSavePlan({
  required BeakSavePlan plan,
  required BeakModelRegistry registry,
  required BeakSaveOperationRunner run,
  BeakSaveResult? previous,
  BeakSaveMode mode = BeakSaveMode.staged,
  BeakSaveCheckpointWriter? checkpoint,
}) async {
  final ordered = plan.orderedOperations(registry);
  if (previous != null && previous.saveId != plan.saveId) {
    throw const BeakConfigurationException('Receipt belongs to another save.');
  }
  final results = <String, BeakOperationResult>{
    for (final op in ordered)
      op.id: BeakOperationResult(
        id: op.id,
        status: BeakWriteOutcome.unapplied,
        reason: 'notStarted',
      ),
    for (final entry in previous?.outcomes ?? const <BeakOperationResult>[])
      entry.id: entry,
  };
  final rootOperation = ordered
      .where(
        (op) =>
            op.target.table == plan.root.table &&
            op.target.id == plan.root.id &&
            op.target.draftId == plan.root.draftId &&
            (op.kind == BeakSaveOperationKind.create ||
                op.kind == BeakSaveOperationKind.update),
      )
      .lastOrNull;
  BeakSaveResult snapshot() => BeakSaveResult(
    saveId: plan.saveId,
    mode: mode,
    outcomes: [for (final op in ordered) results[op.id]!],
    rootOperationId: rootOperation?.id,
  );
  if (previous?.hasUnknown ?? false) return snapshot();
  for (final op in ordered) {
    if (results[op.id]!.status == BeakWriteOutcome.applied) continue;
    final identities = snapshot().identities;
    results[op.id] = BeakOperationResult(
      id: op.id,
      status: BeakWriteOutcome.unknown,
      reason: 'inFlight',
    );
    // Failure to write a pre-dispatch checkpoint must prevent the mutation.
    await checkpoint?.call(snapshot());
    try {
      results[op.id] = await run(op, identities);
    } on Object catch (error) {
      results[op.id] = BeakOperationResult(
        id: op.id,
        status: BeakWriteOutcome.unknown,
        error: BeakSaveError.fromException(error),
      );
    }
    await checkpoint?.call(snapshot());
    if (results[op.id]!.status != BeakWriteOutcome.applied) break;
  }
  return snapshot();
}

/// Safely adapts ordinary CRUD to staged, session-local graph saving.
///
/// Successful operations are never replayed. Errors after dispatch remain
/// unknown: an arbitrary CRUD provider can throw after it has stored the data.
final class BeakStagedCommitDataSource implements BeakCommitDataSource {
  /// Wraps [source] without claiming transaction or durable receipt support.
  BeakStagedCommitDataSource({required this.source, required this.registry});

  /// Existing CRUD transport.
  final BeakDataSource source;

  /// Metadata used to bind references and extract returned identities.
  final BeakModelRegistry registry;

  final Map<String, String> _plans = {};
  final Map<String, BeakSaveResult> _results = {};
  final Map<String, Future<BeakSaveResult>> _active = {};

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    final encoded = jsonEncode(plan.toJson());
    if (_plans[plan.saveId] case final String prior when prior != encoded) {
      throw const BeakConflictException(
        'Save identity was reused with different content.',
      );
    }
    plan.orderedOperations(registry);
    _plans[plan.saveId] = encoded;
    final affected = {
      for (final operation in plan.operations) operation.target.table,
    };
    bool dependsOnAffected(BeakModel model, List<BeakRelationLoad> loads) {
      for (final load in loads) {
        final relation = model.relationshipByKey(load.relationKey)!;
        if (affected.contains(relation.relatedTable) ||
            dependsOnAffected(
              registry.byTableOrThrow(relation.relatedTable),
              load.nested,
            )) {
          return true;
        }
      }
      return false;
    }

    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final model in registry.all) {
        if (dependsOnAffected(model, model.behavior.relationLoads) ||
            model.relationships.any(
              (relation) =>
                  affected.contains(relation.relatedTable) &&
                  (relation is BeakHasMany && relation.owned ||
                      relation is BeakHasOne && relation.owned),
            )) {
          if (affected.add(model.table)) expanded = true;
        }
      }
    }
    if (plan.action != null ||
        registry.all.any(
          (model) => affected.contains(model.table) && !model.behavior.isEmpty,
        )) {
      return _results[plan.saveId] = BeakSaveResult(
        saveId: plan.saveId,
        mode: BeakSaveMode.staged,
        outcomes: [
          for (final operation in plan.operations)
            BeakOperationResult(
              id: operation.id,
              status: BeakWriteOutcome.unapplied,
              reason: 'unsupportedBehavior',
              error: BeakSaveError(
                code: 'configuration',
                message:
                    'Model behaviors require an authoritative atomic graph provider.',
              ),
            ),
        ],
      );
    }
    if (_active[plan.saveId] case final Future<BeakSaveResult> running) {
      return running;
    }
    final future = executeBeakSavePlan(
      plan: plan,
      registry: registry,
      previous: _results[plan.saveId],
      run: (op, identities) => executeBeakSaveOperation(
        op,
        source: source,
        registry: registry,
        identities: identities,
      ),
      checkpoint: (result) async => _results[plan.saveId] = result,
    );
    _active[plan.saveId] = future;
    try {
      return _results[plan.saveId] = await future;
    } finally {
      unawaited(_active.remove(plan.saveId));
    }
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async =>
      _results[saveId] ??
      (throw BeakNotFoundException('No receipt for save "$saveId".'));
}

/// Executes an already validated operation against an ordinary CRUD provider.
///
/// The caller establishes authorization when used server-side. Exceptions
/// after dispatch do not imply that nothing was stored.
Future<BeakOperationResult> executeBeakSaveOperation(
  BeakSaveOperation op, {
  required BeakDataSource source,
  required BeakModelRegistry registry,
  required Map<String, Object> identities,
}) async {
  if (op.kind == BeakSaveOperationKind.delete && op.owner != null) {
    final relation = registry
        .byTableOrThrow(op.owner!.table)
        .relationshipByKey(op.relationKey!);
    final owned = switch (relation) {
      BeakHasMany(:final owned) || BeakHasOne(:final owned) => owned,
      _ => false,
    };
    if (!owned) {
      return BeakOperationResult(
        id: op.id,
        status: BeakWriteOutcome.unapplied,
        reason: 'rejected',
        error: BeakSaveError(
          code: 'validation',
          message: 'Only owned relationships may delete their rows.',
        ),
      );
    }
  }
  if (op.expectedUpdatedAt != null) {
    return BeakOperationResult(
      id: op.id,
      status: BeakWriteOutcome.unapplied,
      reason: 'rejected',
      error: BeakSaveError(
        code: 'configuration',
        message: 'This provider does not support conditional graph writes.',
      ),
    );
  }
  final values = op.resolveValues(registry, identities);
  BeakRecord? record;
  Object? resolvedId;
  switch (op.kind) {
    case BeakSaveOperationKind.create:
      record = await source.create(op.target.table, values);
      resolvedId = registry
          .byTableOrThrow(op.target.table)
          .primaryKeyOf(record);
      if (resolvedId == null) {
        throw const BeakConfigurationException(
          'Create returned no primary key.',
        );
      }
    case BeakSaveOperationKind.update:
      resolvedId = op.target.resolve(identities);
      record = await source.update(op.target.table, resolvedId, values);
    case BeakSaveOperationKind.delete:
      resolvedId = op.target.resolve(identities);
      await source.delete(op.target.table, resolvedId);
    case BeakSaveOperationKind.attach:
      resolvedId = op.target.resolve(identities);
      await source.attach(op.target.table, resolvedId, op.relationKey!, [
        op.related!.resolve(identities),
      ]);
    case BeakSaveOperationKind.detach:
      resolvedId = op.target.resolve(identities);
      await source.detach(op.target.table, resolvedId, op.relationKey!, [
        op.related!.resolve(identities),
      ]);
  }
  return BeakOperationResult(
    id: op.id,
    table: op.target.table,
    status: BeakWriteOutcome.applied,
    draftId: op.kind == BeakSaveOperationKind.create ? op.target.draftId : null,
    resolvedId: resolvedId,
    record: record,
  );
}
