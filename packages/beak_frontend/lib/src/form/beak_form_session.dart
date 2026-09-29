import 'dart:async';
import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../data/beak_resource_repository.dart';
import '../data/beak_relation_loads.dart';
import '../data/beak_data_changes.dart';
import '../data/beak_form_commit_repository.dart';
import 'beak_form_controller_builder.dart';
import 'beak_form_layout.dart';
import '../presentation/beak_record_template.dart';
import 'upload_field.dart';
import 'beak_draft_uploads.dart';
import 'beak_form_drafts.dart';

part 'beak_form_draft_runtime.dart';

/// Typed, read-only access used by conditions, validators and calculations.
class BeakFormReader implements BeakDraftReader {
  /// Creates a tracked reader over a local record draft.
  BeakFormReader(this.draft);

  /// Record whose typed values this reader observes.
  final BeakDraftRecord draft;

  /// The current zero-based wizard step, or zero for a single-page form.
  int get stepIndex => draft.session.currentStep;

  /// Field paths accessed by this reader, used for dependency tracking.
  final Set<String> reads = {};

  /// The enclosing row owner, when this reader belongs to a related row.
  BeakFormReader? get parent =>
      draft.parent == null ? null : BeakFormReader(draft.parent!);

  /// The root record of this form.
  BeakFormReader get root => BeakFormReader(draft.session.root);

  @override
  T? read<T extends Object>(BeakFieldRef<T> field) {
    if (field.model.table != draft.model.table) {
      throw BeakConfigurationException(
        'Field ${field.qualifiedKey} does not belong to ${draft.model.table}.',
      );
    }
    reads.add(field.qualifiedKey);
    return field.readFrom(draft.snapshot);
  }

  /// Related row readers, tracked together with collection membership.
  List<BeakFormReader> rows(BeakToManyField field) {
    reads.add(field.qualifiedKey);
    return [for (final row in draft.rows(field)) BeakFormReader(row)];
  }
}

final class _Placement {
  _Placement(this.node, this.conditions, this.editConditions);
  final BeakFormNode node;
  final List<BeakVisibility> conditions;
  final List<BeakVisibility> editConditions;
  bool enabled(BeakFormReader reader) =>
      editConditions.every((test) => test(reader));
  bool visible(BeakFormReader reader) =>
      conditions.every((test) => test(reader));
}

/// One local record in the form graph. It never persists itself.
class BeakDraftRecord implements BeakDraftReader {
  BeakDraftRecord._(
    this.session,
    this.model,
    this.layout,
    this.localId, {
    this.parent,
    this.relation,
  }) {
    _compile(layout, const [], const []);
    final columns = <String, BeakColumn>{};
    for (final placement in _placements) {
      switch (placement.node) {
        case BeakInput<Object>(:final field):
          columns[field.column.key] = field.column;
        case BeakRelationInput(:final field):
          if (field.relation case BeakBelongsTo(:final foreignKey)) {
            final column = model.columnByKey(foreignKey);
            if (column != null) columns[column.key] = column;
          }
        default:
          break;
      }
    }
    for (final behavior in model.behavior.values) {
      columns[behavior.field.key] = behavior.field.column;
    }
    controller = BeakFormController(
      model: model,
      sections: [BeakFormSection(title: '', columns: columns.values.toList())],
      valueMode: session.valueMode,
    );
    controller.addListener(_changed);
    session._ownedDrafts.add(this);
  }

  /// Session owning this record and all nested changes.
  final BeakFormSession session;

  /// Model metadata defining fields, rules and relationships.
  final BeakModel model;

  /// Reusable layout declaring the visible inputs and sections.
  final BeakFormLayout layout;

  /// Stable session-local identity retained until the draft is disposed.
  final String localId;

  /// Owning record when this draft is a related row.
  final BeakDraftRecord? parent;

  /// Relationship through which this row belongs to its owner.
  final BeakToManyField? relation;

  /// Automatic scalar-field controller; available for advanced integrations.
  late final BeakFormController controller;
  final List<_Placement> _placements = [];
  final Map<String, List<BeakDraftRecord>> _rows = {};
  final Map<String, BeakDraftRecord> _createdSelections = {};
  final Map<String, BeakDraftRecord> _linkedReferences = {};
  final Map<String, BeakRecord> _selected = {};

  /// Validation and server errors indexed by the declared field key.
  final Map<String, List<String>> errors = {};

  /// Lookup transport errors retained until a successful retry.
  final Map<String, BeakException> optionErrors = {};
  final Map<String, BeakQuerySpec> _optionSpecs = {};
  final Map<String, int> _requestVersions = {};
  final Map<String, int> _selectionVersions = {};
  final Map<String, (Object, BeakQuerySpec)> _hydrationAttempts = {};
  final Map<String, Future<void>> _selectionHydrations = {};
  final Map<String, Future<List<BeakRecord>>> _searchRequests = {};
  final Map<String, Set<String>> _derivedReads = {};
  BeakRecord _initial = const BeakRecord(values: {});
  BeakRecord? _lastBehaviorRecord;
  BeakRecord? _conflictBaseline;
  final Set<String> _manualOverrides = {};
  BeakAccessCapabilities _capabilities = const BeakAccessCapabilities();
  Future<void>? _capabilityRequest;

  /// Server-supplied field and relationship capabilities for this draft.
  BeakAccessCapabilities get capabilities => _capabilities;

  /// Whether the server permits displaying this placement.
  bool visible(BeakFormNode node) {
    final field = _placementField(node);
    if (field != null && !_capabilities.canRead(field.key)) return false;
    final dependencies = switch (node) {
      BeakFormSummary(source: final source?) => [source],
      BeakFormSummary(:final lines) => [
        for (final line in lines) ...line.dependencies,
      ],
      BeakInput<Object>(:final dependencies) ||
      BeakCalculated(:final dependencies) ||
      BeakFormNotice(:final dependencies) ||
      BeakFormCapacity(:final dependencies) ||
      BeakFormMetrics(:final dependencies) ||
      BeakFormProgress<Enum>(:final dependencies) => dependencies,
      _ => const <BeakFieldRef<Object>>[],
    };
    if (dependencies.any(
      (field) => !_capabilities.canRead(
        field.path.isEmpty ? field.key : field.path.first.key,
      ),
    )) {
      return false;
    }
    if (node case BeakFormProgress<Enum>(:final field)) {
      if (!_capabilities.canRead(field.key)) return false;
    }
    if (node case BeakFormTimeline(:final field)) {
      if (!_capabilities.canRead(field.key)) return false;
    }
    if (node
        case BeakFormTemplate(:final template) ||
            BeakFormPlaceholder(template: final template?)) {
      if (template.fields.any(
        (field) => !_capabilities.canRead(
          field.path.isEmpty ? field.key : field.path.first.key,
        ),
      )) {
        return false;
      }
    }
    if (node case BeakRelationInput(
      field: BeakToOneField(relation: BeakBelongsTo(:final foreignKey)),
    )) {
      if (!_capabilities.canRead(foreignKey)) return false;
    }
    return node.visibleIf?.call(BeakFormReader(this)) ?? true;
  }

  /// Persisted baseline, unchanged by local edits until a confirmed save.
  BeakRecord get initialRecord => _initial;

  /// Persisted identity, or null until a new draft has been saved.
  Object? id;

  /// Whether the row is staged for removal from its owner.
  bool removed = false;

  /// Whether the staged removal deletes an explicitly owned record.
  bool deleteRemote = false;
  bool _needsAttach = false;
  int _validationVersion = 0;
  int _optionRevision = 0;
  final Map<String, int> _optionRevisions = {};

  /// Advances only when a validation pass starts, for focus/navigation helpers.
  int get validationEpoch => _validationVersion;

  /// Advances when remote choices change, preserving the picker's current query.
  int get optionRevision => _optionRevision;

  /// Changes only when this relation's query or source data is invalidated.
  /// Unrelated field dependencies do not restart the picker's current search.
  int optionRevisionFor(BeakToOneField field) =>
      _optionRevisions[field.key] ?? 0;

  void _invalidateOptions(String key) {
    _optionRevision++;
    _optionRevisions[key] = (_optionRevisions[key] ?? 0) + 1;
  }

  bool _disposed = false;
  Timer? _preflightTimer;
  int _preflightVersion = 0;
  String? _remoteSignature;
  Future<BeakResult<BeakValidationReport>>? _remoteRequest;
  final Set<String> _remoteErrorKeys = {};

  /// Whether a debounced or in-flight authoritative validation is pending.
  bool get validating =>
      _capabilityRequest != null ||
      _preflightTimer != null ||
      _remoteRequest != null ||
      _createdSelections.values.any((draft) => draft.validating) ||
      _rows.values
          .expand((rows) => rows)
          .any((draft) => !draft.removed && draft.validating);

  Set<String> get _remoteKeys => {
    for (final column in model.columns)
      if (column.unique) column.key,
    for (final rule in model.validationRules.whereType<BeakAsyncRecordRule>())
      for (final field in rule.fields) field.key,
  };

  void _schedulePreflight() {
    _preflightVersion++;
    _preflightTimer?.cancel();
    _preflightTimer = null;
    if (_remoteKeys.isEmpty ||
        session.repository.dataSource is! BeakValidationDataSource ||
        session.submitting.value) {
      return;
    }
    final version = _preflightVersion;
    _preflightTimer = Timer(const Duration(milliseconds: 350), () {
      _preflightTimer = null;
      _preflight(version);
    });
  }

  Future<BeakResult<BeakValidationReport>> _checkRemote(
    BeakValidationDataSource source,
  ) {
    final request = BeakValidationRequest.forModel(
      model,
      BeakRecord(values: buildRecord().values, relations: snapshot.relations),
      recordId: id,
    );
    final signature = jsonEncode(request.toJson());
    if (_remoteSignature == signature && _remoteRequest != null) {
      return _remoteRequest!;
    }
    final task = session.repository.run(() => source.validateRecord(request));
    _remoteSignature = signature;
    _remoteRequest = task;
    session._notify();
    unawaited(
      task.whenComplete(() {
        if (_disposed) return;
        if (identical(_remoteRequest, task)) {
          _remoteRequest = null;
          session._notify();
        }
      }),
    );
    return task;
  }

  Future<void> _preflight(int version) async {
    if (_disposed || session.hasUnknown) return;
    final source = session.repository.dataSource;
    if (source case final BeakValidationDataSource validationSource) {
      final keys = _remoteKeys.difference(_deferredReferenceKeys);
      final result = await _checkRemote(validationSource);
      if (_disposed ||
          version != _preflightVersion ||
          session.submitting.value) {
        return;
      }
      for (final key in _remoteErrorKeys) {
        errors.remove(key);
      }
      _remoteErrorKeys.clear();
      switch (result) {
        case BeakOk(:final value):
          for (final entry in value.fieldErrors.entries) {
            if (keys.contains(entry.key)) {
              errors[entry.key] = entry.value;
              _remoteErrorKeys.add(entry.key);
            }
          }
        case BeakErr(:final error):
          if (keys.firstOrNull case final String key) {
            errors[key] = [error.message];
            _remoteErrorKeys.add(key);
          }
      }
      session._notify();
    }
  }

  void _compile(
    BeakFormNode node,
    List<BeakVisibility> parents,
    List<BeakVisibility> parentEdits,
  ) {
    final edits = [...parentEdits, if (node.enabledIf != null) node.enabledIf!];
    final conditions = [
      ...parents,
      if (node.visibleIf != null) node.visibleIf!,
    ];
    if (node is BeakFormLayout) {
      for (final child in node.children) {
        _compile(child, conditions, edits);
      }
      return;
    }
    if (node case BeakFormSummary(source: final source?)) {
      // A summary alone still hydrates the ordinary read-only child drafts.
      // When an editable table exists, _table selects it so both presentations
      // observe the exact same rows instead of creating a second state owner.
      _compile(
        BeakRelationTable(
          field: source,
          readOnly: true,
          allowAdding: false,
          allowEdit: false,
          allowRemove: false,
          children: const [],
        ),
        conditions,
        edits,
      );
    } else if (node case BeakFormSummary(:final lines)) {
      // Child collection dependencies are draft-aware too: state.rows(options)
      // must include saved extras even when no editor displays that collection.
      for (final dependency
          in lines
              .expand((line) => line.dependencies)
              .whereType<BeakToManyField>()) {
        if (dependency.path.isNotEmpty) continue;
        _compile(
          BeakRelationTable(
            field: dependency,
            readOnly: true,
            allowAdding: false,
            allowEdit: false,
            allowRemove: false,
            children: const [],
          ),
          conditions,
          edits,
        );
      }
    }
    final BeakFieldRef<Object>? field = switch (node) {
      BeakInput<Object>(:final field) => field,
      BeakRelationInput(:final field) => field,
      BeakRelationTable(:final field) => field,
      _ => null,
    };
    if (field != null) {
      if (field.model.table != model.table || field.path.isNotEmpty) {
        throw BeakConfigurationException(
          'Input ${field.qualifiedKey} is outside the ${model.table} draft.',
        );
      }
      if (_placements.any(
        (p) => switch (p.node) {
          BeakInput<Object>(field: final other) => other.key == field.key,
          BeakRelationInput(field: final other) => other.key == field.key,
          BeakRelationTable(field: final other, readOnly: final readOnly) =>
            other.key == field.key &&
                !readOnly &&
                !(node is BeakRelationTable && node.readOnly),
          _ => false,
        },
      )) {
        throw BeakConfigurationException(
          'Duplicate editable field ${field.qualifiedKey}.',
        );
      }
      session.registry.registerIfMissing(field.model);
      if (field is BeakToOneField) {
        session.registry.registerIfMissing(field.target);
      }
      if (field is BeakToManyField) {
        session.registry.registerIfMissing(field.target);
      }
    }
    _placements.add(_Placement(node, conditions, edits));
  }

  void _changed() {
    if (_disposed) return;
    session._changed();
    _schedulePreflight();
  }

  @override
  T? read<T extends Object>(BeakFieldRef<T> field) =>
      BeakFormReader(this).read(field);

  /// Updates a typed field. Saving freezes the draft until its result is known.
  void set<T extends Object>(BeakScalarField<T> field, T? value) {
    if (session.submitting.value || session.hasUnknown) return;
    _requireOwner(field);
    _manualOverrides.add(field.key);
    controller.setValue<Object>(field.column, value);
    errors.remove(field.key);
  }

  void _requireOwner(BeakFieldRef<Object> field) {
    if (field.model.table != model.table || field.path.isNotEmpty) {
      throw BeakConfigurationException(
        'Cannot write ${field.qualifiedKey} in ${model.table}.',
      );
    }
  }

  /// The complete local record, including currently hidden values and relations.
  BeakRecord get snapshot => BeakRecord(
    values: {
      ..._initial.values,
      ...controller.buildData().values,
      if (id != null) model.primaryKey.key: BeakValue.of(id),
    },
    relations: {
      ..._initial.relations,
      // Picker bindings own their relation, including an explicitly cleared or
      // not-yet-hydrated selection. Never expose an old initial relation after
      // its foreign key changes.
      for (final input
          in _placements
              .map((placement) => placement.node)
              .whereType<BeakRelationInput>())
        input.field.key: [
          if (_selected[input.field.key] case final BeakRecord selected)
            selected,
        ],
      for (final entry in _selected.entries) entry.key: [entry.value],
      for (final entry in _createdSelections.entries)
        entry.key: [entry.value.snapshot],
      for (final relation in model.relationships.whereType<BeakBelongsTo>())
        if (_linkedReferences[relation.foreignKey]
            case final BeakDraftRecord target)
          relation.key: [target.snapshot],
      for (final entry in _rows.entries)
        entry.key: [
          for (final row in entry.value)
            if (!row.removed) row.snapshot,
        ],
    },
  );

  /// The scalar command/patch after visibility and placement filtering.
  BeakRecord buildRecord() {
    final values = <String, BeakValue>{};
    final all = controller.buildData();
    final reader = BeakFormReader(this);
    for (final placement in _placements) {
      switch (placement.node) {
        case BeakInput<Object>(:final field, :final submitWhenHidden):
          if ((placement.visible(reader) || submitWhenHidden) &&
              all[field.key] != null &&
              _capabilities.canWrite(field.key) &&
              model.behavior.canEdit(field.key, _initial)) {
            values[field.key] = all[field.key]!;
          }
        case BeakRelationInput(:final field):
          if (field.relation case BeakBelongsTo(
            :final foreignKey,
          ) when placement.visible(reader)) {
            final key = foreignKey;
            if (all[key] != null &&
                _capabilities.canWrite(key) &&
                _capabilities.canWrite(field.key) &&
                model.behavior.canEdit(key, _initial)) {
              values[key] = all[key]!;
            }
          }
        default:
          break;
      }
    }
    return BeakRecord(values: values);
  }

  /// Whether this editable field differs from its persisted baseline.
  bool fieldChanged(BeakFieldRef<Object> field) {
    if (field.path.isNotEmpty || field.model.table != model.table) return false;
    final key = switch (field) {
      BeakToOneField(relation: BeakBelongsTo(:final foreignKey)) => foreignKey,
      _ => field.key,
    };
    return _capabilities.canRead(field.key) &&
        _capabilities.canRead(key) &&
        _capabilities.canWrite(field.key) &&
        _capabilities.canWrite(key) &&
        model.behavior.canEdit(key, _initial) &&
        snapshot[key] != _initial[key];
  }

  /// Whether this draft contains unapplied scalar or relationship changes.
  bool get isDirty =>
      (id == null && parent != null) ||
      controller.isDirty ||
      _needsAttach ||
      _createdSelections.isNotEmpty ||
      _rows.values
          .expand((rows) => rows)
          .any((row) => (row.removed ? row.id != null : row.isDirty));

  /// Current visible rows; removing a new row discards it without a remote op.
  List<BeakDraftRecord> rows(BeakToManyField field) => List.unmodifiable(
    (_rows[field.key] ?? const <BeakDraftRecord>[]).where(
      (row) => !row.removed,
    ),
  );

  /// The editable collection definition owning this relationship's local rows.
  BeakRelationTable relationTable(BeakToManyField field) => _table(field);

  BeakRelationTable _table(BeakToManyField field) {
    final tables = _placements
        .map((p) => p.node)
        .whereType<BeakRelationTable>()
        .where((node) => node.field.key == field.key);
    return tables.where((node) => !node.readOnly).firstOrNull ?? tables.first;
  }

  BeakFormLayout _rowLayout(BeakToManyField field) => BeakFormLayout(
    children: [
      ..._table(field).rowLayout.children,
      // Every presentation contributes read dependencies to the one row owner.
      // Editable inputs still come only from the selected table, so duplicate
      // summaries cannot duplicate editors, validation or save operations.
      for (final summary
          in _placements
              .map((placement) => placement.node)
              .whereType<BeakFormSummary>())
        if (summary.source?.key == field.key)
          BeakFormSummary(lines: summary.lines),
    ],
  );

  /// Adds an unsaved related row and initializes its automatic input state.
  BeakDraftRecord addRow(BeakToManyField field, {BeakRecord? values}) {
    if (session.submitting.value || session.hasUnknown) {
      throw StateError('The save result must be known before editing.');
    }
    final table = _table(field);
    _requireTableEnabled(table);
    if (!table.allowAdding) {
      throw const BeakConfigurationException('Adding rows is disabled.');
    }
    final row = BeakDraftRecord._(
      session,
      field.target,
      _rowLayout(field),
      session._nextId(),
      parent: this,
      relation: field,
    );
    row._needsAttach = field.relation is BeakBelongsToMany;
    if (values != null) row._prefill(values, existing: false);
    _rows.putIfAbsent(field.key, () => []).add(row);
    session._queueCapabilities(row);
    session._changed();
    return row;
  }

  /// Builds a catalog query from the owner's draft and typed presentation.
  BeakQuerySpec catalogQuery(
    BeakRelationTable table,
    String term, {
    BeakFilter? filter,
  }) {
    final catalog = table.catalog;
    if (catalog == null ||
        catalog.selection.model.table != table.field.target.table) {
      throw const BeakConfigurationException(
        'A catalog selection must belong to the collection row model.',
      );
    }
    if (catalog.maxOptions == null &&
        [
          ...catalog.tabs,
          ...catalog.filters,
        ].any((item) => item.matches != null)) {
      throw const BeakConfigurationException(
        'Local catalog facets require an explicit finite maxOptions.',
      );
    }
    var query = beakWithFieldLoads(
      catalog.options?.call(BeakFormReader(this)).query ??
          catalog.selection.options().query,
      [
        ...catalog.template.fields,
        ...?catalog.advancedLabel?.dependencies,
        ?catalog.groupBy,
        ?catalog.variantLabel,
        ?catalog.price,
        for (final facet in [...catalog.tabs, ...catalog.filters])
          ...facet.dependencies,
      ],
    );
    if (filter != null) query = query.withFilter(filter);
    if (query.table != catalog.selection.target.table) {
      throw const BeakConfigurationException(
        'Catalog query targets the wrong model.',
      );
    }
    return BeakQuerySpec(
      table: query.table,
      filter: query.filter,
      sorts: query.sorts,
      search: term.trim().isEmpty
          ? query.search
          : BeakSearch(
              term.trim(),
              _optionSearchSources(
                catalog.selection,
                catalog.searchSources,
                catalog.template,
                query,
              ),
            ),
      relationLoads: _mergeDraftLoads(query.relationLoads, [
        for (final load in [
          ...table.field.target.behavior.relationLoads,
          ...session._loadsFor(_rowLayout(table.field)),
        ])
          if (load.relationKey == catalog.selection.key) ...load.nested,
      ]),
      pagination: query.pagination,
      withTrashed: query.withTrashed,
    );
  }

  /// Adds a catalog selection as one unsaved owned row, preserving model behavior.
  BeakDraftRecord addCatalogRow(BeakRelationTable table, BeakRecord record) {
    final catalog = table.catalog;
    if (catalog == null ||
        catalog.selection.model.table != table.field.target.table) {
      throw const BeakConfigurationException(
        'A catalog selection must belong to the collection row model.',
      );
    }
    final reason = catalog.disabledReason?.call(record, BeakFormReader(this));
    if (reason != null) throw BeakConfigurationException(reason);
    if (catalog.selection.target.primaryKeyOf(record) == null) {
      throw const BeakConfigurationException(
        'Catalog records require an identity.',
      );
    }
    final row = addRow(table.field);
    row.select(catalog.selection, record);
    return row;
  }

  /// Stages a relationship removal; new unsaved rows are discarded locally.
  void removeRow(BeakDraftRecord row) {
    if (session.submitting.value || session.hasUnknown) return;
    final field = row.relation;
    if (field == null || row.parent != this) {
      throw StateError('This row belongs to another draft.');
    }
    final table = _table(field);
    _requireTableEnabled(table);
    final deleteRemote = table.removeBehavior == BeakRemoveBehavior.deleteOwned;
    if (!table.allowRemove) {
      throw const BeakConfigurationException(
        'This relationship operation is disabled.',
      );
    }
    if (deleteRemote &&
        !(field.relation is BeakHasMany &&
            switch (field.relation) {
              BeakHasMany(:final owned) => owned,
              _ => false,
            })) {
      throw const BeakConfigurationException(
        'Deleting a related row requires an owned has-many relationship.',
      );
    }
    if (row.id == null) {
      _rows[field.key]?.remove(row);
    } else {
      row.removed = true;
      row.deleteRemote = deleteRemote;
    }
    session._changed();
  }

  /// Cancels a staged removal and restores the row to the visible collection.
  void restoreRow(BeakDraftRecord row) {
    if (session.submitting.value || session.hasUnknown) return;
    final field = row.relation;
    if (field == null || row.parent != this) {
      throw StateError('This row belongs to another draft.');
    }
    _requireTableEnabled(_table(field));
    row.removed = false;
    row.deleteRemote = false;
    session._changed();
  }

  /// Effective editability, including ancestor sections and owning collections.
  bool enabled(BeakFormNode node) {
    if (node is BeakRelationTable && node.readOnly) return false;
    final field = _placementField(node);
    if (field != null &&
        (!_capabilities.canWrite(field.key) ||
            !model.behavior.canEdit(field.key, _initial))) {
      return false;
    }
    if (node case BeakRelationInput(
      field: BeakToOneField(relation: BeakBelongsTo(:final foreignKey)),
    )) {
      if (!_capabilities.canWrite(foreignKey) ||
          !model.behavior.canEdit(foreignKey, _initial)) {
        return false;
      }
    }
    if (parent case final BeakDraftRecord owner) {
      if (relation case final BeakToManyField field) {
        if (!owner.enabled(owner._table(field))) return false;
      }
    }
    final placement = _placements
        .where((p) => identical(p.node, node))
        .firstOrNull;
    return (placement?.enabled(BeakFormReader(this)) ??
            node.enabledIf?.call(BeakFormReader(this)) ??
            true) &&
        (node is! BeakRelationInput || missingPrerequisites(node).isEmpty);
  }

  void _requireTableEnabled(BeakRelationTable table) {
    if (!enabled(table)) {
      throw const BeakConfigurationException('This relationship is read-only.');
    }
  }

  /// A modal checkpoint. Restoring affects only this record's local values.
  BeakDraftCheckpoint checkpoint() => BeakDraftCheckpoint._(
    snapshot,
    {
      for (final entry in _rows.entries)
        entry.key: [
          for (final row in entry.value)
            (row, row.checkpoint(), row.removed, row.deleteRemote),
        ],
    },
    Map.of(_createdSelections),
    Map.of(_linkedReferences),
    Map.of(_selected),
    Set.of(_manualOverrides),
  );

  /// Restores a local checkpoint without changing the persisted baseline.
  void restore(BeakDraftCheckpoint checkpoint) {
    final updating = session._restoringDraft;
    session._restoringDraft = true;
    BeakRecord complete(BeakRecord record) => BeakRecord(
      values: {
        for (final column in model.columns)
          if (controller.hasFieldFor(column))
            column.key: record[column.key] ?? const BeakNullValue(),
      },
    );
    controller.prefill(complete(checkpoint.record));
    final saved = {
      for (final slot in controller.registeredFields)
        slot: controller.get<Object>(slot),
    };
    controller.prefill(complete(_initial));
    for (final entry in saved.entries) {
      controller.set(entry.key, entry.value);
    }
    _selected
      ..clear()
      ..addAll(checkpoint.selected);
    for (final entry in _rows.entries) {
      final keep = checkpoint.rows[entry.key] ?? const [];
      for (final row in entry.value) {
        if (!keep.any((item) => identical(item.$1, row))) row.removed = true;
      }
    }
    _rows.clear();
    for (final entry in checkpoint.rows.entries) {
      _rows[entry.key] = [for (final item in entry.value) item.$1];
      for (final item in entry.value) {
        item.$1.restore(item.$2);
        item.$1.removed = item.$3;
        item.$1.deleteRemote = item.$4;
      }
    }
    _createdSelections
      ..clear()
      ..addAll(checkpoint.createdSelections);
    _linkedReferences
      ..clear()
      ..addAll(checkpoint.linkedReferences);
    _manualOverrides
      ..clear()
      ..addAll(checkpoint.overrides);
    _lastBehaviorRecord = snapshot;
    session._restoringDraft = updating;
    session._changed();
  }

  /// Selects a lookup result, binding both its label record and foreign key.
  void select(BeakToOneField field, BeakRecord? record) {
    if (session.submitting.value || session.hasUnknown) return;
    _requireOwner(field);
    final relation = field.relation;
    if (relation is! BeakBelongsTo) {
      throw const BeakConfigurationException(
        'A picker requires a belongs-to relationship.',
      );
    }
    _selectionVersions[field.key] = (_selectionVersions[field.key] ?? 0) + 1;
    _hydrationAttempts.remove(field.key);
    if (record == null) {
      _selected.remove(field.key);
    } else {
      _selected[field.key] = record;
    }
    _createdSelections.remove(field.key);
    _linkedReferences.remove(relation.foreignKey);
    controller.set(
      controller.slotOfForeignKey(relation),
      record == null ? null : field.target.primaryKeyOf(record),
    );
    errors.remove(field.key);
    session._changed();
  }

  /// Creates a related record locally; the enclosing save resolves its identity.
  BeakDraftRecord createSelection(BeakRelationInput input) {
    if (session.submitting.value || session.hasUnknown) {
      throw StateError('The save result must be known before editing.');
    }
    if (!enabled(input)) {
      throw const BeakConfigurationException(
        'Complete the relationship prerequisites first.',
      );
    }
    final child = BeakDraftRecord._(
      session,
      input.field.target,
      input.createForm ??
          session.relatedLayouts[input.field.target.table] ??
          BeakFormLayout.fromModel(
            input.field.target,
            registry: session.registry,
          ),
      session._nextId(),
    );
    for (final rule in _eligibility(input)) {
      for (final match in rule.matching) {
        final pending = match.source.path.isEmpty
            ? _draftForForeignKey(match.source.key)
            : null;
        if (pending != null) {
          child._linkReference(match.target.key, pending);
        } else {
          child.controller.setValue<Object>(
            match.target.column,
            read(match.source),
          );
        }
      }
    }
    _createdSelections[input.field.key] = child;
    session._queueCapabilities(child);
    _selected.remove(input.field.key);
    session._changed();
    return child;
  }

  BeakDraftRecord? _draftForForeignKey(String key) {
    if (_linkedReferences[key] case final BeakDraftRecord target) return target;
    for (final relation in model.relationships.whereType<BeakBelongsTo>()) {
      if (relation.foreignKey == key) return _createdSelections[relation.key];
    }
    return null;
  }

  void _linkReference(String key, BeakDraftRecord target) {
    final relation = model.relationships
        .whereType<BeakBelongsTo>()
        .where(
          (relation) =>
              relation.foreignKey == key &&
              relation.relatedTable == target.model.table,
        )
        .firstOrNull;
    if (relation == null || !identical(session, target.session)) {
      throw const BeakConfigurationException(
        'A staged reference must match a belongs-to relationship in the same form.',
      );
    }
    final seen = <BeakDraftRecord>{};
    bool reaches(BeakDraftRecord from) {
      if (identical(from, this)) return true;
      if (!seen.add(from)) return false;
      return [
        ...from._createdSelections.values,
        ...from._linkedReferences.values,
        ...from._rows.values.expand((rows) => rows),
      ].any(reaches);
    }

    if (reaches(target)) {
      throw const BeakConfigurationException('Cyclic staged relationship.');
    }
    _linkedReferences[key] = target;
    _selected.remove(relation.key);
  }

  Set<String> get _deferredReferenceKeys => {
    ..._linkedReferences.keys,
    for (final relation in model.relationships.whereType<BeakBelongsTo>())
      if (_createdSelections.containsKey(relation.key) ||
          _linkedReferences.containsKey(relation.foreignKey)) ...[
        relation.key,
        relation.foreignKey,
      ],
  };

  Iterable<BeakExists<Object>> _eligibility(BeakRelationInput input) sync* {
    final relation = input.field.relation;
    if (relation is! BeakBelongsTo) return;
    for (final rule in model.validationRules.whereType<BeakExists<Object>>()) {
      if (rule.field.key == relation.foreignKey &&
          rule.target.model.table == input.field.target.table &&
          rule.target.key == input.field.target.primaryKey.key) {
        yield rule;
      }
    }
  }

  /// Prerequisite fields inferred from the model's authoritative eligibility rules.
  List<BeakScalarField<Object>> missingPrerequisites(BeakRelationInput input) =>
      [
        for (final rule in _eligibility(input))
          for (final match in rule.matching)
            if (read(match.source) == null &&
                (match.source.path.isNotEmpty ||
                    _draftForForeignKey(match.source.key) == null))
              match.source,
      ];

  BeakQuerySpec _options(BeakRelationInput input) {
    final configured = input.options?.call(BeakFormReader(this));
    var query = beakWithFieldLoads(
      configured?.query ?? input.field.options().query,
      input.template?.fields ?? const [],
    );
    if (query.table != input.field.target.table) {
      throw BeakConfigurationException(
        'Options for ${input.field.key} must query ${input.field.target.table}.',
      );
    }
    for (final rule in _eligibility(input)) {
      if (rule.where case final BeakFilter filter) {
        query = query.withFilter(filter);
      }
      for (final match in rule.matching) {
        query = query.withFilter(match.target.eq(read(match.source)));
      }
    }
    final nested = [
      for (final load in [
        ...model.behavior.relationLoads,
        ...session._loadsFor(layout),
      ])
        if (load.relationKey == input.field.key) ...load.nested,
    ];
    return BeakQuerySpec(
      table: query.table,
      filter: query.filter,
      sorts: query.sorts,
      search: query.search,
      relationLoads: _mergeDraftLoads(query.relationLoads, nested),
      pagination: query.pagination,
      withTrashed: query.withTrashed,
    );
  }

  List<String> _optionSearchSources(
    BeakToOneField field,
    List<BeakScalarField<Object>> configured,
    BeakRecordTemplate? template,
    BeakQuerySpec query,
  ) {
    final sources = configured.isNotEmpty
        ? configured
        : [
            for (final source
                in template?.fields ?? const <BeakFieldRef<Object>>[])
              if (source is BeakScalarField<Object> && source.column.searchable)
                source,
          ];
    if (sources.any((source) => source.model.table != field.target.table)) {
      throw const BeakConfigurationException(
        'Search sources must be rooted at the option model.',
      );
    }
    return {
      if (configured.isEmpty) ...?query.search?.columnKeys,
      if (configured.isEmpty) ...field.relation.effectiveSearchColumnKeys,
      for (final source in sources) source.qualifiedKey,
    }.toList();
  }

  /// Searches through the declared query; failures stay visible and retryable.
  Future<List<BeakRecord>> search(BeakRelationInput input, String term) async {
    final key = input.field.key;
    if (input.presentation == BeakRelationPresentation.code &&
        term.trim().isEmpty) {
      return const [];
    }
    if (missingPrerequisites(input).isNotEmpty) return const [];
    var pending = _search(input, term);
    _searchRequests[key] = pending;
    while (!_disposed) {
      final records = await pending;
      if (identical(pending, _searchRequests[key])) return records;
      pending = _searchRequests[key]!;
    }
    return const [];
  }

  Future<List<BeakRecord>> _search(BeakRelationInput input, String term) async {
    final key = input.field.key;
    final version = (_requestVersions[key] ?? 0) + 1;
    _requestVersions[key] = version;
    final base = _options(input);
    final codeField = input.codeField;
    if (input.presentation == BeakRelationPresentation.code &&
        (codeField == null ||
            codeField.model.table != input.field.target.table ||
            codeField.path.isNotEmpty)) {
      throw const BeakConfigurationException(
        'Code lookups require a string field rooted at the option model.',
      );
    }
    final columns = _optionSearchSources(
      input.field,
      input.searchSources,
      input.template,
      base,
    );
    final query = input.presentation == BeakRelationPresentation.code
        ? base
              .withFilter(
                codeField!.eq(
                  input.normalizeCode?.call(term.trim()) ?? term.trim(),
                ),
              )
              .paginate(page: 1, perPage: 2)
        : term.trim().isEmpty
        ? base
        : BeakQuerySpec(
            table: base.table,
            filter: base.filter,
            sorts: base.sorts,
            relationLoads: base.relationLoads,
            pagination: base.pagination,
            search: BeakSearch(term.trim(), columns),
          );
    final result = await session.repository.query(query);
    if (_disposed || version != _requestVersions[key]) return const [];
    switch (result) {
      case BeakOk(:final value):
        optionErrors.remove(key);
        if (input.field.relation case BeakBelongsTo(
          :final foreignKey,
        ) when !_selected.containsKey(key)) {
          final desiredId = snapshot[foreignKey]?.raw;
          final match = value.items
              .where(
                (record) =>
                    input.field.target.primaryKeyOf(record) == desiredId,
              )
              .firstOrNull;
          if (match != null) {
            _selected[key] = match;
            session._changed();
          }
          if (desiredId == null &&
              term.trim().isEmpty &&
              input.selectDefaultOption) {
            final owner = BeakFormReader(this);
            final preferred = value.items
                .where(
                  (record) =>
                      input.disabledReason?.call(record, owner) == null &&
                      (input.defaultOptionMatch?.call(record, owner) ??
                          (input.defaultOption != null &&
                              input.field.target.primaryKeyOf(record) ==
                                  input.field.target.primaryKeyOf(
                                    read(input.defaultOption!) ??
                                        const BeakRecord(values: {}),
                                  ))),
                )
                .firstOrNull;
            if (preferred != null) select(input.field, preferred);
          }
        }
        session._notify();
        return value.items;
      case BeakErr(:final error):
        optionErrors[key] = error;
        session._notify();
        return const [];
    }
  }

  void _refreshOptions() {
    for (final input
        in _placements.map((p) => p.node).whereType<BeakRelationInput>()) {
      final spec = _options(input);
      final previous = _optionSpecs[input.field.key];
      _optionSpecs[input.field.key] = spec;
      final relation = input.field.relation;
      if (relation is BeakBelongsTo &&
          !_createdSelections.containsKey(input.field.key)) {
        final selected = _selected[input.field.key];
        final desiredId = snapshot[relation.foreignKey]?.raw;
        if (desiredId !=
            (selected == null
                ? null
                : input.field.target.primaryKeyOf(selected))) {
          _selected.remove(input.field.key);
          if (desiredId != null &&
              _hydrationAttempts[input.field.key] != (desiredId, spec)) {
            _hydrationAttempts[input.field.key] = (desiredId, spec);
            final request = _hydrateBinding(input, relation, spec, desiredId);
            _selectionHydrations[input.field.key] = request;
            unawaited(request);
          }
        }
      }
      if (previous != null && previous != spec) {
        _invalidateOptions(input.field.key);
        _requestVersions[input.field.key] =
            (_requestVersions[input.field.key] ?? 0) + 1;
        if (_selected.containsKey(input.field.key)) {
          unawaited(_checkSelection(input, spec));
        }
      }
    }
  }

  Future<void> _hydrateBinding(
    BeakRelationInput input,
    BeakBelongsTo relation,
    BeakQuerySpec spec,
    Object id,
  ) async {
    final key = input.field.key;
    final version = (_selectionVersions[key] ?? 0) + 1;
    _selectionVersions[key] = version;
    final result = await session.repository.query(
      spec.withFilter(
        BeakFieldFilter(
          column: input.field.target.primaryKey,
          operator: BeakOperator.eq,
          value: BeakValue.of(id),
        ),
      ),
    );
    if (_disposed || version != _selectionVersions[key]) return;
    unawaited(_selectionHydrations.remove(key));
    if (snapshot[relation.foreignKey]?.raw != id || _optionSpecs[key] != spec) {
      return;
    }
    switch (result) {
      case BeakOk(:final value) when value.items.isNotEmpty:
        _selected[key] = value.items.first;
        optionErrors.remove(key);
        session._changed();
      case BeakOk():
        optionErrors[key] = const BeakNotFoundException(
          'The selected record is not available for these values.',
        );
        session._notify();
      case BeakErr(:final error):
        optionErrors[key] = error;
        session._notify();
    }
  }

  Future<void> _checkSelection(
    BeakRelationInput input,
    BeakQuerySpec spec,
  ) async {
    final record = _selected[input.field.key];
    if (record == null) return;
    if (missingPrerequisites(input).isNotEmpty) {
      select(input.field, null);
      return;
    }
    final selectedId = input.field.target.primaryKeyOf(record);
    final requestVersion = (_selectionVersions[input.field.key] ?? 0) + 1;
    _selectionVersions[input.field.key] = requestVersion;
    final result = await session.repository.query(
      spec.withFilter(
        BeakFieldFilter(
          column: input.field.target.primaryKey,
          operator: BeakOperator.eq,
          value: BeakValue.of(selectedId),
        ),
      ),
    );
    if (_disposed ||
        requestVersion != _selectionVersions[input.field.key] ||
        _optionSpecs[input.field.key] != spec ||
        !identical(_selected[input.field.key], record)) {
      return;
    }
    switch (result) {
      case BeakOk(:final value) when value.items.isEmpty:
        select(input.field, null);
      case BeakErr(:final error):
        optionErrors[input.field.key] = error;
        session._notify();
      case BeakOk(:final value):
        _selected[input.field.key] = value.items.first;
        optionErrors.remove(input.field.key);
        session._changed();
    }
  }

  bool _canValidate(BeakFormNode node) {
    if (node is BeakRelationTable && node.readOnly) return false;
    final field = _placementField(node);
    if (field != null &&
        (!_capabilities.canWrite(field.key) ||
            !model.behavior.canEdit(field.key, _initial))) {
      return false;
    }
    if (field case BeakToOneField(relation: BeakBelongsTo(:final foreignKey))) {
      return _capabilities.canWrite(foreignKey);
    }
    return true;
  }

  /// Validates visible placements and nested drafts, awaiting asynchronous rules.
  Future<bool> validate({Set<BeakFormNode>? only}) async {
    await _capabilityRequest;
    while (!_disposed && _selectionHydrations.isNotEmpty) {
      final pending = _selectionHydrations.values.toList();
      await Future.wait(pending);
      // A user selection can supersede an in-flight request without scheduling
      // another. Remove completed stale entries without touching newer loads.
      _selectionHydrations.removeWhere((_, future) => pending.contains(future));
    }
    if (_disposed) return false;
    _preflightTimer?.cancel();
    _preflightTimer = null;
    final version = ++_validationVersion;
    final draftVersion = session._changeVersion;
    final next = <String, List<String>>{};
    for (final placement in _placements) {
      final node = placement.node;
      if (only != null && !only.contains(node)) continue;
      if (!placement.visible(BeakFormReader(this)) ||
          !visible(node) ||
          !_canValidate(node)) {
        continue;
      }
      switch (node) {
        case BeakInput<Object>():
          if (_linkedReferences.containsKey(node.field.key)) continue;
          final messages = [
            if (controller.inputErrors[node.field.key] case final String error)
              error,
            ...await node.errors(BeakFormReader(this)),
          ];
          if (messages.isNotEmpty) next[node.field.key] = messages;
        case BeakRelationInput(:final field, :final validate):
          final value = read(field);
          final backingRules = switch (field.relation) {
            BeakBelongsTo(:final foreignKey) =>
              model.columnByKey(foreignKey)?.rules ?? const <BeakRule>[],
            _ => const <BeakRule>[],
          };
          final rules = [
            if (field.isRequired) const BeakRequired(),
            ...backingRules,
            ...validate,
          ];
          final messages = [
            for (final rule in rules)
              if (rule.validate(value) case final String message) message,
          ];
          if (value != null) {
            final reason = node.disabledReason?.call(
              value,
              BeakFormReader(this),
            );
            if (reason != null) messages.add(reason);
          }
          if (messages.isNotEmpty) next[field.key] = messages;
          if (_createdSelections[field.key] case final BeakDraftRecord child) {
            if (!await child.validate()) {
              next[field.key] = ['Complete the new related record.'];
            }
            for (final rule in _eligibility(node)) {
              for (final match in rule.matching) {
                final expected = match.source.path.isEmpty
                    ? _draftForForeignKey(match.source.key)
                    : null;
                final linked = child._linkedReferences[match.target.key];
                if (linked != null && !identical(linked, expected)) {
                  next[field.key] = [
                    'Create or select a record for the current prerequisites.',
                  ];
                }
              }
            }
          } else if (field.relation case BeakBelongsTo(
            :final foreignKey,
          ) when _linkedReferences.containsKey(foreignKey)) {
            if (!session._allDrafts().contains(_linkedReferences[foreignKey])) {
              next[field.key] = ['The related draft is no longer selected.'];
            }
          } else if (value != null) {
            final check = await session.repository.query(
              _options(node).withFilter(
                BeakFieldFilter(
                  column: field.target.primaryKey,
                  operator: BeakOperator.eq,
                  value: BeakValue.of(field.target.primaryKeyOf(value)),
                ),
              ),
            );
            switch (check) {
              case BeakErr(:final error):
                next[field.key] = [error.message];
              case BeakOk(:final value) when value.items.isEmpty:
                next[field.key] = ['Selection is no longer available.'];
              default:
                break;
            }
          }
        case BeakRelationTable(:final field, :final minRows):
          final visibleRows = rows(field);
          if (visibleRows.length < minRows) {
            next[field.key] = [
              'Add at least $minRows ${minRows == 1 ? 'row' : 'rows'}.',
            ];
          }
          for (final row in visibleRows) {
            if (!await row.validate()) {
              next[field.key] = ['Complete the related rows.'];
            }
          }
        default:
          break;
      }
    }
    final visibleKeys = <String>{
      for (final placement in _placements)
        if ((only == null || only.contains(placement.node)) &&
            placement.visible(BeakFormReader(this)) &&
            visible(placement.node) &&
            _canValidate(placement.node))
          ...switch (placement.node) {
            BeakInput<Object>(:final field) => [field.key],
            BeakRelationInput(:final field) => [field.key],
            BeakRelationTable(:final field) => [field.key],
            _ => <String>[],
          },
    };
    void merge(Map<String, List<String>> messages) {
      for (final entry in messages.entries) {
        final key = entry.key.split('.').first;
        if (visibleKeys.contains(key) &&
            !_deferredReferenceKeys.contains(key)) {
          next[key] = {...?next[key], ...entry.value}.toList(growable: false);
        }
      }
    }

    for (final rule in model.validationRules) {
      merge(rule.validate(snapshot));
    }
    final source = session.repository.dataSource;
    final needsRemote =
        model.columns.any(
          (column) => column.unique && visibleKeys.contains(column.key),
        ) ||
        model.validationRules.whereType<BeakAsyncRecordRule>().any(
          (rule) => rule.fields.any((field) => visibleKeys.contains(field.key)),
        );
    if ((next.isEmpty && needsRemote, source) case (
      true,
      final BeakValidationDataSource validator,
    )) {
      final result = await _checkRemote(validator);
      if (!_disposed) {
        switch (result) {
          case BeakOk(:final value):
            merge(value.fieldErrors);
          case BeakErr(:final error):
            if (visibleKeys.firstOrNull case final String key) {
              next[key] = [error.message];
            }
        }
      }
    }
    if (_disposed || version != _validationVersion) return false;
    if (draftVersion != session._changeVersion) return validate(only: only);
    if (only == null) {
      errors.clear();
    } else {
      for (final node in only) {
        switch (node) {
          case BeakInput<Object>(:final field):
            errors.remove(field.key);
          case BeakRelationInput(:final field):
            errors.remove(field.key);
          case BeakRelationTable(:final field):
            errors.remove(field.key);
          default:
            break;
        }
      }
    }
    errors.addAll(next);
    session._notify();
    return next.isEmpty;
  }

  void _prefill(BeakRecord record, {bool existing = true}) {
    if (existing) id = model.primaryKeyOf(record);
    // Initial values also provide read-only dependencies which have no editor.
    _initial = record;
    controller.prefill(record);
    _lastBehaviorRecord = record;
    _manualOverrides.clear();
    if (id == null) _manualOverrides.addAll(record.values.keys);
    _selectionVersions.updateAll((_, version) => version + 1);
    _hydrationAttempts.clear();
    _selectionHydrations.clear();
    _selected.clear();
    _createdSelections.clear();
    _linkedReferences.clear();
    for (final placement in _placements) {
      switch (placement.node) {
        case BeakRelationInput(:final field):
          final selected = record.relations[field.key];
          if (selected != null && selected.isNotEmpty) {
            _selected[field.key] = selected.first;
          }
        case BeakRelationTable(:final field):
          if (!identical(_table(field), placement.node)) continue;
          _rows[field.key] = [
            for (final child
                in record.relations[field.key] ?? const <BeakRecord>[])
              BeakDraftRecord._(
                session,
                field.target,
                _rowLayout(field),
                session._nextId(),
                parent: this,
                relation: field,
              ).._prefill(child),
          ];
        default:
          break;
      }
    }
  }

  /// Releases controllers and subscriptions owned by this draft.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _preflightTimer?.cancel();
    controller.removeListener(_changed);
    controller.dispose();
    for (final row in _rows.values.expand((value) => value)) {
      row.dispose();
    }
    for (final child in _createdSelections.values) {
      child.dispose();
    }
  }
}

/// A local modal snapshot. It is not a server transaction or an undo of a save.
class BeakDraftCheckpoint {
  const BeakDraftCheckpoint._(
    this.record,
    this.rows,
    this.createdSelections,
    this.linkedReferences,
    this.selected,
    this.overrides,
  );

  /// Values captured when the modal checkpoint was created.
  final BeakRecord record;

  /// Related rows and their local values and removal flags at the checkpoint.
  final Map<String, List<(BeakDraftRecord, BeakDraftCheckpoint, bool, bool)>>
  rows;

  /// New related records present at the checkpoint.
  final Map<String, BeakDraftRecord> createdSelections;

  /// Shared staged records referenced by foreign keys at the checkpoint.
  final Map<String, BeakDraftRecord> linkedReferences;

  /// Existing selected records present at the checkpoint.
  final Map<String, BeakRecord> selected;

  /// Manual suggestion overrides preserved across modal cancellation.
  final Set<String> overrides;
}

/// Owns one configured form's complete local record graph and save lifecycle.
class BeakFormSession {
  /// Creates the automatic local graph and save lifecycle for a form.
  BeakFormSession({
    required this.model,
    required BeakDataSource dataSource,
    BeakFormLayout? layout,
    this.steps = const [],
    this.regions = const [],
    this.recordId,
    this.initialValues,
    this.relatedLayouts = const {},
    BeakModelRegistry? registry,
    this.valueMode = BeakFormValueMode.populated,
    this.editValues,
    BeakUploadClient? uploader,
    this.filePicker,
    this.drafts,
  }) : repository = BeakResourceRepository.coalescing(dataSource),
       registry = registry ?? BeakModelRegistry() {
    final uploadClient =
        uploader ??
        switch (dataSource) {
          final BeakUploadClient client => client,
          _ => null,
        };
    this.uploader = uploadClient == null
        ? null
        : BeakDraftUploads(uploadClient);
    final visited = <String>{};
    void register(BeakModel model) {
      if (!visited.add(model.table)) return;
      this.registry.registerIfMissing(model);
      for (final related in model.relatedModels) {
        register(related);
      }
    }

    register(model);
    final effective =
        layout ??
        (steps.isNotEmpty
            ? BeakFormLayout(children: steps)
            : BeakFormLayout.fromModel(model, registry: this.registry));
    root = BeakDraftRecord._(
      this,
      model,
      regions.isEmpty
          ? effective
          : BeakFormLayout(
              showChangeIndicators: effective.showChangeIndicators,
              children: [effective, ...regions],
            ),
      _nextId(),
    );
    root.id = recordId;
    if (initialValues != null) {
      if (recordId != null) {
        throw const BeakConfigurationException(
          'Initial values are only available when creating a record.',
        );
      }
      root._prefill(initialValues!, existing: false);
    }
    for (final placement in root._placements) {
      final node = placement.node;
      if (node is! BeakFormActionInput) continue;
      final name = node.action.name;
      if (_actionInputs.containsKey(name)) {
        throw BeakConfigurationException('Duplicate inline action: $name.');
      }
      final inputModel = model.behavior.action(name).inputModel;
      if (inputModel == null) {
        throw BeakConfigurationException(
          'Inline action $name needs an input model.',
        );
      }
      if (node.submitWithForm case final BeakModelAction submitWithForm) {
        final primary = model.behavior.action(submitWithForm.name).inputModel;
        if (primary == null || primary.table != inputModel.table) {
          throw const BeakConfigurationException(
            'Inline and primary actions must share an argument model.',
          );
        }
      }
      _actionInputs[name] =
          BeakFormSession(
              model: inputModel,
              dataSource: dataSource,
              layout: node.layout,
              registry: this.registry,
            )
            .._indicatorOwner = this
            .._onInputChanged = _changed;
      _actionInputNodes[name] = node;
    }
    _ready = true;
    _changed();
    if (dataSource case final BeakMutationSource source) {
      _mutations = source.changes.listen(_dataChanged);
    }
  }

  /// Model metadata defining fields, rules and relationships.
  final BeakModel model;

  /// Optional durable local draft storage with an explicit user/tenant namespace.
  final BeakFormDrafts? drafts;
  Timer? _draftTimer;
  Future<void> _draftWrite = Future.value();
  Map<String, Object?>? _storedDraft;
  Map<String, Object?> _storedActionInputs = {};
  DateTime? _storedDraftSavedAt;
  DateTime? _draftSavedAt;
  final Map<String, BeakDraftRecord> _restoredDraftIds = {};
  bool _checkedStoredDraft = false;
  bool _restoringDraft = false;
  String? _draftNotice;
  final Map<String, BeakDraftConflict> _conflicts = {};
  final Map<String, void Function(bool)> _conflictResolutions = {};

  /// Upload transport shared by all nested drafts.
  late final BeakDraftUploads? uploader;

  /// Completes after abandoned-upload cleanup; failed cleanup can be retried.
  Future<List<BeakException>> get uploadCleanup => _uploadCleanup;
  Future<List<BeakException>> _uploadCleanup = Future.value(const []);

  /// Platform file selection used by upload placements.
  final BeakFilePicker? filePicker;

  /// Exception boundary for the configured data source.
  final BeakResourceRepository repository;

  /// Model registry used to resolve related drafts and save operations.
  final BeakModelRegistry registry;

  /// Ordered wizard steps; empty for a single-page form.
  final List<BeakWizardStep> steps;

  final Signal<int> _currentStep = signal(0);
  int _stepNavigationVersion = 0;

  /// The current zero-based wizard step, or zero for a single-page form.
  int get currentStep => _currentStep.value;

  /// Navigates the wizard while validating every prerequisite for a forward jump.
  /// A failed prerequisite is shown without discarding any draft values.
  Future<bool> goToStep(int target) async {
    RangeError.checkValidIndex(target, steps, 'target');
    if (_disposed ||
        _loading.value ||
        _submitting.value ||
        hasUnknown ||
        hasStoredDraft) {
      return false;
    }
    final version = ++_stepNavigationVersion;
    if (target > currentStep) {
      for (var index = 0; index < target; index++) {
        final valid = await validateStep(index);
        if (_disposed ||
            version != _stepNavigationVersion ||
            _submitting.value ||
            hasUnknown) {
          return false;
        }
        if (!valid) {
          _currentStep.value = index;
          _notify();
          return false;
        }
      }
    }
    _currentStep.value = target;
    _notify();
    return true;
  }

  /// Header, summary and footer nodes sharing the same binding and validation.
  final List<BeakFormNode> regions;

  /// Existing record identity to load, or null when creating.
  final Object? recordId;

  /// Resource create layouts inherited by relationship creation dialogs.
  final Map<String, BeakFormLayout> relatedLayouts;

  /// Optional typed defaults for a new graph, including duplicated owned rows.
  final BeakRecord? initialValues;

  /// Whether submitted scalar commands contain populated, changed or all fields.
  final BeakFormValueMode valueMode;

  /// Optional source-specific edit command loader.
  final Future<BeakRecord> Function(Object id)? editValues;

  /// Root draft containing all scalar and relationship state.
  late final BeakDraftRecord root;

  /// Reactive version incremented after local state or validation changes.
  final Signal<int> _revision = signal(0);

  /// Read-only observation of the form revision state.
  ReadonlySignal<int> get revision => _revision;

  /// Whether initial record and related selections are being loaded.
  final Signal<bool> _loading = signal(false);

  /// Read-only observation of the form loading state.
  ReadonlySignal<bool> get loading => _loading;

  /// Whether validation, saving or receipt recovery is in progress.
  final Signal<bool> _submitting = signal(false);

  /// Read-only observation of the form submitting state.
  ReadonlySignal<bool> get submitting => _submitting;

  /// Most recent load or save transport failure.
  final Signal<BeakException?> _error = signal(null);

  /// Read-only observation of the form error state.
  ReadonlySignal<BeakException?> get error => _error;

  /// Latest confirmed or uncertain outcomes of the current save plan.
  final Signal<BeakSaveResult?> _saveResult = signal(null);

  /// Read-only observation of the form saveResult state.
  ReadonlySignal<BeakSaveResult?> get saveResult => _saveResult;
  bool _ready = false;
  bool _updating = false;
  bool _disposed = false;
  final List<BeakDraftRecord> _ownedDrafts = [];
  int _sequence = 0;
  Future<BeakSaveResult?>? _activeSave;
  Future<void>? _activeRecovery;
  int _saveSequence = 0;
  int _changeVersion = 0;
  int _loadVersion = 0;
  StreamSubscription<BeakDataChange>? _mutations;
  final String _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  BeakSavePlan? _pending;
  BeakCommitDataSource? _committer;
  final Map<String, BeakDraftRecord> _operations = {};
  String _nextId() => 'draft_${++_sequence}';
  bool _navigationAllowed = false;
  bool _loaded = false;

  /// Whether editing can proceed after the initial record has loaded.
  bool get initialized => recordId == null || _loaded;

  /// Whether navigation can proceed without discarding a pending draft.
  bool get canLeave =>
      !_submitting.value && (_navigationAllowed || (!isDirty && !hasUnknown));

  /// Acknowledges a successful save or an explicit decision to leave.
  void allowExit() {
    _navigationAllowed = true;
    _notify();
  }

  /// Whether this draft contains unapplied scalar or relationship changes.
  bool get isDirty =>
      root.isDirty || _actionInputs.values.any((input) => input.isDirty);

  BeakFormSession? _indicatorOwner;

  /// Whether draft-derived indicators are enabled in a persisted edit context.
  bool get showChangeIndicators =>
      _indicatorOwner?.showChangeIndicators ??
      (root.layout.showChangeIndicators &&
          (recordId != null || root.id != null));

  final Map<String, BeakFormSession> _actionInputs = {};
  final Map<String, BeakFormActionInput> _actionInputNodes = {};
  void Function()? _onInputChanged;

  /// Session-owned argument draft for a declared inline command.
  BeakFormSession actionInput(BeakModelAction action) =>
      _actionInputs[action.name] ??
      (throw BeakConfigurationException(
        'No inline argument form for ${action.name}.',
      ));

  /// Whether the command arguments already have an inline placement.
  bool hasActionInput(BeakModelAction action) =>
      _actionInputNodes.values.any((node) => _feeds(node, action.name));

  /// Whether an inline placement supplies the arguments of the command [name].
  bool _feeds(BeakFormActionInput node, String name) =>
      node.action.name == name || node.submitWithForm?.name == name;

  /// Validates inline arguments without opening another dialog or sending a write.
  Future<BeakRecord?> actionArguments(BeakModelAction action) async {
    final node = _actionInputNodes.values.firstWhere(
      (node) => _feeds(node, action.name),
    );
    if (!root.visible(node) || !root.enabled(node)) return null;
    final input = actionInput(node.action);
    final arguments = input.root.buildRecord();
    final empty = arguments.values.values.every(
      (value) => switch (value.raw) {
        null => true,
        final String text => text.trim().isEmpty,
        _ => false,
      },
    );
    if (node.submitWithForm?.name == action.name &&
        node.optionalWithForm &&
        empty) {
      input.root.errors.clear();
      return const BeakRecord(values: {});
    }
    return await input.validate() ? input.root.buildRecord() : null;
  }

  void _clearCommittedActionInput() {
    final name = _pending?.action;
    if (name == null) return;
    for (final node in _actionInputNodes.values) {
      if (!_feeds(node, name)) continue;
      final input = actionInput(node.action);
      final unchanged = input.root.buildRecord().values.entries.every((entry) {
        final submitted = _pending?.arguments[entry.key]?.raw;
        final current = entry.value.raw;
        return current == submitted ||
            submitted == null &&
                (current == null ||
                    current is String && current.trim().isEmpty);
      });
      if (!unchanged && _pending?.arguments.values.isNotEmpty == true) continue;
      input.root._prefill(
        BeakRecord(
          values: {
            for (final column in input.model.columns)
              column.key: const BeakNullValue(),
          },
        ),
        existing: false,
      );
      input.root.errors.clear();
    }
  }

  /// Whether any write outcome remains uncertain and requires receipt recovery.
  bool get hasUnknown =>
      _saveResult.value?.outcomes.any(
        (value) => value.status == BeakWriteOutcome.unknown,
      ) ??
      false;

  void _dataChanged(BeakDataChange change) {
    repository.invalidateQueries();
    if (_disposed || _submitting.value || hasUnknown) return;
    final reload = _loaded && !isDirty && change.affects(model.table);
    for (final draft in _allDrafts()) {
      for (final input
          in draft._placements
              .map((placement) => placement.node)
              .whereType<BeakRelationInput>()) {
        if (!change.affects(input.field.target.table)) continue;
        draft._invalidateOptions(input.field.key);
        draft._hydrationAttempts.remove(input.field.key);
        draft._requestVersions[input.field.key] =
            (draft._requestVersions[input.field.key] ?? 0) + 1;
        if (!reload) {
          unawaited(draft._checkSelection(input, draft._options(input)));
        }
      }
    }
    _notify();
    if (reload) unawaited(load());
  }

  void _notify() {
    if (_ready && !_disposed) _revision.value++;
  }

  void _changed() {
    if (!_ready ||
        _disposed ||
        _updating ||
        _restoringDraft ||
        _loading.value) {
      return;
    }
    _updating = true;
    _changeVersion++;
    _navigationAllowed = false;
    try {
      var changed = true;
      var round = 0;
      while (changed) {
        if (++round > 64) {
          throw const BeakConfigurationException(
            'Cyclic derived field values in form.',
          );
        }
        changed = false;
        for (final draft in _allDrafts()) {
          if (draft.id == null || _loaded) {
            final before = draft.snapshot;
            final previous = draft._lastBehaviorRecord;
            if (previous != null) {
              for (final behavior in draft.model.behavior.values) {
                if (behavior.lifecycle == BeakValueLifecycle.suggested &&
                    behavior.field.readFrom(before) !=
                        behavior.field.readFrom(previous)) {
                  draft._manualOverrides.add(behavior.field.key);
                }
              }
            }
            final computed = draft.model.behavior.apply(
              before,
              initial: draft.id == null ? null : draft.initialRecord,
              overriddenFields: draft._manualOverrides,
            );
            for (final behavior in draft.model.behavior.values) {
              final field = behavior.field;
              if (field.readFrom(computed) != field.readFrom(before)) {
                draft.controller.setValue<Object>(
                  field.column,
                  field.readFrom(computed),
                );
                changed = true;
              }
            }
            draft._lastBehaviorRecord = draft.snapshot;
          }
          for (final input
              in draft._placements
                  .map((p) => p.node)
                  .whereType<BeakInput<Object>>()) {
            final derive = input.derive;
            if (derive == null) continue;
            final reader = BeakFormReader(draft);
            final value = derive(reader);
            draft._derivedReads[input.field.key] = reader.reads;
            _checkCycles(draft._derivedReads);
            if (draft.read(input.field) != value) {
              draft.controller.setValue<Object>(input.field.column, value);
              changed = true;
            }
          }
          draft._refreshOptions();
        }
      }
    } finally {
      _updating = false;
    }
    _notify();
    _onInputChanged?.call();
    if (drafts != null &&
        _checkedStoredDraft &&
        initialized &&
        !_restoringDraft &&
        _storedDraft == null) {
      _draftTimer?.cancel();
      _draftTimer = Timer(drafts!.debounce, persistDraft);
    }
  }

  void _checkCycles(Map<String, Set<String>> edges) {
    final visited = <String>{};
    final active = <String>{};
    void visit(String field) {
      if (active.contains(field)) {
        throw BeakConfigurationException('Cyclic derived field: $field.');
      }
      if (!visited.add(field)) return;
      active.add(field);
      for (final next in edges[field] ?? const <String>{}) {
        if (edges.containsKey(next)) visit(next);
      }
      active.remove(field);
    }

    for (final field in edges.keys) {
      visit(field);
    }
  }

  Iterable<BeakDraftRecord> _allDrafts([BeakDraftRecord? from]) sync* {
    final draft = from ?? root;
    yield draft;
    for (final child in draft._createdSelections.values) {
      yield* _allDrafts(child);
    }
    for (final child in draft._rows.values.expand((rows) => rows)) {
      if (!child.removed) yield* _allDrafts(child);
    }
  }

  List<BeakRelationLoad> _loadsFor(BeakFormNode node) => switch (node) {
    BeakTab(:final badge, :final children) => [
      ...beakWithFieldLoads(BeakQuerySpec(table: model.table), [
        ...?badge?.dependencies,
      ]).relationLoads,
      for (final child in children) ..._loadsFor(child),
    ],
    BeakCard(:final headerSubtitle, :final headerTrailing, :final children) => [
      ...beakWithFieldLoads(BeakQuerySpec(table: model.table), [
        ...?headerSubtitle?.dependencies,
        ...?headerTrailing?.dependencies,
      ]).relationLoads,
      for (final child in children) ..._loadsFor(child),
    ],
    BeakFormSummary(source: final source?, :final lines) => [
      BeakRelationLoad(
        source.key,
        nested: beakWithFieldLoads(BeakQuerySpec(table: source.target.table), [
          for (final line in lines) ...line.dependencies,
        ]).relationLoads,
      ),
    ],
    BeakFormSummary(:final lines) => beakWithFieldLoads(
      BeakQuerySpec(
        table:
            lines
                .expand((line) => line.dependencies)
                .firstOrNull
                ?.model
                .table ??
            model.table,
      ),
      [for (final line in lines) ...line.dependencies],
    ).relationLoads,
    BeakInput<Object>(:final dependencies) ||
    BeakCalculated(:final dependencies) ||
    BeakFormNotice(:final dependencies) ||
    BeakFormCapacity(:final dependencies) ||
    BeakFormMetrics(:final dependencies) => beakWithFieldLoads(
      BeakQuerySpec(
        table: dependencies.firstOrNull?.model.table ?? model.table,
      ),
      dependencies,
    ).relationLoads,
    BeakFormLinks(:final links) => beakWithFieldLoads(
      BeakQuerySpec(table: model.table),
      [for (final link in links) ...link.destination.dependencies],
    ).relationLoads,
    BeakFormProgress<Enum>(:final field, :final dependencies) =>
      beakWithFieldLoads(
        BeakQuerySpec(table: field.model.table),
        dependencies,
      ).relationLoads,
    BeakFormTimeline(
      :final field,
      :final title,
      :final time,
      :final description,
      :final actor,
      :final messageIdentity,
    ) =>
      [
        BeakRelationLoad(
          field.key,
          nested: beakWithFieldLoads(BeakQuerySpec(table: field.target.table), [
            title,
            time,
            ?description,
            ...?actor?.dependencies,
            ...?messageIdentity?.fields,
          ]).relationLoads,
        ),
      ],
    BeakFormTemplate(:final template) => beakWithFieldLoads(
      BeakQuerySpec(
        table: template.fields.firstOrNull?.model.table ?? model.table,
      ),
      template.fields,
    ).relationLoads,
    BeakFormPlaceholder(template: final template?) => beakWithFieldLoads(
      BeakQuerySpec(table: model.table),
      template.fields,
    ).relationLoads,
    BeakRelationInput(
      :final field,
      :final template,
      :final dependencies,
      :final selectionSummary,
    ) =>
      [
        if (selectionSummary != null) ..._loadsFor(selectionSummary),
        ...beakWithFieldLoads(
          BeakQuerySpec(table: field.model.table),
          dependencies,
        ).relationLoads,
        BeakRelationLoad(
          field.key,
          nested: beakWithFieldLoads(
            BeakQuerySpec(table: field.target.table),
            template?.fields ?? const [],
          ).relationLoads,
        ),
      ],
    BeakRelationTable(
      :final field,
      :final rowLayout,
      :final rowTemplate,
      :final catalog,
    ) =>
      [
        if (catalog != null) ...[
          ...beakWithFieldLoads(
            BeakQuerySpec(table: field.model.table),
            catalog.dependencies,
          ).relationLoads,
          if (catalog.notice != null) ..._loadsFor(catalog.notice!),
        ],
        BeakRelationLoad(
          field.key,
          nested: _mergeDraftLoads(
            _loadsFor(rowLayout),
            _mergeDraftLoads(
              field.target.behavior.relationLoads,
              beakWithFieldLoads(
                BeakQuerySpec(table: field.target.table),
                rowTemplate?.fields ?? const [],
              ).relationLoads,
            ),
          ),
        ),
      ],
    BeakWizardStep(:final children, :final dependencies) => [
      ...beakWithFieldLoads(
        BeakQuerySpec(table: model.table),
        dependencies,
      ).relationLoads,
      for (final child in children) ..._loadsFor(child),
    ],
    BeakSection(:final children, :final trailing) => [
      if (trailing != null)
        ...beakWithFieldLoads(
          BeakQuerySpec(table: model.table),
          trailing.dependencies,
        ).relationLoads,
      for (final child in children) ..._loadsFor(child),
    ],
    BeakFormLayout(:final children) => [
      for (final child in children) ..._loadsFor(child),
    ],
    _ => const [],
  };

  Future<void> _hydrateSelections(
    BeakDraftRecord draft,
    int loadVersion,
  ) async {
    for (final input
        in draft._placements
            .map((placement) => placement.node)
            .whereType<BeakRelationInput>()) {
      final relation = input.field.relation;
      if (relation is! BeakBelongsTo) {
        continue;
      }
      final id = draft.snapshot[relation.foreignKey]?.raw;
      if (id == null) continue;
      final draftVersion = _changeVersion;
      final includes = draft._options(input).relationLoads;
      if (draft._selected.containsKey(input.field.key) && includes.isEmpty) {
        continue;
      }
      final BeakResult<BeakRecord> result;
      if (includes.isEmpty) {
        result = await repository.getOne(input.field.target.table, id);
      } else {
        final queried = await repository.query(
          BeakQuerySpec(
            table: input.field.target.table,
            filter: BeakFieldFilter(
              column: input.field.target.primaryKey,
              operator: BeakOperator.eq,
              value: BeakValue.of(id),
            ),
            relationLoads: includes,
            pagination: const BeakPagination(perPage: 1),
          ),
        );
        result = switch (queried) {
          BeakOk(:final value) when value.items.isNotEmpty => BeakOk(
            value.items.first,
          ),
          BeakOk() => const BeakErr(
            BeakNotFoundException('The related record no longer exists.'),
          ),
          BeakErr(:final error) => BeakErr(error),
        };
      }
      if (_disposed || loadVersion != _loadVersion) return;
      if (draftVersion != _changeVersion) continue;
      switch (result) {
        case BeakOk(:final value):
          draft._selected[input.field.key] = value;
        case BeakErr(:final error):
          draft.optionErrors[input.field.key] = error;
      }
    }
    for (final row in draft._rows.values.expand((rows) => rows)) {
      await _hydrateSelections(row, loadVersion);
    }
  }

  final Map<String, Future<BeakResult<BeakAccessCapabilities>>>
  _createCapabilities = {};

  void _queueCapabilities(BeakDraftRecord draft) {
    if (repository.dataSource is! BeakCapabilityDataSource) return;
    draft._capabilities = const BeakAccessCapabilities(
      readableFields: {},
      writableFields: {},
      executableActions: {},
    );
    unawaited(_loadDraftCapabilities(draft));
  }

  Future<void> _loadDraftCapabilities(BeakDraftRecord draft) async {
    if (draft._capabilityRequest case final Future<void> active) {
      return active;
    }
    final source = repository.dataSource;
    if (source case final BeakCapabilityDataSource capable) {
      Future<BeakResult<BeakAccessCapabilities>> fetch() => repository.run(
        () => capable.capabilities(draft.model.table, id: draft.id),
      );
      final request = draft.id == null
          ? _createCapabilities.putIfAbsent(draft.model.table, fetch)
          : fetch();
      final apply = request.then((result) {
        if (_disposed || draft._disposed) return;
        switch (result) {
          case BeakOk(:final value):
            draft._capabilities = value;
          case BeakErr(:final error):
            draft._capabilities = const BeakAccessCapabilities(
              readableFields: {},
              writableFields: {},
              executableActions: {},
            );
            _error.value = error;
        }
      });
      draft._capabilityRequest = apply;
      await apply;
      draft._capabilityRequest = null;
      _notify();
    }
  }

  Future<void> _loadCapabilities() async {
    // Permissions remain record-specific. Bound parallel reads so an owned
    // collection does not serialize one network round trip per child.
    final drafts = _allDrafts().toList();
    const concurrency = 4;
    for (var offset = 0; offset < drafts.length; offset += concurrency) {
      if (_disposed) return;
      await Future.wait(
        drafts.skip(offset).take(concurrency).map(_loadDraftCapabilities),
      );
    }
  }

  /// Loads an existing record and the relationships required by its layout.
  Future<void> load() async {
    if (recordId == null) {
      if (repository.dataSource is! BeakCapabilityDataSource &&
          drafts == null) {
        _loaded = true;
        return;
      }
      _loading.value = true;
      _loaded = true;
      await _loadCapabilities();
      await _readStoredDraft();
      if (_disposed) return;
      _loading.value = false;
      _changed();
      return;
    }
    final requestVersion = ++_loadVersion;
    final draftVersion = _changeVersion;
    _loading.value = true;
    _error.value = null;
    // --8<-- [start:recordLoad]
    final result = editValues != null
        ? await repository.run(() => editValues!(recordId!))
        : await repository.run(() async {
            final page = await repository.dataSource.query(
              BeakQuerySpec(
                table: model.table,
                filter: BeakFieldFilter(
                  column: model.primaryKey,
                  operator: BeakOperator.eq,
                  value: BeakValue.of(recordId),
                ),
                relationLoads: _mergeDraftLoads(
                  _loadsFor(root.layout),
                  model.behavior.relationLoads,
                ),
                pagination: const BeakPagination(perPage: 1),
              ),
            );
            if (page.items.isEmpty) {
              throw const BeakNotFoundException('The record no longer exists.');
            }
            return page.items.first;
          });
    // --8<-- [end:recordLoad]
    if (_disposed || requestVersion != _loadVersion) return;
    if (_loaded && draftVersion != _changeVersion) {
      _loading.value = false;
      return;
    }
    switch (result) {
      case BeakOk(:final value):
        _loaded = true;
        root._prefill(value);
        await _loadCapabilities();
        await _hydrateSelections(root, requestVersion);
        if (_disposed || requestVersion != _loadVersion) return;
        _changed();
      case BeakErr(:final error):
        _error.value = error;
    }
    _loading.value = false;
    _changed();
    await _readStoredDraft();
  }

  /// Discards unapplied field, relationship and command-argument edits together.
  /// Unknown or active writes must be resolved before their drafts can be reset.
  Future<void> discardChanges() async {
    if (submitting.value || hasUnknown) return;
    root._prefill(root.initialRecord, existing: root.id != null);
    for (final input in _actionInputs.values) {
      await input.discardChanges();
    }
    _conflicts.clear();
    _saveResult.value = null;
    _error.value = null;
    await discardStoredDraft();
    _changed();
  }

  /// Reported validation issues across the live graph and inline arguments.
  int get validationIssueCount =>
      _allDrafts().fold<int>(
        0,
        (count, draft) =>
            count +
            draft.errors.values.fold<int>(
              0,
              (sum, errors) => sum + errors.length,
            ) +
            draft.controller.inputErrors.keys
                .where((key) => !draft.errors.containsKey(key))
                .length,
      ) +
      _actionInputs.values.fold<int>(
        0,
        (count, input) => count + input.validationIssueCount,
      );

  /// Validates visible placements and nested drafts, awaiting asynchronous rules.
  Future<bool> validate() async => _conflicts.isEmpty && await root.validate();

  /// Validates one wizard step without revealing errors in subsequent steps.
  Future<bool> validateStep(int step) {
    final nodes = <BeakFormNode>{};
    void walk(BeakFormNode node) {
      if (node is BeakFormLayout) {
        node.children.forEach(walk);
      } else {
        nodes.add(node);
      }
    }

    walk(steps[step]);
    return root.validate(only: nodes);
  }

  BeakRecordRef _ref(BeakDraftRecord draft) => draft.id == null
      ? BeakRecordRef.draft(draft.model.table, draft.localId)
      : BeakRecordRef.existing(draft.model.table, draft.id!);

  BeakSavePlan _plan({
    BeakModelAction? action,
    BeakRecord arguments = const BeakRecord(values: {}),
  }) {
    final operations = <BeakSaveOperation>[];
    _operations.clear();
    final visited = <BeakDraftRecord>{};
    void walk(
      BeakDraftRecord draft, {
      BeakDraftRecord? owner,
      BeakToManyField? relation,
    }) {
      if (!visited.add(draft)) return;
      final dependencies = <String>[];
      final references = <String, BeakRecordRef>{};
      for (final entry in draft._linkedReferences.entries) {
        walk(entry.value);
        references[entry.key] = _ref(entry.value);
        if (entry.value.id == null) {
          dependencies.add('${entry.value.localId}:create');
        }
      }
      final visibleRelations = <String>{
        for (final placement in draft._placements)
          if (placement.visible(BeakFormReader(draft)) &&
              draft.visible(placement.node) &&
              draft._canValidate(placement.node))
            ...switch (placement.node) {
              BeakRelationInput(:final field) => [field.key],
              BeakRelationTable(:final field, readOnly: false) => [field.key],
              _ => <String>[],
            },
      };
      for (final entry in draft._createdSelections.entries) {
        if (draft.removed || !visibleRelations.contains(entry.key)) continue;
        walk(entry.value);
        final relation = draft.model.relationshipByKey(entry.key);
        if (relation is BeakBelongsTo) {
          references[relation.foreignKey] = _ref(entry.value);
          if (entry.value.id == null) {
            dependencies.add('${entry.value.localId}:create');
          }
        }
      }
      if (owner != null && relation != null && !draft.removed) {
        if (owner.id == null) dependencies.add('${owner.localId}:create');
        if (relation.relation case BeakHasMany(:final foreignKey)) {
          references[foreignKey] = _ref(owner);
        }
      }
      final kind = draft.removed
          ? (draft.deleteRemote
                ? BeakSaveOperationKind.delete
                : BeakSaveOperationKind.detach)
          : draft.id == null
          ? BeakSaveOperationKind.create
          : BeakSaveOperationKind.update;
      final operationId = '${draft.localId}:${kind.name}';
      if ((identical(draft, root) && action != null) ||
          draft.removed ||
          draft.id == null ||
          draft.controller.isDirty ||
          references.isNotEmpty) {
        operations.add(
          BeakSaveOperation(
            id: operationId,
            kind: kind,
            target: kind == BeakSaveOperationKind.detach
                ? _ref(owner!)
                : _ref(draft),
            values: draft.removed
                ? const BeakRecord(values: {})
                : draft.buildRecord(),
            references: references,
            dependsOn: dependencies,
            owner: owner == null || kind == BeakSaveOperationKind.detach
                ? null
                : _ref(owner),
            relationKey: relation?.key,
            expectedUpdatedAt: switch (draft.initialRecord['updated_at']?.raw) {
              final DateTime value => value,
              _ => null,
            },
            related: kind == BeakSaveOperationKind.detach ? _ref(draft) : null,
          ),
        );
        _operations[operationId] = draft;
      }
      if (draft.removed) return;
      for (final entry in draft._rows.entries) {
        if (!visibleRelations.contains(entry.key)) continue;
        for (final row in entry.value) {
          walk(row, owner: draft, relation: row.relation);
          if (!row.removed &&
              row.relation?.relation is BeakBelongsToMany &&
              row._needsAttach) {
            final attachId = '${row.localId}:attach';
            operations.add(
              BeakSaveOperation(
                id: attachId,
                kind: BeakSaveOperationKind.attach,
                target: _ref(draft),
                related: _ref(row),
                relationKey: row.relation!.key,
                dependsOn: [
                  if (draft.id == null) '${draft.localId}:create',
                  if (row.id == null) '${row.localId}:create',
                ],
              ),
            );
            _operations[attachId] = row;
          }
        }
      }
    }

    walk(root);
    return BeakSavePlan(
      saveId: '$_sessionId-${++_saveSequence}',
      root: _ref(root),
      operations: operations,
      action: action?.name,
      arguments: arguments,
    );
  }

  /// Validates all steps and persists a staged graph, retaining unapplied edits.
  Future<BeakSaveResult?> save({
    BeakModelAction? action,
    BeakRecord arguments = const BeakRecord(values: {}),
  }) {
    if (_loading.value || !initialized || hasStoredDraft) {
      return Future.value(null);
    }
    if (action != null &&
        !canExecuteAction(model.behavior.action(action.name))) {
      _error.value = const BeakAuthorizationException(
        'This action is not permitted.',
      );
      return Future.value(null);
    }
    if (_activeSave != null) return _activeSave!;
    if (hasUnknown) return Future.value(_saveResult.value);
    final pending = _performSave(action: action, arguments: arguments);
    _activeSave = pending;
    return pending.whenComplete(() => _activeSave = null);
  }

  /// Whether the account and persisted workflow state permit this command.
  bool canExecuteAction(BeakModelAction action) =>
      (root.id != null || action.allowOnCreate) &&
      root.capabilities.canExecuteAction(action.name) &&
      action.isAvailable(
        root.id == null
            ? const BeakValidation().applyDefaults(model, root.snapshot)
            : root.initialRecord,
      );

  /// Executes a declared model action through the same validated graph commit.
  Future<BeakSaveResult?> executeAction(
    BeakModelAction action, {
    BeakRecord arguments = const BeakRecord(values: {}),
  }) {
    if (!canExecuteAction(model.behavior.action(action.name))) {
      _error.value = const BeakValidationException(
        'This action is unavailable in the current state.',
      );
      return Future.value(null);
    }
    return save(action: action, arguments: arguments);
  }

  Future<BeakSaveResult?> _performSave({
    BeakModelAction? action,
    required BeakRecord arguments,
  }) async {
    _submitting.value = true;
    _error.value = null;
    final result = await repository
        .run<BeakSaveResult?>(() async {
          if (!await validate()) return null;
          final plan = _plan(action: action, arguments: arguments);
          _pending = await uploader?.prepare(plan) ?? plan;
          final source = repository.dataSource;
          _committer ??= switch (source) {
            final BeakCommitDataSource capable => capable,
            _ => BeakStagedCommitDataSource(source: source, registry: registry),
          };
          await _persistPendingDraft();
          uploader?.submitted(_pending!);
          final receipt = await BeakFormCommitRepository(
            _committer!,
          ).commit(_pending!);
          uploader?.resolve(_pending!, receipt);
          return receipt;
        })
        .whenComplete(() {
          if (!_disposed) _submitting.value = false;
        });
    if (_disposed) return null;
    _submitting.value = false;
    switch (result) {
      case BeakOk(:final value):
        if (value != null) {
          _apply(value);
          await _persistSaveOutcome();
          await _refreshCommittedAction(value);
        }
        return value;
      case BeakErr(:final error):
        _error.value = error;
        await persistDraft();
        return null;
    }
  }

  /// Reconciles uncertain operations; never blindly repeats an unknown write.
  Future<void> recover() {
    if (_activeRecovery case final Future<void> active) return active;
    if (_disposed ||
        _pending == null ||
        _committer == null ||
        _submitting.value) {
      return Future<void>.value();
    }
    final future = _performRecovery().whenComplete(
      () => _activeRecovery = null,
    );
    _activeRecovery = future;
    return future;
  }

  Future<void> _performRecovery() async {
    _submitting.value = true;
    final result = await repository
        .run(() => _committer!.recover(_pending!.saveId))
        .whenComplete(() {
          if (!_disposed) _submitting.value = false;
        });
    if (result case BeakOk(:final value)) uploader?.resolve(_pending!, value);
    if (_disposed) return;
    _submitting.value = false;
    switch (result) {
      case BeakOk(:final value):
        _apply(value);
        await _persistSaveOutcome();
        await _refreshCommittedAction(value);
      case BeakErr(:final error):
        _error.value = error;
    }
  }

  Future<void> _refreshCommittedAction(BeakSaveResult result) async {
    // Commands may append history or update related records outside the local
    // graph. A receipt confirms writes, but need not contain loaded relations.
    // Never replace unsubmitted edits or reconcile an uncertain write by read.
    if (_disposed ||
        !result.complete ||
        _pending?.action == null ||
        recordId == null ||
        isDirty) {
      return;
    }
    _submitting.value = true;
    try {
      await load();
    } finally {
      if (!_disposed) {
        _submitting.value = false;
        if (!isDirty) allowExit();
      }
    }
  }

  void _apply(BeakSaveResult result) {
    _saveResult.value = result;
    for (final outcome in result.outcomes) {
      final draft = _operations[outcome.id];
      if (draft == null) continue;
      if (outcome.status == BeakWriteOutcome.applied) {
        if (outcome.id.endsWith(':attach')) {
          draft._needsAttach = false;
          continue;
        }
        if (draft.removed) {
          draft.parent?._rows[draft.relation?.key]?.remove(draft);
          draft.dispose();
        } else {
          draft.id = outcome.resolvedId ?? draft.id;
          final submitted = _pending?.operations
              .where((op) => op.id == outcome.id)
              .firstOrNull;
          // Commit responses may omit fields excluded from the submitted
          // layout. Keep their local values while accepting explicit server
          // values (including null) as the new baseline.
          final record = BeakRecord(
            values: {
              ...draft.snapshot.values,
              ...?submitted?.values.values,
              ...?outcome.record?.values,
            },
            relations: outcome.record?.relations ?? const {},
          );
          draft._initial = BeakRecord(
            values: record.values,
            relations: {...draft.snapshot.relations, ...record.relations},
          );
          draft.controller.prefill(record);
          draft.errors.clear();
        }
      } else if (outcome.error case final BeakSaveError failure) {
        draft.errors.addAll(failure.fieldErrors);
      }
    }
    // Resolve shared references before disposing their original create owners.
    for (final draft in _allDrafts()) {
      final resolved = <String>[];
      for (final entry in draft._linkedReferences.entries) {
        if (entry.value.id == null) continue;
        final relation = draft.model.relationships
            .whereType<BeakBelongsTo>()
            .firstWhere((relation) => relation.foreignKey == entry.key);
        draft._selected[relation.key] = entry.value.snapshot;
        final column = draft.model.columnByKey(entry.key);
        if (column != null && draft.controller.hasFieldFor(column)) {
          draft.controller.setValue<Object>(column, entry.value.id);
        }
        resolved.add(entry.key);
      }
      for (final key in resolved) {
        draft._linkedReferences.remove(key);
      }
    }
    for (final draft in _allDrafts()) {
      final saved = <String>[];
      for (final entry in draft._createdSelections.entries) {
        if (entry.value.id != null) {
          draft._selected[entry.key] = entry.value.snapshot;
          final relation = draft.model.relationshipByKey(entry.key);
          if (relation is BeakBelongsTo) {
            final column = draft.model.columnByKey(relation.foreignKey);
            if (column != null) {
              draft.controller.setValue<Object>(column, entry.value.id);
            }
          }
          saved.add(entry.key);
        }
      }
      for (final key in saved) {
        draft._createdSelections.remove(key)?.dispose();
      }
    }
    if (result.complete) _clearCommittedActionInput();
    _changed();
    if (result.complete && !isDirty) {
      allowExit();
    }
  }

  /// Releases controllers and subscriptions owned by this draft.
  void dispose() {
    if (_disposed) return;
    unawaited(persistDraft());
    _disposed = true;
    _uploadCleanup = () async {
      try {
        await _activeSave;
        await _activeRecovery;
      } on Exception {
        // The upload ledger retains anything whose outcome is uncertain.
      }
      return await uploader?.dispose() ?? const <BeakException>[];
    }();
    unawaited(_mutations?.cancel());
    for (final input in _actionInputs.values) {
      input.dispose();
    }
    for (final draft in _ownedDrafts) {
      draft.dispose();
    }
    _currentStep.dispose();
    _revision.dispose();
    _loading.dispose();
    _submitting.dispose();
    _error.dispose();
    _saveResult.dispose();
  }
}

extension on BeakModelRegistry {
  void registerIfMissing(BeakModel model) {
    if (byTable(model.table) == null) register(model);
  }
}

List<BeakRelationLoad> _mergeDraftLoads(
  List<BeakRelationLoad> first,
  List<BeakRelationLoad> second,
) {
  final result = <String, BeakRelationLoad>{};
  for (final load in [...first, ...second]) {
    final previous = result[load.relationKey];
    result[load.relationKey] = previous == null
        ? load
        : BeakRelationLoad(
            load.relationKey,
            filter: previous.filter,
            nested: _mergeDraftLoads(previous.nested, load.nested),
          );
  }
  return result.values.toList();
}
