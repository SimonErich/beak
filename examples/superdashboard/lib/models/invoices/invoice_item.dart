import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'invoice.dart';

part 'invoice_item.beak.dart';

/// The invoice-items resource — one line of an invoice.
@Resource()
final class InvoiceItem extends BeakSchema {
  /// The owning invoice.
  @BelongsTo()
  late final Invoice? invoice;

  /// Line item name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(160)])
  late final String item;

  /// Line description.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? description;

  /// Unit price in dollars.
  @Column(prefix: r'$', rules: [BeakMin(0)])
  late final double price;

  /// Quantity billed.
  @Column(label: 'Qty', min: 1, rules: [BeakMin(1)])
  late final int quantity;

  /// Line total in dollars.
  @Column(prefix: r'$', sortable: true)
  late final double? total;
}
