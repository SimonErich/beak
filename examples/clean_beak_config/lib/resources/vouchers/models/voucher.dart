import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'voucher.beak.dart';

/// How a voucher reduces the remaining net subtotal.
enum VoucherKind {
  /// A fixed euro amount.
  fixed,

  /// A percentage of the remaining net subtotal.
  percentage,
}

/// A reusable discount definition; applied invoices retain their own snapshot.
@Resource()
final class Voucher extends BeakSchema {
  /// Inclusive start and exclusive end are validated everywhere.
  static List<BeakRecordRule> get validationRules => [
    BeakAfterField(VoucherModel.endsAt, VoucherModel.startsAt),
  ];

  /// Code entered by an administrator or customer.
  @Display()
  @Column(searchable: true, sortable: true, unique: true)
  late final String code;

  /// Human-readable description.
  @Column(searchable: true)
  late final String name;

  /// Fixed euro value or percentage reduction.
  @Column(defaultValue: VoucherKind.fixed)
  late final VoucherKind kind;

  /// Euro amount for fixed vouchers, percentage for percentage vouchers.
  @Column(rules: [BeakMin(0)])
  late final double value;

  /// Whether new invoices may use this voucher.
  late final bool active;

  /// Optional first eligible instant, inclusive.
  late final DateTime? startsAt;

  /// Optional last eligible instant, exclusive.
  late final DateTime? endsAt;

  /// Minimum net subtotal before vouchers, in euros.
  @Column(prefix: '€', rules: [BeakMin(0)])
  late final double? minimumSubtotal;

  /// Optional cap on this voucher's discount, in euros.
  @Column(prefix: '€', rules: [BeakMin(0)])
  late final double? maximumDiscount;
}
