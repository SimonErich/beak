import 'package:beak/server.dart';

import 'domain/shop_graph_preparer.dart';
import 'resources/categories/models/category_attribute.dart';
import 'resources/invoices/models/invoice.dart';
import 'resources/invoices/models/invoice_item.dart';
import 'resources/invoices/models/invoice_voucher.dart';
import 'resources/orders/models/order.dart';
import 'resources/orders/models/order_item.dart';
import 'resources/products/models/product.dart';
import 'resources/products/models/product_attribute.dart';
import 'resources/products/models/product_variant.dart';
import 'resources/products/models/variant_attribute.dart';
import 'resources/taxes/models/tax_rate.dart';
import 'resources/vouchers/models/voucher.dart';

/// Adds the example's transactional shop invariants to the generated host.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: ShopGraphPreparer(defaults.registry).prepare,
  graphOnly: const [
    OrderModel(),
    OrderItemModel(),
    InvoiceModel(),
    InvoiceItemModel(),
    InvoiceVoucherModel(),
    ProductModel(),
    ProductVariantModel(),
    VariantAttributeModel(),
    ProductAttributeModel(),
    CategoryAttributeModel(),
    VoucherModel(),
    TaxRateModel(),
  ],
);
