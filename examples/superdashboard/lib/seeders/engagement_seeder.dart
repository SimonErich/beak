import 'package:superdashboard/models/models.dart';

import 'seed_context.dart';

/// Seeds the richer Commerce surfaces that hang off products and orders:
/// per-product variants, gallery images, reviews, and price rules; and
/// per-order lifecycle events and internal comments. Runs after Commerce so
/// it can read the exact products, orders, and users already inserted.
final class EngagementSeeder {
  /// Creates the seeder.
  const EngagementSeeder();

  static const List<String> _variantNames = [
    'Standard',
    'Large',
    'XL',
    'Gift set',
    'Refill pack',
    'Bundle',
    'Starter',
  ];

  static const List<String> _reviewTitles = [
    'Exactly what I needed',
    'Great value',
    'Better than expected',
    'Does the job',
    'Would buy again',
    'A little pricey but worth it',
    'Solid everyday choice',
    'Impressive quality',
  ];

  static const List<({String name, PriceRuleKind kind})> _ruleTemplates = [
    (name: 'Bulk 10+', kind: PriceRuleKind.percentage),
    (name: 'Launch discount', kind: PriceRuleKind.fixed),
    (name: 'Member price', kind: PriceRuleKind.override),
    (name: 'Clearance', kind: PriceRuleKind.percentage),
  ];

  /// Seeds every engagement row through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final products = await ctx.selectAll('products');
    final orders = await ctx.selectAll('orders');
    final users = await ctx.selectAll('users');
    final userIds = [
      for (final user in users)
        if (user['id'] case final String id) id,
    ];
    final nameById = <String, String>{
      for (final user in users)
        if (user['id'] case final String id) id: _asText(user['name'], 'User'),
    };
    await _seedProductExtras(ctx, products, userIds, nameById);
    await _seedOrderExtras(ctx, orders, userIds, nameById);
  }

  Future<void> _seedProductExtras(
    SeedContext ctx,
    List<Map<String, Object?>> products,
    List<String> userIds,
    Map<String, String> nameById,
  ) async {
    final variantRows = <Map<String, Object?>>[];
    final imageRows = <Map<String, Object?>>[];
    final reviewRows = <Map<String, Object?>>[];
    final ruleRows = <Map<String, Object?>>[];

    for (final product in products) {
      final productId = product['id'];
      if (productId is! String) {
        continue;
      }
      final basePrice = _asNum(product['price']);

      final variantCount = ctx.between(2, 4);
      final names = <String>{};
      while (names.length < variantCount) {
        names.add(ctx.pick(_variantNames));
      }
      var first = true;
      for (final name in names) {
        variantRows.add({
          'id': ctx.uuid(),
          'name': name,
          'sku': 'VAR-${ctx.between(10000, 99999)}',
          'price': _round(basePrice * ctx.money(0.9, 1.4)),
          'stock': ctx.between(0, 120),
          'is_default': first,
          'product_id': productId,
        });
        first = false;
      }

      final imageCount = ctx.between(3, 5);
      for (var i = 0; i < imageCount; i++) {
        imageRows.add({
          'id': ctx.uuid(),
          'url': ctx.faker.imageUrl(width: 600, height: 600),
          'alt': '${product['name']} — view ${i + 1}',
          'sort_index': i,
          'is_primary': i == 0,
          'product_id': productId,
        });
      }

      final reviewCount = ctx.between(2, 6);
      for (var i = 0; i < reviewCount; i++) {
        final authorId = ctx.pick(userIds);
        reviewRows.add({
          'id': ctx.uuid(),
          'rating': ctx.weighted({5: 5, 4: 4, 3: 2, 2: 1, 1: 1}),
          'title': ctx.pick(_reviewTitles),
          'body': ctx.faker.paragraph(sentenceCount: 2),
          'author_name': nameById[authorId],
          'created_at': ctx.daysAgo(200),
          'product_id': productId,
          'user_id': authorId,
        });
      }

      final ruleCount = ctx.between(0, 2);
      final ruleOffset = ctx.between(0, _ruleTemplates.length - 1);
      for (var i = 0; i < ruleCount; i++) {
        final template =
            _ruleTemplates[(ruleOffset + i) % _ruleTemplates.length];
        ruleRows.add({
          'id': ctx.uuid(),
          'name': template.name,
          'kind': template.kind.name,
          'value': template.kind == PriceRuleKind.override
              ? _round(basePrice * 0.8)
              : ctx.money(5, 25),
          'min_quantity': ctx.pick(const [1, 3, 5, 10]),
          'starts_at': ctx.daysAgo(90),
          'ends_at': ctx.around(60),
          'active': ctx.chance(0.7),
          'product_id': productId,
        });
      }
    }

    await ctx.insertMany('product_variants', variantRows);
    await ctx.insertMany('product_images', imageRows);
    await ctx.insertMany('product_reviews', reviewRows);
    await ctx.insertMany('price_rules', ruleRows);
  }

  Future<void> _seedOrderExtras(
    SeedContext ctx,
    List<Map<String, Object?>> orders,
    List<String> userIds,
    Map<String, String> nameById,
  ) async {
    final eventRows = <Map<String, Object?>>[];
    final commentRows = <Map<String, Object?>>[];

    for (final order in orders) {
      final orderId = order['id'];
      if (orderId is! String) {
        continue;
      }
      final reference = _asText(order['reference'], 'order');
      final status = _asText(order['status'], OrderEventKind.placed.name);
      final placedAt = _asDate(order['placed_at'], SeedContext.now);

      // A coherent lifecycle up to the order's current status.
      final lifecycle = _lifecycleFor(status);
      for (var i = 0; i < lifecycle.length; i++) {
        final kind = lifecycle[i];
        eventRows.add({
          'id': ctx.uuid(),
          'kind': kind.name,
          'description': _describe(kind, reference),
          'actor': i == 0 ? 'Customer' : 'System',
          'created_at': placedAt.add(Duration(hours: i * 8)),
          'order_id': orderId,
        });
      }

      final commentCount = ctx.between(1, 3);
      for (var i = 0; i < commentCount; i++) {
        final authorId = ctx.pick(userIds);
        commentRows.add({
          'id': ctx.uuid(),
          'body': ctx.faker.sentence(wordCount: ctx.between(8, 16)),
          'is_internal': ctx.chance(0.6),
          'author_name': nameById[authorId],
          'created_at': placedAt.add(Duration(days: i + 1)),
          'order_id': orderId,
          'author_id': authorId,
        });
      }
    }

    await ctx.insertMany('order_events', eventRows);
    await ctx.insertMany('order_comments', commentRows);
  }

  /// The ordered events an order in [status] has gone through.
  List<OrderEventKind> _lifecycleFor(String status) {
    const full = [
      OrderEventKind.placed,
      OrderEventKind.paid,
      OrderEventKind.packed,
      OrderEventKind.shipped,
      OrderEventKind.delivered,
    ];
    return switch (status) {
      'pending' => const [OrderEventKind.placed],
      'processing' => full.sublist(0, 3),
      'shipped' => full.sublist(0, 4),
      'delivered' => full,
      'cancelled' => const [OrderEventKind.placed, OrderEventKind.cancelled],
      'refunded' => const [
        OrderEventKind.placed,
        OrderEventKind.paid,
        OrderEventKind.refunded,
      ],
      _ => const [OrderEventKind.placed],
    };
  }

  String _describe(OrderEventKind kind, String reference) => switch (kind) {
    OrderEventKind.placed => 'Order $reference was placed.',
    OrderEventKind.paid => 'Payment confirmed.',
    OrderEventKind.packed => 'Items packed and ready to ship.',
    OrderEventKind.shipped => 'Handed to the carrier.',
    OrderEventKind.delivered => 'Delivered to the customer.',
    OrderEventKind.cancelled => 'Order cancelled.',
    OrderEventKind.refunded => 'Order refunded in full.',
    OrderEventKind.note => 'Note added.',
  };

  String _asText(Object? raw, String fallback) => switch (raw) {
    final String value => value,
    _ => fallback,
  };

  double _asNum(Object? raw) => switch (raw) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v) ?? 0,
    _ => 0,
  };

  DateTime _asDate(Object? raw, DateTime fallback) => switch (raw) {
    final DateTime v => v,
    final String v => DateTime.tryParse(v) ?? fallback,
    _ => fallback,
  };

  double _round(double value) => double.parse(value.toStringAsFixed(2));
}
