import 'package:beak/panel.dart';
import 'package:beak/testing.dart';
import 'package:clean_beak_config/beak/registry.g.dart';
import 'package:clean_beak_config/resources/orders/models/order.dart';
import 'package:clean_beak_config/resources/orders/models/order_item.dart';
import 'package:clean_beak_config/resources/orders/screens/order_form_wizard_screen.dart';
import 'package:clean_beak_config/resources/products/models/product.dart';
import 'package:clean_beak_config/resources/users/models/user.dart';
import 'package:clean_beak_config/resources/users/models/user_profile_connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clean_beak_config/seeders/shop_seeder.dart';
import 'support/shop_test_api.dart';
import 'support/money.dart';

void main() {
  // --8<-- [start:formLogicInMemoryTest]
  test(
    'model suggestions follow catalog changes until the price is overridden',
    () async {
      final registry = buildBeakRegistry();
      final source = InMemoryBeakDataSource(registry: registry);
      final session = BeakFormSession(
        model: const OrderModel(),
        registry: registry,
        dataSource: source,
        steps: orderSteps(),
      );
      addTearDown(session.dispose);
      final first = const ProductModel().record([
        ProductModel.id.to('a'),
        ProductModel.name.to('First'),
        ProductModel.price.to(eur('12.50')),
      ]);
      final second = const ProductModel().record([
        ProductModel.id.to('b'),
        ProductModel.name.to('Second'),
        ProductModel.price.to(eur('20.00')),
      ]);
      source.seed(const ProductModel(), [first, second]);
      final row = session.root.addRow(OrderModel.items);
      row.select(OrderItemModel.product, first);
      expect(row.read(OrderItemModel.overwritePrice), eur('12.50'));
      expect(row.read(OrderItemModel.label), 'First');
      row.select(OrderItemModel.product, second);
      expect(row.read(OrderItemModel.overwritePrice), eur('20.00'));
      expect(row.read(OrderItemModel.label), 'Second');
      row.set(OrderItemModel.overwritePrice, eur('7.00'));
      row.select(OrderItemModel.product, first);
      expect(row.read(OrderItemModel.overwritePrice), eur('7.00'));
      expect(row.read(OrderItemModel.label), 'First');
    },
  );
  // --8<-- [end:formLogicInMemoryTest]

  // --8<-- [start:formSaveThroughApiTest]
  test(
    'the actual configured wizard binds, calculates and saves its draft',
    () async {
      final registry = buildBeakRegistry();
      final api = await ShopTestApi.start();
      addTearDown(api.dispose);
      final source = HttpBeakDataSource(api.client);
      final customer = (await source.getOne(
        const UserModel().table,
        ShopSeedIds.ada,
      ))!;
      final profile = (await source.getOne(
        const UserProfileConnectionModel().table,
        ShopSeedIds.adaProfile,
      ))!;
      final product = (await source.getOne(
        const ProductModel().table,
        ShopSeedIds.beans,
      ))!;
      final before = (await source.query(const OrderModel().query())).total;
      final session = BeakFormSession(
        model: const OrderModel(),
        dataSource: source,
        registry: registry,
        steps: orderSteps(),
      );
      addTearDown(session.dispose);
      expect(await session.validateStep(0), isFalse);
      session.root.set(OrderModel.reference, 'SHOP-001');
      session.root.select(OrderModel.customer, customer);
      expect(await session.validateStep(0), isTrue);
      session.root.select(OrderModel.profile, profile);
      session.root.set(OrderModel.deliveryDate, DateTime.utc(2200));
      final row = session.root.addRow(OrderModel.items);
      row.set(OrderItemModel.quantity, 2);
      row.select(OrderItemModel.product, product);
      expect(lineTotal(BeakFormReader(row)), eur('25.00'));
      final checkpoint = row.checkpoint();
      row.set(OrderItemModel.discount, eur('5'));
      expect(lineTotal(BeakFormReader(row)), eur('20.00'));
      row.restore(checkpoint);
      expect(lineTotal(BeakFormReader(row)), eur('25.00'));
      expect((await source.query(const OrderModel().query())).total, before);
      final result = await session.save();
      expect(
        result?.complete,
        isTrue,
        reason:
            '${session.error.value}; root=${session.root.errors}; row=${row.errors}; result=${result?.toJson()}',
      );
      expect(
        (await source.query(const OrderModel().query())).total,
        before + 1,
      );
      expect(
        (await source.query(
          const OrderItemModel().query(
            filter: OrderItemModel.orderId.eq(result!.rootRecord!.asOrder.id),
          ),
        )).items.single.asOrderItem.quantity,
        2,
      );
    },
  );
  // --8<-- [end:formSaveThroughApiTest]
}
