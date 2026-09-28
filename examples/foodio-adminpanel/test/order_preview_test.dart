import 'package:beak/migrations.dart';
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:foodio_adminpanel/theme/gabel_theme.dart';
import 'package:foodio_adminpanel/resources/orders/order_items.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/beak/registry.g.dart';
import 'package:foodio_adminpanel/beak/server.g.dart';
import 'package:foodio_adminpanel/models/models.dart';
import 'package:foodio_adminpanel/domain/foodio_order_preparer.dart';
import 'package:foodio_adminpanel/resources/orders/order_detail.dart';
import 'package:foodio_adminpanel/resources/orders/order_summary.dart';
import 'package:foodio_adminpanel/resources/orders/order_totals.dart';
import 'package:foodio_adminpanel/seeders/foodio_seeder.dart';

void main() {
  late DatabaseAdapter adapter;
  late WormDataSource source;
  final registry = buildBeakRegistry();
  setUpAll(() async {
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
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
    source = WormDataSource(registry, adapter: adapter);
  });
  tearDownAll(() async {
    await adapter.disconnect();
    await Worm.reset();
  });

  testWidgets(
    'dish typography matches detail and review roles without a pinned weight',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> pump(bool review) async {
        await tester.pumpWidget(
          OiApp(
            theme: gabelTheme(),
            home: BeakFormattingScope(
              formatting: const BeakFormatting(
                locale: 'en_AT',
                currency: 'EUR',
              ),
              child: BeakConfiguredForm(
                model: const OrderModel(),
                dataSource: source,
                registry: registry,
                recordId: FoodioIds.order(24817),
                mode: BeakFormMode.read,
                layout: BeakFormLayout(
                  children: [
                    orderItems(
                      allowEditing: false,
                      compact: true,
                      review: review,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final review in [false, true]) {
        await pump(review);
        final title = tester.widget<Text>(
          find.text(
            review
                ? '1 × Beetroot risotto with goat’s cheese'
                : 'Beetroot risotto with goat’s cheese',
          ),
        );
        final amount = tester.widget<Text>(find.text('€11.90'));
        for (final text in [title, amount]) {
          expect(
            text.style!.fontWeight,
            identical(text, title) && review
                ? FontWeight.w400
                : FontWeight.w500,
            reason: text.data,
          );
          expect(
            text.style!.fontVariations?.where((axis) => axis.axis == 'wght'),
            isEmpty,
          );
        }
        expect(
          amount.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('detail root enables persisted edit change indicators', () {
    final screen = orderDetailAndEdit();
    expect(screen.layout?.showChangeIndicators, isTrue);
  });

  Future<BeakFormSession> loadOrder({bool existing = true}) async {
    final screen = orderDetailAndEdit();
    final session = BeakFormSession(
      model: const OrderModel(),
      dataSource: source,
      registry: registry,
      recordId: existing ? FoodioIds.order(24817) : null,
      initialValues: existing
          ? null
          : BeakRecord.fromRow({
              'customer_id': FoodioIds.lena,
              'profile_id': FoodioIds.lenaCompany,
              'delivery_date': '2026-09-28',
              'payment_mode': 'monthlyInvoice',
            }),
      layout: screen.layout,
      regions: [?screen.aside, ?screen.header],
    );
    addTearDown(session.dispose);
    await session.load();
    expect(session.error.value, isNull);
    if (!existing) {
      final profile = (await source.query(
        const DeliveryProfileModel().query(
          filter: DeliveryProfileModel.id.eq(FoodioIds.lenaCompany),
          relationLoads: const [BeakRelationLoad('budgets')],
        ),
      )).items.single;
      session.root.select(OrderModel.profile, profile);
      session.root.set(OrderModel.paymentMode, 'monthlyInvoice');
    }
    return session;
  }

  void expectBudgetCapacity(
    BeakFormReader state, {
    required int contribution,
    required int available,
  }) {
    expect(companyBudgetContribution(state), contribution);
    expect(availableBudgetForOrder(state), available);
    final capacity = orderSummaryFooter().children
        .whereType<BeakFormCapacity>()
        .single;
    expect(capacity.value(state), contribution / 100);
    expect(capacity.max(state), available / 100);
    const format = BeakFormatPolicy(currency: 'EUR');
    expect(
      capacity.caption!(state, format),
      'Uses ${format.format(money(contribution), BeakValueFormat.currency)} of the '
      '${format.format(money(available), BeakValueFormat.currency)} left this month',
    );
  }

  test(
    'new order capacity shows its portion of the remaining budget',
    () async {
      final session = await loadOrder(existing: false);
      final state = BeakFormReader(session.root);
      expectBudgetCapacity(state, contribution: 0, available: 5660);
      final item = session.root.addRow(OrderModel.items);
      item.set(OrderItemModel.quantity, 1);
      item.set(OrderItemModel.unitPriceCents, 4131);
      expectBudgetCapacity(state, contribution: 4131, available: 5660);
      expect(projectedBudgetUsed(state), 10471);
      expect(
        budgetFor(state)!.allowanceCents - projectedBudgetUsed(state),
        1529,
      );
      session.root.set(OrderModel.paymentMode, 'card');
      expectBudgetCapacity(state, contribution: 0, available: 5660);
      expect(projectedBudgetUsed(state), 6340);
    },
  );

  test('budget preview replaces only the current reservation', () async {
    final session = await loadOrder();
    final state = BeakFormReader(session.root);
    expect(orderTotals(state).grossCents, 3140);
    expect(
      budgetUsed(state),
      6340,
      reason: '${state.read(OrderModel.profile)}',
    );
    expect(projectedBudgetUsed(state), 6340);
    expectBudgetCapacity(state, contribution: 3140, available: 8800);
    final risotto = session.root
        .rows(OrderModel.items)
        .firstWhere(
          (row) => row.read(OrderItemModel.dishId) == FoodioIds.risotto,
        );
    risotto.set(OrderItemModel.quantity, 2);
    expect(orderTotals(state).grossCents, 4330);
    expect(projectedBudgetUsed(state), 7530);
    expectBudgetCapacity(state, contribution: 4330, available: 8800);
    for (final mode in [
      'weeklyInvoice',
      'perOrderInvoice',
      'sepa',
      'subsidyCard',
    ]) {
      session.root.set(OrderModel.paymentMode, mode);
      expect(projectedBudgetUsed(state), 7530, reason: mode);
      expectBudgetCapacity(state, contribution: 4330, available: 8800);
    }
    session.root.set(OrderModel.paymentMode, 'card');
    expect(projectedBudgetUsed(state), 3200);
    expectBudgetCapacity(state, contribution: 0, available: 8800);
    session.root.set(OrderModel.paymentMode, 'monthlyInvoice');
    session.root.set(OrderModel.deliveryDate, const BeakDate(2026, 10, 1));
    expect(
      session.root.read(OrderModel.deliveryDate),
      const BeakDate(2026, 10, 1),
      reason: '${session.root.controller.buildData()["delivery_date"]}',
    );
    expect(budgetFor(state)?.period, '2026-10');
    expect(projectedBudgetUsed(state), 4330);
    expectBudgetCapacity(state, contribution: 4330, available: 12000);
  });

  test('zero remaining budget stays zero for the bar and caption', () async {
    final where = const Field<String>('profile_id')
        .eq(FoodioIds.lenaCompany)
        .and(const Field<String>('period').eq('2026-09'));
    await adapter.update(
      UpdateDescriptor(
        table: 'budget_accounts',
        where: where,
        values: {'spent_cents': 8860},
      ),
    );
    addTearDown(
      () => adapter.update(
        UpdateDescriptor(
          table: 'budget_accounts',
          where: where,
          values: {'spent_cents': 3200},
        ),
      ),
    );
    final session = await loadOrder(existing: false);
    final state = BeakFormReader(session.root);
    expectBudgetCapacity(state, contribution: 0, available: 0);
    final item = session.root.addRow(OrderModel.items);
    item.set(OrderItemModel.quantity, 1);
    item.set(OrderItemModel.unitPriceCents, 500);
    expectBudgetCapacity(state, contribution: 500, available: 0);
    expect(budgetFor(state)!.allowanceCents - projectedBudgetUsed(state), -500);
    session.root.set(OrderModel.paymentMode, 'card');
    expectBudgetCapacity(state, contribution: 0, available: 0);
  });

  test(
    'new mixed food and drink preview matches authoritative voucher and VAT',
    () async {
      final screen = orderDetailAndEdit();
      final session = BeakFormSession(
        model: const OrderModel(),
        dataSource: source,
        registry: registry,
        layout: screen.layout,
        regions: [?screen.aside, ?screen.header],
      );
      addTearDown(session.dispose);
      await session.load();
      session.root.select(
        OrderModel.voucher,
        await source.getOne('vouchers', FoodioIds.lunch15),
      );
      const root = BeakRecordRef.draft('orders', 'mixed-order');
      final operations = <BeakSaveOperation>[
        BeakSaveOperation(
          id: 'order',
          kind: BeakSaveOperationKind.create,
          target: root,
          values: BeakRecord.fromRow({
            'delivery_date': '2026-09-29',
            'payment_mode': 'monthlyInvoice',
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
            'voucher_id': const BeakRecordRef.existing(
              'vouchers',
              FoodioIds.lunch15,
            ),
          },
        ),
      ];
      for (final (dish, size) in [
        (FoodioIds.risotto, 'Regular'),
        (FoodioIds.lemonade, '0.33 l'),
      ]) {
        final variantId = FoodioIds.variant(dish, size);
        final variant = (await source.query(
          const DishVariantModel().query(
            filter: DishVariantModel.id.eq(variantId),
            relationLoads: const [BeakRelationLoad('dish')],
          ),
        )).items.single;
        final item = session.root.addRow(OrderModel.items);
        item.select(OrderItemModel.variant, variant);
        operations.add(
          BeakSaveOperation(
            id: dish,
            kind: BeakSaveOperationKind.create,
            target: BeakRecordRef.draft('order_items', dish),
            owner: root,
            relationKey: 'items',
            values: BeakRecord.fromRow({'quantity': 1}),
            references: {
              'dish_id': BeakRecordRef.existing('dishes', dish),
              'variant_id': BeakRecordRef.existing('dish_variants', variantId),
            },
          ),
        );
      }
      await session.validate();
      final items = session.root.rows(OrderModel.items);
      expect(items.last.read(OrderItemModel.food), isFalse);
      expect(items.first.read(OrderItemModel.allergens), 'G,L,O');
      final preview = orderTotals(BeakFormReader(session.root));
      final prepared = await FoodioOrderPreparer(registry).prepare(
        BeakSavePlan(
          saveId: 'mixed-preview',
          root: root,
          operations: operations,
        ),
        source,
        null,
      );
      final stored = prepared.operations
          .firstWhere((operation) => operation.target == root)
          .values;
      expect(preview.subtotalCents, 1480);
      expect(preview.voucherDiscountCents, 179);
      expect(preview.grossCents, 1301);
      expect(preview.grossCents, OrderModel.grossCents.readFrom(stored));
      expect(preview.netCents, OrderModel.netCents.readFrom(stored));
      expect(preview.taxCents, OrderModel.taxCents.readFrom(stored));
    },
  );

  test(
    'placed voucher and food snapshots survive catalog edits in previews',
    () async {
      await adapter.update(
        UpdateDescriptor(
          table: 'orders',
          where: const Field<String>('id').eq(FoodioIds.order(24817)),
          values: {
            'voucher_id': FoodioIds.lunch15,
            'voucher_rate_basis_points': 1500,
            'voucher_maximum_discount_cents': null,
            'voucher_food_only': true,
          },
        ),
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'vouchers',
          where: const Field<String>('id').eq(FoodioIds.lunch15),
          values: {'percent_basis_points': 7000, 'food_only': false},
        ),
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'dishes',
          where: const Field<String>('id').eq(FoodioIds.risotto),
          values: {'food': false, 'tax_basis_points': 2000},
        ),
      );
      final session = await loadOrder();
      final state = BeakFormReader(session.root);
      final totals = orderTotals(state);
      expect(totals.subtotalCents, 3140);
      expect(totals.voucherDiscountCents, 428);
      expect(totals.grossCents, 2712);
      expect(totals.taxCents, 268);
      expect(totals.netCents, 2444);
      session.root.set(OrderModel.manualDiscountCents, 99999);
      expect(orderTotals(state).grossCents, 0);
    },
  );
}
