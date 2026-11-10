import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _name = BeakStringColumn(key: 'name', label: 'Name');

final class _OrderModel extends BeakModel {
  const _OrderModel();

  @override
  String get table => 'orders';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    _name,
  ];
}

void main() {
  Future<void> pumpLink(WidgetTester tester, BeakFormWidget link) async {
    final session = BeakFormSession(
      model: const _OrderModel(),
      dataSource: FakeDataSource(
        models: const [_OrderModel()],
        records: {
          'orders': {
            'o1': BeakRecord.fromRow({'id': 'o1', 'name': 'Lunch for ten'}),
          },
        },
      ),
      recordId: 'o1',
      layout: BeakFormLayout(children: [link]),
    );
    addTearDown(session.dispose);
    await tester.runAsync(session.load);
    await tester.pumpWidget(
      OiApp(
        home: Builder(
          builder: (context) => link.builder(context, session.root),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('links the shown record by its display value', (tester) async {
    await pumpLink(tester, const _OrderModel().recordLink());

    expect(find.text('Lunch for ten'), findsOneWidget);
    expect(find.byType(OiTappable), findsOneWidget);
  });

  testWidgets('a title binding replaces the display value', (tester) async {
    await pumpLink(
      tester,
      const _OrderModel().recordLink(
        title: BeakValueBinding<String>.computed(
          dependencies: const [
            BeakScalarField<String>(model: _OrderModel(), column: _name),
          ],
          compute: (reader) =>
              'Order: ${reader.read(const BeakScalarField<String>(model: _OrderModel(), column: _name))}',
        ),
      ),
    );

    expect(find.text('Order: Lunch for ten'), findsOneWidget);
  });
}
