import 'package:beak_core/beak_core.dart';

import '../data/worm/worm_data_source.dart';

/// One small tree a save must keep a tree: a parent link, its children, and
/// the structural rules the graph has to satisfy.
///
/// A tree rule runs inside the save transaction, ahead of the host's
/// `preparePlan`, and rejects the whole save when the proposed graph would
/// create a cycle, remove a row that still has children or references, repeat a
/// sibling value named in [sameAs], or grow deeper than [maxDepth].
///
/// Its rows are locked first (`SELECT … FOR UPDATE` on PostgreSQL), so two
/// admins moving the same branches cannot both validate against the state
/// before the other. Locks are taken in table-name order and rows in primary-key
/// order by [WormDataSource.lockRows], which keeps opposing moves from
/// deadlocking. Pass [lockRows] `false` for a tree small and cold enough that
/// the lock costs more than the race.
///
/// ```dart
/// final categories = BeakTreeRule(
///   parent: ProductCategoryModel.parent,
///   children: ProductCategoryModel.children,
///   referencedBy: [ProductModel.categoryId],
/// );
/// ```
final class BeakTreeRule {
  /// Describes the tree of [parent]'s model.
  ///
  /// [parent], [children] and every [sameAs] field belong to the same model;
  /// [referencedBy] may name fields of other models that point at it.
  BeakTreeRule({
    required this.parent,
    required this.children,
    this.sameAs = const [],
    this.maxDepth,
    this.referencedBy = const [],
    this.lockRows = true,
  }) {
    final table = parent.model.table;
    if (children.model.table != table) {
      throw BeakConfigurationException(
        'A tree rule pairs fields of one model, but "${parent.key}" belongs '
        'to $table and "${children.key}" to ${children.model.table}.',
      );
    }
    if (parent.relation is! BeakBelongsTo) {
      throw BeakConfigurationException(
        'A tree rule needs a belongs-to parent field (got "${parent.key}").',
      );
    }
    final relationship = children.relation;
    if (relationship is! BeakHasMany && relationship is! BeakHasOne) {
      throw BeakConfigurationException(
        'A tree rule needs a has-many or has-one children field (got '
        '"${children.key}").',
      );
    }
    for (final field in sameAs) {
      if (field.model.table != table) {
        throw BeakConfigurationException(
          'The tree field "${field.key}" belongs to ${field.model.table}, '
          'not $table.',
        );
      }
    }
    if (maxDepth != null && maxDepth! < 1) {
      throw const BeakConfigurationException(
        'A tree rule maxDepth is at least 1.',
      );
    }
  }

  /// The belongs-to link to the parent row, or `null` at the root.
  final BeakToOneField parent;

  /// The children collection of a row.
  final BeakToManyField children;

  /// Fields whose value must be unique among the children of one parent.
  final List<BeakScalarField<Object>> sameAs;

  /// The deepest level a row may sit at, counting the root as level 0.
  final int? maxDepth;

  /// Fields that point at a row and block deleting it while they hold it.
  final List<BeakScalarField<Object>> referencedBy;

  /// Whether a structural change locks the tree's rows first (default: yes).
  final bool lockRows;

  /// The model this rule governs.
  BeakModel get model => parent.model;

  /// The parent's foreign key column.
  String get _parentKey => switch (parent.relation) {
    BeakBelongsTo(:final foreignKey) => foreignKey,
    _ => parent.key,
  };

  /// Whether [plan] writes any row of this tree.
  bool touches(BeakSavePlan plan) => plan.operations.any(
    (operation) =>
        operation.target.table == model.table &&
        operation.kind != BeakSaveOperationKind.delete,
  );

  /// Whether [plan] changes the shape of this tree.
  bool changes(BeakSavePlan plan) => plan.operations.any((operation) {
    if (operation.target.table != model.table) return false;
    return switch (operation.kind) {
      BeakSaveOperationKind.create || BeakSaveOperationKind.delete => true,
      BeakSaveOperationKind.update =>
        operation.values.values.containsKey(_parentKey) ||
            operation.references.containsKey(_parentKey),
      _ => false,
    };
  });

  /// Validates [plan] against this tree, locking its rows first when it
  /// changes the structure.
  ///
  /// Throws a [BeakConflictException] for a delete blocked by children or
  /// references, and a [BeakValidationException] on the parent or sibling
  /// field for a cycle, an over-deep move or a repeated sibling value.
  Future<void> apply(
    BeakSavePlan plan,
    WormDataSource source,
    BeakModelRegistry registry,
    BeakPrincipal? principal,
  ) async {
    if (lockRows) await source.lockRows(model);
    await validate(plan, source, registry, principal);
  }

  /// Validates [plan] without taking the row locks first.
  ///
  /// [applyBeakTreeRules] uses this after locking every changing tree in table
  /// order.
  Future<void> validate(
    BeakSavePlan plan,
    WormDataSource source,
    BeakModelRegistry registry,
    BeakPrincipal? principal,
  ) async {
    final graph = await BeakCandidateGraph.open(
      plan: plan,
      source: source,
      registry: registry,
      authorizeRead: source.authorizeRead,
    );
    for (final node in graph.nodes.toList()) {
      if (!node.isOf(model) || !node.changed) continue;
      if (node.deleted) {
        await _validateDelete(node, graph, source);
      } else {
        await _validateShape(node, graph);
        await _validateSiblings(node, source);
      }
    }
  }

  Future<void> _validateDelete(
    BeakCandidateNode node,
    BeakCandidateGraph graph,
    WormDataSource source,
  ) async {
    final remaining = await graph.children(node, children);
    if (remaining.isNotEmpty) {
      throw BeakConflictException(
        'Move or remove the ${remaining.length == 1 ? 'child' : 'children'} '
        'of this ${model.table} record before deleting it.',
      );
    }
    final id = node.ref.id;
    if (id == null) return;
    for (final field in referencedBy) {
      final page = await source.query(
        field.model.query(
          filter: field.eq(id),
          pagination: const BeakPagination(perPage: 1),
        ),
      );
      if (page.items.isNotEmpty) {
        throw BeakConflictException(
          'A ${field.model.table} record still refers to this '
          '${model.table} record. Remove the reference before deleting it.',
        );
      }
    }
  }

  Future<void> _validateShape(
    BeakCandidateNode node,
    BeakCandidateGraph graph,
  ) async {
    final seen = <BeakRecordRef>{node.ref};
    var depth = 0;
    BeakCandidateNode? ancestor = await graph.linked(node, parent);
    while (ancestor != null) {
      depth++;
      if (!seen.add(ancestor.ref)) {
        throw parent.invalid(
          'A ${model.table} record cannot be its own ancestor.',
        );
      }
      if (ancestor.deleted) {
        throw parent.invalid('The parent record is being removed.');
      }
      ancestor = await graph.linked(ancestor, parent);
    }
    final limit = maxDepth;
    if (limit == null) return;
    final height = await _height(node, graph, <BeakRecordRef>{});
    if (depth + height > limit) {
      throw parent.invalid(
        'This move would make the tree deeper than $limit levels.',
      );
    }
  }

  Future<int> _height(
    BeakCandidateNode node,
    BeakCandidateGraph graph,
    Set<BeakRecordRef> seen,
  ) async {
    if (!seen.add(node.ref)) {
      throw parent.invalid(
        'A ${model.table} record cannot be its own ancestor.',
      );
    }
    var height = 0;
    for (final child in await graph.children(node, children)) {
      final below = await _height(child, graph, {...seen});
      if (below + 1 > height) height = below + 1;
    }
    return height;
  }

  Future<void> _validateSiblings(
    BeakCandidateNode node,
    WormDataSource source,
  ) async {
    if (sameAs.isEmpty) return;
    final values = <BeakScalarField<Object>, Object>{};
    for (final field in sameAs) {
      final value = node.read(field);
      if (value != null) values[field] = value;
    }
    if (values.isEmpty) return;
    final parentRef = node.reference(parent);
    if (parentRef != null && parentRef.id == null) return;
    final parentId = parentRef?.id;
    final page = await source.query(
      model.query(
        filter: BeakAndFilter([
          parent.equalsId(parentId),
          for (final entry in values.entries) entry.key.eq(entry.value),
        ]),
        pagination: const BeakPagination(perPage: 1),
      ),
    );
    final duplicate = page.items.firstOrNull;
    if (duplicate == null) return;
    final ownId = node.ref.id;
    if (ownId != null && model.primaryKeyOf(duplicate) == ownId) return;
    final field = values.keys.last;
    throw field.invalid(
      'Another ${model.table} record under the same parent already uses this '
      '${field.label.toLowerCase()}.',
    );
  }
}

/// Applies [rules] to [plan] in a stable order, then returns the plan.
///
/// Locks are taken for every changing tree in table-name order before any rule
/// validates, so a save that touches two trees locks them in one order.
Future<BeakSavePlan> applyBeakTreeRules(
  List<BeakTreeRule> rules,
  BeakSavePlan plan,
  WormDataSource source,
  BeakModelRegistry registry,
  BeakPrincipal? principal,
) async {
  if (rules.isEmpty) return plan;
  final touching = [
    for (final rule in rules)
      if (rule.touches(plan) || rule.changes(plan)) rule,
  ];
  final changing = [
    for (final rule in touching)
      if (rule.changes(plan)) rule,
  ]..sort((a, b) => a.model.table.compareTo(b.model.table));
  for (final rule in changing) {
    if (rule.lockRows) await source.lockRows(rule.model);
  }
  for (final rule in touching) {
    await rule.validate(plan, source, registry, principal);
  }
  return plan;
}
