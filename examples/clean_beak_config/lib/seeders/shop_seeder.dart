import 'package:beak/migrations.dart';

import '../domain/shop_totals.dart';

/// Stable identities shared by the demo and its integration tests.
abstract final class ShopSeedIds {
  /// Ada, with the first delivery profile.
  static const ada = '00000000-0000-4000-8000-000000000001';

  /// Linus, with a different delivery profile.
  static const linus = '00000000-0000-4000-8000-000000000002';

  /// The seeded employer.
  static const company = '00000000-0000-4000-8000-000000000003';

  /// Ada's shared address profile.
  static const home = '00000000-0000-4000-8000-000000000004';

  /// Linus's shared address profile.
  static const office = '00000000-0000-4000-8000-000000000005';

  /// Ada's association with her profile.
  static const adaProfile = '00000000-0000-4000-8000-000000000006';

  /// Linus's association with his profile.
  static const linusProfile = '00000000-0000-4000-8000-000000000007';

  /// Espresso beans, €12.50 per unit.
  static const beans = '00000000-0000-4000-8000-000000000008';

  /// A grinder, €48.00 per unit.
  static const grinder = '00000000-0000-4000-8000-000000000009';

  /// Coffee catalog category.
  static const coffeeCategory = '00000000-0000-4000-8000-000000000010';

  /// Equipment catalog category.
  static const equipmentCategory = '00000000-0000-4000-8000-000000000011';

  /// Standard illustrative exclusive tax rate.
  static const standardTax = '00000000-0000-4000-8000-000000000012';

  /// Reduced illustrative exclusive tax rate.
  static const reducedTax = '00000000-0000-4000-8000-000000000013';

  /// Zero tax rate.
  static const zeroTax = '00000000-0000-4000-8000-000000000014';

  /// Category attribute definition for roast level.
  static const roastAttribute = '00000000-0000-4000-8000-000000000015';

  /// Category attribute definition for origin.
  static const originAttribute = '00000000-0000-4000-8000-000000000016';

  /// A new catalog product with variants and attributes.
  static const filterCoffee = '00000000-0000-4000-8000-000000000017';

  /// Variant of the filter coffee.
  static const filterCoffeeLarge = '00000000-0000-4000-8000-000000000018';

  /// Smaller variant of the filter coffee.
  static const filterCoffeeSmall = '00000000-0000-4000-8000-000000000019';

  /// Percentage voucher.
  static const welcomeVoucher = '00000000-0000-4000-8000-000000000020';

  /// Fixed voucher.
  static const loyaltyVoucher = '00000000-0000-4000-8000-000000000021';

  /// Example saved invoice.
  static const invoice = '00000000-0000-4000-8000-000000000022';

  /// Confirmed example order awaiting fulfilment.
  static const order = '00000000-0000-4000-8000-000000000050';
}

/// Idempotent demonstration data. Existing rows and user edits are preserved.
final class ShopSeeder extends Seeder {
  /// Creates the deterministic demo seeder.
  const ShopSeeder();

  @override
  String get name => 'ShopSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      final id = values['id'];
      if (id == null) throw StateError('A seed row needs an identity.');
      if (await adapter.selectOne(
            QueryDescriptor(
              table: table,
              where: const Field<Object>('id').eq(id),
              limit: 1,
            ),
          ) !=
          null) {
        return;
      }
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    await insert('fulfillment_policies', {
      'id': '00000000-0000-4000-8000-000000000060',
      'name': 'Central Europe standard',
      'code': 'central-europe-standard',
      'support_email': 'dispatch@example.com',
      'support_phone': '+43 1 555 0100',
      'tracking_url': 'https://example.com/tracking',
      'currency': 'EUR',
      'delivery_fee': 490,
      'insurance_rate': 0.025,
      'maximum_weight': 20.0,
      'attachment_limit': 10485760,
      'effective_date': '2026-01-01',
      'dispatch_cutoff': '15:30:00',
      'handling_time': const Duration(hours: 24).inMicroseconds,
      'tags': '["tracked","warehouse-vienna"]',
      'regions': '["AT","DE"]',
      'signature_required': null,
      'speed': 'standard',
      'origin':
          '{"street":"1 Market Street","postal_code":"1010","city":"Vienna","email":"warehouse@example.com"}',
      'provider_options': '{"tracking":true,"labelFormat":"A6"}',
    });

    await insert('companies', {
      'id': ShopSeedIds.company,
      'name': 'Analytical Engines',
    });
    await insert('users', {
      'id': ShopSeedIds.ada,
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'email': 'ada@example.com',
      'company_id': ShopSeedIds.company,
      'invoice_company': false,
    });
    await insert('users', {
      'id': ShopSeedIds.linus,
      'first_name': 'Linus',
      'last_name': 'Cove',
      'email': 'linus@example.com',
      'company_id': null,
      'invoice_company': false,
    });
    await insert('profiles', {
      'id': ShopSeedIds.home,
      'name': 'Home',
      'address': '1 Market Street, Vienna',
    });
    await insert('profiles', {
      'id': ShopSeedIds.office,
      'name': 'Office',
      'address': '20 Ring Road, Vienna',
    });
    await insert('user_profile_connections', {
      'id': ShopSeedIds.adaProfile,
      'name': 'Ada — Home',
      'user_id': ShopSeedIds.ada,
      'profile_id': ShopSeedIds.home,
    });
    await insert('user_profile_connections', {
      'id': ShopSeedIds.linusProfile,
      'name': 'Linus — Office',
      'user_id': ShopSeedIds.linus,
      'profile_id': ShopSeedIds.office,
    });
    await insert('products', {
      'id': ShopSeedIds.beans,
      'name': 'Espresso Beans',
      'price': 12.5,
    });
    await insert('products', {
      'id': ShopSeedIds.grinder,
      'name': 'Hand Grinder',
      'price': 48.0,
    });

    await insert('categories', {
      'id': ShopSeedIds.coffeeCategory,
      'name': 'Specialty coffee',
      'description': 'Single origin beans, blends and seasonal roasts.',
    });
    await insert('categories', {
      'id': ShopSeedIds.equipmentCategory,
      'name': 'Brewing equipment',
      'description': 'Tools for better coffee at home.',
    });
    for (final (id, name, rate) in [
      (ShopSeedIds.standardTax, 'Standard — 20%', 20.0),
      (ShopSeedIds.reducedTax, 'Reduced — 10%', 10.0),
      (ShopSeedIds.zeroTax, 'Zero rate', 0.0),
    ]) {
      await insert('tax_rates', {
        'id': id,
        'name': name,
        'rate_percent': rate,
        'active': true,
      });
    }
    await insert('category_attributes', {
      'id': ShopSeedIds.roastAttribute,
      'name': 'Roast level',
      'value_type': 'choice',
      'choices': 'Light, Medium, Dark',
      'required': true,
      'category_id': ShopSeedIds.coffeeCategory,
    });
    await insert('category_attributes', {
      'id': ShopSeedIds.originAttribute,
      'name': 'Origin',
      'value_type': 'text',
      'required': false,
      'category_id': ShopSeedIds.coffeeCategory,
    });
    await insert('products', {
      'id': ShopSeedIds.filterCoffee,
      'name': 'Ethiopia — Yirgacheffe',
      'sku': 'COF-ETH',
      'description':
          'Floral washed coffee with citrus notes. Prices are net of exclusive tax.',
      'price': 14.5,
      'active': true,
      'category_id': ShopSeedIds.coffeeCategory,
      'tax_rate_id': ShopSeedIds.standardTax,
    });
    await insert('product_attributes', {
      'id': '00000000-0000-4000-8000-000000000023',
      'name': 'Roast level',
      'value': 'Light',
      'definition_id': ShopSeedIds.roastAttribute,
      'product_id': ShopSeedIds.filterCoffee,
    });
    await insert('product_attributes', {
      'id': '00000000-0000-4000-8000-000000000024',
      'name': 'Origin',
      'value': 'Ethiopia',
      'definition_id': ShopSeedIds.originAttribute,
      'product_id': ShopSeedIds.filterCoffee,
    });
    await insert('product_variants', {
      'id': ShopSeedIds.filterCoffeeSmall,
      'name': '250 g · Whole bean',
      'sku': 'COF-ETH-250',
      'price': 14.5,
      'stock': 48,
      'active': true,
      'product_id': ShopSeedIds.filterCoffee,
    });
    await insert('product_variants', {
      'id': ShopSeedIds.filterCoffeeLarge,
      'name': '1 kg · Whole bean',
      'sku': 'COF-ETH-1000',
      'price': 49.0,
      'stock': 12,
      'active': true,
      'product_id': ShopSeedIds.filterCoffee,
    });
    await insert('variant_attributes', {
      'id': '00000000-0000-4000-8000-000000000025',
      'name': 'Package size',
      'value': '1 kg',
      'variant_id': ShopSeedIds.filterCoffeeLarge,
    });
    await insert('variant_attributes', {
      'id': '00000000-0000-4000-8000-000000000026',
      'name': 'Grind',
      'value': 'Whole bean',
      'variant_id': ShopSeedIds.filterCoffeeLarge,
    });
    await insert('variant_attributes', {
      'id': '00000000-0000-4000-8000-000000000027',
      'name': 'Package size',
      'value': '250 g',
      'variant_id': ShopSeedIds.filterCoffeeSmall,
    });
    await insert('vouchers', {
      'id': ShopSeedIds.welcomeVoucher,
      'code': 'WELCOME10',
      'name': 'Welcome discount',
      'kind': 'percentage',
      'value': 10.0,
      'active': true,
      'minimum_subtotal': 10.0,
      'maximum_discount': 25.0,
    });
    await insert('vouchers', {
      'id': ShopSeedIds.loyaltyVoucher,
      'code': 'LOYAL5',
      'name': 'Loyalty credit',
      'kind': 'fixed',
      'value': 5.0,
      'active': true,
    });
    // Preserve an administrator's status, delivery date and line edits on rerun.
    if (await adapter.selectOne(
          QueryDescriptor(
            table: 'orders',
            where: const Field<String>('id').eq(ShopSeedIds.order),
            limit: 1,
          ),
        ) ==
        null) {
      await insert('orders', {
        'id': ShopSeedIds.order,
        'reference': 'ORD-DEMO-2026-001',
        'status': 'confirmed',
        'customer_id': ShopSeedIds.ada,
        'profile_id': ShopSeedIds.adaProfile,
        'delivery_date': DateTime.now().toUtc().add(const Duration(days: 3)),
        'notes':
            'Pack two bags of whole-bean coffee. Deliver to the home profile.',
      });
      await insert('order_items', {
        'id': '00000000-0000-4000-8000-000000000051',
        'order_id': ShopSeedIds.order,
        'product_id': ShopSeedIds.filterCoffee,
        'variant_id': ShopSeedIds.filterCoffeeSmall,
        'tax_rate_id': ShopSeedIds.standardTax,
        'label': 'Ethiopia Yirgacheffe — 250 g · Whole bean',
        'quantity': 2,
        'discount': 0.0,
      });
      await insert('order_items', {
        'id': '00000000-0000-4000-8000-000000000052',
        'order_id': ShopSeedIds.order,
        'tax_rate_id': ShopSeedIds.standardTax,
        'label': 'Local delivery',
        'quantity': 1,
        'overwrite_price': 4.5,
        'discount': 0.0,
      });
    }
    // Do not reconstruct an invoice graph that an administrator already edited.
    if (await adapter.selectOne(
          QueryDescriptor(
            table: 'invoices',
            where: const Field<String>('id').eq(ShopSeedIds.invoice),
            limit: 1,
          ),
        ) !=
        null) {
      return;
    }
    final totals = ShopTotals.calculate(
      lines: const [
        ShopLineInput(
          id: 'coffee',
          label: 'Ethiopia — 1 kg · Whole bean',
          quantity: 2,
          unitPriceCents: 4900,
          taxBasisPoints: 2000,
        ),
        ShopLineInput(
          id: 'service',
          label: 'Barista setup consultation',
          quantity: 1,
          unitPriceCents: 2500,
          taxBasisPoints: 1000,
        ),
      ],
      vouchers: const [
        ShopVoucherInput.percentage(
          id: ShopSeedIds.welcomeVoucher,
          code: 'WELCOME10',
          basisPoints: 1000,
        ),
        ShopVoucherInput.fixed(
          id: ShopSeedIds.loyaltyVoucher,
          code: 'LOYAL5',
          amountCents: 500,
        ),
      ],
    );
    await insert('invoices', {
      'id': ShopSeedIds.invoice,
      'number': 'INV-DEMO-2026-001',
      'status': 'issued',
      'customer_id': ShopSeedIds.ada,
      'issued_at': DateTime.utc(2026, 9, 15),
      'due_at': DateTime.utc(2026, 9, 29),
      'customer_name': 'Ada Lovelace',
      'customer_email': 'ada@example.com',
      'customer_address': '1 Market Street, Vienna',
      'subtotal_cents': totals.subtotalCents,
      'discount_cents': totals.discountCents,
      'tax_cents': totals.taxCents,
      'total_cents': totals.totalCents,
    });
    for (var index = 0; index < totals.lines.length; index++) {
      final line = totals.lines[index];
      await insert('invoice_items', {
        'id': '00000000-0000-4000-8000-00000000003${index + 1}',
        'invoice_id': ShopSeedIds.invoice,
        'label': line.input.label,
        'quantity': line.input.quantity,
        'unit_price': line.input.unitPriceCents / 100,
        'discount': 0.0,
        'tax_rate_id': index == 0
            ? ShopSeedIds.standardTax
            : ShopSeedIds.reducedTax,
        'tax_percent': line.input.taxBasisPoints / 100,
        'net_cents': line.netCents,
        'tax_cents': line.taxCents,
        'total_cents': line.totalCents,
        if (index == 0) 'product_id': ShopSeedIds.filterCoffee,
        if (index == 0) 'variant_id': ShopSeedIds.filterCoffeeLarge,
      });
    }
    for (var index = 0; index < totals.vouchers.length; index++) {
      final voucher = totals.vouchers[index];
      await insert('invoice_vouchers', {
        'id': '00000000-0000-4000-8000-00000000004${index + 1}',
        'invoice_id': ShopSeedIds.invoice,
        'voucher_id': voucher.input.id,
        'position': index,
        'code_snapshot': voucher.input.code,
        'discount_cents': voucher.discountCents,
      });
    }
  }
}
