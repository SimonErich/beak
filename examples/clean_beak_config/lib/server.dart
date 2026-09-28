import 'package:beak/server.dart';

import 'domain/shop_graph_preparer.dart';

/// Adds the example's transactional shop invariants to the generated host.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: ShopGraphPreparer(defaults.registry).prepare,
  graphOnlyTables: const {
    'orders',
    'order_items',
    'invoices',
    'invoice_items',
    'invoice_vouchers',
    'products',
    'product_variants',
    'variant_attributes',
    'product_attributes',
    'category_attributes',
    'vouchers',
    'tax_rates',
  },
);
