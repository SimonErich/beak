import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'plan_perk.dart';

part 'plan.beak.dart';

/// A sponsorship plan, drawn by the pricing block.
@Resource()
final class Plan extends BeakSchema {
  /// The plan's name.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// A one-line pitch.
  late final String tagline;

  /// Monthly price.
  @Column(prefix: '€', precision: 2, rules: [BeakMin(0)])
  late final double monthlyPrice;

  /// Yearly price.
  @Column(prefix: '€', precision: 2, rules: [BeakMin(0)])
  late final double yearlyPrice;

  /// Whether to highlight the plan.
  late final bool featured;

  /// What the plan includes.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<PlanPerk> perks;
}
