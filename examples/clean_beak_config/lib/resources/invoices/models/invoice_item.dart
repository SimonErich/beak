import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'invoice.dart';
import '../../products/models/product.dart';
import '../../products/models/product_variant.dart';
import '../../taxes/models/tax_rate.dart';
part 'invoice_item.beak.dart';

/// One invoice line; catalog references are optional for custom work.
@Resource()
final class InvoiceItem extends BeakSchema {
  /// Custom lines require their own description and price; variants match products.
  static List<BeakRecordRule> get validationRules => [
    BeakRequiredIf(
      InvoiceItemModel.label,
      when: BeakWhen.present(InvoiceItemModel.productId).not,
      message: 'Describe this custom item.',
    ),
    BeakRequiredIf(
      InvoiceItemModel.unitPrice,
      when: BeakWhen.present(InvoiceItemModel.productId).not,
      message: 'Enter a price for this custom item.',
    ),
    BeakExists(
      InvoiceItemModel.variantId,
      ProductVariantModel.id,
      matching: [
        BeakFieldMatch(
          target: ProductVariantModel.productId,
          source: InvoiceItemModel.productId,
        ),
      ],
    ),
  ];

  /// Saved description; required for a custom line, otherwise catalog-derived.
  @Display()
  late final String? label;

  /// Whole units sold.
  @Column(rules: [BeakMin(1)])
  late final int quantity;

  /// Optional catalog product.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Product? product;

  /// Optional variant belonging to the selected product.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final ProductVariant? variant;

  /// Net unit price; blank derives a catalog price before saving.
  @Column(
    semantic: BeakSemantic.money(currency: 'EUR'),
    rules: [BeakMin(0)],
  )
  late final BeakDecimal? unitPrice;

  /// Net reduction on the whole line, before vouchers.
  @Column(
    semantic: BeakSemantic.money(currency: 'EUR'),
    rules: [BeakMin(0)],
  )
  late final BeakDecimal? discount;

  /// Optional selected rate; blank uses the product rate or zero.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final TaxRate? taxRate;

  /// Saved percentage independent of subsequent tax-rate changes.
  @Column(
    suffix: '%',
    semantic: BeakSemantic.exactDecimal(scale: 2),
    visibleOn: {BeakContext.detail},
  )
  late final BeakDecimal? taxPercent;

  /// Saved net line amount after vouchers.
  @Column(
    semantic: BeakSemantic.money(currency: 'EUR'),
    visibleOn: {BeakContext.detail},
  )
  late final BeakDecimal? net;

  /// Saved rounded tax amount.
  @Column(
    semantic: BeakSemantic.money(currency: 'EUR'),
    visibleOn: {BeakContext.detail},
  )
  late final BeakDecimal? tax;

  /// Saved line payable amount.
  @Column(
    semantic: BeakSemantic.money(currency: 'EUR'),
    visibleOn: {BeakContext.detail},
  )
  late final BeakDecimal? total;

  /// Owning invoice.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Invoice invoice;
}
