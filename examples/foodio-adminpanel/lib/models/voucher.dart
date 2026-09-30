import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'voucher.beak.dart';

/// Voucher configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class Voucher extends BeakSchema {
  /// The date range has the same rule in the form and on direct API writes.
  static List<BeakRecordRule> get validationRules => [
    BeakAfterField(
      VoucherModel.validUntil,
      VoucherModel.validFrom,
      inclusive: true,
    ),
  ];

  /// Code.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String code;

  /// Description.
  @Column(defaultValue: '')
  late final String? description;

  /// Percent basis points.
  @Column(defaultValue: 1500, rules: [BeakMin(0), BeakMax(10000)])
  late final int percentBasisPoints;

  /// Maximum discount cents.
  @Column(defaultValue: 1000, rules: [BeakMin(0)])
  late final int maximumDiscountCents;

  /// Food only.
  @Column(defaultValue: true)
  late final bool foodOnly;

  /// Valid from.
  @Column(sortable: true, filterable: true)
  late final BeakDate? validFrom;

  /// Valid until.
  @Column(sortable: true, filterable: true)
  late final BeakDate? validUntil;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
