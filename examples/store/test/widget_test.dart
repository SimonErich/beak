import 'package:beak/beak.dart';
import 'package:beak/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store/beak/app.g.dart';
import 'package:store/beak/panel.g.dart';
import 'package:store/beak/registry.g.dart';
import 'package:store/models/product.dart';

void main() {
  testWidgets('the panel boots with every declared model registered', (
    tester,
  ) async {
    final registry = buildBeakRegistry();
    final source = InMemoryBeakDataSource(registry: registry)
      ..seed(const ProductModel(), [
        BeakRecord.fromRow(const {
          'id': 'p1',
          'name': 'Espresso Beans',
          'sku': 'COF-ESP-1KG',
          'price': 12.5,
          'stock': 42,
          'featured': true,
          'status': 'published',
        }),
      ]);

    // A desktop-sized surface: the default 800×600 test window is narrower
    // than the panel's own layout breakpoints.
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(BeakApp(dataSource: source));
    await tester.pumpAndSettle();

    expect(beakModels, isNotEmpty, reason: 'no model was discovered');
    for (final model in beakModels) {
      expect(
        registry.byTable(model.table),
        isNotNull,
        reason: '${model.table} is not registered',
      );
    }
  });

  test('the sidebar lists the navigable resources, not the private ones', () {
    final config = buildBeakPanel();
    final tables = config.resources.map((resource) => resource.model.table);

    expect(tables, containsAll(['products', 'orders', 'users']));
    // Reached through its order, never from the sidebar — but it keeps its
    // model, its API and its relationships.
    expect(tables, isNot(contains('order_items')));
    expect(buildBeakRegistry().byTable('order_items'), isNotNull);
  });

  test('every column kind Beak has is demonstrated somewhere', () {
    // `BeakEnumColumn<T>` is one runtime type per enum; collapse them.
    final Set<String> kinds = {
      for (final model in beakModels)
        for (final column in model.columns)
          column.runtimeType.toString().split('<').first,
    };

    // The point of this example is that a reader can find every kind in it.
    // A new column kind nothing here uses fails this test, which is the
    // reminder to teach it.
    expect(
      kinds,
      containsAll(const {
        'BeakStringColumn',
        'BeakTextColumn',
        'BeakRichTextColumn',
        'BeakIntColumn',
        'BeakDecimalColumn',
        'BeakBoolColumn',
        'BeakDateTimeColumn',
        'BeakEnumColumn',
        'BeakJsonColumn',
        'BeakColorColumn',
        'BeakImageColumn',
        'BeakFileColumn',
        'BeakCustomColumn',
      }),
    );
  });

  test('every relationship kind is demonstrated somewhere', () {
    final Set<String> kinds = {
      for (final model in beakModels)
        for (final relation in model.relationships)
          relation.runtimeType.toString(),
    };

    expect(kinds, {
      'BeakBelongsTo',
      'BeakHasOne',
      'BeakHasMany',
      'BeakBelongsToMany',
    });
  });
}
