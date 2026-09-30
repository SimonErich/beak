import 'dart:collection';

import '../common/beak_exception.dart';
import '../model/beak_field_ref.dart';
import '../model/beak_field_value.dart';
import '../model/beak_model.dart';
import '../model/beak_model_registry.dart';
import '../query/beak_filter.dart';
import '../query/beak_operator.dart';
import '../query/beak_pagination.dart';
import '../query/beak_query_spec.dart';
import '../query/beak_record.dart';
import '../query/beak_relation_load.dart';
import '../query/beak_value.dart';
import '../relations/beak_relationship.dart';
import 'beak_commit.dart';
import 'beak_data_source.dart';

/// One proposed record, with its original snapshot and unresolved draft links.
final class BeakCandidateNode {
  BeakCandidateNode._(this.ref, this.model, this.initial)
    : _values = {...?initial?.values};

  /// Existing or local identity, stable throughout preparation.
  final BeakRecordRef ref;

  /// Metadata of this record.
  final BeakModel model;

  /// Stored values before this transaction, absent for a new record.
  final BeakRecord? initial;
  final Map<String, BeakValue> _values;
  final Map<String, BeakRecordRef> _references = {};
  BeakSaveOperation? _write;
  bool _changed = false;
  bool _deleted = false;
  BeakRecordRef? _owner;
  String? _relationKey;

  /// Proposed scalar values. Use [read] for typed access.
  Map<String, BeakValue> get values => UnmodifiableMapView(_values);

  /// Proposed scalar record. [BeakCandidateGraph.materialize] loads relations.
  BeakRecord get record => BeakRecord(values: Map.unmodifiable(_values));

  /// Whether this node is a record of [model].
  bool isOf(BeakModel model) => ref.isOf(model);

  /// Whether the request or a calculation affects this node.
  bool get changed => _changed;

  /// Whether the final graph removes this record.
  bool get deleted => _deleted;

  /// Reads a root scalar value without string keys or casts.
  T? read<T extends Object>(BeakScalarField<T> field) {
    _check(field);
    return field.readFrom(record);
  }

  /// Reads the persisted value before this transaction.
  T? original<T extends Object>(BeakScalarField<T> field) {
    _check(field);
    return initial == null ? null : field.readFrom(initial!);
  }

  /// Resolves a belongs-to identity, including newly created draft records.
  BeakRecordRef? reference(BeakToOneField field) {
    _check(field);
    final relation = field.relation;
    if (relation is! BeakBelongsTo) {
      throw const BeakConfigurationException(
        'A reference requires belongs-to metadata.',
      );
    }
    return _reference(relation.foreignKey, relation.relatedTable);
  }

  /// The stored belongs-to identity before this transaction.
  BeakRecordRef? originalReference(BeakToOneField field) {
    _check(field);
    final relation = field.relation;
    if (relation is! BeakBelongsTo) {
      throw const BeakConfigurationException(
        'A reference requires belongs-to metadata.',
      );
    }
    final id = initial?[relation.foreignKey]?.raw;
    return id == null
        ? null
        : BeakRecordRef.existing(relation.relatedTable, id);
  }

  /// Whether a scalar or belongs-to changed, including draft selections.
  bool hasChanged(BeakFieldRef<Object> field) {
    _check(field);
    return switch (field) {
      BeakToOneField() => reference(field) != originalReference(field),
      _ => record[field.key] != initial?[field.key],
    };
  }

  /// Whether substantive scalar content changed, ignoring known computed fields.
  bool materiallyChanged({Iterable<BeakFieldRef<Object>> except = const []}) {
    if (deleted || initial == null) return changed;
    final ignored = {for (final field in except) field.key};
    return _values.entries.any(
          (entry) =>
              !ignored.contains(entry.key) &&
              entry.value != initial?[entry.key],
        ) ||
        _references.entries.any(
          (entry) =>
              !ignored.contains(entry.key) &&
              (entry.value.draftId != null ||
                  entry.value.id != initial?[entry.key]?.raw),
        );
  }

  BeakRecordRef? _reference(String key, String table) {
    final reference = _references[key];
    if (reference != null && reference.table != table) {
      throw BeakConfigurationException(
        'Relationship "$key" must reference "$table".',
      );
    }
    return reference ??
        switch (_values[key]?.raw) {
          final Object id => BeakRecordRef.existing(table, id),
          null => null,
        };
  }

  void _check(BeakFieldRef<Object> field) {
    if (field.model.table != ref.table || field.path.isNotEmpty) {
      throw BeakConfigurationException(
        'Use a root field of ${ref.table} on this candidate.',
      );
    }
  }
}

/// A transaction-local view of existing records overlaid with all proposed writes.
///
/// Reads are cached; children include new drafts and exclude detached/deleted
/// rows. No writes execute here. [build] returns the enriched immutable plan for
/// normal authorization, validation and transactional persistence.
final class BeakCandidateGraph {
  BeakCandidateGraph._({
    required this.plan,
    required this.source,
    required this.registry,
    required this.maxNodes,
    this.authorizeRead,
  });

  /// Loads request operations and resolves their ownership metadata.
  static Future<BeakCandidateGraph> open({
    required BeakSavePlan plan,
    required BeakDataSource source,
    required BeakModelRegistry registry,
    int maxNodes = 10000,
    Future<void> Function(BeakRecordRef ref)? authorizeRead,
  }) async {
    plan.orderedOperations(registry);
    final graph = BeakCandidateGraph._(
      plan: plan,
      source: source,
      registry: registry,
      maxNodes: maxNodes,
      authorizeRead: authorizeRead,
    );
    for (final op in plan.orderedOperations(registry)) {
      final node = await graph.load(op.target);
      node._changed = true;
      if (op.kind == BeakSaveOperationKind.delete) node._deleted = true;
      if (op.kind == BeakSaveOperationKind.create ||
          op.kind == BeakSaveOperationKind.update) {
        node._write = op;
        node._values.addAll(op.values.values);
        node._references.addAll(op.references);
        for (final entry in op.references.entries) {
          if (entry.value.id != null) {
            node._values[entry.key] = BeakValue.of(entry.value.id);
          }
        }
      }
      if (op.owner case final owner?) {
        node._owner = owner;
        node._relationKey = op.relationKey;
        final relation = registry
            .byTableOrThrow(owner.table)
            .relationshipByKey(op.relationKey!);
        final foreignKey = switch (relation) {
          BeakHasMany(:final foreignKey) ||
          BeakHasOne(:final foreignKey) => foreignKey,
          _ => null,
        };
        if (foreignKey != null && op.kind == BeakSaveOperationKind.create) {
          node._references[foreignKey] = owner;
          if (owner.id != null) {
            node._values[foreignKey] = BeakValue.of(owner.id);
          }
        }
      }
      if (op.kind == BeakSaveOperationKind.attach ||
          op.kind == BeakSaveOperationKind.detach) {
        final related = await graph.load(op.related!);
        final relation = node.model.relationshipByKey(op.relationKey!);
        if (relation is BeakHasMany) {
          related._references.remove(relation.foreignKey);
          related._values[relation.foreignKey] = const BeakNullValue();
          if (op.kind == BeakSaveOperationKind.attach) {
            related._references[relation.foreignKey] = op.target;
            if (op.target.id != null) {
              related._values[relation.foreignKey] = BeakValue.of(op.target.id);
            }
          }
          related._changed = true;
        }
      }
    }
    return graph;
  }

  /// Original immutable request.
  final BeakSavePlan plan;

  /// Transaction-bound read source. The context never mutates it directly.
  final BeakDataSource source;

  /// Registry used for typed relationships and draft identities.
  final BeakModelRegistry registry;

  /// Maximum loaded graph size; oversized preparation fails explicitly.
  final int maxNodes;

  /// Optional authoritative read check, invoked for every existing node.
  final Future<void> Function(BeakRecordRef ref)? authorizeRead;
  final Map<BeakRecordRef, BeakCandidateNode> _nodes = {};
  final Map<String, BeakSaveOperation> _replacements = {};
  final Map<BeakRecordRef, BeakSaveOperation> _additions = {};

  /// Loaded nodes, including request deletions, as an unmodifiable snapshot:
  /// loading more nodes while iterating it is safe.
  Iterable<BeakCandidateNode> get nodes => List.unmodifiable(_nodes.values);

  /// Loads a stored or request-local identity exactly once.
  Future<BeakCandidateNode> load(BeakRecordRef ref) async {
    if (_nodes[ref] case final cached?) return cached;
    final model = registry.byTableOrThrow(ref.table);
    if (_nodes.length >= maxNodes) {
      throw const BeakValidationException('The proposed graph is too large.');
    }
    if (ref.id != null) await authorizeRead?.call(ref);
    final initial = ref.id == null
        ? null
        : await source.getOne(ref.table, ref.id!);
    if (ref.id != null && initial == null) {
      throw BeakNotFoundException(
        'The ${ref.table} record is no longer available.',
      );
    }
    if (ref.draftId != null &&
        !plan.operations.any(
          (op) => op.kind == BeakSaveOperationKind.create && op.target == ref,
        )) {
      throw const BeakConfigurationException(
        'The draft is not declared in this plan.',
      );
    }
    return _nodes[ref] = BeakCandidateNode._(ref, model, initial);
  }

  /// Reads a typed to-one relationship from the proposed graph.
  Future<BeakCandidateNode?> linked(
    BeakCandidateNode node,
    BeakToOneField field,
  ) async {
    node._check(field);
    final rows = await _related(node, field.relation);
    return rows.firstOrNull;
  }

  /// Reads the final collection, including additions and excluding removals.
  Future<List<BeakCandidateNode>> children(
    BeakCandidateNode node,
    BeakToManyField field, {
    bool includeDeleted = false,
  }) async {
    node._check(field);
    final rows = await _related(
      node,
      field.relation,
      includeDeleted: includeDeleted,
    );
    return List.unmodifiable(rows);
  }

  Future<List<BeakCandidateNode>> _related(
    BeakCandidateNode parent,
    BeakRelationship relation, {
    bool includeDeleted = false,
  }) async {
    if (relation is BeakBelongsTo) {
      final ref = parent._reference(relation.foreignKey, relation.relatedTable);
      if (ref == null) return [];
      final node = await load(ref);
      return node.deleted && !includeDeleted ? [] : [node];
    }
    final foreignKey = switch (relation) {
      BeakHasMany(:final foreignKey) ||
      BeakHasOne(:final foreignKey) => foreignKey,
      _ => null,
    };
    final selected = <BeakRecordRef>{};
    if (parent.ref.id case final id?) {
      if (foreignKey != null) {
        var page = 1;
        while (true) {
          final result = await source.query(
            BeakQuerySpec(
              table: relation.relatedTable,
              filter: BeakFieldFilter.forKey(
                foreignKey,
                BeakOperator.eq,
                BeakValue.of(id),
              ),
              pagination: BeakPagination(page: page, perPage: 100),
            ),
          );
          for (final row in result.items) {
            final model = registry.byTableOrThrow(relation.relatedTable);
            final ref = BeakRecordRef.existing(
              model.table,
              model.primaryKeyOf(row)!,
            );
            await load(ref);
          }
          if (page * 100 >= result.total || result.items.isEmpty) break;
          page++;
        }
      } else {
        final result = await source.query(
          parent.model.query(
            filter: BeakFieldFilter(
              column: parent.model.primaryKey,
              operator: BeakOperator.eq,
              value: BeakValue.of(id),
            ),
            relationLoads: [BeakRelationLoad(relation.key)],
            pagination: const BeakPagination(perPage: 1),
          ),
        );
        for (final row
            in result.items.firstOrNull?.relations[relation.key] ??
                <BeakRecord>[]) {
          final model = registry.byTableOrThrow(relation.relatedTable);
          final ref = BeakRecordRef.existing(
            model.table,
            model.primaryKeyOf(row)!,
          );
          await load(ref);
          selected.add(ref);
        }
      }
    }
    if (foreignKey != null) {
      for (final node in _nodes.values) {
        if (node.ref.table == relation.relatedTable &&
            node._reference(foreignKey, parent.ref.table) == parent.ref) {
          selected.add(node.ref);
        }
      }
    } else {
      for (final op in plan.operations.where(
        (op) =>
            op.target == parent.ref &&
            op.relationKey == relation.key &&
            op.related != null,
      )) {
        if (op.kind == BeakSaveOperationKind.attach) selected.add(op.related!);
        if (op.kind == BeakSaveOperationKind.detach) {
          selected.remove(op.related);
        }
      }
    }
    final result = [
      for (final ref in selected)
        if (includeDeleted || !_nodes[ref]!.deleted) _nodes[ref]!,
    ];
    for (final node in result) {
      if (foreignKey != null) {
        node._owner ??= parent.ref;
        node._relationKey ??= relation.key;
      }
    }
    return result;
  }

  /// Loads the original or proposed owner of an explicitly owned child.
  /// The same parent guard applies even when a child is edited as its own resource.
  Future<List<BeakCandidateNode>> owners(BeakCandidateNode node) =>
      parents(node, ownedOnly: true);

  /// Existing and proposed inverse parents, including non-owned collections.
  Future<List<BeakCandidateNode>> parents(
    BeakCandidateNode node, {
    bool ownedOnly = false,
  }) async {
    final refs = <BeakRecordRef>{};
    if (node._owner case final owner?) {
      final relation = registry
          .byTableOrThrow(owner.table)
          .relationshipByKey(node._relationKey!);
      if (!ownedOnly ||
          relation is BeakHasMany && relation.owned ||
          relation is BeakHasOne && relation.owned) {
        refs.add(owner);
      }
    }
    for (final model in registry.all) {
      for (final relation in model.relationships) {
        final foreignKey = switch (relation) {
          BeakHasMany(:final owned, :final foreignKey) ||
          BeakHasOne(
            :final owned,
            :final foreignKey,
          ) when owned || !ownedOnly => foreignKey,
          _ => null,
        };
        if (foreignKey == null || relation.relatedTable != node.ref.table) {
          continue;
        }
        final proposed = node._reference(foreignKey, model.table);
        if (proposed != null) refs.add(proposed);
        final original = node.initial?[foreignKey]?.raw;
        if (original != null) {
          refs.add(BeakRecordRef.existing(model.table, original));
        }
      }
    }
    return [for (final ref in refs) await load(ref)];
  }

  /// Candidate nodes read along declared dependency paths.
  Future<List<BeakCandidateNode>> dependencies(
    BeakCandidateNode node,
    Iterable<BeakFieldRef<Object>> fields,
  ) async {
    final result = <BeakRecordRef, BeakCandidateNode>{};
    Future<void> visit(
      BeakCandidateNode current,
      List<BeakRelationship> path,
    ) async {
      if (path.isEmpty) return;
      for (final related in await _related(current, path.first)) {
        result[related.ref] = related;
        await visit(related, path.sublist(1));
      }
    }

    for (final field in fields) {
      await visit(node, [
        ...field.path,
        if (field is BeakToOneField) field.relation,
        if (field is BeakToManyField) field.relation,
      ]);
    }
    return result.values.toList();
  }

  /// Original dependencies, without overlaying changes from this transaction.
  Future<BeakRecord?> materializeInitial(
    BeakCandidateNode node, {
    Iterable<BeakFieldRef<Object>> fields = const [],
  }) async {
    if (node.initial == null) return null;
    final paths = <List<BeakRelationship>>[
      for (final field in fields)
        [
          ...field.path,
          if (field is BeakToOneField) field.relation,
          if (field is BeakToManyField) field.relation,
        ],
    ];
    return _initial(node, paths.where((path) => path.isNotEmpty).toList());
  }

  Future<BeakRecord> _initial(
    BeakCandidateNode node,
    List<List<BeakRelationship>> paths,
  ) async {
    final grouped = <String, List<List<BeakRelationship>>>{};
    for (final path in paths) {
      grouped.putIfAbsent(path.first.key, () => []).add(path);
    }
    final relations = <String, List<BeakRecord>>{};
    for (final entry in grouped.entries) {
      final relation = entry.value.first.first;
      final rows = <BeakCandidateNode>[];
      if (relation is BeakBelongsTo) {
        final id = node.initial?[relation.foreignKey]?.raw;
        if (id != null) {
          rows.add(
            await load(BeakRecordRef.existing(relation.relatedTable, id)),
          );
        }
      } else if (node.ref.id != null) {
        final result = await source.query(
          node.model.query(
            filter: BeakFieldFilter(
              column: node.model.primaryKey,
              operator: BeakOperator.eq,
              value: BeakValue.of(node.ref.id),
            ),
            relationLoads: [BeakRelationLoad(relation.key)],
            pagination: const BeakPagination(perPage: 1),
          ),
        );
        for (final row
            in result.items.firstOrNull?.relations[relation.key] ??
                <BeakRecord>[]) {
          final target = registry.byTableOrThrow(relation.relatedTable);
          rows.add(
            await load(
              BeakRecordRef.existing(target.table, target.primaryKeyOf(row)!),
            ),
          );
        }
      }
      relations[entry.key] = [
        for (final child in rows)
          await _initial(child, [
            for (final path in entry.value)
              if (path.length > 1) path.sublist(1),
          ]),
      ];
    }
    return BeakRecord(values: node.initial!.values, relations: relations);
  }

  /// Writes a typed scalar; each generated operation is still authorized on commit.
  void write<T extends Object>(
    BeakCandidateNode node,
    BeakScalarField<T> field,
    T? value,
  ) {
    node._check(field);
    patch(node, BeakRecord(values: {field.key: field.encode(value)}));
  }

  /// Changes a belongs-to link, retaining request-local identities until commit.
  ///
  /// The target draft must already have a create operation in this graph. Both
  /// the target and this generated write retain normal commit authorization.
  void link(
    BeakCandidateNode node,
    BeakToOneField field,
    BeakRecordRef? target,
  ) {
    node._check(field);
    final relation = field.relation;
    if (relation is! BeakBelongsTo || node.deleted) {
      throw const BeakConfigurationException(
        'A link requires a live record and a belongs-to relationship.',
      );
    }
    if (target != null &&
        (target.table != relation.relatedTable ||
            target.draftId != null &&
                !plan.operations.any(
                  (op) =>
                      op.kind == BeakSaveOperationKind.create &&
                      op.target == target,
                ))) {
      throw const BeakConfigurationException(
        'The linked target must match the relationship and declare its draft.',
      );
    }
    if (node.reference(field) == target) return;
    final key = relation.foreignKey;
    node._values[key] = BeakValue.of(target?.id);
    if (target == null) {
      node._references.remove(key);
    } else {
      node._references[key] = target;
    }
    node._changed = true;
    final original = node._write;
    final previous = original == null
        ? _additions[node.ref]
        : _replacements[original.id] ?? original;
    final operation = BeakSaveOperation(
      id: previous?.id ?? _nextId(),
      kind: previous?.kind ?? BeakSaveOperationKind.update,
      target: node.ref,
      values: BeakRecord(
        values: {...?previous?.values.values, key: BeakValue.of(target?.id)},
      ),
      references: {...?previous?.references, key: ?target}
        ..removeWhere((entryKey, _) => entryKey == key && target == null),
      dependsOn: previous?.dependsOn ?? const [],
      owner: previous?.owner ?? node._owner,
      relationKey: previous?.relationKey ?? node._relationKey,
      related: previous?.related,
      expectedUpdatedAt: previous?.expectedUpdatedAt,
    );
    if (original == null) {
      _additions[node.ref] = operation;
    } else {
      _replacements[original.id] = operation;
    }
  }

  /// Writes several typed scalars at once.
  ///
  /// Every field must be a root field of [node]'s model; build the pairs with
  /// [BeakScalarField.to].
  void writeAll(BeakCandidateNode node, Iterable<BeakFieldValue> values) {
    for (final value in values) {
      node._check(value.field);
    }
    patch(node, node.model.record(values));
  }

  /// Returns [fields] to their persisted values, or clears them on a new record.
  ///
  /// The way a preparer keeps server-derived columns from being edited.
  void restore(
    BeakCandidateNode node,
    Iterable<BeakScalarField<Object>> fields,
  ) {
    for (final field in fields) {
      node._check(field);
    }
    patch(
      node,
      BeakRecord(
        values: {
          for (final field in fields)
            field.key: node.initial?[field.key] ?? const BeakNullValue(),
        },
      ),
    );
  }

  /// Applies a typed record patch. Prefer [write] for individual fields.
  void patch(BeakCandidateNode node, BeakRecord patch) {
    if (node.deleted) {
      throw const BeakConfigurationException(
        'Cannot patch a deleted candidate.',
      );
    }
    for (final key in patch.values.keys) {
      if (node.model.columnByKey(key) == null) {
        throw BeakConfigurationException('Unknown field "$key".');
      }
    }
    final changed = {
      for (final entry in patch.values.entries)
        if (node._values[entry.key] != entry.value) entry.key: entry.value,
    };
    if (changed.isEmpty) return;
    node._values.addAll(changed);
    for (final key in changed.keys) {
      node._references.remove(key);
    }
    node._changed = true;
    final original = node._write;
    final previous = original == null
        ? _additions[node.ref]
        : _replacements[original.id] ?? original;
    final operation = BeakSaveOperation(
      id: previous?.id ?? _nextId(),
      kind: previous?.kind ?? BeakSaveOperationKind.update,
      target: node.ref,
      values: BeakRecord(values: {...?previous?.values.values, ...changed}),
      references: {
        for (final entry
            in previous?.references.entries ??
                <MapEntry<String, BeakRecordRef>>[])
          if (!changed.containsKey(entry.key)) entry.key: entry.value,
      },
      dependsOn: previous?.dependsOn ?? const [],
      owner: previous?.owner ?? node._owner,
      relationKey: previous?.relationKey ?? node._relationKey,
      related: previous?.related,
      expectedUpdatedAt: previous?.expectedUpdatedAt,
    );
    if (original == null) {
      _additions[node.ref] = operation;
    } else {
      _replacements[original.id] = operation;
    }
  }

  String _nextId() {
    var number = _additions.length;
    final occupied = {
      for (final op in plan.operations) op.id,
      for (final op in _additions.values) op.id,
    };
    while (occupied.contains('beak-derived-$number')) {
      number++;
    }
    return 'beak-derived-$number';
  }

  /// Loads only declared dependency paths and overlays their proposed values.
  Future<BeakRecord> materialize(
    BeakCandidateNode node, {
    Iterable<BeakFieldRef<Object>> fields = const [],
  }) async {
    final paths = <List<BeakRelationship>>[
      for (final field in fields)
        [
          ...field.path,
          if (field is BeakToOneField) field.relation,
          if (field is BeakToManyField) field.relation,
        ],
    ];
    return _materialize(node, paths.where((path) => path.isNotEmpty).toList());
  }

  Future<BeakRecord> _materialize(
    BeakCandidateNode node,
    List<List<BeakRelationship>> paths,
  ) async {
    final grouped = <String, List<List<BeakRelationship>>>{};
    for (final path in paths) {
      grouped.putIfAbsent(path.first.key, () => []).add(path);
    }
    final relations = <String, List<BeakRecord>>{};
    for (final entry in grouped.entries) {
      final relation = entry.value.first.first;
      final rows = await _related(node, relation);
      relations[entry.key] = [
        for (final child in rows)
          await _materialize(child, [
            for (final path in entry.value)
              if (path.length > 1) path.sublist(1),
          ]),
      ];
    }
    return BeakRecord(values: node.record.values, relations: relations);
  }

  // --8<-- [start:BeakCandidateGraphBuild]
  /// Builds a new plan while preserving command, retry and operation identities.
  BeakSavePlan build() => BeakSavePlan(
    saveId: plan.saveId,
    root: plan.root,
    action: plan.action,
    arguments: plan.arguments,
    operations: [
      for (final op in plan.operations) _replacements[op.id] ?? op,
      ..._additions.values,
    ],
  );
  // --8<-- [end:BeakCandidateGraphBuild]
}
