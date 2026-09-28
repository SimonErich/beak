import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _formats = BeakFormatting(
  locale: 'de_AT',
  currency: 'EUR',
  datePattern: 'dd.MM.yyyy',
  dateTimePattern: 'dd.MM.yyyy HH:mm',
);
const _title = BeakScalarField<String>(
  model: _Product(),
  column: _Product.title,
);
const _description = BeakScalarField<String>(
  model: _Product(),
  column: _Product.description,
);
const _price = BeakScalarField<int>(model: _Product(), column: _Product.price);
const _products = BeakToManyField(
  model: _Basket(),
  target: _Product(),
  relation: _Basket.products,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 1100,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFormattingScope(formatting: _formats, child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'numeric cents keep their storage scale when display currency has no decimals',
    (tester) async {
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFormattingScope(
            formatting: const BeakFormatting(currency: 'JPY'),
            child: BeakConfiguredForm(
              model: const _Product(),
              dataSource: FakeDataSource(),
              layout: BeakFormLayout(
                children: [_price.inputCurrency(minorUnits: true)],
              ),
              onSession: (value) => session = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '12.34');
      expect(session.root.read(_price), 1234);
      await tester.enterText(find.byType(EditableText), '-');
      expect(await session.root.validate(), isFalse);
      expect(session.root.read(_price), 1234);
    },
  );

  test(
    'one formatting policy controls numbers, currency, dates and summaries',
    () {
      expect(_formats.number(1234.5, precision: 2), '1\u00a0234,50');
      expect(_formats.currency(1234.5), contains('1\u00a0234,50'));
      expect(_formats.currency(1234.5), contains('€'));
      expect(_formats.date(DateTime(2026, 9, 26)), '26.09.2026');
      expect(
        _formats.dateTime(DateTime(2026, 9, 26, 14, 35)),
        '26.09.2026 14:35',
      );
      expect(
        _formats.format(1234.5, BeakValueFormat.currency),
        _formats.currency(1234.5),
      );
      expect(_formats.format(0.0825, BeakValueFormat.percent), '8,25\u00a0%');
      expect(_formats.parseNumber('1\u00a0234,56'), 1234.56);
      expect(_formats.parseNumber('-12,5'), -12.5);
      expect(_formats.parseNumber('1.23'), isNull);
      expect(_formats.parseNumber('12\u00a03,45'), isNull);
      expect(_formats.parseNumber('1,2,3'), isNull);
    },
  );

  test('column text uses panel formats including relative date fallback', () {
    const amount = BeakDecimalColumn(
      key: 'amount',
      label: 'Amount',
      prefix: '€',
    );
    expect(
      beakCellText(amount, '1234.50', formatting: _formats),
      _formats.currency(1234.5),
    );
    const quantity = BeakIntColumn(
      key: 'quantity',
      label: 'Quantity',
      suffix: ' pcs',
    );
    expect(
      beakCellText(quantity, 1234, formatting: _formats),
      '1\u00a0234 pcs',
    );
    const date = BeakDateTimeColumn(
      key: 'at',
      label: 'At',
      format: BeakDateFormat.dateOnly,
    );
    expect(
      beakCellText(date, '2026-09-26T14:35:00Z', formatting: _formats),
      '26.09.2026',
    );
    const relative = BeakDateTimeColumn(
      key: 'at',
      label: 'At',
      format: BeakDateFormat.relative,
    );
    expect(
      beakCellText(
        relative,
        DateTime(2026, 9, 26),
        now: () => DateTime(2027),
        formatting: _formats,
      ),
      '26.09.2026',
    );
    expect(
      beakCellText(
        relative,
        DateTime(2026, 9, 26),
        now: () => DateTime(2026, 1, 1),
        formatting: _formats,
      ),
      '26.09.2026',
    );
  });

  test('formatting preserves value types and supports currency precision', () {
    const formats = BeakFormatting(
      currency: 'JPY',
      useGrouping: false,
      useLocalTime: false,
    );
    expect(formats.moneyPrecision, 0);
    expect(formats.currencySymbol, '¥');
    expect(formats.currency(1234), '¥1234');
    expect(formats.number(1234.5), '1234.50');
    expect(
      formats.currency(1234.5, code: 'EUR', symbol: '€', precision: 2),
      '€1234.50',
    );
    expect(formats.time(DateTime.utc(2026, 9, 26, 14, 35)), '14:35');
    expect(
      formats.format('2026-09-26T14:35:00Z', BeakValueFormat.date),
      '2026-09-26',
    );
    expect(
      formats.format('2026-09-26T14:35:00Z', BeakValueFormat.dateTime),
      '2026-09-26 14:35',
    );
    expect(formats.format('12.5', BeakValueFormat.number), '12.50');
    expect(formats.format('text', BeakValueFormat.currency), 'text');
    expect(formats.format(null, BeakValueFormat.text), '—');
    expect(formats.parseNumber(''), isNull);
    expect(formats.parseNumber('NaN'), isNull);
    expect(formats.parseNumber('1e3'), isNull);
    expect(formats.parseNumber('1,234.56'), 1234.56);
    expect(formats.parseNumber('1,23.45'), isNull);
    expect(formats.parseNumber('12.3,4'), isNull);
    expect(const BeakFormatting(currencyPrecision: 3).moneyPrecision, 3);
  });

  testWidgets('typed currency fields share table and form presentation', (
    tester,
  ) async {
    final amount = _price.currency(minorUnits: true, label: 'Amount due');
    final record = BeakRecord.fromRow({
      'id': 'p1',
      'title': 'Coffee',
      'price_in_cents': 123456,
    });
    final source = FakeDataSource(
      models: const [_Product()],
      records: {
        'format_products': {'p1': record},
      },
    );
    expect(amount.readFrom(record), 123456);
    expect(amount.eq(123456).toJson(), _price.eq(123456).toJson());
    await pump(
      tester,
      BeakDataTable(
        model: const _Product(),
        dataSource: source,
        fields: [amount],
        enableDelete: false,
      ),
    );
    expect(find.text('Amount due'), findsOneWidget);
    expect(find.text(_formats.currency(1234.56)), findsOneWidget);
    await pump(
      tester,
      BeakConfiguredForm(
        model: const _Product(),
        dataSource: source,
        recordId: 'p1',
        mode: BeakFormMode.read,
        layout: BeakFormLayout(children: [amount.input()]),
      ),
    );
    expect(find.text('Amount due'), findsOneWidget);
    expect(find.text(_formats.currency(1234.56)), findsOneWidget);
  });

  testWidgets('tabs retain drafts and activate an invalid inactive tab', (
    tester,
  ) async {
    final source = FakeDataSource(models: const [_Product()]);
    await pump(
      tester,
      BeakConfiguredForm(
        model: const _Product(),
        dataSource: source,
        layout: BeakTabs(
          tabs: [
            BeakTab(title: 'Basics', children: [_title.inputText()]),
            BeakTab(title: 'Details', children: [_description.inputText()]),
          ],
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'Coffee');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('This field is required.'), findsOneWidget);
    expect(source.createCalls, isEmpty);
    await tester.enterText(find.byType(EditableText), 'Freshly roasted');
    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Coffee',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(source.createCalls.single.$2['description']?.raw, 'Freshly roasted');
  });

  testWidgets('tabs retain custom local widget state across navigation', (
    tester,
  ) async {
    await pump(
      tester,
      BeakConfiguredForm(
        model: const _Product(),
        dataSource: FakeDataSource(models: const [_Product()]),
        layout: BeakTabs(
          tabs: [
            BeakTab(
              title: 'One',
              children: [BeakFormWidget(builder: (_, _) => const _Counter())],
            ),
            const BeakTab(title: 'Two', children: []),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Count 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsNothing);
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
  });

  testWidgets(
    'nested row errors activate their tab and summaries stay numeric',
    (tester) async {
      late BeakFormSession session;
      await pump(
        tester,
        BeakConfiguredForm(
          model: const _Basket(),
          dataSource: FakeDataSource(models: const [_Basket(), _Product()]),
          onSession: (value) => session = value,
          layout: BeakTabs(
            tabs: [
              BeakTab(
                title: 'Overview',
                children: [_Basket.locked.inputToggle(visibleIf: (_) => false)],
              ),
              BeakTab(
                title: 'Items',
                children: [
                  _products.tableForm(
                    minRows: 1,
                    children: [
                      _price.inputCurrency(
                        minorUnits: true,
                        validate: const [BeakRequired()],
                      ),
                    ],
                    summary: (rows) =>
                        rows.fold<num>(
                          0,
                          (sum, row) => sum + (row.read(_price) ?? 0),
                        ) /
                        100,
                    summaryLabel: 'Total',
                    summaryFormat: BeakValueFormat.currency,
                    enabledIf: (state) => state.read(_Basket.locked) != true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Add Products'), findsOneWidget);
      expect(session.root.errors['products'], isNotEmpty);
      await tester.tap(find.text('Add Products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '12,50');
      await tester.pumpAndSettle();
      expect(find.text('Total: ${_formats.currency(12.5)}'), findsOneWidget);
      session.root.set(_Basket.locked, true);
      await tester.pumpAndSettle();
      expect(find.text('Add Products'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text(_formats.currency(12.5)), findsOneWidget);
    },
  );

  testWidgets(
    'currency input uses locale separators and stores integer cents',
    (tester) async {
      final source = FakeDataSource(models: const [_Product()]);
      await pump(
        tester,
        BeakConfiguredForm(
          model: const _Product(),
          dataSource: source,
          layout: BeakFormLayout(
            children: [_price.inputCurrency(minorUnits: true)],
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '1\u00a0234,56');
      await tester.enterText(find.byType(EditableText), '12\u00a03,56');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '1\u00a0234,56',
      );
      await tester.enterText(find.byType(EditableText), '1.23');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '1\u00a0234,56',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(source.createCalls.single.$2['price_in_cents']?.raw, 123456);
      expect(find.text(_formats.currency(1234.56)), findsOneWidget);
    },
  );

  testWidgets('columns collapse with their available width', (tester) async {
    final layout = BeakColumns(
      children: [_title.inputText(), _description.inputText()],
    );
    await pump(
      tester,
      BeakConfiguredForm(
        model: const _Product(),
        dataSource: FakeDataSource(models: const [_Product()]),
        layout: layout,
      ),
      width: 390,
    );
    final fields = find.byType(EditableText);
    expect(
      tester.getRect(fields.at(1)).top,
      greaterThan(tester.getRect(fields.first).bottom),
    );
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    await tester.pumpAndSettle();
    expect(tester.getRect(fields.at(1)).top, tester.getRect(fields.first).top);
  });

  for (final variant in [
    OiResourcePageVariant.create,
    OiResourcePageVariant.edit,
  ]) {
    testWidgets('a tall ${variant.name} form scrolls through cards to Save', (
      tester,
    ) async {
      await pump(
        tester,
        BeakPageScaffold(
          resource: const BeakResource(model: _Product()),
          variant: variant,
          child: BeakConfiguredForm(
            model: const _Product(),
            dataSource: FakeDataSource(models: const [_Product()]),
            layout: BeakTabs(
              tabs: [
                BeakTab(
                  title: 'Overview',
                  children: [
                    BeakColumns(
                      children: [
                        BeakCard(
                          title: 'First card',
                          children: [
                            _title.inputText(),
                            BeakFormWidget(
                              builder: (_, _) => const SizedBox(height: 350),
                            ),
                          ],
                        ),
                        BeakCard(
                          title: 'Second card',
                          children: [
                            _price.inputCurrency(),
                            BeakFormWidget(
                              builder: (_, _) => const SizedBox(height: 350),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        width: 375,
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.text('Second card')),
          scrollDelta: const Offset(0, 1000),
        ),
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
      expect(find.text('Save').hitTestable(), findsOneWidget);
    });
  }
}

class _Counter extends HookWidget {
  const _Counter();
  @override
  Widget build(BuildContext context) {
    final count = useState(0);
    return OiButton.secondary(
      label: 'Count ${count.value}',
      onTap: () => count.value++,
    );
  }
}

final class _Basket extends BeakModel {
  const _Basket();
  static const locked = BeakScalarField<bool>(
    model: _Basket(),
    column: BeakBoolColumn(key: 'locked', label: 'Locked'),
  );
  static const products = BeakHasMany(
    key: 'products',
    label: 'Products',
    relatedTable: 'format_products',
    displayColumnKey: 'title',
    foreignKey: 'basket_id',
  );
  @override
  String get table => 'format_baskets';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    locked.column,
  ];
  @override
  List<BeakRelationship> get relationships => const [products];
}

final class _Product extends BeakModel {
  const _Product();
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    rules: [BeakRequired()],
  );
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    rules: [BeakRequired()],
  );
  static const price = BeakIntColumn(key: 'price_in_cents', label: 'Price');
  @override
  String get table => 'format_products';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    title,
    description,
    price,
  ];
}
