import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _formats = BeakFormatting(
  locale: 'de_AT',
  currency: 'EUR',
  emptyValue: 'None',
);
const _model = _Model();

void main() {
  test(
    'semantic read text uses shared exact formatting and record currency',
    () {
      const record = BeakRecord(
        values: {
          'money': BeakIntValue(123456),
          'currency': BeakStringValue('KWD'),
        },
      );
      final text = beakCellText(
        _Model.money,
        123456,
        record: record,
        formatting: _formats,
      );
      expect(text, contains('123,456'));
      expect(
        text,
        _formats.exactCurrency(
          const BeakDecimal(123456, scale: 3),
          code: 'KWD',
        ),
      );
      expect(
        beakCellText(_Model.date, '2028-02-29', formatting: _formats),
        '2028-02-29',
      );
      expect(
        beakCellText(_Model.percent, 0.0825, formatting: _formats),
        '8,25\u00a0%',
      );
      expect(
        beakCellText(_Model.password, 'secret', formatting: _formats),
        isNot(contains('secret')),
      );
      expect(beakCellText(_Model.email, null, formatting: _formats), 'None');
    },
  );

  testWidgets('semantic text inputs use keyboard types and obscure passwords', (
    tester,
  ) async {
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: _model,
          dataSource: FakeDataSource(),
          layout: BeakFormLayout(
            children: [
              for (final column in [
                _Model.email,
                _Model.url,
                _Model.phone,
                _Model.password,
              ])
                BeakScalarField<String>(model: _model, column: column).input(),
            ],
          ),
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final inputs = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(inputs[0].keyboardType, TextInputType.emailAddress);
    expect(inputs[1].keyboardType, TextInputType.url);
    expect(inputs[2].keyboardType, TextInputType.phone);
    expect(inputs[3].obscureText, isTrue);
    await tester.enterText(find.byType(EditableText).first, 'invalid');
    expect(await session.root.validate(), isFalse);
    await tester.enterText(
      find.byType(EditableText).first,
      'person@example.com',
    );
    expect(await session.root.validate(), isTrue);
  });

  testWidgets(
    'money filters emit exact stored units and reject malformed input',
    (tester) async {
      BeakFilter? filter;
      final filters = beakDefaultFiltersOf(_model);
      expect(filters.whereType<BeakSemanticRangeFilter>(), hasLength(3));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFormattingScope(
            formatting: _formats,
            child: BeakFilterBar(
              filters: [filters.first],
              onChanged: (value) => filter = value,
              presentation: BeakFilterBarPresentation.controls,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, '12,345');
      await tester.pump();
      expect(filter, isNotNull);
      final predicates = switch (filter) {
        BeakAndFilter(:final filters) => filters,
        final BeakFilter one => [one],
        _ => <BeakFilter>[],
      };
      expect(
        predicates.single,
        isA<BeakFieldFilter>().having(
          (value) => value.value.raw,
          'exact units',
          12345,
        ),
      );
      final valid = filter;
      await tester.enterText(find.byType(EditableText).first, '12,3456');
      await tester.pump();
      expect(filter, same(valid));
      expect(
        tester
            .widgetList<OiTextInput>(find.byType(OiTextInput))
            .any((input) => input.error != null),
        isTrue,
      );
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pump();
      expect(filter, isNull);
    },
  );

  testWidgets(
    'inline calendar presets update both inputs and retain custom bounds',
    (tester) async {
      BeakFilter? filter;
      const field = BeakScalarField<BeakDate>(
        model: _model,
        column: _Model.date,
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFilterBar(
            stacked: true,
            filters: [
              field.dateRangeFilter(
                inline: true,
                presets: const [
                  BeakRangePreset(
                    label: 'Next week',
                    lower: BeakDate(2028, 2, 28),
                    upper: BeakDate(2028, 3, 5),
                  ),
                ],
              ),
            ],
            onChanged: (value) => filter = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next week'));
      await tester.pumpAndSettle();
      expect(
        filter,
        BeakAndFilter([
          field.gte(const BeakDate(2028, 2, 28)),
          field.lte(const BeakDate(2028, 3, 5)),
        ]),
      );
      final inputs = tester
          .widgetList<OiDateInput>(find.byType(OiDateInput))
          .toList();
      expect(inputs.first.value, DateTime(2028, 2, 28));
      expect(inputs.last.value, DateTime(2028, 3, 5));
      expect(
        tester.getTopLeft(find.byType(OiDateInput).first).dy,
        tester.getTopLeft(find.byType(OiDateInput).last).dy,
      );
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      inputs.last.onChanged!(DateTime(2028, 3, 6));
      await tester.pumpAndSettle();
      expect(
        filter,
        BeakAndFilter([
          field.gte(const BeakDate(2028, 2, 28)),
          field.lte(const BeakDate(2028, 3, 6)),
        ]),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date-only range filter serializes calendar bounds without timezone',
    (tester) async {
      BeakFilter? filter;
      const field = BeakScalarField<BeakDate>(
        model: _model,
        column: _Model.date,
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFilterBar(
            filters: [field.rangeFilter()],
            onChanged: (value) => filter = value,
            presentation: BeakFilterBarPresentation.controls,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<OiDateInput>(find.byType(OiDateInput).first).onChanged!(
        DateTime(2028, 2, 29),
      );
      await tester.pump();
      expect(
        filter,
        isA<BeakFieldFilter>().having(
          (value) => value.value.raw,
          'calendar bound',
          '2028-02-29',
        ),
      );
    },
  );
}

final class _Model extends BeakModel {
  const _Model();
  static const currency = BeakStringColumn(key: 'currency', label: 'Currency');
  static const money = BeakIntColumn(
    key: 'money',
    label: 'Money',
    filterable: true,
    semantic: BeakSemantic.money(scale: 3, currencyColumn: currency),
  );
  static const date = BeakStringColumn(
    key: 'date',
    label: 'Date',
    filterable: true,
    semantic: BeakSemantic.calendarDate(),
  );
  static const percent = BeakDecimalColumn(
    key: 'percent',
    label: 'Percent',
    precision: 4,
    filterable: true,
    semantic: BeakSemantic.percentage(scale: 1),
  );
  static const email = BeakStringColumn(
    key: 'email',
    label: 'Email',
    semantic: BeakSemantic.email(),
  );
  static const url = BeakStringColumn(
    key: 'url',
    label: 'URL',
    semantic: BeakSemantic.url(),
  );
  static const phone = BeakStringColumn(
    key: 'phone',
    label: 'Phone',
    semantic: BeakSemantic.phone(),
  );
  static const password = BeakStringColumn(
    key: 'password',
    label: 'Password',
    semantic: BeakSemantic.password(),
  );
  @override
  String get table => 'presentation';
  @override
  String get displayColumnKey => 'email';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    money,
    currency,
    date,
    percent,
    email,
    url,
    phone,
    password,
  ];
}
