part of 'beak_form_session.dart';

/// Review, persistence and conflict handling use the same live draft graph as
/// validation and submission. No second application state tree is required.
extension BeakFormDraftRuntime on BeakFormSession {
  /// Whether a compatible saved draft is available for explicit resumption.
  bool get hasStoredDraft => _storedDraft != null;

  /// Current unresolved conflicts. A save cannot proceed until each is resolved.
  List<BeakDraftConflict> get conflicts => List.unmodifiable(_conflicts.values);

  /// Informational storage or file-reselection notice, separate from save errors.
  String? get draftNotice => _draftNotice;

  /// Timestamp of the last successfully stored editable draft, or null before
  /// a write, after removal, or while a stored draft awaits explicit resumption.
  DateTime? get draftSavedAt => _draftSavedAt;

  /// Field changes and relationship operations in their visible graph order.
  List<BeakDraftChange> get reviewChanges {
    final result = <BeakDraftChange>[];
    void walk(BeakDraftRecord draft, String path) {
      for (final entry in draft.buildRecord().values.entries) {
        final column = draft.model.columnByKey(entry.key);
        if (column == null || draft.initialRecord[entry.key] == entry.value) {
          continue;
        }
        final secret = column.semantic.kind == BeakSemanticKind.password;
        result.add(
          BeakDraftChange(
            path: '$path.${entry.key}',
            label: switch (draft._placements
                .where(
                  (placement) =>
                      draft.visible(placement.node) &&
                      switch (placement.node) {
                        BeakInput<Object>(:final field) =>
                          field.key == entry.key,
                        BeakRelationInput(
                          field: BeakToOneField(
                            relation: BeakBelongsTo(:final foreignKey),
                          ),
                        ) =>
                          foreignKey == entry.key,
                        _ => false,
                      },
                )
                .map((placement) => placement.node)
                .firstOrNull) {
              BeakInput<Object>(:final label, :final labelBuilder) =>
                labelBuilder?.call(BeakFormReader(draft)) ??
                    label ??
                    column.label,
              BeakRelationInput(:final label) => label ?? column.label,
              _ => column.label,
            },
            column: column,
            kind: BeakDraftChangeKind.update,
            before: secret ? null : draft.initialRecord[entry.key],
            after: secret ? null : entry.value,
          ),
        );
      }
      for (final entry in draft._createdSelections.entries) {
        result.add(
          BeakDraftChange(
            path: '$path.${entry.key}',
            label: entry.value.model.table,
            kind: BeakDraftChangeKind.create,
          ),
        );
        walk(entry.value, '$path.${entry.key}');
      }
      for (final entry in draft._rows.entries) {
        for (final row in entry.value) {
          final rowPath = '$path.${entry.key}.${row.localId}';
          if (row.removed || row.id == null) {
            result.add(
              BeakDraftChange(
                path: rowPath,
                label: row._capabilities.canRead(row.model.displayColumnKey)
                    ? row.snapshot[row.model.displayColumnKey]?.raw
                              ?.toString() ??
                          row.model.table
                    : row.model.table,
                kind: row.removed
                    ? (row.deleteRemote
                          ? BeakDraftChangeKind.delete
                          : BeakDraftChangeKind.detach)
                    : BeakDraftChangeKind.create,
              ),
            );
          }
          if (!row.removed) walk(row, rowPath);
        }
      }
    }

    walk(root, model.table);
    for (final entry in _actionInputs.entries) {
      walk(entry.value.root, 'action:${entry.key}');
    }
    return List.unmodifiable(result);
  }

  /// Compact graph operations; fields inside a created row stay in full review.
  List<BeakDraftChange> get compactReviewChanges {
    final changes = reviewChanges;
    final created = changes
        .where((change) => change.kind == BeakDraftChangeKind.create)
        .map((change) => change.path)
        .toList();
    return List.unmodifiable(
      changes.where(
        (change) => !created.any((path) => change.path.startsWith('$path.')),
      ),
    );
  }

  /// Actual operation count used by compact unsaved-change chrome.
  int get reviewChangeCount => compactReviewChanges.length;

  /// Human labels from the same operations as the compact count.
  String get reviewChangeSummary => compactReviewChanges
      .map(
        (change) => switch (change.kind) {
          BeakDraftChangeKind.update => change.label,
          BeakDraftChangeKind.create => '${change.label} added',
          BeakDraftChangeKind.delete => '${change.label} deleted',
          BeakDraftChangeKind.detach => '${change.label} removed',
        },
      )
      .join(' · ');

  /// Explains active conditions, value origins, dependencies and validation.
  List<BeakFieldExplanation> explain() => [
    for (final draft in _allDrafts())
      for (final placement in draft._placements)
        if (_placementField(placement.node)
            case final BeakFieldRef<Object> field)
          BeakFieldExplanation(
            path: '${draft.localId}.${field.key}',
            label: field.label,
            visible: draft.visible(placement.node),
            enabled: draft.enabled(placement.node),
            origin:
                draft.model.behavior.values.any(
                  (value) => value.field.key == field.key,
                )
                ? '${draft.model.behavior.values.firstWhere((value) => value.field.key == field.key).lifecycle.name}${draft._manualOverrides.contains(field.key) ? ' (manually overridden)' : ''}'
                : draft._derivedReads.containsKey(field.key)
                ? 'Derived from tracked fields'
                : draft.initialRecord[field.key] == draft.snapshot[field.key]
                ? 'Persisted baseline'
                : 'Draft value',
            dependencies: [
              ...?draft._derivedReads[field.key],
              for (final value in draft.model.behavior.values)
                if (value.field.key == field.key)
                  for (final dependency in value.dependencies)
                    dependency.qualifiedKey,
              if (placement.node case final BeakRelationInput input)
                for (final rule in draft._eligibility(input))
                  for (final match in rule.matching) match.source.qualifiedKey,
            ],
            validation: [
              if (field case BeakScalarField<Object>(:final column))
                for (final rule in column.rules) rule.runtimeType.toString(),
              for (final rule in draft.model.validationRules)
                if (rule.fields.any((other) => other.key == field.key))
                  rule.runtimeType.toString(),
              ...?draft.errors[field.key],
            ],
          ),
  ];

  /// Flushes correctable local changes. In-flight submissions are stored
  /// separately with their receipt identity and can only be recovered.
  /// Returns whether this exact snapshot was stored (or its clean draft removed).
  Future<bool> persistDraft() {
    _draftTimer?.cancel();
    _draftTimer = null;
    final config = drafts;
    if (config == null ||
        !initialized ||
        !_checkedStoredDraft ||
        hasStoredDraft ||
        _restoringDraft ||
        hasUnknown ||
        submitting.value) {
      return Future.value(false);
    }
    final savedAt = DateTime.now().toUtc();
    final document = jsonEncode(_draftDocument(savedAt));
    final shouldWrite = isDirty;
    var persisted = false;
    _draftWrite = _draftWrite.then((_) async {
      try {
        final key = config.storageKey(model.table, recordId);
        if (shouldWrite) {
          await config.store.write(key, document);
        } else {
          await config.store.remove(key);
        }
        _draftSavedAt = shouldWrite ? savedAt : null;
        persisted = true;
        if (_draftNotice ==
            'The draft could not be stored. Your current edits remain available.') {
          _draftNotice = null;
        }
        _notify();
      } on Object {
        _draftNotice =
            'The draft could not be stored. Your current edits remain available.';
        _notify();
      }
    });
    return _draftWrite.then((_) => persisted);
  }

  Future<void> _readStoredDraft() async {
    final config = drafts;
    if (config == null || _checkedStoredDraft) return;
    _checkedStoredDraft = true;
    try {
      final document = await config.store.read(
        config.storageKey(model.table, recordId),
      );
      if (document == null || _disposed) return;
      final data = _draftMap(jsonDecode(document));
      final timestamp = data['savedAt'];
      final savedAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
      if (data['context'] == config.context && data['pending'] != null) {
        _restorePendingDraft(data);
        if (data['version'] != config.schemaVersion) {
          _draftNotice =
              'The form changed since submission. Checking the saved transaction before editing.';
        }
        await recover();
      } else if (data['version'] != config.schemaVersion ||
          data['context'] != config.context ||
          savedAt == null ||
          DateTime.now().difference(savedAt) > config.retention) {
        await config.store.remove(config.storageKey(model.table, recordId));
        _draftNotice = 'An expired or incompatible saved draft was discarded.';
      } else {
        _storedDraft = _draftMap(data['root']);
        _storedActionInputs = _draftMap(data['actionInputs']);
        _storedDraftSavedAt = savedAt;
      }
    } on Object {
      _draftNotice =
          'The saved draft could not be read. You can continue editing.';
    }
    _notify();
  }

  Map<String, Object?> _draftDocument(DateTime savedAt) => {
    'version': drafts!.schemaVersion,
    'context': drafts!.context,
    'savedAt': savedAt.toIso8601String(),
    'root': _captureDraft(root),
    'actionInputs': {
      for (final entry in _actionInputs.entries)
        entry.key: _safeDraftRecord(
          entry.value.model,
          entry.value.root.snapshot,
        ).toJson(),
    },
  };

  Future<void> _persistPendingDraft() async {
    final config = drafts;
    final plan = _pending;
    if (config == null || plan == null) return;
    _draftTimer?.cancel();
    await _draftWrite;
    final safePlan = plan.toJson()..remove('arguments');
    safePlan['operations'] = [
      for (final operation in plan.operations)
        {
          ...operation.toJson(),
          'values': _safeDraftRecord(
            registry.byTableOrThrow(operation.target.table),
            operation.values,
          ).toJson(),
        },
    ];
    // This snapshot is recovery metadata, never a replayable save request.
    try {
      await config.store.write(
        config.storageKey(model.table, recordId),
        jsonEncode({
          ..._draftDocument(DateTime.now().toUtc()),
          'pending': safePlan,
          'operationDrafts': {
            for (final entry in _operations.entries)
              entry.key: entry.value.localId,
          },
        }),
      );
    } on Object {
      throw const BeakStorageException(
        'The recovery snapshot could not be stored. Nothing was submitted.',
      );
    }
    _storedDraft = null;
  }

  void _restorePendingDraft(Map<String, Object?> document) {
    final plan = BeakSavePlan.fromJson(_draftMap(document['pending']));
    _pending = plan;
    _pendingSentHere = false;
    _committer = switch (repository.dataSource) {
      final BeakCommitDataSource capable => capable,
      _ => BeakStagedCommitDataSource(
        source: repository.dataSource,
        registry: registry,
      ),
    };
    _saveResult.value = BeakSaveResult(
      saveId: plan.saveId,
      mode: _committer!.commitCapabilities.atomicGraph
          ? BeakSaveMode.atomic
          : BeakSaveMode.staged,
      outcomes: [
        for (final operation in plan.operations)
          BeakOperationResult(
            id: operation.id,
            status: BeakWriteOutcome.unknown,
            reason: 'restoredPendingSave',
          ),
      ],
    );
    _restoringDraft = true;
    _restoredDraftIds.clear();
    try {
      _restoreFrozenDraft(root, _draftMap(document['root']));
      _restoreActionInputs(_draftMap(document['actionInputs']));
      _restoreDraftLinks(root, _draftMap(document['root']));
      _loaded = true;
      _operations.clear();
      for (final entry in _draftMap(document['operationDrafts']).entries) {
        if (_restoredDraftIds[entry.value] case final BeakDraftRecord draft) {
          _operations[entry.key] = draft;
        }
      }
      _storedDraft = null;
    } finally {
      _restoringDraft = false;
    }
    _notify();
  }

  void _restoreFrozenDraft(BeakDraftRecord draft, Map<String, Object?> stored) {
    final initial = BeakRecord.fromJson(_draftMap(stored['initial']));
    final current = BeakRecord.fromJson(_draftMap(stored['current']));
    draft._prefill(initial);
    for (final entry in current.values.entries) {
      final column = draft.model.columnByKey(entry.key);
      if (column == null || !draft.controller.hasFieldFor(column)) continue;
      draft.controller.setValue<Object>(
        column,
        column.semantic.tryDecode(entry.value) ?? entry.value.raw,
      );
    }
    draft._manualOverrides
      ..clear()
      ..addAll(_draftList(stored['overrides']).whereType<String>());
    draft.removed = stored['removed'] == true;
    draft.deleteRemote = stored['deleteRemote'] == true;
    draft._needsAttach = stored['attach'] == true;
    if (stored['localId'] case final String localId) {
      _restoredDraftIds[localId] = draft;
    }
    final rows = _draftMap(stored['rows']);
    final created = _draftMap(stored['created']);
    for (final placement in draft._placements) {
      switch (placement.node) {
        case BeakRelationTable(:final field):
          if (!identical(draft._table(field), placement.node)) continue;
          draft._rows[field.key] = [
            for (final row in _draftList(rows[field.key]))
              _frozenChild(
                draft,
                field.target,
                draft._rowLayout(field),
                _draftMap(row),
                field,
              ),
          ];
        case BeakRelationInput(:final field, :final createForm):
          if (created[field.key] case final Object child) {
            draft._createdSelections[field.key] = _frozenChild(
              null,
              field.target,
              createForm ??
                  relatedLayouts[field.target.table] ??
                  BeakFormLayout.fromModel(field.target, registry: registry),
              _draftMap(child),
              null,
            );
          } else if (current.relations[field.key]?.firstOrNull
              case final BeakRecord selected) {
            draft._selected[field.key] = selected;
          }
        default:
          break;
      }
    }
  }

  BeakDraftRecord _frozenChild(
    BeakDraftRecord? parent,
    BeakModel model,
    BeakFormLayout layout,
    Map<String, Object?> stored,
    BeakToManyField? relation,
  ) {
    final child = BeakDraftRecord._(
      this,
      model,
      layout,
      _nextId(),
      parent: parent,
      relation: relation,
    );
    _restoreFrozenDraft(child, stored);
    _queueCapabilities(child);
    return child;
  }

  Future<void> _persistSaveOutcome() async {
    if (drafts == null || _disposed) return;
    try {
      if (hasUnknown) {
        await _persistPendingDraft();
      } else if (_saveResult.value?.complete == true) {
        await discardStoredDraft();
      } else {
        await persistDraft();
      }
    } on Object {
      _draftNotice =
          'The save status could not be stored locally. Keep this form open until the result is known.';
      _notify();
    }
  }

  /// Resumes a saved draft against the newly loaded server baseline. Conflicting
  /// edits remain explicit; unrelated server changes are retained automatically.
  void resumeDraft() {
    final stored = _storedDraft;
    if (stored == null || submitting.value || hasUnknown) return;
    _restoringDraft = true;
    _restoredDraftIds.clear();
    try {
      _mergeDraft(root, stored);
      _restoreActionInputs(_storedActionInputs);
      _storedActionInputs = {};
      _restoreDraftLinks(root, stored);
      _storedDraft = null;
      _draftSavedAt = _storedDraftSavedAt;
      _storedDraftSavedAt = null;
    } on Object {
      _draftNotice = 'This saved draft is incompatible with the current form.';
    } finally {
      _restoringDraft = false;
    }
    _changed();
  }

  void _restoreActionInputs(Map<String, Object?> stored) {
    for (final entry in stored.entries) {
      final input = _actionInputs[entry.key];
      if (input == null) continue;
      final record = BeakRecord.fromJson(_draftMap(entry.value));
      for (final value in record.values.entries) {
        final column = input.model.columnByKey(value.key);
        if (column == null || !input.root.controller.hasFieldFor(column)) {
          continue;
        }
        input.root.controller.setValue<Object>(
          column,
          column.semantic.tryDecode(value.value) ?? value.value.raw,
        );
      }
    }
  }

  /// Removes a stored draft without changing the currently displayed values.
  Future<void> discardStoredDraft() async {
    if (hasUnknown || submitting.value) return;
    final config = drafts;
    _storedDraft = null;
    _storedDraftSavedAt = null;
    _draftTimer?.cancel();
    await _draftWrite;
    if (config != null) {
      try {
        await config.store.remove(config.storageKey(model.table, recordId));
        _draftSavedAt = null;
      } on Object {
        _draftNotice = 'The stored draft could not be removed.';
      }
    }
    _notify();
  }

  /// Whether a save is unknown because its receipt cannot be read again.
  ///
  /// That happens when a reload finds a pending save and the data source keeps
  /// receipts in memory only. The save may have been applied, so the form stays
  /// frozen until the user has checked and discards its edits with
  /// [discardChanges].
  bool get receiptLost =>
      hasUnknown &&
      _saveResult.value!.outcomes
          .where((outcome) => outcome.status == BeakWriteOutcome.unknown)
          .every((outcome) => outcome.reason == 'receiptLost');

  /// Whether the last receipt refused a write of an existing record as a
  /// conflict, most often because another editor saved first.
  ///
  /// Saving the same edits again would send the same stale version and be
  /// refused again, so the form offers [refreshForConflicts] instead.
  bool get refusedAsConflict =>
      root.id != null &&
      !hasUnknown &&
      (_saveResult.value?.outcomes.any(
            (outcome) =>
                outcome.status == BeakWriteOutcome.unapplied &&
                outcome.error?.code == const BeakConflictException('').code,
          ) ??
          false);

  /// Fetches the latest graph and rebases local edits with field-level conflicts.
  /// Useful after the server rejects a stale write or another view edits a record.
  ///
  /// A successful refresh replaces the earlier refusal: the receipt and the error
  /// described the version that was just replaced.
  Future<void> refreshForConflicts() async {
    if (root.id == null || submitting.value || hasUnknown) return;
    final stored = _captureDraft(root);
    _loading.value = true;
    final result = await repository.query(
      BeakQuerySpec(
        table: model.table,
        filter: BeakFieldFilter(
          column: model.primaryKey,
          operator: BeakOperator.eq,
          value: BeakValue.of(root.id),
        ),
        relationLoads: _mergeDraftLoads(
          _loadsFor(root.layout),
          model.behavior.relationLoads,
        ),
        pagination: const BeakPagination(perPage: 1),
      ),
    );
    if (_disposed) return;
    _restoringDraft = true;
    try {
      switch (result) {
        case BeakOk(:final value) when value.items.isNotEmpty:
          root._prefill(value.items.first);
          _conflicts.clear();
          _conflictResolutions.clear();
          _mergeDraft(root, stored);
          _error.value = null;
          _saveResult.value = null;
        case BeakOk():
          _error.value = const BeakNotFoundException(
            'The record no longer exists.',
          );
        case BeakErr(:final error):
          _error.value = error;
      }
    } finally {
      _restoringDraft = false;
      _loading.value = false;
    }
    _changed();
  }

  /// Chooses one side of a conflict, then runs normal derivations and validation.
  void resolveConflict(String path, {required bool useRemote}) {
    final resolve = _conflictResolutions.remove(path);
    if (resolve == null) {
      throw ArgumentError.value(path, 'path', 'Unknown conflict');
    }
    resolve(useRemote);
    _conflicts.remove(path);
    for (final draft in _allDrafts()) {
      if (!_conflicts.keys.any((key) => key.startsWith('${draft.localId}.'))) {
        draft._conflictBaseline = null;
      }
    }
    _changed();
  }

  Map<String, Object?> _captureDraft(BeakDraftRecord draft) => {
    'localId': draft.localId,
    'initial': _safeDraftRecord(
      draft.model,
      draft._conflictBaseline ?? draft.initialRecord,
    ).toJson(),
    'current': _safeDraftRecord(draft.model, draft.snapshot).toJson(),
    'removed': draft.removed,
    'deleteRemote': draft.deleteRemote,
    'attach': draft._needsAttach,
    'overrides': draft._manualOverrides.toList(),
    'rows': {
      for (final entry in draft._rows.entries)
        entry.key: [for (final row in entry.value) _captureDraft(row)],
    },
    'links': {
      for (final entry in draft._linkedReferences.entries)
        entry.key: entry.value.localId,
    },
    'created': {
      for (final entry in draft._createdSelections.entries)
        entry.key: _captureDraft(entry.value),
    },
  };

  void _restoreDraftLinks(BeakDraftRecord draft, Map<String, Object?> stored) {
    for (final entry in _draftMap(stored['links']).entries) {
      final target = _restoredDraftIds[entry.value];
      if (target == null) {
        throw const BeakConfigurationException(
          'The related local draft is missing.',
        );
      }
      draft._linkReference(entry.key, target);
    }
    final created = _draftMap(stored['created']);
    for (final entry in draft._createdSelections.entries) {
      if (created[entry.key] case final Object child) {
        _restoreDraftLinks(entry.value, _draftMap(child));
      }
    }
    final rows = _draftMap(stored['rows']);
    for (final entry in rows.entries) {
      for (final row in _draftList(entry.value)) {
        final data = _draftMap(row);
        if (_restoredDraftIds[data['localId']]
            case final BeakDraftRecord child) {
          _restoreDraftLinks(child, data);
        }
      }
    }
  }

  BeakRecord _safeDraftRecord(BeakModel model, BeakRecord record) => BeakRecord(
    values: {
      for (final entry in record.values.entries)
        if (model.columnByKey(entry.key)?.semantic.kind !=
            BeakSemanticKind.password)
          entry.key:
              entry.value.raw is String &&
                  '${entry.value.raw}'.startsWith('beak-draft:')
              ? const BeakNullValue()
              : entry.value,
    },
    relations: {
      for (final entry in record.relations.entries)
        if (registry.byTable(
              model.relationshipByKey(entry.key)?.relatedTable ?? '',
            )
            case final BeakModel target)
          entry.key: [
            for (final row in entry.value) _safeDraftRecord(target, row),
          ],
    },
  );

  void _mergeDraft(BeakDraftRecord draft, Map<String, Object?> stored) {
    if (stored['localId'] case final String localId) {
      _restoredDraftIds[localId] = draft;
    }
    final initial = BeakRecord.fromJson(_draftMap(stored['initial']));
    final local = BeakRecord.fromJson(_draftMap(stored['current']));
    final remote = draft.initialRecord;
    if (stored['overrides'] case final List<Object?> fields) {
      draft._manualOverrides.addAll(fields.whereType<String>());
    }
    for (final entry in local.values.entries) {
      final column = draft.model.columnByKey(entry.key);
      if (column == null ||
          !draft.controller.hasFieldFor(column) ||
          column.semantic.kind == BeakSemanticKind.password ||
          initial[entry.key] == entry.value) {
        continue;
      }
      final value = entry.value;
      void apply(BeakValue? chosen) => draft.controller.setValue<Object>(
        column,
        chosen == null ? null : column.semantic.tryDecode(chosen) ?? chosen.raw,
      );
      apply(value);
      if (draft.id != null &&
          remote[entry.key] != initial[entry.key] &&
          remote[entry.key] != value) {
        final path = '${draft.localId}.${entry.key}';
        draft._conflictBaseline = initial;
        _conflicts[path] = BeakDraftConflict(
          path: path,
          label: column.label,
          column: column,
          original: initial[entry.key],
          local: value,
          remote: remote[entry.key],
        );
        _conflictResolutions[path] = (useRemote) {
          apply(useRemote ? remote[entry.key] : value);
          for (final input
              in draft._placements
                  .map((p) => p.node)
                  .whereType<BeakRelationInput>()) {
            if (input.field.relation case BeakBelongsTo(:final foreignKey)) {
              if (foreignKey == entry.key) {
                final selected = (useRemote ? remote : local)
                    .relations[input.field.key]
                    ?.firstOrNull;
                if (selected == null) {
                  draft._selected.remove(input.field.key);
                } else {
                  draft._selected[input.field.key] = selected;
                }
              }
            }
          }
        };
      }
    }
    draft._needsAttach = stored['attach'] == true;
    final storedRows = _draftMap(stored['rows']);
    for (final table
        in draft._placements
            .map((p) => p.node)
            .whereType<BeakRelationTable>()) {
      if (!identical(draft._table(table.field), table)) continue;
      final entries = storedRows[table.field.key];
      if (entries is! List<Object?>) continue;
      final rows = draft._rows.putIfAbsent(table.field.key, () => []);
      for (final entry in entries) {
        final data = _draftMap(entry);
        final baseline = BeakRecord.fromJson(_draftMap(data['initial']));
        final current = BeakRecord.fromJson(_draftMap(data['current']));
        final id = table.field.target.primaryKeyOf(baseline);
        var row = id == null ? null : rows.where((r) => r.id == id).firstOrNull;
        if (id != null && row == null && data['removed'] == true) continue;
        if (id != null && row == null && baseline == current) continue;
        final missing = id != null && row == null;
        row ??= BeakDraftRecord._(
          this,
          table.field.target,
          draft._rowLayout(table.field),
          _nextId(),
          parent: draft,
          relation: table.field,
        );
        if (!rows.contains(row)) {
          rows.add(row);
          _queueCapabilities(row);
        }
        _mergeDraft(row, data);
        row.removed = data['removed'] == true;
        row.deleteRemote = data['deleteRemote'] == true;
        if (missing) {
          row._conflictBaseline = baseline;
          final path = '${row.localId}.membership';
          final orphan = row;
          _conflicts[path] = BeakDraftConflict(
            path: path,
            label:
                '${row.model.table} was removed remotely. Keep as a new record or discard it.',
            original: BeakValue.of(id),
            local: BeakValue.of('Recreate'),
            remote: const BeakNullValue(),
          );
          _conflictResolutions[path] = (useRemote) {
            if (useRemote) rows.remove(orphan);
          };
        } else if (row.removed && baseline != row.initialRecord) {
          row._conflictBaseline = baseline;
          final path = '${row.localId}.membership';
          final removed = row;
          _conflicts[path] = BeakDraftConflict(
            path: path,
            label: '${row.model.table} changed before removal.',
            original: BeakValue.of(id),
            local: const BeakNullValue(),
            remote: BeakValue.of(id),
          );
          _conflictResolutions[path] = (useRemote) {
            removed.removed = !useRemote;
          };
        }
      }
    }
    final created = _draftMap(stored['created']);
    for (final input
        in draft._placements
            .map((p) => p.node)
            .whereType<BeakRelationInput>()) {
      if (created[input.field.key] case final Object data) {
        final child = BeakDraftRecord._(
          this,
          input.field.target,
          input.createForm ??
              relatedLayouts[input.field.target.table] ??
              BeakFormLayout.fromModel(input.field.target, registry: registry),
          _nextId(),
        );
        _mergeDraft(child, _draftMap(data));
        draft._createdSelections[input.field.key] = child;
        _queueCapabilities(child);
        draft._selected.remove(input.field.key);
      } else {
        final selected = local.relations[input.field.key]?.firstOrNull;
        if (selected != null) {
          if (input.field.relation case BeakBelongsTo(:final foreignKey)) {
            if (local[foreignKey] != initial[foreignKey]) {
              draft._selected[input.field.key] = selected;
            }
          }
        }
      }
    }
    if (local.values.values.any((v) => v is BeakNullValue) &&
        draft.model.columns.any((c) => c is BeakUploadColumn)) {
      _draftNotice =
          'Resumed draft. Select any uncommitted files again; file bytes and passwords are not stored.';
    }
  }
}

BeakFieldRef<Object>? _placementField(BeakFormNode node) => switch (node) {
  BeakInput<Object>(:final field) => field,
  BeakRelationInput(:final field) => field,
  BeakRelationTable(:final field) => field,
  _ => null,
};

List<Object?> _draftList(Object? value) => switch (value) {
  null => const [],
  final List<Object?> list => list,
  _ => throw const FormatException('Invalid draft document'),
};

Map<String, Object?> _draftMap(Object? value) => switch (value) {
  final Map<String, Object?> map => map,
  _ => throw const FormatException('Invalid draft document'),
};
