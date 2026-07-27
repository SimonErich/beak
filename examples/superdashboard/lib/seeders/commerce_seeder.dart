import 'package:superdashboard/models/models.dart';

import 'seed_context.dart';

/// Seeds the Commerce domain: catalog, ~100 orders with line items, and a
/// settling transaction for each paid order — the raw material the analytics
/// seeder rolls up.
final class CommerceSeeder {
  /// Creates the seeder.
  const CommerceSeeder();

  static const List<String> _categoryNames = [
    'Coffee',
    'Gear',
    'Apparel',
    'Books',
    'Electronics',
  ];

  static const List<String> _tagNames = [
    'new',
    'hot',
    'sale',
    'limited',
    'eco',
    'premium',
  ];

  static const List<String> _productNames = [
    'Espresso Beans',
    'Hand Grinder',
    'Pour-Over Kettle',
    'Cold Brew Jar',
    'Travel Mug',
    'Canvas Tote',
    'Merino Beanie',
    'Field Notebook',
    'Desk Lamp',
    'Wireless Earbuds',
    'Mechanical Keyboard',
    'Standing Desk Mat',
    'Ceramic Pour Set',
    'Barista Apron',
    'Roasters Handbook',
  ];

  /// Seeds all Commerce-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final categoryIds = await _seedLookups(ctx, 'categories', _categoryNames);
    final tagIds = await _seedLookups(ctx, 'tags', _tagNames);
    final products = await _seedProducts(ctx, categoryIds, tagIds);
    await _seedOrders(ctx, products);
  }

  Future<List<String>> _seedLookups(
    SeedContext ctx,
    String table,
    List<String> names,
  ) async {
    final ids = <String>[];
    final rows = <Map<String, Object?>>[];
    for (final name in names) {
      final id = ctx.uuid();
      ids.add(id);
      rows.add({'id': id, 'name': name});
    }
    await ctx.insertMany(table, rows);
    return ids;
  }

  Future<List<({String id, double price})>> _seedProducts(
    SeedContext ctx,
    List<String> categoryIds,
    List<String> tagIds,
  ) async {
    final products = <({String id, double price})>[];
    final productRows = <Map<String, Object?>>[];
    final pivotRows = <Map<String, Object?>>[];

    for (var index = 0; index < _productNames.length; index++) {
      final id = ctx.uuid();
      final price = ctx.money(9, 320);
      products.add((id: id, price: price));
      productRows.add({
        'id': id,
        'name': _productNames[index],
        'sku': 'SKU-${1000 + index}',
        'description': ctx.faker.paragraph(sentenceCount: 2),
        'price': price,
        'cost': double.parse((price * 0.55).toStringAsFixed(2)),
        'stock': ctx.between(0, 240),
        'status': ctx.weighted({
          ProductStatus.published.name: 8,
          ProductStatus.draft.name: 2,
          ProductStatus.scheduled.name: 1,
          ProductStatus.inactive.name: 1,
        }),
        'image': ctx.faker.imageUrl(width: 480, height: 480),
        'category_id': ctx.pick(categoryIds),
        'created_at': ctx.daysAgo(400),
        'updated_at': ctx.daysAgo(30),
      });
      final tags = <String>{};
      final tagCount = ctx.between(1, 3);
      while (tags.length < tagCount) {
        tags.add(ctx.pick(tagIds));
      }
      for (final tagId in tags) {
        pivotRows.add({'product_id': id, 'tag_id': tagId});
      }
    }
    await ctx.insertMany('products', productRows);
    await ctx.insertMany('product_tag', pivotRows);
    return products;
  }

  Future<void> _seedOrders(
    SeedContext ctx,
    List<({String id, double price})> products,
  ) async {
    final users = await ctx.selectAll('users');
    final userIds = [for (final user in users) user['id']! as String];

    final orderRows = <Map<String, Object?>>[];
    final itemRows = <Map<String, Object?>>[];
    final txRows = <Map<String, Object?>>[];

    for (var index = 0; index < 100; index++) {
      final orderId = ctx.uuid();
      final userId = ctx.pick(userIds);
      // Within the 12-month chart window so every order lands in a bucket.
      final placedAt = ctx.daysAgo(330);

      var subtotal = 0.0;
      final lineCount = ctx.between(1, 3);
      for (var line = 0; line < lineCount; line++) {
        final product = ctx.pick(products);
        final quantity = ctx.between(1, 4);
        final lineTotal = product.price * quantity;
        subtotal += lineTotal;
        itemRows.add({
          'id': ctx.uuid(),
          'label': '$quantity× ${_productNames[products.indexOf(product)]}',
          'quantity': quantity,
          'unit_price': product.price,
          'order_id': orderId,
          'product_id': product.id,
        });
      }
      subtotal = double.parse(subtotal.toStringAsFixed(2));
      final shipping = ctx.money(0, 20);
      final tax = double.parse((subtotal * 0.1).toStringAsFixed(2));
      final total = double.parse(
        (subtotal + shipping + tax).toStringAsFixed(2),
      );

      final status = ctx.weighted({
        OrderStatus.delivered.name: 8,
        OrderStatus.shipped.name: 4,
        OrderStatus.processing.name: 3,
        OrderStatus.pending.name: 2,
        OrderStatus.cancelled.name: 1,
        OrderStatus.refunded.name: 1,
      });
      final settled =
          status == OrderStatus.delivered.name ||
          status == OrderStatus.shipped.name;
      final source = ctx.weighted({
        PurchaseChannel.direct.name: 5,
        PurchaseChannel.search.name: 4,
        PurchaseChannel.social.name: 3,
        PurchaseChannel.email.name: 2,
        PurchaseChannel.affiliate.name: 1,
      });

      orderRows.add({
        'id': orderId,
        'reference': 'ORD-${2000 + index}',
        'user_id': userId,
        'status': status,
        'payment_status': settled
            ? PaymentStatus.paid.name
            : PaymentStatus.pending.name,
        'source': source,
        'subtotal': subtotal,
        'shipping': shipping,
        'tax': tax,
        'total': total,
        'placed_at': placedAt,
      });

      if (settled) {
        final brand = ctx.pick(CardBrand.values);
        txRows.add({
          'id': ctx.uuid(),
          'reference': 'TXN-${5000 + index}',
          'user_id': userId,
          'order_id': orderId,
          'method': ctx.weighted({
            PaymentMethod.card.name: 6,
            PaymentMethod.paypal.name: 2,
            PaymentMethod.wallet.name: 1,
            PaymentMethod.bankTransfer.name: 1,
          }),
          'brand': brand.name,
          'amount': total,
          'status': PaymentStatus.paid.name,
          'direction': TxDirection.incoming.name,
          'occurred_at': placedAt,
        });
      }
    }

    await ctx.insertMany('orders', orderRows);
    await ctx.insertMany('order_items', itemRows);
    await ctx.insertMany('transactions', txRows);
  }
}
