import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

/// A small model whose columns exercise the detail-field renderers.
final class _ItemModel extends BeakModel {
  const _ItemModel();

  @override
  String get table => 'items';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakStringColumn(key: 'sku', label: 'SKU'),
    BeakIntColumn(key: 'stock', label: 'Stock'),
  ];
}

void main() {
  const name = BeakStringColumn(key: 'name', label: 'Name');
  const sku = BeakStringColumn(key: 'sku', label: 'SKU');
  const stock = BeakIntColumn(key: 'stock', label: 'Stock');

  final record = BeakRecord.fromRow(const {
    'id': 'i1',
    'name': 'Wireless mouse',
    'sku': 'WM-001',
    'stock': 42,
  });

  Future<void> pump(
    WidgetTester tester,
    BeakBlock block, {
    bool scoped = true,
  }) {
    Widget child = BeakBlockHost(block: block);
    if (scoped) {
      child = BeakRecordScope(
        model: const _ItemModel(),
        record: record,
        child: child,
      );
    }
    return tester.pumpWidget(OiApp(theme: OiThemeData.light(), home: child));
  }

  testWidgets('field block renders its label and scoped value', (tester) async {
    await pump(tester, const BeakFieldBlock(name));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Wireless mouse'), findsOneWidget);
  });

  testWidgets('field block honors a label override', (tester) async {
    await pump(tester, const BeakFieldBlock(sku, label: 'Article number'));
    await tester.pumpAndSettle();

    expect(find.text('Article number'), findsOneWidget);
    expect(find.text('WM-001'), findsOneWidget);
  });

  testWidgets('field group lays several fields onto a grid', (tester) async {
    await pump(
      tester,
      const BeakFieldGroupBlock([name, sku, stock], columnCount: 3),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OiGrid), findsWidgets);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('SKU'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Wireless mouse'), findsOneWidget);
    expect(find.text('WM-001'), findsOneWidget);
  });

  testWidgets('field block renders nothing outside a record scope', (
    tester,
  ) async {
    await pump(tester, const BeakFieldBlock(name), scoped: false);
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsNothing);
    expect(find.text('Wireless mouse'), findsNothing);
  });
}
