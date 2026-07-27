import 'package:beak/migrations.dart';

/// Primary keys of the seeded catalog.
///
/// Fixed and uuid-shaped, so a test or a demo can name a record instead of
/// searching for it: `StoreSeedIds.productEspresso` is the same row on every
/// machine and every run.
abstract final class StoreSeedIds {
  /// The "Coffee" category.
  static const categoryCoffee = '00000000-0000-4000-8000-000000000101';

  /// The "Gear" category.
  static const categoryGear = '00000000-0000-4000-8000-000000000102';

  /// The "hot" tag.
  static const tagHot = '00000000-0000-4000-8000-000000000201';

  /// The "new" tag.
  static const tagNew = '00000000-0000-4000-8000-000000000202';

  /// The "sale" tag.
  static const tagSale = '00000000-0000-4000-8000-000000000203';

  /// Ada, the staff account.
  static const userAda = '00000000-0000-4000-8000-000000000301';

  /// Linus, the disabled customer.
  static const userLinus = '00000000-0000-4000-8000-000000000302';

  /// The espresso beans product.
  static const productEspresso = '00000000-0000-4000-8000-000000000401';

  /// The hand grinder product.
  static const productGrinder = '00000000-0000-4000-8000-000000000402';

  /// The unpublished teaser product.
  static const productTeaser = '00000000-0000-4000-8000-000000000403';

  /// The espresso beans' roast profile.
  static const roastEspresso = '00000000-0000-4000-8000-000000000501';

  /// Ada's seeded order.
  static const order1001 = '00000000-0000-4000-8000-000000000601';
}

/// Seeds a small, deterministic catalog: two categories, three tags, two
/// users, three products (tagged, categorised, one with a roast profile) and
/// one order with two lines.
///
/// Enough for the panel to be worth looking at and stable enough to assert
/// against — `dart run bin/migrate.dart db:seed` runs it.
final class StoreSeeder extends Seeder {
  /// Creates the seeder.
  const StoreSeeder();

  @override
  String get name => 'StoreSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    final DateTime now = DateTime.utc(2026, 6, 30, 9, 30);

    await insert('categories', {
      'id': StoreSeedIds.categoryCoffee,
      'name': 'Coffee',
      'blurb': 'Beans, ground and whole.',
    });
    await insert('categories', {
      'id': StoreSeedIds.categoryGear,
      'name': 'Gear',
      'blurb': 'Everything that is not a bean.',
    });

    await insert('tags', {'id': StoreSeedIds.tagHot, 'name': 'hot'});
    await insert('tags', {'id': StoreSeedIds.tagNew, 'name': 'new'});
    await insert('tags', {'id': StoreSeedIds.tagSale, 'name': 'sale'});

    await insert('users', {
      'id': StoreSeedIds.userAda,
      'name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'role': 'staff',
      'active': true,
      'created_at': now,
      'updated_at': now,
    });
    await insert('users', {
      'id': StoreSeedIds.userLinus,
      'name': 'Linus Cove',
      'email': 'linus@example.com',
      'role': 'customer',
      'active': false,
      'created_at': now,
      'updated_at': now,
    });

    await insert('products', {
      'id': StoreSeedIds.productEspresso,
      'name': 'Espresso Beans',
      'sku': 'COF-ESP-1KG',
      'summary': 'Dark roast, chocolate notes.',
      'price': 12.5,
      'stock': 42,
      'featured': true,
      'status': 'published',
      'published_at': now,
      'swatch': '#4B2E2B',
      'category_id': StoreSeedIds.categoryCoffee,
      'created_at': now,
      'updated_at': now,
    });
    await insert('products', {
      'id': StoreSeedIds.productGrinder,
      'name': 'Hand Grinder',
      'sku': 'GER-GRD-01',
      'summary': 'Steel burrs, 40 clicks.',
      'price': 89,
      'stock': 7,
      'featured': false,
      'status': 'published',
      'published_at': now,
      'category_id': StoreSeedIds.categoryGear,
      'created_at': now,
      'updated_at': now,
    });
    await insert('products', {
      'id': StoreSeedIds.productTeaser,
      'name': 'Mystery Roast',
      'sku': 'COF-MYS-1KG',
      'summary': 'Coming soon.',
      'price': 15,
      'stock': 0,
      'featured': false,
      'status': 'draft',
      'category_id': StoreSeedIds.categoryCoffee,
      'created_at': now,
      'updated_at': now,
    });

    await insert('roast_profiles', {
      'id': StoreSeedIds.roastEspresso,
      'name': 'Sunday dark',
      'level': 'dark',
      'duration_in_minutes': 14,
      'product_id': StoreSeedIds.productEspresso,
    });

    await insert('product_tag', {
      'product_id': StoreSeedIds.productEspresso,
      'tag_id': StoreSeedIds.tagHot,
    });
    await insert('product_tag', {
      'product_id': StoreSeedIds.productEspresso,
      'tag_id': StoreSeedIds.tagNew,
    });
    await insert('product_tag', {
      'product_id': StoreSeedIds.productGrinder,
      'tag_id': StoreSeedIds.tagSale,
    });

    await insert('orders', {
      'id': StoreSeedIds.order1001,
      'reference': 'ORD-1001',
      'status': 'paid',
      'total': 114,
      'placed_at': now,
      'customer_id': StoreSeedIds.userAda,
      'created_at': now,
      'updated_at': now,
    });
    await insert('order_items', {
      'id': '00000000-0000-4000-8000-000000000701',
      'label': '2× Espresso Beans',
      'quantity': 2,
      'unit_price': 12.5,
      'order_id': StoreSeedIds.order1001,
      'product_id': StoreSeedIds.productEspresso,
    });
    await insert('order_items', {
      'id': '00000000-0000-4000-8000-000000000702',
      'label': '1× Hand Grinder',
      'quantity': 1,
      'unit_price': 89,
      'order_id': StoreSeedIds.order1001,
      'product_id': StoreSeedIds.productGrinder,
    });
  }
}
