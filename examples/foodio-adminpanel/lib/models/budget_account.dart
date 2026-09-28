import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'budget_account.beak.dart';

/// BudgetAccount configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class BudgetAccount extends BeakSchema {
  /// Each profile has one authoritative ledger per billing month.
  static List<BeakRecordRule> get validationRules => [
    BeakUnique(
      BudgetAccountModel.period,
      scope: [BudgetAccountModel.profileId],
    ),
  ];

  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Profile.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final DeliveryProfile profile;

  /// Period.
  @Column(
    rules: [
      BeakPattern(
        r'^\d{4}-(0[1-9]|1[0-2])$',
        message: 'Use a month in YYYY-MM format.',
      ),
    ],
  )
  late final String period;

  /// Allowance cents.
  @Column(defaultValue: 12000, rules: [BeakMin(0)])
  late final int allowanceCents;

  /// Reserved cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int reservedCents;

  /// Spent cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int spentCents;
}
