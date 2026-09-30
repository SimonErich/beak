import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'invoice.dart';
import '../../vouchers/models/voucher.dart';
part 'invoice_voucher.beak.dart';

/// One ordered voucher application and its captured result.
@Resource()
final class InvoiceVoucher extends BeakSchema {
  /// Voucher selected from the reusable catalog.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Voucher voucher;

  /// Application order; ties use a stable row identity.
  @Column(rules: [BeakMin(0)])
  late final int position;

  /// Code captured when the invoice is saved.
  @Display()
  @Column(visibleOn: {BeakContext.detail})
  late final String? codeSnapshot;

  /// Reduction actually applied.
  @Column(
    semantic: BeakSemantic.money(currency: 'EUR'),
    visibleOn: {BeakContext.detail},
  )
  late final BeakDecimal? discount;

  /// Owning invoice.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Invoice invoice;
}
