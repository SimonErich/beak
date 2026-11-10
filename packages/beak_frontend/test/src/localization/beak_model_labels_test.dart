import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

enum _Status { active, retired }

const _name = BeakStringColumn(
  key: 'name',
  label: 'Name',
  translations: {'de': 'Bezeichnung', 'en': 'Title'},
  hints: {'de': 'Wie der Kunde es sieht', 'en': 'As the customer sees it'},
);

const _status = BeakEnumColumn<_Status>(
  key: 'status',
  label: 'Status',
  translations: {'de': 'Zustand', 'en': 'State'},
  values: _Status.values,
  filterable: true,
  valueTranslations: {
    'de': {_Status.active: 'Aktiv', _Status.retired: 'Eingestellt'},
    'en': {_Status.active: 'Active', _Status.retired: 'Retired'},
  },
);

final class _ProductModel extends BeakModel {
  const _ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id', visibleOn: {BeakContext.detail}),
    _name,
    _status,
  ];

  @override
  BeakModelLabels get labels => const BeakModelLabels(
    one: {'de': 'Produkt', 'en': 'Product'},
    other: {'de': 'Produkte', 'en': 'Products'},
  );
}

const _nameField = BeakScalarField<String>(
  model: _ProductModel(),
  column: _name,
);

const _statusField = BeakScalarField<_Status>(
  model: _ProductModel(),
  column: _status,
);

void main() {
  tearDown(() => BeakLabels.language = null);

  Future<void> pumpPanel(WidgetTester tester, Locale locale) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: BeakPanelConfig(
          title: 'Shop',
          locale: locale,
          resources: [
            BeakResource.standard(
              const _ProductModel(),
              columns: [_nameField, _statusField],
              filters: [_statusField.selectFilter()],
              form: [_nameField.inputText()],
            ),
          ],
        ),
        dataSource: FakeDataSource(
          models: const [_ProductModel()],
          records: {
            'products': {
              'p1': const BeakRecord(
                values: {
                  'name': BeakStringValue('Tea'),
                  'status': BeakStringValue('active'),
                },
              ),
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(OiAppShell))).go(location);
    await tester.pumpAndSettle();
  }

  for (final (locale, plural, column, state, value) in [
    (const Locale('de'), 'Produkte', 'Bezeichnung', 'Zustand', 'Aktiv'),
    (const Locale('en'), 'Products', 'Title', 'State', 'Active'),
  ]) {
    testWidgets('the list speaks ${locale.languageCode} from the model', (
      tester,
    ) async {
      await pumpPanel(tester, locale);
      await go(tester, '/products');

      expect(find.text(plural), findsWidgets);
      expect(find.text(column), findsWidgets);
      expect(find.text(state), findsWidgets);
      expect(find.text(value), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an input shows the column hint in the panel language', (
    tester,
  ) async {
    await pumpPanel(tester, const Locale('de'));
    await go(tester, '/products/create');

    expect(find.text('Bezeichnung'), findsWidgets);
    expect(find.text('Wie der Kunde es sieht'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a label placed with the input wins over the model', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: BeakPanelConfig(
          title: 'Shop',
          locale: const Locale('de'),
          resources: [
            BeakResource.standard(
              const _ProductModel(),
              form: [_nameField.inputText(label: 'Lala')],
            ),
          ],
        ),
        dataSource: FakeDataSource(models: const [_ProductModel()]),
      ),
    );
    await tester.pumpAndSettle();
    await go(tester, '/products/create');

    expect(find.text('Lala'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
