import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'delivery_profile.beak.dart';

/// DeliveryProfile configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class DeliveryProfile extends BeakSchema {
  /// Monthly budget ledgers available for declarative previews and filtering.
  @HasMany(foreignKey: 'profile_id')
  late final List<BudgetAccount> budgets;

  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Customer.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Customer customer;

  /// Organization.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Organization? organization;

  /// Location.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final DeliveryLocation? location;

  /// Menu plan.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final MenuPlan? menuPlan;

  /// Recurring preferred delivery window start, resolved against dated slots.
  @Column()
  late final BeakTime? preferredDeliveryStart;

  /// Recurring preferred delivery window end, without a dated slot identity.
  @Column()
  late final BeakTime? preferredDeliveryEnd;

  /// Kind.
  @Column(defaultValue: 'company')
  late final String kind;

  /// Role.
  @Column(defaultValue: 'Employee')
  late final String role;

  /// Cost center.
  @Column(defaultValue: '4100 Marketing')
  late final String costCenter;

  /// Payment mode.
  @Column(defaultValue: 'monthlyInvoice')
  late final String paymentMode;

  /// Monthly budget cents.
  @Column(defaultValue: 12000, rules: [BeakMin(0)])
  late final int monthlyBudgetCents;

  /// Approval threshold cents.
  @Column(defaultValue: 4000, rules: [BeakMin(0)])
  late final int approvalThresholdCents;

  /// Approver.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final StaffMember? approver;

  /// Is default.
  @Column(defaultValue: false)
  late final bool isDefault;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
