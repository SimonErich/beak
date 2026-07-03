import 'package:worm/worm.dart';

/// Deterministic primary keys of the seeded catalog — UUID-shaped (the
/// tables use real `uuid` columns) but fixed, so tests and demos can
/// reference records by name.
abstract final class ReferenceSeedIds {
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

  /// Ada, the active customer.
  static const userAda = '00000000-0000-4000-8000-000000000301';

  /// Linus, the disabled customer.
  static const userLinus = '00000000-0000-4000-8000-000000000302';

  /// The espresso beans product.
  static const productEspresso = '00000000-0000-4000-8000-000000000401';

  /// The hand grinder product.
  static const productGrinder = '00000000-0000-4000-8000-000000000402';

  /// The unpublished teaser product.
  static const productTeaser = '00000000-0000-4000-8000-000000000403';

  /// Ada's seeded order.
  static const order1001 = '00000000-0000-4000-8000-000000000601';
}

/// Seeds a small, deterministic catalog: two categories, three tags, two
/// users, three products (tagged and categorized), and one order with two
/// line items — enough data for the panel and the E2E flow to be
/// meaningful, stable enough to assert against.
final class ReferenceSeeder extends Seeder {
  /// Creates the seeder.
  const ReferenceSeeder();

  @override
  String get name => 'ReferenceSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    await insert('categories', {
      'id': ReferenceSeedIds.categoryCoffee,
      'name': 'Coffee',
    });
    await insert('categories', {
      'id': ReferenceSeedIds.categoryGear,
      'name': 'Gear',
    });

    await insert('tags', {'id': ReferenceSeedIds.tagHot, 'name': 'hot'});
    await insert('tags', {'id': ReferenceSeedIds.tagNew, 'name': 'new'});
    await insert('tags', {'id': ReferenceSeedIds.tagSale, 'name': 'sale'});

    await insert('users', {
      'id': ReferenceSeedIds.userAda,
      'name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'active': true,
    });
    await insert('users', {
      'id': ReferenceSeedIds.userLinus,
      'name': 'Linus Cove',
      'email': 'linus@example.com',
      'active': false,
    });

    await insert('products', {
      'id': ReferenceSeedIds.productEspresso,
      'name': 'Espresso Beans',
      'description': 'Dark roast, chocolate notes.',
      'price': 12.5,
      'stock': 42,
      'status': 'published',
      'category_id': ReferenceSeedIds.categoryCoffee,
    });
    await insert('products', {
      'id': ReferenceSeedIds.productGrinder,
      'name': 'Hand Grinder',
      'description': 'Steel burrs, 40 clicks.',
      'price': 89.0,
      'stock': 7,
      'status': 'published',
      'category_id': ReferenceSeedIds.categoryGear,
    });
    await insert('products', {
      'id': ReferenceSeedIds.productTeaser,
      'name': 'Mystery Roast',
      'description': 'Coming soon.',
      'price': 15.0,
      'stock': 0,
      'status': 'draft',
      'category_id': ReferenceSeedIds.categoryCoffee,
    });

    await insert('product_tag', {
      'product_id': ReferenceSeedIds.productEspresso,
      'tag_id': ReferenceSeedIds.tagHot,
    });
    await insert('product_tag', {
      'product_id': ReferenceSeedIds.productEspresso,
      'tag_id': ReferenceSeedIds.tagNew,
    });
    await insert('product_tag', {
      'product_id': ReferenceSeedIds.productGrinder,
      'tag_id': ReferenceSeedIds.tagSale,
    });

    await insert('orders', {
      'id': ReferenceSeedIds.order1001,
      'reference': 'ORD-1001',
      'total': 114.0,
      'placed_at': DateTime.utc(2026, 6, 30, 9, 30),
      'user_id': ReferenceSeedIds.userAda,
    });
    await insert('order_items', {
      'id': '00000000-0000-4000-8000-000000000701',
      'label': '2× Espresso Beans',
      'quantity': 2,
      'unit_price': 12.5,
      'order_id': ReferenceSeedIds.order1001,
      'product_id': ReferenceSeedIds.productEspresso,
    });
    await insert('order_items', {
      'id': '00000000-0000-4000-8000-000000000702',
      'label': '1× Hand Grinder',
      'quantity': 1,
      'unit_price': 89.0,
      'order_id': ReferenceSeedIds.order1001,
      'product_id': ReferenceSeedIds.productGrinder,
    });
  }
}
