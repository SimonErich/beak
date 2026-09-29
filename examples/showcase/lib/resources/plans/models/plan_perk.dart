import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'plan.dart';

part 'plan_perk.beak.dart';

/// One line in a plan's feature list.
@Resource()
final class PlanPerk extends BeakSchema {
  /// What the sponsor gets.
  @Display()
  late final String label;

  /// The plan that includes it.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Plan plan;
}
