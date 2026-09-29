@TestOn('vm')
library;

import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:clean_beak_config/beak/server.g.dart';
import 'package:clean_beak_config/resources/invoices/models/invoice.dart';
import 'package:clean_beak_config/resources/invoices/models/invoice_item.dart';
import 'package:clean_beak_config/resources/invoices/models/invoice_voucher.dart';
import 'package:clean_beak_config/resources/orders/models/order.dart';
import 'package:clean_beak_config/resources/orders/models/order_item.dart';
import 'package:clean_beak_config/resources/fulfillment/models/fulfillment_policy.dart';
import 'package:clean_beak_config/resources/products/models/product.dart';
import 'package:clean_beak_config/resources/products/models/product_variant.dart';
import 'package:clean_beak_config/resources/taxes/models/tax_rate.dart';
import 'package:clean_beak_config/resources/users/models/user.dart';
import 'package:clean_beak_config/resources/users/models/user_profile_connection.dart';
import 'package:clean_beak_config/resources/vouchers/models/voucher.dart';
import 'package:clean_beak_config/seeders/shop_seeder.dart';
import 'package:test/test.dart';

import 'support/money.dart';

void main() {
  late DatabaseAdapter adapter;
  late HttpServer server;
  late BeakClient client;

  setUp(() async {
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close();
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

  tearDown(() async {
    client.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  });

  test('new products and customers apply non-null business defaults', () async {
    const root = BeakRecordRef.draft('products', 'product');
    final result = await client.commit(
      BeakSavePlan(
        saveId: 'default-product',
        root: root,
        operations: [
          BeakSaveOperation(
            id: 'create-product',
            kind: BeakSaveOperationKind.create,
            target: root,
            values: const ProductModel().record([
              ProductModel.name.to('Simple product'),
              ProductModel.price.to(eur('4.90')),
            ]),
          ),
        ],
      ),
    );
    expect(result.complete, isTrue, reason: result.toJson().toString());
    expect(result.rootRecord?['active']?.raw, isTrue);
    final customer = await client.create(
      'users',
      BeakRecord.fromRow({
        'first_name': 'New',
        'last_name': 'Customer',
        'email': 'new@example.com',
      }),
    );
    expect(customer['invoice_company']?.raw, isFalse);
  });

  test(
    'semantic policy values round-trip through generated fields, HTTP and SQLite',
    () async {
      final page = await client.query(
        'fulfillment_policies',
        const FulfillmentPolicyModel().query(),
      );
      final row = page.items.single;
      expect(
        FulfillmentPolicyModel.deliveryFee.readFrom(row),
        const BeakDecimal(490, scale: 2),
      );
      expect(
        FulfillmentPolicyModel.effectiveDate.readFrom(row),
        const BeakDate(2026, 1, 1),
      );
      expect(
        FulfillmentPolicyModel.dispatchCutoff.readFrom(row),
        const BeakTime(15, 30),
      );
      expect(
        FulfillmentPolicyModel.handlingTime.readFrom(row),
        const Duration(hours: 24),
      );
      expect(FulfillmentPolicyModel.tags.readFrom(row), [
        'tracked',
        'warehouse-vienna',
      ]);
      expect(FulfillmentPolicyModel.signatureRequired.readFrom(row), isNull);
      final id = row['id']!.raw!;
      final updated = await client.update(
        'fulfillment_policies',
        id,
        const FulfillmentPolicyModel().record([
          FulfillmentPolicyModel.deliveryFee.to(
            const BeakDecimal(12345, scale: 2),
          ),
          FulfillmentPolicyModel.regions.to(['AT', 'IT']),
        ]),
      );
      expect(
        FulfillmentPolicyModel.deliveryFee.readFrom(updated)?.toString(),
        '123.45',
      );
      expect(FulfillmentPolicyModel.regions.readFrom(updated), ['AT', 'IT']);
      final filtered = await client.query(
        'fulfillment_policies',
        const FulfillmentPolicyModel().query(
          filter: FulfillmentPolicyModel.deliveryFee.gte(
            const BeakDecimal(12344, scale: 2),
          ),
        ),
      );
      expect(filtered.total, 1);
      final physical = await adapter.selectOne(
        const QueryDescriptor(table: 'fulfillment_policies'),
      );
      expect(physical?['delivery_fee'], 12345);
    },
  );

  test(
    'semantic constraints and shared date rules reject direct API writes',
    () async {
      final row = (await client.query(
        'fulfillment_policies',
        const FulfillmentPolicyModel().query(),
      )).items.single;
      final id = row['id']!.raw!;
      await expectLater(
        client.update(
          'fulfillment_policies',
          id,
          BeakRecord.fromRow({'support_email': 'invalid'}),
        ),
        throwsA(isA<BeakValidationException>()),
      );
      await expectLater(
        client.update(
          'fulfillment_policies',
          id,
          BeakRecord.fromRow({'promotion_starts_at': '2026-10-01T00:00:00Z'}),
        ),
        throwsA(isA<BeakValidationException>()),
      );
      await expectLater(
        client.update(
          'fulfillment_policies',
          id,
          BeakRecord.fromRow({
            'promotion_starts_at': '2026-10-01T00:00:00Z',
            'promotion_ends_at': '2026-09-01T00:00:00Z',
          }),
        ),
        throwsA(isA<BeakValidationException>()),
      );
    },
  );

  test(
    'typed dependent choices contain only the selected customer profiles',
    () async {
      final choices = UserProfileConnectionModel.options(
        filter: UserProfileConnectionModel.userId.eq(ShopSeedIds.ada),
      );
      final page = await client.query(choices.model.table, choices.query);
      expect(page.items.map((row) => row.asUserProfileConnection.name), [
        'Ada — Home',
      ]);
    },
  );

  test(
    'one final graph save creates owned lines and survives replay',
    () async {
      final plan = _orderPlan('valid-order', quantity: 2);
      final result = await client.commit(plan);
      expect(result.complete, isTrue, reason: '${result.toJson()}');
      expect(result.mode, BeakSaveMode.atomic);
      final replayed = await client.commit(plan);
      expect(replayed.identities, result.identities);
      final recovered = await client.recoverCommit(plan.saveId);
      expect(recovered.identities, result.identities);

      final orders = await client.query(
        'orders',
        const OrderModel().query(
          filter: OrderModel.reference.eq('SHOP-001'),
          relationLoads: const [BeakRelationLoad('items')],
        ),
      );
      expect(orders.total, 1);
      expect(orders.items.single.asOrder.items.single.quantity, 2);
      expect(orders.items.single.asOrder.customerId, ShopSeedIds.ada);
    },
  );

  test(
    'invalid child validation leaves the whole order graph unapplied',
    () async {
      final result = await client.commit(
        _orderPlan('invalid-order', quantity: 0),
      );
      expect(result.complete, isFalse);
      expect(
        result.outcomes.every(
          (outcome) => outcome.status == BeakWriteOutcome.unapplied,
        ),
        isTrue,
      );
      final orders = await client.query('orders', const OrderModel().query());
      expect(orders.total, 1);
      expect(orders.items.single.asOrder.id, ShopSeedIds.order);
    },
  );

  test(
    'invoice graph snapshots variants, custom work, mixed taxes and vouchers',
    () async {
      final plan = _invoicePlan('invoice-calculation');
      final saved = await client.commit(plan);
      expect(saved.complete, isTrue, reason: '${saved.toJson()}');
      final invoice = saved.rootRecord!;
      expect(InvoiceModel.subtotal.readFrom(invoice), eur('123.00'));
      expect(InvoiceModel.discount.readFrom(invoice), eur('17.30'));
      expect(InvoiceModel.tax.readFrom(invoice), eur('18.99'));
      expect(InvoiceModel.total.readFrom(invoice), eur('124.69'));
      expect(saved.rootRecord?['customer_name']?.raw, 'Ada Lovelace');
      final item = await client.getOne(
        'invoice_items',
        saved.identities['catalog-line']!,
      );
      expect(InvoiceItemModel.unitPrice.readFrom(item!), eur('49.00'));
      expect(InvoiceItemModel.taxPercent.readFrom(item), eur('20.00'));
      expect(InvoiceItemModel.label.readFrom(item), contains('1 kg'));
      const catalogRef = BeakRecordRef.existing(
        'product_variants',
        ShopSeedIds.filterCoffeeLarge,
      );
      final catalogSave = await client.commit(
        BeakSavePlan(
          saveId: 'new-catalog-price',
          root: catalogRef,
          operations: [
            BeakSaveOperation(
              id: 'catalog-price',
              kind: BeakSaveOperationKind.update,
              target: catalogRef,
              values: const ProductVariantModel().record([
                ProductVariantModel.price.to(eur('99.00')),
              ]),
            ),
          ],
        ),
      );
      expect(catalogSave.complete, isTrue);
      expect(
        InvoiceItemModel.unitPrice.readFrom(
          (await client.getOne(
            'invoice_items',
            saved.identities['catalog-line']!,
          ))!,
        ),
        eur('49.00'),
      );
      expect(
        (await client.commit(plan)).toJson(),
        saved.toJson(),
        reason: 'A replay does not reprice after catalog edits.',
      );
      expect(
        (await client.recoverCommit(plan.saveId)).toJson(),
        saved.toJson(),
      );
    },
  );

  test(
    'issued status changes accept unchanged child patches and reject content edits',
    () async {
      final saved = await client.commit(_invoicePlan('immutable-invoice'));
      expect(saved.complete, isTrue, reason: '${saved.toJson()}');
      final root = BeakRecordRef.existing(
        'invoices',
        saved.identities['invoice']!,
      );
      final item = BeakRecordRef.existing(
        'invoice_items',
        saved.identities['catalog-line']!,
      );
      final row = (await client.getOne(item.table, item.id!))!;
      final paid = await client.commit(
        BeakSavePlan(
          saveId: 'mark-paid',
          action: InvoiceActions.markPaid.name,
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'status',
              kind: BeakSaveOperationKind.update,
              target: root,
              values: const BeakRecord(values: {}),
            ),
            BeakSaveOperation(
              id: 'unchanged-line',
              kind: BeakSaveOperationKind.update,
              target: item,
              owner: root,
              relationKey: 'items',
              values: row,
              references: const {
                'product_id': BeakRecordRef.existing(
                  'products',
                  ShopSeedIds.filterCoffee,
                ),
              },
            ),
          ],
        ),
      );
      expect(paid.complete, isTrue, reason: '${paid.toJson()}');
      expect(paid.rootRecord?['status']?.raw, 'paid');
      expect(InvoiceModel.total.readFrom(paid.rootRecord!), eur('124.69'));
      final edited = await client.commit(
        BeakSavePlan(
          saveId: 'edit-issued',
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'line',
              kind: BeakSaveOperationKind.update,
              target: item,
              owner: root,
              relationKey: 'items',
              values: BeakRecord.fromRow({'quantity': 5}),
            ),
          ],
        ),
      );
      expect(edited.complete, isFalse);
      expect(edited.hasUnknown, isFalse);
      expect((await client.getOne(item.table, item.id!))?['quantity']?.raw, 2);
    },
  );

  test(
    'wrong variants, duplicate vouchers and invalid custom lines remain unapplied',
    () async {
      for (final plan in [
        _invoicePlan('wrong-variant', wrongProduct: true),
        _invoicePlan('duplicate-voucher', duplicateVoucher: true),
        _invoicePlan('duplicate-position', duplicatePosition: true),
        _invoicePlan('invalid-custom', customLabel: ''),
      ]) {
        final result = await client.commit(plan);
        expect(result.complete, isFalse, reason: plan.saveId);
        expect(result.hasUnknown, isFalse);
        expect(
          result.outcomes.every(
            (op) => op.status == BeakWriteOutcome.unapplied,
          ),
          isTrue,
        );
      }
      final invoices = await client.query(
        'invoices',
        const BeakQuerySpec(table: 'invoices'),
      );
      expect(
        invoices.total,
        1,
        reason: 'Only the original seeded invoice exists.',
      );
      expect(
        () => client.create(
          'invoice_items',
          BeakRecord.fromRow({'label': 'Bypass', 'quantity': 1}),
        ),
        throwsA(isA<BeakValidationException>()),
      );
    },
  );

  test(
    'collection search and typed filters operate through the real SQLite API',
    () async {
      for (final search in const [
        BeakSearch('light', ['attributes.value']),
        BeakSearch('COF-ETH-1000', ['variants.sku']),
      ]) {
        final products = await client.query(
          'products',
          BeakQuerySpec(table: 'products', search: search),
        );
        expect(products.items.map((row) => row['id']?.raw), [
          ShopSeedIds.filterCoffee,
        ]);
      }
      for (final search in const [
        BeakSearch('consultation', ['items.label']),
        BeakSearch('WELCOME10', ['vouchers.code_snapshot']),
      ]) {
        final invoices = await client.query(
          'invoices',
          BeakQuerySpec(table: 'invoices', search: search),
        );
        expect(invoices.items.map((row) => row['id']?.raw), [
          ShopSeedIds.invoice,
        ]);
      }
      final filtered = await client.query(
        'invoices',
        const InvoiceModel().query(
          filter: BeakAndFilter([
            InvoiceModel.status.eq(InvoiceStatus.issued),
            InvoiceModel.total.gte(eur('120.00')),
            InvoiceModel.total.lte(eur('130.00')),
            InvoiceModel.issuedAt.gte(DateTime.utc(2026, 9)),
          ]),
        ),
      );
      expect(filtered.total, 1);
      final active = await client.query(
        'product_variants',
        const BeakQuerySpec(
          table: 'product_variants',
          filter: BeakFieldFilter.forKey(
            'active',
            BeakOperator.eq,
            BeakBoolValue(true),
          ),
        ),
      );
      expect(active.total, 2);
    },
  );

  test(
    'required category attributes validate the final owned product graph',
    () async {
      const product = BeakRecordRef.draft('products', 'new-product');
      final create = BeakSaveOperation(
        id: 'product',
        kind: BeakSaveOperationKind.create,
        target: product,
        values: const ProductModel().record([
          ProductModel.name.to('Test coffee'),
          ProductModel.price.to(eur('8.50')),
        ]),
        references: const {
          'category_id': BeakRecordRef.existing(
            'categories',
            ShopSeedIds.coffeeCategory,
          ),
        },
      );
      final missing = await client.commit(
        BeakSavePlan(
          saveId: 'missing-attribute',
          root: product,
          operations: [create],
        ),
      );
      expect(missing.complete, isFalse);
      expect(missing.hasUnknown, isFalse);
      final saved = await client.commit(
        BeakSavePlan(
          saveId: 'with-attribute',
          root: product,
          operations: [
            create,
            BeakSaveOperation(
              id: 'roast',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('product_attributes', 'roast'),
              owner: product,
              relationKey: 'attributes',
              values: BeakRecord.fromRow({'name': 'Roast', 'value': 'Light'}),
              references: const {
                'definition_id': BeakRecordRef.existing(
                  'category_attributes',
                  ShopSeedIds.roastAttribute,
                ),
              },
            ),
          ],
        ),
      );
      expect(saved.complete, isTrue, reason: '${saved.toJson()}');
      final root = BeakRecordRef.existing(
        'products',
        saved.identities['new-product']!,
      );
      final attribute = BeakRecordRef.existing(
        'product_attributes',
        saved.identities['roast']!,
      );
      final removed = await client.commit(
        BeakSavePlan(
          saveId: 'remove-required',
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'remove',
              kind: BeakSaveOperationKind.delete,
              target: attribute,
              owner: root,
              relationKey: 'attributes',
            ),
          ],
        ),
      );
      expect(removed.complete, isFalse);
      expect(removed.hasUnknown, isFalse);
      expect(await client.getOne(attribute.table, attribute.id!), isNotNull);
      final categoryChanged = await client.commit(
        BeakSavePlan(
          saveId: 'change-category',
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'category',
              kind: BeakSaveOperationKind.update,
              target: root,
              references: const {
                'category_id': BeakRecordRef.existing(
                  'categories',
                  ShopSeedIds.equipmentCategory,
                ),
              },
            ),
          ],
        ),
      );
      expect(categoryChanged.complete, isFalse);
      expect(categoryChanged.hasUnknown, isFalse);
      expect(
        (await client.getOne(root.table, root.id!))?['category_id']?.raw,
        ShopSeedIds.coffeeCategory,
      );
    },
  );

  test(
    'variant attributes support collection search, nested loading and owned edits',
    () async {
      const variant = BeakRecordRef.existing(
        'product_variants',
        ShopSeedIds.filterCoffeeLarge,
      );
      final found = await client.query(
        'product_variants',
        const BeakQuerySpec(
          table: 'product_variants',
          search: BeakSearch('Whole bean', ['attributes.value']),
          relationLoads: [BeakRelationLoad('attributes')],
        ),
      );
      expect(found.total, 1);
      expect(found.items.single['id']?.raw, variant.id);
      final attributes = found.items.single.relations['attributes']!;
      expect(attributes, hasLength(2));
      final grind = attributes.singleWhere(
        (row) => row['name']?.raw == 'Grind',
      );
      final edited = await client.commit(
        BeakSavePlan(
          saveId: 'variant-attribute-edit',
          root: variant,
          operations: [
            BeakSaveOperation(
              id: 'grind',
              kind: BeakSaveOperationKind.update,
              target: BeakRecordRef.existing(
                'variant_attributes',
                grind['id']!.raw!,
              ),
              owner: variant,
              relationKey: 'attributes',
              values: BeakRecord.fromRow({'value': 'Espresso ground'}),
            ),
            BeakSaveOperation(
              id: 'tasting',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft(
                'variant_attributes',
                'tasting',
              ),
              owner: variant,
              relationKey: 'attributes',
              values: BeakRecord.fromRow({
                'name': 'Tasting notes',
                'value': 'Citrus',
              }),
            ),
          ],
        ),
      );
      expect(edited.complete, isTrue, reason: '${edited.toJson()}');
      final searched = await client.query(
        'product_variants',
        const BeakQuerySpec(
          table: 'product_variants',
          search: BeakSearch('citrus', ['attributes.value']),
        ),
      );
      expect(searched.items.single['id']?.raw, variant.id);
      final products = await client.query(
        'products',
        const BeakQuerySpec(
          table: 'products',
          relationLoads: [
            BeakRelationLoad(
              'variants',
              nested: [BeakRelationLoad('attributes')],
            ),
          ],
        ),
      );
      final product = products.items.singleWhere(
        (row) => row['id']?.raw == ShopSeedIds.filterCoffee,
      );
      final loaded = product.relations['variants']!.singleWhere(
        (row) => row['id']?.raw == variant.id,
      );
      expect(
        loaded.relations['attributes']!.map((row) => row['value']?.raw),
        containsAll(['Espresso ground', 'Citrus']),
      );
    },
  );

  test(
    'draft tax references reprice deliberately while catalog edits preserve snapshots',
    () async {
      final saved = await client.commit(
        _invoicePlan('draft-tax-change', status: InvoiceStatus.draft),
      );
      expect(saved.complete, isTrue, reason: '${saved.toJson()}');
      final invoice = BeakRecordRef.existing(
        'invoices',
        saved.identities['invoice']!,
      );
      final item = BeakRecordRef.existing(
        'invoice_items',
        saved.identities['custom-line']!,
      );
      const tax = BeakRecordRef.existing('tax_rates', ShopSeedIds.reducedTax);
      final rateChanged = await client.commit(
        BeakSavePlan(
          saveId: 'catalog-tax-change',
          root: tax,
          operations: [
            BeakSaveOperation(
              id: 'tax',
              kind: BeakSaveOperationKind.update,
              target: tax,
              values: const TaxRateModel().record([
                TaxRateModel.ratePercent.to(eur('15')),
              ]),
            ),
          ],
        ),
      );
      expect(rateChanged.complete, isTrue);
      final resaved = await client.commit(
        BeakSavePlan(
          saveId: 'draft-note',
          root: invoice,
          operations: [
            BeakSaveOperation(
              id: 'address',
              kind: BeakSaveOperationKind.update,
              target: invoice,
              values: BeakRecord.fromRow({
                'customer_address': 'Updated billing address',
              }),
            ),
          ],
        ),
      );
      expect(resaved.complete, isTrue, reason: '${resaved.toJson()}');
      expect(
        InvoiceItemModel.taxPercent.readFrom(
          (await client.getOne(item.table, item.id!))!,
        ),
        eur('10.00'),
      );
      final changed = await client.commit(
        BeakSavePlan(
          saveId: 'draft-explicit-tax',
          root: invoice,
          operations: [
            BeakSaveOperation(
              id: 'line',
              kind: BeakSaveOperationKind.update,
              target: item,
              owner: invoice,
              relationKey: 'items',
              references: const {
                'tax_rate_id': BeakRecordRef.existing(
                  'tax_rates',
                  ShopSeedIds.standardTax,
                ),
              },
            ),
          ],
        ),
      );
      expect(changed.complete, isTrue, reason: '${changed.toJson()}');
      expect(
        InvoiceItemModel.taxPercent.readFrom(
          (await client.getOne(item.table, item.id!))!,
        ),
        eur('20.00'),
      );
      expect(InvoiceModel.tax.readFrom(changed.rootRecord!), eur('21.14'));
      final moved = await client.commit(
        BeakSavePlan(
          saveId: 'move-invoice-row',
          root: invoice,
          operations: [
            BeakSaveOperation(
              id: 'move',
              kind: BeakSaveOperationKind.update,
              target: item,
              references: const {
                'invoice_id': BeakRecordRef.existing(
                  'invoices',
                  ShopSeedIds.invoice,
                ),
              },
            ),
          ],
        ),
      );
      expect(moved.complete, isFalse);
      expect(moved.hasUnknown, isFalse);
    },
  );

  test(
    'attribute definitions reject empty choices and nonfinite numeric values',
    () async {
      const definition = BeakRecordRef.existing(
        'category_attributes',
        ShopSeedIds.originAttribute,
      );
      final empty = await client.commit(
        BeakSavePlan(
          saveId: 'empty-choice',
          root: definition,
          operations: [
            BeakSaveOperation(
              id: 'choice',
              kind: BeakSaveOperationKind.update,
              target: definition,
              values: BeakRecord.fromRow({
                'value_type': 'choice',
                'choices': ', ,',
              }),
            ),
          ],
        ),
      );
      expect(empty.complete, isFalse);
      expect(empty.hasUnknown, isFalse);
      final numeric = await client.commit(
        BeakSavePlan(
          saveId: 'number-definition',
          root: definition,
          operations: [
            BeakSaveOperation(
              id: 'number',
              kind: BeakSaveOperationKind.update,
              target: definition,
              values: BeakRecord.fromRow({'value_type': 'number'}),
            ),
          ],
        ),
      );
      expect(numeric.complete, isTrue, reason: '${numeric.toJson()}');
      const product = BeakRecordRef.existing(
        'products',
        ShopSeedIds.filterCoffee,
      );
      for (final invalid in ['NaN', 'Infinity', '-Infinity']) {
        final result = await client.commit(
          BeakSavePlan(
            saveId: 'nonfinite-$invalid',
            root: product,
            operations: [
              BeakSaveOperation(
                id: 'numeric-attribute',
                kind: BeakSaveOperationKind.create,
                target: BeakRecordRef.draft(
                  'product_attributes',
                  'number-$invalid',
                ),
                owner: product,
                relationKey: 'attributes',
                values: BeakRecord.fromRow({
                  'name': 'Numeric value',
                  'value': invalid,
                }),
                references: const {'definition_id': definition},
              ),
            ],
          ),
        );
        expect(result.complete, isFalse);
        expect(result.hasUnknown, isFalse);
      }
    },
  );
  test(
    'invoice named actions enforce terminal states and idempotent receipts',
    () async {
      final draft = await client.commit(
        _invoicePlan('workflow', status: InvoiceStatus.draft),
      );
      expect(draft.complete, isTrue, reason: '${draft.toJson()}');
      final root = BeakRecordRef.existing(
        'invoices',
        draft.identities['invoice']!,
      );
      BeakSavePlan command(
        String id,
        BeakModelAction? action, [
        BeakRecord values = const BeakRecord(values: {}),
      ]) => BeakSavePlan(
        saveId: id,
        root: root,
        action: action?.name,
        operations: [
          BeakSaveOperation(
            id: 'invoice',
            kind: BeakSaveOperationKind.update,
            target: root,
            values: values,
          ),
        ],
      );
      final forged = await client.commit(
        command('forged-status', null, BeakRecord.fromRow({'status': 'paid'})),
      );
      expect(forged.complete, isFalse);
      expect(forged.hasUnknown, isFalse);
      final plan = command('issue-workflow', InvoiceActions.issue);
      final issued = await client.commit(plan);
      expect(issued.complete, isTrue, reason: '${issued.toJson()}');
      expect(issued.rootRecord?['status']?.raw, 'issued');
      final replay = await client.commit(plan);
      expect(replay.toJson(), issued.toJson());
      final paid = await client.commit(
        command('paid-workflow', InvoiceActions.markPaid),
      );
      expect(paid.complete, isTrue, reason: '${paid.toJson()}');
      expect(paid.rootRecord?['status']?.raw, 'paid');
      final cancelled = await client.commit(
        command('cancel-paid', InvoiceActions.cancel),
      );
      expect(cancelled.complete, isFalse);
      expect(
        (await client.getOne(root.table, root.id!))?['status']?.raw,
        'paid',
      );
    },
  );

  test(
    'duplicate variant combinations are rejected atomically including legacy keys',
    () async {
      const product = BeakRecordRef.existing(
        'products',
        ShopSeedIds.filterCoffee,
      );
      final current = await client.query(
        'product_variants',
        const BeakQuerySpec(
          table: 'product_variants',
          relationLoads: [BeakRelationLoad('attributes')],
        ),
      );
      final existing = current.items.singleWhere(
        (row) => row['id']?.raw == ShopSeedIds.filterCoffeeLarge,
      );
      final attributes = existing.relations['attributes']!;
      const variant = BeakRecordRef.draft('product_variants', 'duplicate');
      final duplicate = await client.commit(
        BeakSavePlan(
          saveId: 'duplicate-combination',
          root: product,
          operations: [
            BeakSaveOperation(
              id: 'variant',
              kind: BeakSaveOperationKind.create,
              target: variant,
              owner: product,
              relationKey: 'variants',
              values: const ProductVariantModel().record([
                ProductVariantModel.name.to('Duplicate'),
                ProductVariantModel.sku.to('UNIQUE-SKU'),
                ProductVariantModel.price.to(eur('12.00')),
                ProductVariantModel.stock.to(0),
                ProductVariantModel.active.to(true),
              ]),
            ),
            for (var index = 0; index < attributes.length; index++)
              BeakSaveOperation(
                id: 'attribute-$index',
                kind: BeakSaveOperationKind.create,
                target: BeakRecordRef.draft('variant_attributes', 'a-$index'),
                owner: variant,
                relationKey: 'attributes',
                values: BeakRecord.fromRow({
                  'name': attributes[index]['name']?.raw,
                  'value': attributes[index]['value']?.raw,
                }),
              ),
          ],
        ),
      );
      expect(duplicate.complete, isFalse);
      expect(duplicate.hasUnknown, isFalse);
      final remaining = await client.query(
        'product_variants',
        const BeakQuerySpec(table: 'product_variants'),
      );
      expect(remaining.total, current.total);
      expect(
        remaining.items.any((row) => row['sku']?.raw == 'UNIQUE-SKU'),
        isFalse,
      );
    },
  );
}

BeakSavePlan _invoicePlan(
  String saveId, {
  bool wrongProduct = false,
  bool duplicateVoucher = false,
  bool duplicatePosition = false,
  String customLabel = 'Barista setup consultation',
  InvoiceStatus status = InvoiceStatus.issued,
}) {
  final invoice = BeakRecordRef.draftOf(const InvoiceModel(), 'invoice');
  return BeakSavePlan(
    saveId: saveId,
    action: status == InvoiceStatus.issued ? InvoiceActions.issue.name : null,
    root: invoice,
    operations: [
      BeakSaveOperation.create(
        id: 'invoice',
        model: const InvoiceModel(),
        draftId: 'invoice',
        values: [
          InvoiceModel.number.to(saveId),
          InvoiceModel.status.to(InvoiceStatus.draft),
          InvoiceModel.issuedAt.to(DateTime.utc(2026, 9, 20)),
          InvoiceModel.dueAt.to(DateTime.utc(2026, 10, 4)),
        ],
        links: [
          InvoiceModel.customer.linkTo(
            BeakRecordRef.of(const UserModel(), ShopSeedIds.ada),
          ),
        ],
      ),
      BeakSaveOperation.create(
        id: 'catalog-line',
        model: const InvoiceItemModel(),
        draftId: 'catalog-line',
        owner: invoice,
        through: InvoiceModel.items,
        values: [InvoiceItemModel.quantity.to(2)],
        links: [
          InvoiceItemModel.product.linkTo(
            BeakRecordRef.of(
              const ProductModel(),
              wrongProduct ? ShopSeedIds.beans : ShopSeedIds.filterCoffee,
            ),
          ),
          InvoiceItemModel.variant.linkTo(
            BeakRecordRef.of(
              const ProductVariantModel(),
              ShopSeedIds.filterCoffeeLarge,
            ),
          ),
        ],
      ),
      BeakSaveOperation.create(
        id: 'custom-line',
        model: const InvoiceItemModel(),
        draftId: 'custom-line',
        owner: invoice,
        through: InvoiceModel.items,
        values: [
          InvoiceItemModel.label.to(customLabel),
          InvoiceItemModel.quantity.to(1),
          InvoiceItemModel.unitPrice.to(eur('25.00')),
        ],
        links: [
          InvoiceItemModel.taxRate.linkTo(
            BeakRecordRef.of(const TaxRateModel(), ShopSeedIds.reducedTax),
          ),
        ],
      ),
      for (var index = 0; index < 2; index++)
        BeakSaveOperation.create(
          id: 'voucher-$index',
          model: const InvoiceVoucherModel(),
          draftId: 'voucher-$index',
          owner: invoice,
          through: InvoiceModel.vouchers,
          values: [
            InvoiceVoucherModel.position.to(duplicatePosition ? 0 : index),
          ],
          links: [
            InvoiceVoucherModel.voucher.linkTo(
              BeakRecordRef.of(
                const VoucherModel(),
                index == 0 || duplicateVoucher
                    ? ShopSeedIds.welcomeVoucher
                    : ShopSeedIds.loyaltyVoucher,
              ),
            ),
          ],
        ),
    ],
  );
}

BeakSavePlan _orderPlan(String saveId, {required int quantity}) {
  final order = BeakRecordRef.draftOf(const OrderModel(), 'order');
  return BeakSavePlan(
    saveId: saveId,
    root: order,
    operations: [
      BeakSaveOperation.create(
        id: 'order',
        model: const OrderModel(),
        draftId: 'order',
        values: [
          OrderModel.reference.to('SHOP-001'),
          OrderModel.deliveryDate.to(DateTime.utc(2200)),
        ],
        links: [
          OrderModel.customer.linkTo(
            BeakRecordRef.of(const UserModel(), ShopSeedIds.ada),
          ),
          OrderModel.profile.linkTo(
            BeakRecordRef.of(
              const UserProfileConnectionModel(),
              ShopSeedIds.adaProfile,
            ),
          ),
        ],
      ),
      BeakSaveOperation.create(
        id: 'line',
        model: const OrderItemModel(),
        draftId: 'line',
        owner: order,
        through: OrderModel.items,
        values: [OrderItemModel.quantity.to(quantity)],
        links: [
          OrderItemModel.product.linkTo(
            BeakRecordRef.of(const ProductModel(), ShopSeedIds.beans),
          ),
        ],
      ),
    ],
  );
}
