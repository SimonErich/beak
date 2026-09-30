import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'organization.beak.dart';

/// Organization configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class Organization extends BeakSchema {
  /// Collective invoices let order previews identify an existing draft period.
  @HasMany(foreignKey: 'organization_id')
  late final List<Invoice> invoices;

  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Legal name.
  @Column(searchable: true)
  late final String legalName;

  /// Billing email.
  @Column(rules: [BeakEmail()])
  late final String billingEmail;

  /// Billing address.
  late final String billingAddress;

  /// Invoice frequency.
  @Column(defaultValue: 'monthly')
  late final String invoiceFrequency;

  /// Cost centers.
  @Column(defaultValue: '4100 Marketing,4200 Sales,1100 Administration')
  late final String costCenters;

  /// Default budget cents.
  @Column(defaultValue: 12000, rules: [BeakMin(0)])
  late final int defaultBudgetCents;

  /// Approval threshold cents.
  @Column(defaultValue: 4000, rules: [BeakMin(0)])
  late final int approvalThresholdCents;

  /// Approver.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final StaffMember? approver;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
