import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the skills resource.
abstract final class SkillColumns {
  /// Skill name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [SharedColumns.id, name];
}

/// Typed relationships of the skills resource.
abstract final class SkillRelations {
  /// Users who have this skill, via the `user_skill` pivot.
  static const users = BeakBelongsToMany(
    key: 'users',
    label: 'Users',
    relatedTable: 'users',
    displayColumnKey: 'name',
    pivotTable: 'user_skill',
    foreignPivotKey: 'skill_id',
    relatedPivotKey: 'user_id',
    searchColumnKeys: ['name'],
  );
}

/// The skills resource — a small lookup of competencies.
final class SkillModel extends BeakModel {
  /// Creates the skills model.
  const SkillModel();

  @override
  String get table => 'skills';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => SkillColumns.values;

  @override
  List<BeakRelationship> get relationships => const [SkillRelations.users];
}
