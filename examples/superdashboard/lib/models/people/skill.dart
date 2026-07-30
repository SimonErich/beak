import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'user.dart';

part 'skill.beak.dart';

/// The skills resource — a small lookup of competencies.
@Resource()
final class Skill extends BeakSchema {
  /// Skill name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(60)])
  late final String name;

  /// Users who have this skill, via the `user_skill` pivot.
  @BelongsToMany(pivotTable: 'user_skill')
  late final List<User> users;
}
