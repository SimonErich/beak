import 'package:superdashboard/seeders/demo_database_seeder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beak/migrations.dart';
import 'package:superdashboard/beak/server.g.dart';

void main() {
  late InMemoryAdapter adapter;

  Future<List<Map<String, Object?>>> rows(String table) =>
      adapter.select(QueryDescriptor(table: table));

  double sumOf(List<Map<String, Object?>> data, String key) =>
      data.fold(0, (total, row) => total + (row[key]! as num).toDouble());

  setUpAll(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: beakHost().migrations,
    ).fresh();
    await const DemoDatabaseSeeder().run(adapter);
  });

  tearDownAll(() => adapter.disconnect());

  group('volume', () {
    test('seeds the expected core row counts', () async {
      expect(await rows('users'), hasLength(40));
      expect(await rows('orders'), hasLength(100));
      expect(await rows('products'), hasLength(15));
      expect(await rows('pricing_plans'), hasLength(4));
      expect(await rows('faqs'), hasLength(8));
      expect((await rows('cards')).length, greaterThan(0));
      expect((await rows('calendar_events')).length, greaterThan(0));
    });

    test('every order has at least one line item', () async {
      final orderIds = {for (final o in await rows('orders')) o['id']};
      final itemOrderIds = {
        for (final i in await rows('order_items')) i['order_id'],
      };
      expect(itemOrderIds, containsAll(orderIds));
    });
  });

  group('analytics reconcile with commerce', () {
    test('purchase-source revenue equals total order revenue', () async {
      final orderRevenue = sumOf(await rows('orders'), 'total');
      final sourceRevenue = sumOf(await rows('purchase_sources'), 'total');
      expect(sourceRevenue, closeTo(orderRevenue, 1.0));
    });

    test('purchase-source order counts sum to the order count', () async {
      final counts = sumOf(await rows('purchase_sources'), 'count');
      expect(counts, 100);
    });

    test('the sales-orders series sums to the order count', () async {
      final series = (await rows(
        'time_series_points',
      )).where((row) => row['series'] == 'sales_orders');
      expect(sumOf(series.toList(), 'value'), 100);
    });

    test('country stats cover only countries that have users', () async {
      final userCodes = {
        for (final u in await rows('users'))
          if (u['country_code'] case final String code) code,
      };
      final statCodes = {
        for (final s in await rows('country_stats')) s['country_code'],
      };
      expect(userCodes, containsAll(statCodes));
    });
  });

  group('derived counters', () {
    test('folder unread counts equal the unread emails per folder', () async {
      final unreadByFolder = <Object?, int>{};
      for (final email in await rows('emails')) {
        if (email['is_read'] == false) {
          final folder = email['folder_id'];
          unreadByFolder[folder] = (unreadByFolder[folder] ?? 0) + 1;
        }
      }
      for (final folder in await rows('mail_folders')) {
        expect(
          folder['unread_count'],
          unreadByFolder[folder['id']] ?? 0,
          reason: 'folder ${folder['key']} unread count is stale',
        );
      }
    });

    test('exactly one pricing plan is featured', () async {
      final featured = (await rows(
        'pricing_plans',
      )).where((plan) => plan['featured'] == true);
      expect(featured, hasLength(1));
    });
  });

  group('reproducibility', () {
    test('a second seeded database is identical', () async {
      final second = InMemoryAdapter();
      await second.connect();
      addTearDown(second.disconnect);
      await MigrationRunner(
        adapter: second,
        migrations: beakHost().migrations,
      ).fresh();
      await const DemoDatabaseSeeder().run(second);

      final firstUsers = await rows('users');
      final secondUsers = await second.select(
        const QueryDescriptor(table: 'users'),
      );
      final firstEmails = [for (final u in firstUsers) u['email']]
        ..sort((a, b) => '$a'.compareTo('$b'));
      final secondEmails = [for (final u in secondUsers) u['email']]
        ..sort((a, b) => '$a'.compareTo('$b'));
      expect(secondEmails, firstEmails);
    });
  });
}
