import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'invoice.dart';

part 'invoice_item.beak.dart';

/// One line of an invoice.
@Resource()
final class InvoiceItem extends BeakSchema {
  /// What was bought.
  @Display()
  late final String description;

  /// How many units.
  @Column(rules: [BeakMin(1)])
  late final int quantity;

  /// Price of one unit.
  @Column(prefix: '€', precision: 2)
  late final double unitPrice;

  /// Line total.
  @Column(prefix: '€', precision: 2)
  late final double amount;

  /// The invoice the line belongs to.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Invoice invoice;
}
