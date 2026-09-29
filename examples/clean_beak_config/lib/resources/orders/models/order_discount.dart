import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'order.dart';

part 'order_discount.beak.dart';

/// OrderDiscount schema; all metadata and typed helpers are generated.
@Resource()
final class OrderDiscount extends BeakSchema {
  /// Explanation shown on the order.
  @Display()
  late final String reason;

  /// Reduction, exact and in euros.
  @Column(
    semantic: BeakSemantic.money(currency: 'EUR'),
    rules: [BeakMin(0)],
  )
  late final BeakDecimal amount;

  /// Owning order; wired automatically on final save.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Order order;
}
