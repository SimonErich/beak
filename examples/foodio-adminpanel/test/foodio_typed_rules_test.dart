@TestOn('vm')
library;

import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:foodio_adminpanel/beak/server.g.dart';
import 'package:foodio_adminpanel/models/models.dart';
import 'package:foodio_adminpanel/seeders/foodio_seeder.dart';
import 'package:test/test.dart';

/// Server-side order rules that reject a forged plan, written entirely
/// through typed fields, models and references.
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

  var saves = 0;

  /// Commits one update of [model]'s record [id] and returns what it reports.
  Future<Map<String, List<String>>> rejectedUpdate(
    BeakModel model,
    String id,
    List<BeakFieldValue> values,
  ) async {
    final target = BeakRecordRef.of(model, id);
    final result = await client.commit(
      BeakSavePlan(
        saveId: 'typed-${saves++}',
        root: target,
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: target,
            values: model.record(values),
          ),
        ],
      ),
    );
    expect(result.complete, isFalse, reason: '${result.toJson()}');
    return result.outcomes
        .map((outcome) => outcome.error)
        .whereType<BeakSaveError>()
        .first
        .fieldErrors;
  }

  Future<BeakRecord> firstOf(BeakModel model, BeakFilter filter) async =>
      (await client.query(
        model.table,
        model.query(
          filter: filter,
          pagination: const BeakPagination(perPage: 1),
        ),
      )).items.first;

  test('activity history can only be written by the server', () async {
    final activity = BeakRecordRef.draftOf(
      const OrderActivityModel(),
      'forged-activity',
    );
    final result = await client.commit(
      BeakSavePlan(
        saveId: 'forged-activity',
        root: activity,
        operations: [
          BeakSaveOperation.create(
            id: 'activity',
            model: const OrderActivityModel(),
            draftId: 'forged-activity',
            values: [
              OrderActivityModel.title.to('Forged'),
              OrderActivityModel.actor.to('Nobody'),
              OrderActivityModel.kind.to('edited'),
              OrderActivityModel.saveKey.to('forged'),
              OrderActivityModel.occurredAt.to(DateTime.utc(2026)),
            ],
            links: [
              OrderActivityModel.order.linkTo(
                BeakRecordRef.of(const OrderModel(), FoodioIds.order(24817)),
              ),
            ],
          ),
        ],
      ),
    );
    expect(result.complete, isFalse);
    expect(
      result.outcomes
          .map((outcome) => outcome.error)
          .whereType<BeakSaveError>(),
      contains(
        isA<BeakSaveError>().having(
          (error) => error.fieldErrors,
          'field errors',
          {
            OrderModel.activities.key: [
              'Activity history is written by the server.',
            ],
          },
        ),
      ),
    );
  });

  test('a delivery slot keeps its capacity and time window valid', () async {
    final booked = await firstOf(
      const DeliverySlotModel(),
      DeliverySlotModel.reservedOrders.gt(0),
    );
    final id = DeliverySlotModel.id.require(booked);
    final booking = DeliverySlotModel.reservedOrders.require(booked);
    expect(
      await rejectedUpdate(const DeliverySlotModel(), id, [
        DeliverySlotModel.reservedOrders.to(booking + 1),
      ]),
      {
        DeliverySlotModel.reservedOrders.key: [
          'Slot reservations are managed by order actions.',
        ],
      },
    );
    expect(
      await rejectedUpdate(const DeliverySlotModel(), id, [
        DeliverySlotModel.capacity.to(booking - 1),
      ]),
      {
        DeliverySlotModel.capacity.key: [
          'Capacity cannot be lower than booked orders.',
        ],
      },
    );
    expect(
      await rejectedUpdate(const DeliverySlotModel(), id, [
        DeliverySlotModel.endMinute.to(
          DeliverySlotModel.startMinute.require(booked),
        ),
      ]),
      {
        DeliverySlotModel.endMinute.key: ['A slot must end after it starts.'],
      },
    );
  });

  test('a budget allowance cannot fall below committed spending', () async {
    final account = await client.getOne('budget_accounts', FoodioIds.budget);
    final committed =
        BudgetAccountModel.reservedCents.require(account!) +
        BudgetAccountModel.spentCents.require(account);
    expect(committed, greaterThan(0));
    expect(
      await rejectedUpdate(const BudgetAccountModel(), FoodioIds.budget, [
        BudgetAccountModel.allowanceCents.to(committed - 1),
      ]),
      {
        BudgetAccountModel.allowanceCents.key: [
          'The allowance cannot be lower than committed spending.',
        ],
      },
    );
  });

  test('an existing order item cannot move to another order', () async {
    final item = await firstOf(
      const OrderItemModel(),
      OrderItemModel.orderId.eq(FoodioIds.order(24818)),
    );
    expect(
      await rejectedUpdate(
        const OrderItemModel(),
        OrderItemModel.id.require(item),
        [OrderItemModel.orderId.to(FoodioIds.order(24806))],
      ),
      {
        OrderItemModel.orderId.key: [
          'An existing item cannot move between orders.',
        ],
      },
    );
  });
}
