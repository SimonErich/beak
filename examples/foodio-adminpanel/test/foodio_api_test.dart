@TestOn('vm')
library;

import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:foodio_adminpanel/beak/server.g.dart';
import 'package:foodio_adminpanel/beak/registry.g.dart';
import 'package:foodio_adminpanel/domain/foodio_clock.dart';
import 'package:foodio_adminpanel/domain/foodio_order_preparer.dart';
import 'package:foodio_adminpanel/domain/foodio_effects.dart';
import 'package:foodio_adminpanel/domain/order_behavior.dart';
import 'package:foodio_adminpanel/models/models.dart';
import 'package:foodio_adminpanel/seeders/foodio_seeder.dart';
import 'package:test/test.dart';

void main() {
  late DatabaseAdapter adapter;
  late HttpServer server;
  late BeakClient client;
  setUpAll(() async {
    final socket = await ServerSocket.bind('127.0.0.1', 0);
    final port = socket.port;
    await socket.close();
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'HOST': '127.0.0.1',
        'PORT': '$port',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
      seeders: host.seeders,
    ).fresh(seed: true);
    server = await host.buildServer(adapter: adapter).start();
    client = BeakClient(baseUrl: 'http://127.0.0.1:$port');
  });
  tearDownAll(() async {
    client.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  });

  Future<int> count(BeakFilter? filter) async => (await client.query(
    'orders',
    const OrderModel().query(
      filter: filter,
      pagination: const BeakPagination(perPage: 1),
    ),
  )).total;
  Future<Map<String, Object?>> stored(String table, String id) async =>
      (await adapter.selectOne(
        QueryDescriptor(table: table, where: const Field<String>('id').eq(id)),
      ))!;

  test(
    'recurring profile preferences resolve dated home and office slots',
    () async {
      final company = await client.getOne(
        'delivery_profiles',
        FoodioIds.lenaCompany,
      );
      final private = await client.getOne(
        'delivery_profiles',
        FoodioIds.lenaPrivate,
      );
      expect(
        DeliveryProfileModel.preferredDeliveryStart.readFrom(company!),
        const BeakTime(11, 30),
      );
      expect(
        DeliveryProfileModel.preferredDeliveryEnd.readFrom(company),
        const BeakTime(12, 0),
      );
      expect(
        DeliveryProfileModel.preferredDeliveryStart.readFrom(private!),
        const BeakTime(18, 0),
      );
      final today = await client.query(
        'delivery_slots',
        const DeliverySlotModel().query(
          filter: DeliverySlotModel.date.eq(const BeakDate(2026, 9, 28)),
        ),
      );
      expect(today.items, hasLength(5));
      expect(
        today.items.every(
          (slot) => DeliverySlotModel.method.readFrom(slot) == 'office',
        ),
        isTrue,
      );
      final home = await client.query(
        'delivery_slots',
        const DeliverySlotModel().query(
          filter: BeakAndFilter([
            DeliverySlotModel.date.eq(const BeakDate(2026, 9, 29)),
            DeliverySlotModel.method.eq('home'),
          ]),
        ),
      );
      expect(home.items, hasLength(1));
      expect(DeliverySlotModel.startMinute.readFrom(home.items.single), 1080);
      expect(DeliverySlotModel.endMinute.readFrom(home.items.single), 1110);
    },
  );

  test('declared numeric order columns sort through the API', () async {
    for (final field in [OrderModel.itemCount, OrderModel.grossCents]) {
      expect(
        field.column.sortable,
        isTrue,
        reason: '${field.key} table sorting',
      );
      for (final descending in [false, true]) {
        final result = await client.query(
          'orders',
          const OrderModel()
              .query(
                filter: OrderModel.deliveryDate.eq(const BeakDate(2026, 9, 28)),
              )
              .orderBy(field, descending: descending)
              .paginate(perPage: 20),
        );
        final values = result.items.map((row) => field.readFrom(row)!).toList();
        expect(values, hasLength(20));
        final expected = [...values]
          ..sort((a, b) => descending ? b.compareTo(a) : a.compareTo(b));
        expect(
          values,
          expected,
          reason: '${field.key}, descending=$descending',
        );
      }
    }
  });

  test(
    'deterministic seed proves every visible count and exact revenue from real records',
    () async {
      expect(await count(null), 48213);
      final allergenSnapshots = await client.query(
        'order_items',
        const OrderItemModel().query(
          filter: OrderItemModel.orderId.eq(FoodioIds.order(24817)),
        ),
      );
      expect(
        {
          for (final row in allergenSnapshots.items)
            OrderItemModel.dishId.readFrom(row): OrderItemModel.allergens
                .readFrom(row),
        },
        {
          FoodioIds.risotto: 'G,L,O',
          FoodioIds.dal: 'L,M',
          FoodioIds.strudel: 'A,C,G,H',
          FoodioIds.lemonade: '',
        },
      );

      expect(
        await count(OrderModel.deliveryDate.eq(const BeakDate(2026, 9, 28))),
        // Includes the failed Friday delivery rescheduled for today.
        413,
      );
      expect(await count(OrderModel.needsAttention.eq(true)), 7);
      expect(await count(OrderModel.awaitingRelease.eq(true)), 96);
      expect(
        await count(OrderModel.deliveryDate.gt(const BeakDate(2026, 9, 28))),
        664,
      );
      expect(await count(OrderModel.status.eq(OrderStatus.draft)), 3);
      expect(await count(OrderModel.customerId.eq(FoodioIds.lena)), 148);
      expect(
        await count(
          BeakAndFilter([
            OrderModel.deliveryDate.gte(const BeakDate(2026, 9, 28)),
            OrderModel.deliveryDate.lte(const BeakDate(2026, 9, 29)),
            BeakOrFilter([
              OrderModel.status.eq(OrderStatus.confirmed),
              OrderModel.status.eq(OrderStatus.inKitchen),
              OrderModel.needsAttention.eq(true),
            ]),
            OrderModel.profile.kind.eq('company'),
            BeakOrFilter([
              OrderModel.organizationId.eq(FoodioIds.nordlicht),
              OrderModel.organizationId.eq(FoodioIds.kessler),
            ]),
            BeakOrFilter([
              OrderModel.slot.startMinute.eq(690),
              OrderModel.slot.startMinute.eq(720),
            ]),
            BeakOrFilter([
              OrderModel.paymentMode.eq('monthlyInvoice'),
              OrderModel.paymentMode.eq('subsidyCard'),
            ]),
          ]),
        ),
        214,
      );

      final today = await adapter.select(
        QueryDescriptor(
          table: 'orders',
          where: const Field<String>('delivery_date').eq('2026-09-28'),
        ),
      );
      expect(
        today
            .where((r) => r['status'] != 'cancelled')
            .fold<int>(0, (sum, r) => sum + (r['gross_cents']! as int)),
        // ORD-24802 was rescheduled onto today; its €13.40 remains in revenue.
        983980,
      );
      final summary = await client.summary(
        const OrderModel().summary(
          filter: OrderModel.deliveryDate.eq(const BeakDate(2026, 9, 28)),
          measures: [
            for (final status in [
              OrderStatus.confirmed,
              OrderStatus.inKitchen,
              OrderStatus.outForDelivery,
              OrderStatus.delivered,
              OrderStatus.cancelled,
            ])
              BeakSummaryMeasure.count(
                status.name,
                filter: BeakAndFilter([
                  OrderModel.status.eq(status),
                  OrderModel.needsAttention.eq(false),
                ]),
              ),
            BeakSummaryMeasure.count(
              'attention',
              filter: OrderModel.needsAttention.eq(true),
            ),
          ],
        ),
      );
      expect(summary.rows.single.values, {
        'confirmed': 83,
        'inKitchen': 131,
        'outForDelivery': 64,
        'delivered': 128,
        'cancelled': 1,
        // The unresolved Friday delivery now scheduled today remains attention.
        'attention': 6,
      });
      final budget = await stored('budget_accounts', FoodioIds.budget);
      expect(budget['spent_cents'], 3200);
      expect(budget['reserved_cents'], 3140);
      for (final (minute, count) in [
        (480, 42),
        (660, 86),
        (690, 118),
        (720, 104),
        (750, 62),
      ]) {
        expect(
          (await stored(
            'delivery_slots',
            FoodioIds.slot('2026-09-28', minute),
          ))['reserved_orders'],
          count,
        );
      }
      await const FoodioSeeder().run(adapter);
      expect(await count(null), 48213);
      final referenceItems = await client.query(
        'order_items',
        const OrderItemModel().query(
          filter: OrderItemModel.orderId.eq(FoodioIds.order(24817)),
        ),
      );
      expect(
        {
          for (final row in referenceItems.items)
            OrderItemModel.dishId.readFrom(row): OrderItemModel.allergens
                .readFrom(row),
        },
        {
          FoodioIds.risotto: 'G,L,O',
          FoodioIds.dal: 'L,M',
          FoodioIds.strudel: 'A,C,G,H',
          FoodioIds.lemonade: '',
        },
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'place wizard computes snapshots and reserves once across replay and recovery',
    () async {
      final plan = placePlan('wizard');
      final result = await client.commit(plan);
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      final record = result.rootRecord!;
      expect(record['reference']?.raw, 'ORD-24819');
      expect(record['gross_cents']?.raw, 4131);
      expect(record['net_cents']?.raw, 3755);
      expect(record['tax_cents']?.raw, 376);
      expect(record['approval_status']?.raw, 'pending');
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['reserved_cents'],
        7271,
      );
      expect(
        (await stored(
          'delivery_slots',
          FoodioIds.slot('2026-09-29', 720),
        ))['reserved_orders'],
        67,
      );
      expect((await client.commit(plan)).toJson(), result.toJson());
      expect(
        (await client.recoverCommit(plan.saveId)).toJson(),
        result.toJson(),
      );
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['reserved_cents'],
        7271,
      );
      final worker = const FoodioEffects().worker(adapter);
      expect(await worker.drain(), 2);
      expect(await worker.drain(), 0);
      expect(
        (await client.query(
          'message_deliveries',
          const MessageDeliveryModel().query(),
        )).total,
        2,
      );
      // Cancellation releases budget and unconsumed capacity.
      final cancelled = await client.commit(
        actionPlan('cancel-wizard', record['id']!.raw!, OrderActions.cancel),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['reserved_cents'],
        3140,
      );
      expect(
        (await stored(
          'delivery_slots',
          FoodioIds.slot('2026-09-29', 720),
        ))['reserved_orders'],
        66,
      );
    },
  );

  test(
    'insufficient budget and full capacity roll back numbering and all writes',
    () async {
      final before = await count(null);
      final budgetFailure = await client.commit(
        placePlan('over-budget', quantity: 10),
      );
      expect(budgetFailure.complete, isFalse);
      expect(budgetFailure.hasUnknown, isFalse);
      expect(await count(null), before);
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['reserved_cents'],
        3140,
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'delivery_slots',
          values: {'capacity': 66},
          where: const Field<String>(
            'id',
          ).eq(FoodioIds.slot('2026-09-29', 720)),
        ),
      );
      final capacityFailure = await client.commit(placePlan('full-slot'));
      expect(
        capacityFailure.complete,
        isFalse,
        reason: '${capacityFailure.toJson()}',
      );
      expect(await count(null), before);
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['reserved_cents'],
        3140,
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'delivery_slots',
          values: {'capacity': 100},
          where: const Field<String>(
            'id',
          ).eq(FoodioIds.slot('2026-09-29', 720)),
        ),
      );
    },
  );

  test(
    'forged workflow state and direct CRUD cannot bypass authoritative graph rules',
    () async {
      final forged = await client.commit(
        placePlan(
          'forged',
          withoutAction: true,
          extra: {'status': 'delivered', 'gross_cents': 1},
        ),
      );
      expect(forged.complete, isFalse);
      await expectLater(
        client.update(
          'orders',
          FoodioIds.order(24817),
          BeakRecord.fromRow({'gross_cents': 1}),
        ),
        throwsA(isA<BeakValidationException>()),
      );
      final locked = await client.commit(
        actionPlan(
          'wrong-delivery',
          FoodioIds.order(24817),
          null,
          values: {'delivery_date': '2026-09-29'},
        ),
      );
      expect(locked.complete, isFalse);
    },
  );

  test(
    'kitchen edit preserves catalog snapshots and moves capacity atomically',
    () async {
      final root = BeakRecordRef.existing('orders', FoodioIds.order(24817));
      await adapter.update(
        UpdateDescriptor(
          table: 'dish_variants',
          values: {'price_cents': 9999},
          where: const Field<String>(
            'id',
          ).eq(FoodioIds.variant(FoodioIds.risotto, 'Regular')),
        ),
      );
      final changed = await client.commit(
        BeakSavePlan(
          saveId: 'soup-edit',
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'order',
              kind: BeakSaveOperationKind.update,
              target: root,
              values: BeakRecord.fromRow({
                'contact_phone': '+43 664 218 4471',
                'delivery_note':
                    'Moved to the 12:00 slot at Lena’s request (call at 09:38).',
              }),
              references: {
                'slot_id': BeakRecordRef.existing(
                  'delivery_slots',
                  FoodioIds.slot('2026-09-28', 720),
                ),
              },
            ),
            BeakSaveOperation(
              id: 'soup',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('order_items', 'soup'),
              owner: root,
              relationKey: 'items',
              values: BeakRecord.fromRow({'quantity': 1}),
              references: {
                'dish_id': const BeakRecordRef.existing(
                  'dishes',
                  FoodioIds.soup,
                ),
                'variant_id': BeakRecordRef.existing(
                  'dish_variants',
                  FoodioIds.variant(FoodioIds.soup, 'Cup'),
                ),
              },
            ),
          ],
        ),
      );
      expect(changed.complete, isTrue, reason: '${changed.toJson()}');
      expect(changed.rootRecord?['gross_cents']?.raw, 3590);
      expect(changed.rootRecord?['net_cents']?.raw, 3242);
      final activities = await client.query(
        'order_activities',
        const OrderActivityModel().query(
          filter: OrderActivityModel.saveKey.eq('soup-edit'),
        ),
      );
      final description = OrderActivityModel.description.readFrom(
        activities.items.single,
      )!;
      expect(description, contains('Items'));
      expect(description, contains('Delivery Note'));
      expect(description, contains('Slot'));
      expect(description, isNot(contains('_')));
      expect(description, isNot(contains('cents')));
      expect(
        (await stored(
          'delivery_slots',
          FoodioIds.slot('2026-09-28', 690),
        ))['reserved_orders'],
        117,
      );
      expect(
        (await stored(
          'delivery_slots',
          FoodioIds.slot('2026-09-28', 720),
        ))['reserved_orders'],
        105,
      );
      final soup = changed.outcomes.singleWhere((row) => row.id == 'soup');
      final removed = await client.commit(
        BeakSavePlan(
          saveId: 'remove-soup-edit',
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'order',
              kind: BeakSaveOperationKind.update,
              target: root,
              expectedUpdatedAt: OrderModel.updatedAt.readFrom(
                changed.rootRecord!,
              ),
              references: {
                'slot_id': BeakRecordRef.existing(
                  'delivery_slots',
                  FoodioIds.slot('2026-09-28', 690),
                ),
              },
            ),
            BeakSaveOperation(
              id: 'remove-soup',
              kind: BeakSaveOperationKind.delete,
              target: BeakRecordRef.existing('order_items', soup.resolvedId!),
              expectedUpdatedAt: OrderItemModel.updatedAt.readFrom(
                soup.record!,
              ),
              owner: root,
              relationKey: 'items',
            ),
          ],
        ),
      );
      expect(removed.complete, isTrue, reason: '${removed.toJson()}');
      expect(removed.rootRecord?['gross_cents']?.raw, 3140);
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['reserved_cents'],
        3140,
      );
      expect(
        (await stored(
          'delivery_slots',
          FoodioIds.slot('2026-09-28', 690),
        ))['reserved_orders'],
        118,
      );
      expect(
        (await stored(
          'delivery_slots',
          FoodioIds.slot('2026-09-28', 720),
        ))['reserved_orders'],
        104,
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'dish_variants',
          values: {'price_cents': 1190},
          where: const Field<String>(
            'id',
          ).eq(FoodioIds.variant(FoodioIds.risotto, 'Regular')),
        ),
      );
    },
  );
  test(
    'payment effects persist receipts, retry declines and refund only once',
    () async {
      await adapter.update(
        UpdateDescriptor(
          table: 'payment_methods',
          values: {'demo_outcome': 'declined'},
          where: const Field<String>('id').eq('payment-lena'),
        ),
      );
      final result = await client.commit(
        placePlan(
          'private-card',
          extra: {'payment_mode': 'card', 'cost_center': ''},
          references: {
            'profile_id': const BeakRecordRef.existing(
              'delivery_profiles',
              FoodioIds.lenaPrivate,
            ),
            'location_id': const BeakRecordRef.existing(
              'delivery_locations',
              'location-home',
            ),
            'payment_method_id': const BeakRecordRef.existing(
              'payment_methods',
              'payment-lena',
            ),
          },
        ),
      );
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      final id = result.rootRecord!['id']!.raw! as String;
      final worker = const FoodioEffects().worker(adapter);
      await worker.drain();
      expect((await stored('orders', id))['payment_status'], 'failed');
      expect(
        (await stored('payment_attempts', 'private-card:charge'))['status'],
        'declined',
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'payment_methods',
          values: {'demo_outcome': 'succeeded'},
          where: const Field<String>('id').eq('payment-lena'),
        ),
      );
      final retry = await client.commit(
        actionPlan('retry-card', id, OrderActions.retryPayment),
      );
      expect(retry.complete, isTrue, reason: '${retry.toJson()}');
      final retryRevision = OrderModel.updatedAt.readFrom(retry.rootRecord!)!;
      expect(await worker.drain(), 1);
      final paid = (await client.getOne('orders', id))!;
      expect(OrderModel.paymentStatus.readFrom(paid), PaymentStatus.paid);
      expect(
        OrderModel.updatedAt.readFrom(paid)!.isAfter(retryRevision),
        isTrue,
      );
      final staleEdit = await client.commit(
        BeakSavePlan(
          saveId: 'stale-before-provider-result',
          root: BeakRecordRef.existing('orders', id),
          operations: [
            BeakSaveOperation(
              id: 'order',
              kind: BeakSaveOperationKind.update,
              target: BeakRecordRef.existing('orders', id),
              expectedUpdatedAt: retryRevision,
              values: BeakRecord.fromRow({'delivery_note': 'Stale edit'}),
            ),
          ],
        ),
      );
      expect(staleEdit.complete, isFalse);
      expect('${staleEdit.toJson()}', contains('conflict'));
      // Simulate a worker dying after provider success but before acknowledgement.
      await adapter.update(
        UpdateDescriptor(
          table: BeakOutboxMigration.table,
          values: {'status': 'pending', 'available_at': 0, 'lease': ''},
          where: const Field<String>('id').eq('retry-card:charge'),
        ),
      );
      expect(await worker.drain(), 1);
      expect(
        (await client.query(
          'payment_attempts',
          const PaymentAttemptModel().query(
            filter: PaymentAttemptModel.orderId.eq(id),
          ),
        )).total,
        2,
      );
      for (final (key, values) in [
        ('mode', {'payment_mode': 'paymentLink'}),
        ('amount', {'manual_discount_cents': 1}),
      ]) {
        final changed = await client.commit(
          actionPlan('paid-change-$key', id, null, values: values),
        );
        expect(changed.complete, isFalse);
        expect('${changed.toJson()}', contains('Cancel and refund'));
        expect((await stored('orders', id))['payment_status'], 'paid');
      }
      final cancelled = await client.commit(
        actionPlan('refund-card', id, OrderActions.cancel),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
      expect(await worker.drain(), 1);
      expect((await stored('orders', id))['payment_status'], 'refunded');
      expect(
        (await stored('payment_attempts', 'refund-card:refund'))['status'],
        'succeeded',
      );
      expect(await worker.drain(), 0);
    },
  );

  test(
    'redelivery validates typed arguments and reserves the new slot',
    () async {
      final id = FoodioIds.order(24802);
      final slot = FoodioIds.slot('2026-09-29', 690);
      final before =
          (await stored('delivery_slots', slot))['reserved_orders']! as int;
      final invalid = await client.commit(
        actionPlan(
          'bad-redelivery',
          id,
          OrderActions.reschedule,
          arguments: {'delivery_date': '2026-09-30', 'slot_id': slot},
        ),
      );
      expect(invalid.complete, isFalse);
      expect((await stored('orders', id))['status'], 'onHold');
      final result = await client.commit(
        actionPlan(
          'redelivery',
          id,
          OrderActions.reschedule,
          arguments: {'delivery_date': '2026-09-29', 'slot_id': slot},
        ),
      );
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      expect((await stored('orders', id))['status'], 'confirmed');
      expect((await stored('orders', id))['delivery_date'], '2026-09-29');
      expect(
        (await stored('delivery_slots', slot))['reserved_orders'],
        before + 1,
      );
    },
  );

  test(
    'invoice issue freezes totals and rejects subsequent content edits',
    () async {
      const ref = BeakRecordRef.existing('invoices', FoodioIds.invoice);
      final issued = await client.commit(
        BeakSavePlan(
          saveId: 'issue-invoice',
          root: ref,
          action: InvoiceActions.issue.name,
          operations: [
            BeakSaveOperation(
              id: 'invoice',
              kind: BeakSaveOperationKind.update,
              target: ref,
            ),
          ],
        ),
      );
      expect(issued.complete, isTrue, reason: '${issued.toJson()}');
      final frozenGross = issued.rootRecord!['gross_cents']!.raw;
      expect(frozenGross, 12560);
      final edit = await client.commit(
        actionPlan(
          'edit-issued-order',
          FoodioIds.order(24817),
          null,
          values: {'manual_discount_cents': 100},
        ),
      );
      expect(edit.complete, isFalse);
      expect(
        (await stored('invoices', FoodioIds.invoice))['gross_cents'],
        frozenGross,
      );
      final forged = await client.commit(
        BeakSavePlan(
          saveId: 'forge-invoice',
          root: ref,
          operations: [
            BeakSaveOperation(
              id: 'invoice',
              kind: BeakSaveOperationKind.update,
              target: ref,
              values: BeakRecord.fromRow({'gross_cents': 1}),
            ),
          ],
        ),
      );
      expect(forged.complete, isFalse);
    },
  );

  test(
    'cutoff rejects scalar and nested edits without modifying persisted rows',
    () async {
      final registry = buildBeakRegistry();
      final source = WormDataSource(registry, adapter: adapter);
      final closed = BeakGraphCommitService(
        registry: registry,
        source: source,
        preparePlan: FoodioOrderPreparer(
          registry,
          clock: FoodioClock(read: () => DateTime.utc(2026, 9, 28, 8, 30)),
        ).prepare,
      );
      final id = FoodioIds.order(24816);
      final scalar = await closed.commit(
        actionPlan(
          'after-cutoff',
          id,
          null,
          values: {'delivery_note': 'Too late'},
        ),
      );
      expect(scalar.complete, isFalse);
      expect('${scalar.toJson()}', contains('cutoff'));
      final items = await adapter.select(
        QueryDescriptor(
          table: 'order_items',
          where: const Field<String>('order_id').eq(id),
        ),
      );
      final item = BeakRecordRef.existing('order_items', items.first['id']!);
      final nested = await closed.commit(
        BeakSavePlan(
          saveId: 'nested-cutoff',
          root: item,
          operations: [
            BeakSaveOperation(
              id: 'line',
              kind: BeakSaveOperationKind.update,
              target: item,
              values: BeakRecord.fromRow({'quantity': 2}),
            ),
          ],
        ),
      );
      expect(nested.complete, isFalse);
      expect('${nested.toJson()}', contains('cutoff'));
      expect(
        (await stored('order_items', '${item.id}'))['quantity'],
        items.first['quantity'],
      );
    },
  );

  test(
    'placed voucher rules stay frozen and delivery settles reserved budget once',
    () async {
      final result = await client.commit(placePlan('settle', quantity: 1));
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      final id = result.rootRecord!['id']!.raw! as String;
      final gross = result.rootRecord!['gross_cents']!.raw! as int;
      final before = await stored('budget_accounts', FoodioIds.budget);
      await adapter.update(
        UpdateDescriptor(
          table: 'vouchers',
          values: {'percent_basis_points': 5000, 'code': 'CHANGED'},
          where: const Field<String>('id').eq(FoodioIds.lunch15),
        ),
      );
      for (final action in [
        OrderActions.startKitchen,
        OrderActions.dispatch,
        OrderActions.deliver,
      ]) {
        final changed = await client.commit(
          actionPlan('settle-${action.name}', id, action),
        );
        expect(changed.complete, isTrue, reason: '${changed.toJson()}');
        expect(changed.rootRecord!['gross_cents']!.raw, gross);
        expect(changed.rootRecord!['voucher_code']!.raw, 'LUNCH15');
      }
      final budget = await stored('budget_accounts', FoodioIds.budget);
      expect(
        budget['reserved_cents'],
        (before['reserved_cents']! as int) - gross,
      );
      expect(budget['spent_cents'], (before['spent_cents']! as int) + gross);
      expect((await stored('orders', id))['budget_reserved'], anyOf(false, 0));
      await client.commit(
        actionPlan('settle-deliver', id, OrderActions.deliver),
      );
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['spent_cents'],
        budget['spent_cents'],
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'vouchers',
          values: {'percent_basis_points': 1500, 'code': 'LUNCH15'},
          where: const Field<String>('id').eq(FoodioIds.lunch15),
        ),
      );
    },
  );

  test(
    'SQLite fresh reverses applied migrations and discards old demo rows',
    () async {
      final database = adapterFromUrl(Uri.parse('sqlite::memory:'));
      await database.connect();
      addTearDown(database.disconnect);
      final resetHost = beakHost(
        environment: {
          'DATABASE_URL': 'sqlite::memory:',
          'BEAK_STORAGE_DRIVER': 'none',
        },
      );
      final runner = MigrationRunner(
        adapter: database,
        migrations: resetHost.migrations,
        seeders: resetHost.seeders,
      );
      await runner.fresh(seed: true);
      expect(
        (await database.rawQuery(
          'SELECT COUNT(*) AS count FROM orders',
          const [],
        )).single['count'],
        48213,
      );
      await database.insert(
        InsertDescriptor(
          table: 'app_settings',
          values: {
            'id': 'old',
            'key': 'old',
            'value': 'discard',
            'created_at': DateTime.utc(2026),
            'updated_at': DateTime.utc(2026),
          },
        ),
      );
      await runner.fresh(seed: true);
      expect(
        await database.select(
          QueryDescriptor(
            table: 'app_settings',
            where: const Field<String>('key').eq('old'),
          ),
        ),
        isEmpty,
      );
      expect(
        (await database.rawQuery(
          'SELECT COUNT(*) AS count FROM orders',
          const [],
        )).single['count'],
        48213,
      );
      expect(
        (await database.rawQuery(
          'PRAGMA foreign_keys',
          const [],
        )).single.values.single,
        1,
      );
      expect(
        await database.rawQuery('PRAGMA foreign_key_check', const []),
        isEmpty,
      );
    },
  );
  test(
    'supporting edits accept unchanged counters and reject authored reservations',
    () async {
      final account = await stored('budget_accounts', FoodioIds.budget);
      const ref = BeakRecordRef.existing('budget_accounts', FoodioIds.budget);
      BeakSavePlan patch(String saveId, Map<String, Object?> values) =>
          BeakSavePlan(
            saveId: saveId,
            root: ref,
            operations: [
              BeakSaveOperation(
                id: 'budget',
                kind: BeakSaveOperationKind.update,
                target: ref,
                values: BeakRecord.fromRow(values),
              ),
            ],
          );
      final saved = await client.commit(
        patch('budget-form', {
          'allowance_cents': 12000,
          'reserved_cents': account['reserved_cents'],
          'spent_cents': account['spent_cents'],
        }),
      );
      expect(saved.complete, isTrue, reason: '${saved.toJson()}');
      final forged = await client.commit(
        patch('forged-budget-counter', {'reserved_cents': 0}),
      );
      expect(forged.complete, isFalse);
      expect(
        (await stored('budget_accounts', FoodioIds.budget))['reserved_cents'],
        account['reserved_cents'],
      );
      const duplicate = BeakRecordRef.draft('budget_accounts', 'duplicate');
      final duplicateResult = await client.commit(
        BeakSavePlan(
          saveId: 'duplicate-ledger',
          root: duplicate,
          operations: [
            BeakSaveOperation(
              id: 'budget',
              kind: BeakSaveOperationKind.create,
              target: duplicate,
              values: BeakRecord.fromRow({
                'name': 'Duplicate month',
                'period': '2026-09',
                'allowance_cents': 12000,
              }),
              references: {
                'profile_id': const BeakRecordRef.existing(
                  'delivery_profiles',
                  FoodioIds.lenaCompany,
                ),
              },
            ),
          ],
        ),
      );
      expect(duplicateResult.complete, isFalse);
      final unlink = await client.commit(
        actionPlan(
          'unlink-issued-invoice',
          FoodioIds.order(24817),
          null,
          values: {'invoice_id': null},
        ),
      );
      expect(unlink.complete, isFalse);
      expect('${unlink.toJson()}', contains('issued invoice'));
    },
  );

  test(
    'customer creation supplies identity and date; internal settings reject direct changes',
    () async {
      const ref = BeakRecordRef.draft('customers', 'new-customer');
      final created = await client.commit(
        BeakSavePlan(
          saveId: 'new-customer',
          root: ref,
          operations: [
            BeakSaveOperation(
              id: 'customer',
              kind: BeakSaveOperationKind.create,
              target: ref,
              values: BeakRecord.fromRow({
                'first_name': 'Sofia',
                'last_name': 'Huber',
                'email': 'sofia@example.test',
              }),
            ),
          ],
        ),
      );
      expect(created.complete, isTrue, reason: '${created.toJson()}');
      expect(created.rootRecord!['name']?.raw, 'Sofia Huber');
      expect(
        created.rootRecord!['joined_at']?.raw,
        DateTime.utc(2026, 9, 28, 7, 42),
      );
      const settings = BeakRecordRef.existing(
        'app_settings',
        'next-order-number',
      );
      final changed = await client.commit(
        BeakSavePlan(
          saveId: 'tamper-sequence',
          root: settings,
          operations: [
            BeakSaveOperation(
              id: 'setting',
              kind: BeakSaveOperationKind.update,
              target: settings,
              values: BeakRecord.fromRow({'value': '1'}),
            ),
          ],
        ),
      );
      expect(changed.complete, isFalse);
    },
  );

  test(
    'Amend saves changes and an optional note atomically and idempotently',
    () async {
      final created = await client.commit(
        placePlan('amend-fixture', withoutAction: true),
      );
      expect(created.complete, isTrue, reason: '${created.toJson()}');
      final id = created.rootRecord!['id']!.raw! as String;
      final before = await stored('orders', id);
      Future<BeakPage<BeakRecord>> notes() => client.query(
        'order_notes',
        const OrderNoteModel().query(filter: OrderNoteModel.orderId.eq(id)),
      );
      final noteCount = (await notes()).total;
      final invalid = await client.commit(
        actionPlan(
          'amend-rollback',
          id,
          OrderActions.amend,
          values: {
            'delivery_note': 'Must roll back',
            'manual_discount_cents': 999999,
          },
          arguments: {'body': 'Must not append on a rejected order.'},
        ),
      );
      expect(invalid.complete, isFalse);
      expect(
        (await stored('orders', id))['delivery_note'],
        before['delivery_note'],
      );
      expect((await notes()).total, noteCount);

      final plan = actionPlan(
        'amend-and-note',
        id,
        OrderActions.amend,
        values: {'delivery_note': 'Reception confirmed the delivery entrance.'},
        arguments: {
          'body': '  Updated together with the delivery instructions.  ',
        },
      );
      final applied = await client.commit(plan);
      expect(applied.complete, isTrue, reason: '${applied.toJson()}');
      expect((await client.commit(plan)).toJson(), applied.toJson());
      expect(
        (await stored('orders', id))['delivery_note'],
        'Reception confirmed the delivery entrance.',
      );
      expect((await notes()).total, noteCount + 1);
      expect(
        (await notes()).items
            .where(
              (note) =>
                  note['body']?.raw ==
                  'Updated together with the delivery instructions.',
            )
            .single['author']
            ?.raw,
        'Marie Novak',
      );

      final withoutNote = await client.commit(
        actionPlan(
          'amend-without-note',
          id,
          OrderActions.amend,
          values: {'delivery_note': before['delivery_note']},
        ),
      );
      expect(withoutNote.complete, isTrue, reason: '${withoutNote.toJson()}');
      expect((await notes()).total, noteCount + 1);
      expect(
        (await stored('orders', id))['gross_cents'],
        before['gross_cents'],
      );
    },
  );

  test(
    'Add note validates arguments and appends once to a finished order',
    () async {
      final delivered = await client.query(
        'orders',
        const OrderModel().query(
          filter: OrderModel.status.eq(OrderStatus.delivered),
          pagination: const BeakPagination(perPage: 1),
        ),
      );
      final id = delivered.items.first['id']!.raw! as String;
      final invalid = await client.commit(
        actionPlan(
          'empty-order-note',
          id,
          OrderActions.addNote,
          arguments: {'body': '   '},
        ),
      );
      expect(invalid.complete, isFalse);
      final plan = actionPlan(
        'finished-order-note',
        id,
        OrderActions.addNote,
        arguments: {'body': '  Customer confirmed safe delivery.  '},
      );
      final result = await client.commit(plan);
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      expect((await client.commit(plan)).toJson(), result.toJson());
      final notes = await client.query(
        'order_notes',
        const OrderNoteModel().query(filter: OrderNoteModel.orderId.eq(id)),
      );
      expect(notes.total, 1);
      final note = notes.items.single;
      expect(note['body']?.raw, 'Customer confirmed safe delivery.');
      expect(note['author']?.raw, 'Marie Novak');
      expect(note['occurred_at']?.raw, DateTime.utc(2026, 9, 28, 7, 42));
      expect((await stored('orders', id))['status'], 'delivered');
      final noteRef = BeakRecordRef.existing('order_notes', note['id']!.raw!);
      final rewrite = await client.commit(
        BeakSavePlan(
          saveId: 'rewrite-audit-note',
          root: noteRef,
          operations: [
            BeakSaveOperation(
              id: 'note',
              kind: BeakSaveOperationKind.update,
              target: noteRef,
              values: BeakRecord.fromRow({'body': 'Rewritten history'}),
            ),
          ],
        ),
      );
      expect(rewrite.complete, isFalse);
      expect('${rewrite.toJson()}', contains('audit trail'));
    },
  );

  test(
    'Add note permits unchanged form rows but rejects material edits',
    () async {
      final root = BeakRecordRef.existing('orders', FoodioIds.order(24817));
      final rows = await client.query(
        'order_items',
        const OrderItemModel().query(
          filter: OrderItemModel.orderId.eq(root.id! as String),
        ),
      );
      final row = rows.items.first;
      final quantity = OrderItemModel.quantity.readFrom(row)!;
      final originalStored = await stored(
        'order_items',
        OrderItemModel.id.readFrom(row)!,
      );
      BeakSavePlan notePlan(String saveId, int amount) => BeakSavePlan(
        saveId: saveId,
        root: root,
        action: OrderActions.addNote.name,
        arguments: BeakRecord.fromRow({'body': 'Checked the existing basket.'}),
        operations: [
          BeakSaveOperation(
            id: 'order',
            kind: BeakSaveOperationKind.update,
            target: root,
          ),
          BeakSaveOperation(
            id: 'unchanged-item',
            kind: BeakSaveOperationKind.update,
            target: BeakRecordRef.existing(
              'order_items',
              OrderItemModel.id.readFrom(row)!,
            ),
            owner: root,
            relationKey: 'items',
            values: BeakRecord.fromRow({'quantity': amount}),
          ),
        ],
      );
      final rejected = await client.commit(
        notePlan('note-with-edit', quantity + 1),
      );
      expect(rejected.complete, isFalse);
      expect('${rejected.toJson()}', contains('Save order changes'));
      final accepted = await client.commit(
        notePlan('note-unchanged-form', quantity),
      );
      expect(accepted.complete, isTrue, reason: '${accepted.toJson()}');
      expect(
        accepted.outcomes.any((row) => row.id == 'unchanged-item'),
        isTrue,
      );
      expect(
        await stored('order_items', OrderItemModel.id.readFrom(row)!),
        originalStored,
        reason:
            'A note does not rewrite unchanged basket snapshots or versions.',
      );
      expect((await stored('orders', root.id! as String))['gross_cents'], 3140);
      final notes = await client.query(
        'order_notes',
        const OrderNoteModel().query(
          filter: BeakAndFilter([
            OrderNoteModel.orderId.eq(root.id! as String),
            OrderNoteModel.body.eq('Checked the existing basket.'),
          ]),
        ),
      );
      expect(notes.total, 1);
    },
  );

  test(
    'payment modes reject unknown values and unfunded private invoices',
    () async {
      final unknown = await client.commit(
        placePlan('unsupported-payment', extra: {'payment_mode': 'split'}),
      );
      expect(unknown.complete, isFalse);
      expect('${unknown.toJson()}', contains('supported payment method'));
      final privateInvoice = await client.commit(
        placePlan(
          'private-company-invoice',
          references: {
            'profile_id': const BeakRecordRef.existing(
              'delivery_profiles',
              FoodioIds.lenaPrivate,
            ),
            'location_id': const BeakRecordRef.existing(
              'delivery_locations',
              'location-home',
            ),
          },
        ),
      );
      expect(privateInvoice.complete, isFalse);
      expect('${privateInvoice.toJson()}', contains('company profile'));
    },
  );

  test(
    'saved payments require the matching method kind and active customer scope',
    () async {
      final before = await count(null);
      for (final (mode, method) in [
        ('paypal', 'payment-lena'),
        ('card', 'payment-lena-paypal'),
        ('subsidyCard', 'payment-lena-paypal'),
      ]) {
        final wrongKind = await client.commit(
          placePlan(
            'wrong-kind-$mode',
            extra: {'payment_mode': mode},
            references: {
              'payment_method_id': BeakRecordRef.existing(
                'payment_methods',
                method,
              ),
            },
          ),
        );
        expect(
          wrongKind.complete,
          isFalse,
          reason: '$mode: ${wrongKind.toJson()}',
        );
        expect('${wrongKind.toJson()}', contains('payment_method_id'));
        expect(await count(null), before);
      }

      await adapter.update(
        UpdateDescriptor(
          table: 'payment_methods',
          values: {'active': false},
          where: const Field<String>('id').eq('payment-lena-paypal'),
        ),
      );
      try {
        final inactiveDraft = await client.commit(
          placePlan(
            'inactive-method-draft',
            withoutAction: true,
            extra: {'payment_mode': 'paypal'},
            references: {
              'payment_method_id': const BeakRecordRef.existing(
                'payment_methods',
                'payment-lena-paypal',
              ),
            },
          ),
        );
        expect(inactiveDraft.complete, isFalse);
        expect('${inactiveDraft.toJson()}', contains('payment_method_id'));
        expect(await count(null), before);
      } finally {
        await adapter.update(
          UpdateDescriptor(
            table: 'payment_methods',
            values: {'active': true},
            where: const Field<String>('id').eq('payment-lena-paypal'),
          ),
        );
      }

      final paypal = await client.commit(
        placePlan(
          'matching-paypal',
          extra: {'payment_mode': 'paypal'},
          references: {
            'payment_method_id': const BeakRecordRef.existing(
              'payment_methods',
              'payment-lena-paypal',
            ),
          },
        ),
      );
      expect(paypal.complete, isTrue, reason: '${paypal.toJson()}');
      final cancelled = await client.commit(
        actionPlan(
          'matching-paypal-cancel',
          OrderModel.id.readFrom(paypal.rootRecord!)!,
          OrderActions.cancel,
        ),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
    },
  );

  test(
    'one-time address is explicit, area-bound, and leaves the saved location unchanged',
    () async {
      final locationBefore = await stored(
        'delivery_locations',
        FoodioIds.headquarters,
      );
      final accepted = await client.commit(
        placePlan(
          'one-time-address',
          withoutAction: true,
          extra: {
            'address_override': true,
            'street': 'Karlsgasse 9, side entrance',
            'postal_code': locationBefore['postal_code'],
            'city': locationBefore['city'],
            'route_code': 'untrusted',
          },
        ),
      );
      expect(accepted.complete, isTrue, reason: '${accepted.toJson()}');
      final record = accepted.rootRecord!;
      expect(OrderModel.addressOverride.readFrom(record), isTrue);
      expect(OrderModel.street.readFrom(record), 'Karlsgasse 9, side entrance');
      expect(
        OrderModel.routeCode.readFrom(record),
        locationBefore['route_code'],
      );
      expect(
        await stored('delivery_locations', FoodioIds.headquarters),
        locationBefore,
      );
      final restored = await client.commit(
        actionPlan(
          'restore-location-address',
          OrderModel.id.readFrom(record)!,
          null,
          values: {'address_override': false},
        ),
      );
      expect(restored.complete, isTrue, reason: '${restored.toJson()}');
      expect(
        OrderModel.street.readFrom(restored.rootRecord!),
        locationBefore['street'],
      );
      final outside = await client.commit(
        placePlan(
          'outside-delivery-area',
          withoutAction: true,
          extra: {
            'address_override': true,
            'street': 'Another city 1',
            'postal_code': '9999',
            'city': 'Elsewhere',
          },
        ),
      );
      expect(outside.complete, isFalse);
      expect('${outside.toJson()}', contains('city and postal area'));
      final implicit = await client.commit(
        placePlan(
          'implicit-address',
          withoutAction: true,
          extra: {'street': 'Must not override', 'postal_code': '9999'},
        ),
      );
      expect(implicit.complete, isTrue, reason: '${implicit.toJson()}');
      expect(
        OrderModel.street.readFrom(implicit.rootRecord!),
        locationBefore['street'],
      );
      expect(
        OrderModel.postalCode.readFrom(implicit.rootRecord!),
        locationBefore['postal_code'],
      );
    },
  );

  test('inactive locations cannot be selected for new orders', () async {
    await adapter.update(
      UpdateDescriptor(
        table: 'delivery_locations',
        values: {'active': false},
        where: const Field<String>('id').eq(FoodioIds.headquarters),
      ),
    );
    try {
      final result = await client.commit(
        placePlan('inactive-location', withoutAction: true),
      );
      expect(result.complete, isFalse);
      expect('${result.toJson()}', contains('active delivery location'));
    } finally {
      await adapter.update(
        UpdateDescriptor(
          table: 'delivery_locations',
          values: {'active': true},
          where: const Field<String>('id').eq(FoodioIds.headquarters),
        ),
      );
    }
  });

  test(
    'API drafts derive profile, location and date from only the customer',
    () async {
      final base = placePlan(
        'customer-only-draft',
        withoutAction: true,
        quantity: 1,
      );
      final saved = await client.commit(
        BeakSavePlan(
          saveId: base.saveId,
          root: base.root,
          operations: [
            BeakSaveOperation(
              id: 'order',
              kind: BeakSaveOperationKind.create,
              target: base.root,
              references: {
                'customer_id': const BeakRecordRef.existing(
                  'customers',
                  FoodioIds.lena,
                ),
              },
            ),
            ...base.operations.skip(1),
          ],
        ),
      );
      expect(saved.complete, isTrue, reason: '${saved.toJson()}');
      final record = saved.rootRecord!;
      expect(OrderModel.profileId.readFrom(record), FoodioIds.lenaCompany);
      expect(OrderModel.locationId.readFrom(record), FoodioIds.headquarters);
      expect(
        OrderModel.deliveryDate.readFrom(record),
        const BeakDate(2026, 9, 29),
      );
      expect(OrderModel.paymentMode.readFrom(record), 'monthlyInvoice');
      expect(OrderModel.capacityReserved.readFrom(record), isFalse);
      expect(OrderModel.budgetReserved.readFrom(record), isFalse);
    },
  );

  test(
    'standalone company profiles initialize their current-month ledger once',
    () async {
      const profile = BeakRecordRef.draft(
        'delivery_profiles',
        'standalone-company',
      );
      final values = BeakRecord.fromRow({'name': 'Standalone company profile'});
      await expectLater(
        client.create('delivery_profiles', values),
        throwsA(isA<BeakValidationException>()),
      );
      final plan = BeakSavePlan(
        saveId: 'standalone-company',
        root: profile,
        operations: [
          BeakSaveOperation(
            id: 'profile',
            kind: BeakSaveOperationKind.create,
            target: profile,
            values: values,
            references: {
              'customer_id': const BeakRecordRef.existing(
                'customers',
                FoodioIds.lena,
              ),
              'organization_id': const BeakRecordRef.existing(
                'organizations',
                FoodioIds.nordlicht,
              ),
              'menu_plan_id': const BeakRecordRef.existing(
                'menu_plans',
                'menu-balanced',
              ),
            },
          ),
        ],
      );
      final result = await client.commit(plan);
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      expect((await client.commit(plan)).toJson(), result.toJson());
      final budgets = await client.query(
        'budget_accounts',
        const BudgetAccountModel().query(
          filter: BudgetAccountModel.profileId.eq(
            DeliveryProfileModel.id.readFrom(result.rootRecord!),
          ),
        ),
      );
      expect(budgets.total, 1);
      final ledger = budgets.items.single;
      expect(BudgetAccountModel.period.readFrom(ledger), '2026-09');
      expect(BudgetAccountModel.allowanceCents.readFrom(ledger), 12000);
      expect(BudgetAccountModel.reservedCents.readFrom(ledger), 0);
      expect(BudgetAccountModel.spentCents.readFrom(ledger), 0);
    },
  );

  test(
    'inline customer and company profile reserve a new ledger atomically once',
    () async {
      final plan = inlineProfilePlan('inline-company');
      final result = await client.commit(plan);
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      final record = result.rootRecord!;
      final customerId = OrderModel.customerId.readFrom(record)!;
      final profileId = OrderModel.profileId.readFrom(record)!;
      final budgetId = OrderModel.budgetAccountId.readFrom(record)!;
      expect(
        (await stored('customers', customerId))['name'],
        'Inline Customer',
      );
      expect(
        (await stored('delivery_profiles', profileId))['customer_id'],
        customerId,
      );
      final ledger = await stored('budget_accounts', budgetId);
      expect(ledger['profile_id'], profileId);
      expect(ledger['period'], '2026-09');
      expect(ledger['allowance_cents'], 12000);
      expect(ledger['reserved_cents'], 4131);
      expect(ledger['spent_cents'], 0);
      expect(OrderModel.budgetReserved.readFrom(record), isTrue);
      expect(
        OrderModel.approvalStatus.readFrom(record),
        ApprovalStatus.pending,
      );
      final replay = await client.commit(plan);
      expect(replay.toJson(), result.toJson());
      expect(
        (await stored('budget_accounts', budgetId))['reserved_cents'],
        4131,
      );
      final cancelled = await client.commit(
        actionPlan(
          'inline-company-cancel',
          OrderModel.id.readFrom(record)!,
          OrderActions.cancel,
        ),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
      expect((await stored('budget_accounts', budgetId))['reserved_cents'], 0);
      for (final action in [
        OrderActions.approve,
        OrderActions.reject,
        OrderActions.requestApproval,
      ]) {
        final rejected = await client.commit(
          actionPlan(
            'cancelled-company-${action.name}',
            OrderModel.id.readFrom(record)!,
            action,
          ),
        );
        expect(
          rejected.complete,
          isFalse,
          reason: '${action.name} on a cancelled order',
        );
      }
      expect(
        (await stored('orders', OrderModel.id.readFrom(record)!))['status'],
        'cancelled',
      );
    },
  );

  test(
    'insufficient inline profile budget rolls back every staged identity and counter',
    () async {
      final beforeCustomers = (await client.query(
        'customers',
        const CustomerModel().query(),
      )).total;
      final beforeProfiles = (await client.query(
        'delivery_profiles',
        const DeliveryProfileModel().query(),
      )).total;
      final beforeBudgets = (await client.query(
        'budget_accounts',
        const BudgetAccountModel().query(),
      )).total;
      final slotId = FoodioIds.slot('2026-09-29', 720);
      final capacity = (await stored(
        'delivery_slots',
        slotId,
      ))['reserved_orders'];
      final result = await client.commit(
        inlineProfilePlan('inline-insufficient', allowance: 100),
      );
      expect(result.complete, isFalse);
      expect(result.hasUnknown, isFalse);
      expect('${result.toJson()}', contains('Insufficient company budget'));
      expect(
        (await client.query('customers', const CustomerModel().query())).total,
        beforeCustomers,
      );
      expect(
        (await client.query(
          'delivery_profiles',
          const DeliveryProfileModel().query(),
        )).total,
        beforeProfiles,
      );
      expect(
        (await client.query(
          'budget_accounts',
          const BudgetAccountModel().query(),
        )).total,
        beforeBudgets,
      );
      expect(
        (await stored('delivery_slots', slotId))['reserved_orders'],
        capacity,
      );
    },
  );

  test('inline private profile places without a company ledger', () async {
    final before = (await client.query(
      'budget_accounts',
      const BudgetAccountModel().query(),
    )).total;
    final result = await client.commit(
      inlineProfilePlan('inline-private', company: false),
    );
    expect(result.complete, isTrue, reason: '${result.toJson()}');
    expect(OrderModel.budgetReserved.readFrom(result.rootRecord!), isFalse);
    expect(OrderModel.budgetAccountId.readFrom(result.rootRecord!), isNull);
    expect(
      (await client.query(
        'budget_accounts',
        const BudgetAccountModel().query(),
      )).total,
      before,
    );
    final cancelled = await client.commit(
      actionPlan(
        'inline-private-cancel',
        OrderModel.id.readFrom(result.rootRecord!)!,
        OrderActions.cancel,
      ),
    );
    expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
  });

  test(
    'new customer and saved card satisfy scoped identity validation together',
    () async {
      final plan = inlineProfilePlan(
        'inline-private-card',
        company: false,
        savedCard: true,
      );
      final result = await client.commit(plan);
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      final record = result.rootRecord!;
      final methodId = OrderModel.paymentMethodId.readFrom(record)!;
      expect(
        (await stored('payment_methods', methodId))['customer_id'],
        OrderModel.customerId.readFrom(record),
      );
      final id = OrderModel.id.readFrom(record)!;
      final foreign = await client.commit(
        BeakSavePlan(
          saveId: 'foreign-payment',
          root: BeakRecordRef.existing('orders', id),
          operations: [
            BeakSaveOperation(
              id: 'order',
              kind: BeakSaveOperationKind.update,
              target: BeakRecordRef.existing('orders', id),
              references: {
                'payment_method_id': const BeakRecordRef.existing(
                  'payment_methods',
                  'payment-lena',
                ),
              },
            ),
          ],
        ),
      );
      expect(foreign.complete, isFalse);
      expect('${foreign.toJson()}', contains('payment_method_id'));
      final cancelled = await client.commit(
        actionPlan('inline-private-card-cancel', id, OrderActions.cancel),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
    },
  );

  test(
    'new company profile creates current and delivery-month ledgers',
    () async {
      for (final dish in [
        FoodioIds.risotto,
        FoodioIds.dal,
        FoodioIds.schnitzel,
      ]) {
        await adapter.insert(
          InsertDescriptor(
            table: 'menu_plan_items',
            values: {
              'id': 'october-$dish',
              'name': 'October menu',
              'menu_plan_id': 'menu-balanced',
              'dish_id': dish,
              'date': '2026-10-01',
              'position': 0,
              'created_at': DateTime.utc(2026, 9, 28),
              'updated_at': DateTime.utc(2026, 9, 28),
            },
          ),
        );
      }
      final result = await client.commit(
        inlineProfilePlan('inline-october', deliveryDate: '2026-10-01'),
      );
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      final record = result.rootRecord!;
      final budgets = await client.query(
        'budget_accounts',
        const BudgetAccountModel().query(
          filter: BudgetAccountModel.profileId.eq(
            OrderModel.profileId.readFrom(record),
          ),
        ),
      );
      expect(budgets.total, 2);
      final byPeriod = {
        for (final row in budgets.items)
          BudgetAccountModel.period.readFrom(row): row,
      };
      expect(
        BudgetAccountModel.reservedCents.readFrom(byPeriod['2026-09']!),
        0,
      );
      expect(
        BudgetAccountModel.reservedCents.readFrom(byPeriod['2026-10']!),
        4131,
      );
      expect(
        OrderModel.budgetAccountId.readFrom(record),
        BudgetAccountModel.id.readFrom(byPeriod['2026-10']!),
      );
      final cancelled = await client.commit(
        actionPlan(
          'inline-october-cancel',
          OrderModel.id.readFrom(record)!,
          OrderActions.cancel,
        ),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
    },
  );

  test(
    'active menu eligibility preserves history and allows the full active catalog',
    () async {
      final original = await client.commit(inlineProfilePlan('menu-history'));
      expect(original.complete, isTrue, reason: '${original.toJson()}');
      final orderId = OrderModel.id.readFrom(original.rootRecord!)!;
      final root = BeakRecordRef.existing('orders', orderId);
      final item = (await client.query(
        'order_items',
        const OrderItemModel().query(
          filter: BeakAndFilter([
            OrderItemModel.orderId.eq(orderId),
            OrderItemModel.dishId.eq(FoodioIds.risotto),
          ]),
        ),
      )).items.first;
      await adapter.update(
        UpdateDescriptor(
          table: 'menu_plans',
          values: {'active': false},
          where: const Field<String>('id').eq('menu-balanced'),
        ),
      );
      final inactive = await client.commit(inlineProfilePlan('inactive-menu'));
      expect(inactive.complete, isFalse);
      expect('${inactive.toJson()}', contains('active menu plan'));
      addTearDown(() async {
        await adapter.update(
          UpdateDescriptor(
            table: 'menu_plans',
            values: {'active': true},
            where: const Field<String>('id').eq('menu-balanced'),
          ),
        );
        for (final day in [28, 29]) {
          await adapter.update(
            UpdateDescriptor(
              table: 'menu_plan_items',
              values: {'date': '2026-09-$day'},
              where: const Field<String>(
                'id',
              ).eq('menu-${FoodioIds.risotto}-$day'),
            ),
          );
        }
      });
      final historical = await client.commit(
        actionPlan(
          'unchanged-inactive-menu',
          root.id!,
          null,
          values: {'delivery_note': 'Historical menu selections remain valid.'},
        ),
      );
      expect(historical.complete, isTrue, reason: '${historical.toJson()}');
      await adapter.update(
        UpdateDescriptor(
          table: 'menu_plans',
          values: {'active': true},
          where: const Field<String>('id').eq('menu-balanced'),
        ),
      );
      for (final day in [28, 29]) {
        await adapter.update(
          UpdateDescriptor(
            table: 'menu_plan_items',
            values: {'date': '2026-10-02'},
            where: const Field<String>(
              'id',
            ).eq('menu-${FoodioIds.risotto}-$day'),
          ),
        );
      }
      final missing = await client.commit(
        inlineProfilePlan('missing-menu-dish'),
      );
      expect(missing.complete, isTrue, reason: '${missing.toJson()}');
      final replacement = await client.commit(
        BeakSavePlan(
          saveId: 'replace-off-menu-size',
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'order',
              kind: BeakSaveOperationKind.update,
              target: root,
            ),
            BeakSaveOperation(
              id: 'item',
              kind: BeakSaveOperationKind.update,
              target: BeakRecordRef.existing(
                'order_items',
                OrderItemModel.id.readFrom(item)!,
              ),
              owner: root,
              relationKey: 'items',
              references: {
                'variant_id': BeakRecordRef.existing(
                  'dish_variants',
                  FoodioIds.variant(FoodioIds.risotto, 'Kids'),
                ),
              },
            ),
          ],
        ),
      );
      expect(replacement.complete, isTrue, reason: '${replacement.toJson()}');
      await adapter.update(
        UpdateDescriptor(
          table: 'dish_variants',
          values: {'active': false},
          where: const Field<String>(
            'id',
          ).eq(FoodioIds.variant(FoodioIds.risotto, 'Regular')),
        ),
      );
      final unavailable = await client.commit(
        inlineProfilePlan('inactive-full-catalog'),
      );
      expect(unavailable.complete, isFalse);
      expect('${unavailable.toJson()}', contains('active dish variant'));
      await adapter.update(
        UpdateDescriptor(
          table: 'dish_variants',
          values: {'active': true},
          where: const Field<String>(
            'id',
          ).eq(FoodioIds.variant(FoodioIds.risotto, 'Regular')),
        ),
      );
      for (final day in [28, 29]) {
        await adapter.update(
          UpdateDescriptor(
            table: 'menu_plan_items',
            values: {'date': '2026-09-$day'},
            where: const Field<String>(
              'id',
            ).eq('menu-${FoodioIds.risotto}-$day'),
          ),
        );
      }
    },
  );

  test(
    'payment link effects advance revisions under the frozen clock',
    () async {
      final worker = const FoodioEffects().worker(adapter);
      await worker.drain();
      final placed = await client.commit(
        inlineProfilePlan('revision-link', company: false),
      );
      expect(placed.complete, isTrue, reason: '${placed.toJson()}');
      await worker.drain();
      final id = OrderModel.id.readFrom(placed.rootRecord!)!;
      final sent = await client.commit(
        actionPlan('resend-revision-link', id, OrderActions.sendPaymentLink),
      );
      expect(sent.complete, isTrue, reason: '${sent.toJson()}');
      final revision = OrderModel.updatedAt.readFrom(sent.rootRecord!)!;
      expect(await worker.drain(), 1);
      final updated = (await client.getOne('orders', id))!;
      expect(OrderModel.updatedAt.readFrom(updated)!.isAfter(revision), isTrue);
      expect(OrderModel.paymentLink.readFrom(updated), contains('/demo/$id'));
      final cancelled = await client.commit(
        actionPlan('cancel-revision-link', id, OrderActions.cancel),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
    },
  );

  test(
    'queued effects skip obsolete payment and notification requests',
    () async {
      final worker = const FoodioEffects().worker(adapter);
      await worker.drain();
      // Earlier scenarios intentionally exhaust Lena's normal monthly budget.
      await adapter.update(
        UpdateDescriptor(
          table: 'budget_accounts',
          values: {'allowance_cents': 200000},
          where: const Field<String>('id').eq(FoodioIds.budget),
        ),
      );
      final card = await client.commit(
        placePlan(
          'obsolete-card',
          extra: {'payment_mode': 'card'},
          references: {
            'payment_method_id': const BeakRecordRef.existing(
              'payment_methods',
              'payment-lena',
            ),
          },
        ),
      );
      expect(card.complete, isTrue, reason: '${card.toJson()}');
      final cardId = card.rootRecord!['id']!.raw! as String;
      final changed = await client.commit(
        actionPlan(
          'invoice-instead-of-card',
          cardId,
          null,
          values: {'payment_mode': 'monthlyInvoice'},
        ),
      );
      expect(changed.complete, isTrue, reason: '${changed.toJson()}');
      final approved = await client.commit(
        actionPlan('approve-before-email', cardId, OrderActions.approve),
      );
      expect(approved.complete, isTrue, reason: '${approved.toJson()}');
      await worker.drain();
      expect((await stored('orders', cardId))['payment_status'], 'invoiced');
      expect(
        (await stored('payment_attempts', 'obsolete-card:charge'))['status'],
        'skipped',
      );
      expect(
        (await stored(
          'message_deliveries',
          'obsolete-card:approval',
        ))['status'],
        'skipped',
      );

      final link = await client.commit(
        placePlan('obsolete-link', extra: {'payment_mode': 'paymentLink'}),
      );
      expect(link.complete, isTrue, reason: '${link.toJson()}');
      final linkId = link.rootRecord!['id']!.raw! as String;
      final cancelled = await client.commit(
        actionPlan('cancel-before-link', linkId, OrderActions.cancel),
      );
      expect(cancelled.complete, isTrue, reason: '${cancelled.toJson()}');
      await worker.drain();
      for (final kind in ['confirmation', 'paymentLink', 'approval']) {
        expect(
          (await stored('message_deliveries', 'obsolete-link:$kind'))['status'],
          'skipped',
        );
      }
      expect((await stored('orders', linkId))['payment_link'], isEmpty);
      expect(await worker.drain(), 0);
    },
  );
}

BeakSavePlan inlineProfilePlan(
  String saveId, {
  int allowance = 12000,
  bool company = true,
  bool savedCard = false,
  String deliveryDate = '2026-09-29',
}) {
  const customer = BeakRecordRef.draft('customers', 'inline-customer');
  const profile = BeakRecordRef.draft('delivery_profiles', 'inline-profile');
  const method = BeakRecordRef.draft('payment_methods', 'inline-payment');
  final paymentMode = company
      ? 'monthlyInvoice'
      : savedCard
      ? 'card'
      : 'paymentLink';
  final base = placePlan(
    saveId,
    extra: {
      'delivery_date': deliveryDate,
      'payment_mode': paymentMode,
      if (!company) ...{
        'street': 'Testgasse 1',
        'postal_code': '1010',
        'city': 'Vienna',
      },
    },
    references: {
      'customer_id': customer,
      'profile_id': profile,
      if (savedCard) 'payment_method_id': method,
      'slot_id': BeakRecordRef.existing(
        'delivery_slots',
        FoodioIds.slot(deliveryDate, 720),
      ),
    },
  );
  final order = base.operations.first;
  return BeakSavePlan(
    saveId: saveId,
    root: base.root,
    action: base.action,
    operations: [
      BeakSaveOperation(
        id: 'customer',
        kind: BeakSaveOperationKind.create,
        target: customer,
        values: BeakRecord.fromRow({
          'first_name': 'Inline',
          'last_name': 'Customer',
          'email': '$saveId@example.test',
        }),
      ),
      BeakSaveOperation(
        id: 'profile',
        kind: BeakSaveOperationKind.create,
        target: profile,
        values: BeakRecord.fromRow({
          'name': 'Inline ${company ? 'company' : 'private'} profile',
          'kind': company ? 'company' : 'private',
          'payment_mode': paymentMode,
          'monthly_budget_cents': allowance,
        }),
        references: {
          'customer_id': customer,
          'menu_plan_id': const BeakRecordRef.existing(
            'menu_plans',
            'menu-balanced',
          ),
          if (company)
            'organization_id': const BeakRecordRef.existing(
              'organizations',
              FoodioIds.nordlicht,
            ),
        },
      ),
      if (savedCard)
        BeakSaveOperation(
          id: 'payment',
          kind: BeakSaveOperationKind.create,
          target: method,
          values: BeakRecord.fromRow({'name': 'Inline Visa'}),
          references: {'customer_id': customer},
        ),
      BeakSaveOperation(
        id: order.id,
        kind: order.kind,
        target: order.target,
        values: order.values,
        references: {...order.references}
          ..removeWhere((key, _) => !company && key == 'location_id'),
      ),
      ...base.operations.skip(1),
    ],
  );
}

BeakSavePlan placePlan(
  String saveId, {
  int quantity = 2,
  bool withoutAction = false,
  Map<String, Object?> extra = const {},
  Map<String, BeakRecordRef> references = const {},
}) {
  const root = BeakRecordRef.draft('orders', 'order');
  return BeakSavePlan(
    saveId: saveId,
    root: root,
    action: withoutAction ? null : OrderActions.place.name,
    operations: [
      BeakSaveOperation(
        id: 'order',
        kind: BeakSaveOperationKind.create,
        target: root,
        values: BeakRecord.fromRow({
          'delivery_date': '2026-09-29',
          'contact_phone': '+43 664 218 4471',
          'cost_center': '4100 Marketing',
          'payment_mode': 'monthlyInvoice',
          ...extra,
        }),
        references: {
          'customer_id': const BeakRecordRef.existing(
            'customers',
            FoodioIds.lena,
          ),
          'profile_id': const BeakRecordRef.existing(
            'delivery_profiles',
            FoodioIds.lenaCompany,
          ),
          'location_id': const BeakRecordRef.existing(
            'delivery_locations',
            FoodioIds.headquarters,
          ),
          'slot_id': BeakRecordRef.existing(
            'delivery_slots',
            FoodioIds.slot('2026-09-29', 720),
          ),
          'voucher_id': const BeakRecordRef.existing(
            'vouchers',
            FoodioIds.lunch15,
          ),
          ...references,
        },
      ),
      for (final (id, dish, qty) in [
        ('risotto', FoodioIds.risotto, quantity),
        ('dal', FoodioIds.dal, 1),
        ('schnitzel', FoodioIds.schnitzel, 1),
      ])
        BeakSaveOperation(
          id: id,
          kind: BeakSaveOperationKind.create,
          target: BeakRecordRef.draft('order_items', id),
          owner: root,
          relationKey: 'items',
          values: BeakRecord.fromRow({'quantity': qty}),
          references: {
            'variant_id': BeakRecordRef.existing(
              'dish_variants',
              FoodioIds.variant(dish, 'Regular'),
            ),
          },
        ),
    ],
  );
}

BeakSavePlan actionPlan(
  String saveId,
  Object id,
  BeakModelAction? action, {
  Map<String, Object?> values = const {},
  Map<String, Object?> arguments = const {},
}) {
  final root = BeakRecordRef.existing('orders', id);
  return BeakSavePlan(
    saveId: saveId,
    root: root,
    action: action?.name,
    arguments: BeakRecord.fromRow(arguments),
    operations: [
      BeakSaveOperation(
        id: 'root',
        kind: BeakSaveOperationKind.update,
        target: root,
        values: BeakRecord.fromRow(values),
      ),
    ],
  );
}
