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
  @Column(prefix: '€', rules: [BeakMin(0)])
  late final double? unitPrice;

  /// Net reduction on the whole line, before vouchers.
  @Column(prefix: '€', rules: [BeakMin(0)])
  late final double? discount;

  /// Optional selected rate; blank uses the product rate or zero.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final TaxRate? taxRate;

  /// Saved percentage independent of subsequent tax-rate changes.
  @Column(visibleOn: {BeakContext.detail})
  late final double? taxPercent;

  /// Saved net line amount after vouchers, in cents.
  @Column(visibleOn: {BeakContext.detail})
  late final int? netCents;

  /// Saved rounded tax amount, in cents.
  @Column(visibleOn: {BeakContext.detail})
  late final int? taxCents;

  /// Saved line payable amount, in cents.
  @Column(visibleOn: {BeakContext.detail})
  late final int? totalCents;

  /// Owning invoice.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Invoice invoice;
}
