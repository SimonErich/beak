import '../behavior/beak_model_behavior.dart';
import '../columns/beak_semantic.dart';
import '../common/beak_exception.dart';
import '../model/beak_field_ref.dart';
import '../model/beak_model.dart';
import '../model/beak_model_registry.dart';
import '../query/beak_record.dart';
import '../relations/beak_relationship.dart';
import '../validation/beak_validation.dart';
import 'beak_candidate_graph.dart';
import 'beak_commit.dart';
import 'beak_data_source.dart';

/// Which owned collections and additional fields a duplicate should reset.
final class BeakDuplicationSpec {
  /// Shared references are retained; owned collection copies are explicit.
  const BeakDuplicationSpec({
    this.relations = const [],
    this.reset = const [],
    this.includeNestedOwned = true,
  });

  /// Root-owned collections to copy with new identities.
  final List<BeakToManyField> relations;

  /// Additional typed fields to clear, on the root or copied child models.
  final List<BeakScalarField<Object>> reset;

  /// Copy owned descendants of selected collections recursively.
  final bool includeNestedOwned;
}

/// Unsaved result: suitable for a configured create form or the commit boundary.
final class BeakDuplicateDraft {
  /// Creates a draft description without performing persistence.
  const BeakDuplicateDraft({required this.record, required this.plan});

  /// Prefill record with new owned rows and no copied identities.
  final BeakRecord record;

  /// Equivalent create graph. Required unique fields may still need user input.
  final BeakSavePlan plan;
}

/// Copies records through the same typed graph seam used for ordinary edits.
final class BeakRecordDuplicator {
  /// Binds the authorized source and model metadata.
  const BeakRecordDuplicator({required this.source, required this.registry});

  /// Read provider; its normal authorization remains in force.
  final BeakDataSource source;

  /// Metadata describing fields, ownership, defaults and value lifecycles.
  final BeakModelRegistry registry;

  /// Creates a draft from the current stored record without saving any changes.
  ///
  /// Identity, timestamps, soft-delete markers, unique columns, secrets,
  /// snapshots, initial values and derived values are cleared. Initial values
  /// are then regenerated. Ordinary values and shared foreign keys are retained.
  Future<BeakDuplicateDraft> duplicate(
    BeakModel model,
    BeakRecord record, {
    required String saveId,
    BeakDuplicationSpec spec = const BeakDuplicationSpec(),
  }) async {
    final id = model.primaryKeyOf(record);
    if (id == null) {
      throw const BeakConfigurationException(
        'Only a stored record can be duplicated.',
      );
    }
    for (final field in spec.relations) {
      final relation = field.relation;
      if (field.model.table != model.table ||
          field.path.isNotEmpty ||
          relation is! BeakHasMany ||
          !relation.owned) {
        throw const BeakConfigurationException(
          'Duplicate collections must be root-owned has-many relationships.',
        );
      }
    }
    for (final field in spec.reset) {
      if (field.path.isNotEmpty ||
          registry.byTableOrThrow(field.model.table).columnByKey(field.key) ==
              null) {
        throw const BeakConfigurationException(
          'Duplicate reset fields must be registered root fields.',
        );
      }
    }
    final graph = await BeakCandidateGraph.open(
      plan: BeakSavePlan(
        saveId: saveId,
        root: BeakRecordRef.existing(model.table, id),
        operations: [],
      ),
      source: source,
      registry: registry,
      maxNodes: 1000,
    );
    final operations = <BeakSaveOperation>[];
    final ancestors = <BeakRecordRef>{};
    var counter = 0;
    Future<(BeakRecordRef, BeakRecord)> copy(
      BeakCandidateNode node, {
      BeakRecordRef? owner,
      BeakRelationship? ownerRelation,
      List<BeakRelationship>? selected,
    }) async {
      if (!ancestors.add(node.ref)) {
        throw const BeakConfigurationException(
          'Owned duplication contains a cycle.',
        );
      }
      final model = node.model;
      final reset = {
        model.primaryKey.key,
        'created_at',
        'updated_at',
        'deleted_at',
        for (final column in model.columns)
          if (column.unique ||
              column.semantic.kind == BeakSemanticKind.password)
            column.key,
        for (final value in model.behavior.values)
          if (value.lifecycle != BeakValueLifecycle.suggested) value.field.key,
        for (final action in model.behavior.actions)
          for (final value in action.values)
            if (value.field.column.defaultValue != null) value.field.key,
        for (final field in spec.reset)
          if (field.model.table == model.table) field.key,
        if (ownerRelation
            case BeakHasMany(:final foreignKey) ||
                BeakHasOne(:final foreignKey))
          foreignKey,
      };
      var draft = BeakRecord(
        values: {
          for (final entry in node.values.entries)
            if (!reset.contains(entry.key)) entry.key: entry.value,
        },
      );
      draft = model.behavior.initialize(
        const BeakValidation().applyDefaults(model, draft),
      );
      final ref = BeakRecordRef.draft(model.table, '$saveId:copy:${counter++}');
      final relations = <String, List<BeakRecord>>{};
      operations.add(
        BeakSaveOperation(
          id: ref.draftId!,
          kind: BeakSaveOperationKind.create,
          target: ref,
          values: draft,
          owner: owner,
          relationKey: ownerRelation?.key,
        ),
      );
      final children =
          selected ??
          (spec.includeNestedOwned
              ? [
                  for (final relation in model.relationships)
                    if (relation is BeakHasMany && relation.owned ||
                        relation is BeakHasOne && relation.owned)
                      relation,
                ]
              : <BeakRelationship>[]);
      for (final relation in children) {
        final target = registry.byTableOrThrow(relation.relatedTable);
        final rows = switch (relation) {
          BeakHasMany() => await graph.children(
            node,
            BeakToManyField(model: model, relation: relation, target: target),
          ),
          BeakHasOne() => [
            ?await graph.linked(
              node,
              BeakToOneField(model: model, relation: relation, target: target),
            ),
          ],
          _ => throw const BeakConfigurationException(
            'Only owned relationships may be duplicated.',
          ),
        };
        relations[relation.key] = [
          for (final child in rows)
            (await copy(child, owner: ref, ownerRelation: relation)).$2,
        ];
      }
      ancestors.remove(node.ref);
      return (ref, BeakRecord(values: draft.values, relations: relations));
    }

    final (root, duplicate) = await copy(
      await graph.load(graph.plan.root),
      selected: [for (final field in spec.relations) field.relation],
    );
    final plan = BeakSavePlan(
      saveId: saveId,
      root: root,
      operations: operations,
    );
    plan.orderedOperations(registry);
    return BeakDuplicateDraft(record: duplicate, plan: plan);
  }
}
