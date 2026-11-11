import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// Visibility predicate shared by queries, relations and conditional writes.
PredicateTree beakSoftDeletePredicate(
  BeakModel model, {
  bool deleted = false,
  String? qualifier,
}) {
  final flag = model.isDeletedColumnKey;
  return LeafNode(
    Predicate(
      fieldName: flag ?? model.deletedAtColumnKey,
      tableName: qualifier,
      operator: flag != null
          ? Operator.eq
          : (deleted ? Operator.isNotNull : Operator.isNull),
      value: flag != null ? deleted : null,
    ),
  );
}

/// Values kept together when a model is deleted or restored.
Map<String, Object?> beakSoftDeleteValues(
  BeakModel model,
  DateTime? instant,
) => {
  model.deletedAtColumnKey: instant?.toUtc(),
  if (model.isDeletedColumnKey case final String flag) flag: instant != null,
};

/// Model-specific soft-delete scope lifted by worm's withTrashed operation.
final class BeakSoftDeleteScope extends GlobalScope<Model> {
  /// Binds visibility to the model's lifecycle keys.
  const BeakSoftDeleteScope(this.model);

  /// Model whose deleted rows this scope hides.
  final BeakModel model;

  @override
  String get name => 'soft_deletes';
  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) =>
      builder.where(beakSoftDeletePredicate(model));
}
