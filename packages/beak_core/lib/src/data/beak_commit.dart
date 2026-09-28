import '../common/beak_exception.dart';
import '../common/json_support.dart';
import '../model/beak_model_registry.dart';
import '../query/beak_record.dart';
import '../query/beak_value.dart';
import '../relations/beak_relationship.dart';

/// A backend's independent guarantees for a submitted change graph.
final class BeakCommitCapabilities {
  /// Describes guarantees; ordinary CRUD alone implies none of them.
  const BeakCommitCapabilities({
    this.atomicGraph = false,
    this.durableReceipts = false,
    this.idempotentReplay = false,
    this.conditionalWrites = false,
  });

  /// All writes and their receipt commit together.
  final bool atomicGraph;

  /// Recovery survives a backend restart.
  final bool durableReceipts;

  /// Resubmitting the same save identity cannot duplicate writes.
  final bool idempotentReplay;

  /// Expected versions are checked within mutations.
  final bool conditionalWrites;
}

/// Optional transport capability for saving a declarative record graph.
abstract interface class BeakCommitDataSource {
  /// Guarantees this source actually implements.
  BeakCommitCapabilities get commitCapabilities;

  /// Saves, or resumes, the immutable plan identified by its save id.
  Future<BeakSaveResult> commit(BeakSavePlan plan);

  /// Reads a previous save's receipt without repeating any mutation.
  Future<BeakSaveResult> recover(String saveId);
}

/// A saved identity or a local identity resolved by an earlier create.
final class BeakRecordRef {
  /// Addresses an existing record.
  const BeakRecordRef.existing(this.table, Object this.id) : draftId = null;

  /// Addresses a not-yet-persisted record within the save plan.
  const BeakRecordRef.draft(this.table, String this.draftId) : id = null;

  /// Resource identity.
  final String table;

  /// Existing primary key, when present.
  final Object? id;

  /// Stable local identity, unique within a plan.
  final String? draftId;

  @override
  bool operator ==(Object other) =>
      other is BeakRecordRef &&
      table == other.table &&
      id == other.id &&
      draftId == other.draftId;

  @override
  int get hashCode => Object.hash(table, id, draftId);

  /// Resolves this reference, refusing an unconfirmed dependency.
  Object resolve(Map<String, Object> identities) =>
      id ??
      identities[draftId] ??
      (throw BeakConfigurationException('Unresolved draft "$draftId".'));

  /// Wire representation.
  Map<String, Object?> toJson() => {
    'table': table,
    if (id != null) 'id': id,
    if (draftId != null) 'draftId': draftId,
  };

  /// Strictly decodes a saved or local identity.
  factory BeakRecordRef.fromJson(Map<String, Object?> json) {
    final table = requireJsonString(json, 'table', 'BeakRecordRef');
    if (table.isEmpty) {
      throw const BeakConfigurationException('A reference needs a table.');
    }
    if (json['draftId'] case final String draftId
        when draftId.isNotEmpty && json['id'] == null) {
      return BeakRecordRef.draft(table, draftId);
    }
    if (json['draftId'] == null) {
      final id = json['id'];
      if (id is int || (id is String && id.isNotEmpty)) {
        return BeakRecordRef.existing(table, id!);
      }
    }
    throw const BeakConfigurationException('Invalid record reference.');
  }
}

/// An individual, auditable write.
enum BeakSaveOperationKind {
  /// Insert a draft.
  create,

  /// Patch an existing record.
  update,

  /// Delete a record using its configured soft-delete behavior.
  delete,

  /// Link one existing or newly created record.
  attach,

  /// Remove a link without deleting its target.
  detach,
}

/// One immutable operation; relation references are resolved just before writing.
final class BeakSaveOperation {
  /// Builds a write. [owner] and [relationKey] identify nested row ownership.
  BeakSaveOperation({
    required this.id,
    required this.kind,
    required this.target,
    BeakRecord? values,
    Map<String, BeakRecordRef> references = const {},
    List<String> dependsOn = const [],
    this.owner,
    this.relationKey,
    this.related,
    this.expectedUpdatedAt,
  }) : values = _snapshot(values ?? const BeakRecord(values: {})),
       references = Map.unmodifiable(references),
       dependsOn = List.unmodifiable(dependsOn);

  /// Stable operation identity within this plan.
  final String id;

  /// Write kind.
  final BeakSaveOperationKind kind;

  /// Record receiving the write.
  final BeakRecordRef target;

  /// Scalar values; foreign references are represented separately.
  final BeakRecord values;

  /// Foreign-key column to referenced record.
  final Map<String, BeakRecordRef> references;

  /// Explicit ordering in addition to inferred draft dependencies.
  final List<String> dependsOn;

  /// Owner of a nested row; never inferred from client-supplied scalar keys.
  final BeakRecordRef? owner;

  /// Owner's relationship key, or link operation's relationship key.
  final String? relationKey;

  /// The single other endpoint of attach/detach.
  final BeakRecordRef? related;

  /// Optional write precondition; unsupported providers must reject it.
  final DateTime? expectedUpdatedAt;

  /// Resolves supplied foreign references and an owned row's foreign key.
  BeakRecord resolveValues(
    BeakModelRegistry registry,
    Map<String, Object> identities,
  ) {
    final resolved = {...values.values};
    for (final entry in references.entries) {
      resolved[entry.key] = BeakValue.of(entry.value.resolve(identities));
    }
    if (owner case final BeakRecordRef parent) {
      final relation = registry
          .byTableOrThrow(parent.table)
          .relationshipByKey(relationKey!);
      final foreignKey = switch (relation) {
        BeakHasMany(:final foreignKey) => foreignKey,
        BeakHasOne(:final foreignKey) => foreignKey,
        _ => null,
      };
      if (foreignKey != null && kind == BeakSaveOperationKind.create) {
        resolved[foreignKey] = BeakValue.of(parent.resolve(identities));
      }
    }
    return BeakRecord(values: resolved);
  }

  /// All references whose create operations precede this operation.
  Iterable<BeakRecordRef> get requiredReferences sync* {
    if (kind != BeakSaveOperationKind.create) yield target;
    yield* references.values;
    if (owner != null) yield owner!;
    if (related != null) yield related!;
  }

  /// Wire representation.
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'target': target.toJson(),
    'values': values.toJson(),
    'references': {
      for (final entry in references.entries) entry.key: entry.value.toJson(),
    },
    'dependsOn': dependsOn,
    if (owner != null) 'owner': owner!.toJson(),
    if (relationKey != null) 'relationKey': relationKey,
    if (related != null) 'related': related!.toJson(),
    if (expectedUpdatedAt != null)
      'expectedUpdatedAt': expectedUpdatedAt!.toUtc().toIso8601String(),
  };

  /// Decodes a write, rejecting malformed nested data.
  factory BeakSaveOperation.fromJson(Map<String, Object?> json) {
    const context = 'BeakSaveOperation';
    final kind = BeakSaveOperationKind.values
        .asNameMap()[requireJsonString(json, 'kind', context)];
    if (kind == null) {
      throw const BeakConfigurationException('Unknown save operation.');
    }
    final refs = optionalJsonMap(json, 'references', context) ?? const {};
    final dependencies = json['dependsOn'] ?? const <Object?>[];
    if (dependencies is! List<Object?> ||
        dependencies.any((value) => value is! String)) {
      throw const BeakConfigurationException('Invalid save dependencies.');
    }
    BeakRecordRef? reference(String key) {
      final map = optionalJsonMap(json, key, context);
      return map == null ? null : BeakRecordRef.fromJson(map);
    }

    final timestamp = json['expectedUpdatedAt'];
    final expected = timestamp is String ? DateTime.tryParse(timestamp) : null;
    if (timestamp != null && expected == null) {
      throw const BeakConfigurationException('Invalid expected timestamp.');
    }
    return BeakSaveOperation(
      id: requireJsonString(json, 'id', context),
      kind: kind,
      target: BeakRecordRef.fromJson(requireJsonMap(json, 'target', context)),
      values: BeakRecord.fromJson(requireJsonMap(json, 'values', context)),
      references: {
        for (final entry in refs.entries)
          entry.key: BeakRecordRef.fromJson(
            requireJsonMap(refs, entry.key, context),
          ),
      },
      dependsOn: dependencies.cast<String>(),
      owner: reference('owner'),
      relationKey: json['relationKey'] == null
          ? null
          : requireJsonString(json, 'relationKey', context),
      related: reference('related'),
      expectedUpdatedAt: expected,
    );
  }
}

/// The immutable snapshot submitted when a form finishes.
final class BeakSavePlan {
  /// Captures the complete operation list.
  BeakSavePlan({
    required this.saveId,
    required this.root,
    required List<BeakSaveOperation> operations,
    this.action,
    BeakRecord arguments = const BeakRecord(values: {}),
  }) : operations = List.unmodifiable(operations),
       arguments = _snapshot(arguments);

  /// Stable retry identity.
  final String saveId;

  /// The form's root record.
  final BeakRecordRef root;

  /// Declared writes.
  final List<BeakSaveOperation> operations;

  /// Optional named command executed on the root in the same transaction.
  final String? action;

  /// Typed inputs validated against the named command input model.
  final BeakRecord arguments;

  /// Validates model references and returns a stable topological ordering.
  List<BeakSaveOperation> orderedOperations(BeakModelRegistry registry) {
    if (saveId.isEmpty ||
        saveId.length > 200 ||
        operations.length > 1000 ||
        (action != null &&
            (action!.isEmpty || action!.length > 200 || operations.isEmpty))) {
      throw const BeakConfigurationException('Invalid or oversized save plan.');
    }
    registry.byTableOrThrow(root.table);
    final byId = <String, BeakSaveOperation>{};
    final creates = <String, BeakSaveOperation>{};
    for (final op in operations) {
      final model = registry.byTableOrThrow(op.target.table);
      if (op.id.isEmpty || byId.containsKey(op.id)) {
        throw const BeakConfigurationException(
          'Duplicate or empty operation id.',
        );
      }
      byId[op.id] = op;
      if (op.kind == BeakSaveOperationKind.create) {
        final draft = op.target.draftId;
        if (draft == null || creates.containsKey(draft)) {
          throw const BeakConfigurationException(
            'Create needs a unique draft id.',
          );
        }
        creates[draft] = op;
      }
      for (final key in [...op.values.values.keys, ...op.references.keys]) {
        if (model.columnByKey(key) == null) {
          throw BeakConfigurationException('Unknown field "$key".');
        }
      }
      if (op.owner != null && op.relationKey == null) {
        throw const BeakConfigurationException(
          'Owned writes need a relationship.',
        );
      }
      if ((op.kind == BeakSaveOperationKind.attach ||
              op.kind == BeakSaveOperationKind.detach) &&
          (op.relationKey == null || op.related == null)) {
        throw const BeakConfigurationException(
          'Link writes need both endpoints.',
        );
      }
      if (op.relationKey != null) {
        final parent = op.owner ?? op.target;
        final relation = registry
            .byTableOrThrow(parent.table)
            .relationshipByKey(op.relationKey!);
        final child = op.owner == null ? op.related : op.target;
        if (relation == null || child?.table != relation.relatedTable) {
          throw const BeakConfigurationException('Invalid relationship write.');
        }
      }
    }
    if (root.draftId != null && creates[root.draftId] == null) {
      throw const BeakConfigurationException('Root draft has no create.');
    }
    final ordered = <BeakSaveOperation>[];
    final visiting = <String>{};
    final visited = <String>{};
    void visit(BeakSaveOperation op) {
      if (visited.contains(op.id)) return;
      if (!visiting.add(op.id)) {
        throw const BeakConfigurationException('Cyclic save dependencies.');
      }
      final dependencies = <String>{...op.dependsOn};
      for (final ref in op.requiredReferences) {
        registry.byTableOrThrow(ref.table);
        if (ref.draftId case final String draft) {
          final create = creates[draft];
          if (create == null || create.target.table != ref.table) {
            throw BeakConfigurationException('Unknown draft "$draft".');
          }
          dependencies.add(create.id);
        }
      }
      for (final id in dependencies) {
        final dependency = byId[id];
        if (dependency == null) {
          throw BeakConfigurationException('Unknown dependency "$id".');
        }
        visit(dependency);
      }
      visiting.remove(op.id);
      visited.add(op.id);
      ordered.add(op);
    }

    for (final op in operations) {
      visit(op);
    }
    return ordered;
  }

  /// Wire representation.
  Map<String, Object?> toJson() => {
    'saveId': saveId,
    'root': root.toJson(),
    'operations': [for (final op in operations) op.toJson()],
    if (action != null) 'action': action,
    if (arguments.values.isNotEmpty || arguments.relations.isNotEmpty)
      'arguments': arguments.toJson(),
  };

  /// Strict wire decoder.
  factory BeakSavePlan.fromJson(Map<String, Object?> json) => BeakSavePlan(
    saveId: requireJsonString(json, 'saveId', 'BeakSavePlan'),
    root: BeakRecordRef.fromJson(requireJsonMap(json, 'root', 'BeakSavePlan')),
    action: json['action'] == null
        ? null
        : requireJsonString(json, 'action', 'BeakSavePlan'),
    arguments: json['arguments'] == null
        ? const BeakRecord(values: {})
        : BeakRecord.fromJson(
            requireJsonMap(json, 'arguments', 'BeakSavePlan'),
          ),
    operations: [
      for (final op in requireJsonMapList(
        json['operations'],
        'operations',
        'BeakSavePlan',
      ))
        BeakSaveOperation.fromJson(op),
    ],
  );
}

/// Whether a write is confirmed saved, confirmed unsaved, or unresolved.
enum BeakWriteOutcome {
  /// The write completed.
  applied,

  /// The write did not take place.
  unapplied,

  /// The provider cannot yet prove whether it took place.
  unknown,
}

/// The actual execution guarantee of a save.
enum BeakSaveMode {
  /// All changes committed together.
  atomic,

  /// Changes committed individually.
  staged,
}

/// A serializable failure associated with an operation.
final class BeakSaveError {
  /// Captures a safe error message and nested field errors.
  BeakSaveError({
    required this.code,
    required this.message,
    Map<String, List<String>> fieldErrors = const {},
  }) : fieldErrors = Map.unmodifiable({
         for (final entry in fieldErrors.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  /// Stable failure category.
  final String code;

  /// User-facing explanation.
  final String message;

  /// Field validation messages.
  final Map<String, List<String>> fieldErrors;

  /// Preserves recognized Beak failures without exposing arbitrary exceptions.
  factory BeakSaveError.fromException(Object error) => switch (error) {
    BeakValidationException(:final code, :final message, :final fieldErrors) =>
      BeakSaveError(code: code, message: message, fieldErrors: fieldErrors),
    BeakException(:final code, :final message) => BeakSaveError(
      code: code,
      message: message,
    ),
    _ => BeakSaveError(
      code: 'unknown',
      message: 'The write outcome could not be confirmed.',
    ),
  };

  /// Wire representation.
  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'fieldErrors': fieldErrors,
  };

  /// Decodes a safe failure.
  factory BeakSaveError.fromJson(Map<String, Object?> json) {
    final fields =
        optionalJsonMap(json, 'fieldErrors', 'BeakSaveError') ?? const {};
    final errors = <String, List<String>>{};
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value is! List<Object?> || value.any((item) => item is! String)) {
        throw const BeakConfigurationException('Malformed field errors.');
      }
      errors[entry.key] = value.cast<String>();
    }
    return BeakSaveError(
      code: requireJsonString(json, 'code', 'BeakSaveError'),
      message: requireJsonString(json, 'message', 'BeakSaveError'),
      fieldErrors: errors,
    );
  }
}

/// Receipt for a single operation.
final class BeakOperationResult {
  /// Captures a known or uncertain outcome.
  BeakOperationResult({
    required this.id,
    required this.status,
    this.draftId,
    this.resolvedId,
    this.table,
    BeakRecord? record,
    this.error,
    this.reason,
  }) : record = record == null ? null : _snapshot(record);

  /// Operation identity.
  final String id;

  /// Confirmed or uncertain write status.
  final BeakWriteOutcome status;

  /// Created draft identity.
  final String? draftId;

  /// Canonical persisted primary key.
  final Object? resolvedId;

  /// Written model, including operations added by authoritative preparation.
  final String? table;

  /// Canonical server data when available.
  final BeakRecord? record;

  /// Failure that stopped this operation.
  final BeakSaveError? error;

  /// Reason an operation was not applied.
  final String? reason;

  /// Wire representation.
  Map<String, Object?> toJson() => {
    'id': id,
    'status': status.name,
    if (draftId != null) 'draftId': draftId,
    if (resolvedId != null) 'resolvedId': resolvedId,
    if (table != null) 'table': table,
    if (record != null) 'record': record!.toJson(),
    if (error != null) 'error': error!.toJson(),
    if (reason != null) 'reason': reason,
  };

  /// Decodes a receipt.
  factory BeakOperationResult.fromJson(Map<String, Object?> json) {
    const context = 'BeakOperationResult';
    final status = BeakWriteOutcome.values
        .asNameMap()[requireJsonString(json, 'status', context)];
    if (status == null) {
      throw const BeakConfigurationException('Invalid write outcome.');
    }
    final record = optionalJsonMap(json, 'record', context);
    final error = optionalJsonMap(json, 'error', context);
    final resolvedId = json['resolvedId'];
    if (resolvedId != null && resolvedId is! String && resolvedId is! int) {
      throw const BeakConfigurationException('Invalid resolved identity.');
    }
    return BeakOperationResult(
      id: requireJsonString(json, 'id', context),
      status: status,
      draftId: json['draftId'] == null
          ? null
          : requireJsonString(json, 'draftId', context),
      resolvedId: resolvedId,
      table: json['table'] == null
          ? null
          : requireJsonString(json, 'table', context),
      record: record == null ? null : BeakRecord.fromJson(record),
      error: error == null ? null : BeakSaveError.fromJson(error),
      reason: json['reason'] == null
          ? null
          : requireJsonString(json, 'reason', context),
    );
  }
}

/// Full receipt: partial success never looks like rollback or completion.
final class BeakSaveResult {
  /// Captures the actual execution mode and every operation outcome.
  BeakSaveResult({
    required this.saveId,
    required this.mode,
    required List<BeakOperationResult> outcomes,
    this.rootOperationId,
  }) : outcomes = List.unmodifiable(outcomes);

  /// Stable retry/recovery identity.
  final String saveId;

  /// Execution guarantee.
  final BeakSaveMode mode;

  /// Per-operation receipts in execution order.
  final List<BeakOperationResult> outcomes;

  /// Operation whose canonical data represents the form root.
  final String? rootOperationId;

  /// True only when every requested operation is confirmed applied.
  bool get complete =>
      outcomes.every((entry) => entry.status == BeakWriteOutcome.applied);

  /// Whether an unresolved write blocks safe replay.
  bool get hasUnknown =>
      outcomes.any((entry) => entry.status == BeakWriteOutcome.unknown);

  /// Local identities resolved only by confirmed writes.
  Map<String, Object> get identities => Map.unmodifiable({
    for (final result in outcomes)
      if (result.status == BeakWriteOutcome.applied &&
          result.draftId != null &&
          result.resolvedId != null)
        result.draftId: result.resolvedId,
  });

  /// Latest canonical root record in this receipt.
  BeakRecord? get rootRecord => outcomes
      .where(
        (entry) =>
            entry.id == rootOperationId &&
            entry.status == BeakWriteOutcome.applied,
      )
      .firstOrNull
      ?.record;

  /// Wire representation.
  Map<String, Object?> toJson() => {
    'saveId': saveId,
    'mode': mode.name,
    'outcomes': [for (final result in outcomes) result.toJson()],
    if (rootOperationId != null) 'rootOperationId': rootOperationId,
  };

  /// Strict wire decoder.
  factory BeakSaveResult.fromJson(Map<String, Object?> json) {
    const context = 'BeakSaveResult';
    final mode = BeakSaveMode.values
        .asNameMap()[requireJsonString(json, 'mode', context)];
    if (mode == null) {
      throw const BeakConfigurationException('Invalid save mode.');
    }
    return BeakSaveResult(
      saveId: requireJsonString(json, 'saveId', context),
      mode: mode,
      outcomes: [
        for (final entry in requireJsonMapList(
          json['outcomes'],
          'outcomes',
          context,
        ))
          BeakOperationResult.fromJson(entry),
      ],
      rootOperationId: json['rootOperationId'] == null
          ? null
          : requireJsonString(json, 'rootOperationId', context),
    );
  }
}

BeakRecord _snapshot(BeakRecord record) => BeakRecord(
  values: Map.unmodifiable({
    for (final entry in record.values.entries)
      entry.key: _freezeValue(entry.value),
  }),
  relations: Map.unmodifiable({
    for (final entry in record.relations.entries)
      entry.key: List<BeakRecord>.unmodifiable(entry.value.map(_snapshot)),
  }),
);

BeakValue _freezeValue(BeakValue value) => switch (value) {
  BeakListValue(:final values) => BeakListValue(
    List<BeakValue>.unmodifiable(values.map(_freezeValue)),
  ),
  _ => value,
};
