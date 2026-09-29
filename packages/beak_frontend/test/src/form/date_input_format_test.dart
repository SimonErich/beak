import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/filters/beak_semantic_range_control.dart';
import 'package:beak_frontend/src/form/beak_value_input.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

const _formatting = BeakFormatting(
  locale: 'de_AT',
  datePattern: 'EEE d MMM',
  dateInputPattern: 'd MMMM yyyy',
  timeZoneOffsetMinutes: 120,
);
const _date = BeakStringColumn(
  key: 'delivery',
  label: 'Delivery',
  semantic: BeakSemantic.calendarDate(),
);
const _dateField = BeakScalarField<Object>(
  model: _DeliveryModel(),
  column: _date,
);

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFormattingScope(formatting: _formatting, child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'calendar inputs localize their independent pattern and retain typed dates',
    (tester) async {
      Object? value = const BeakDate(2028, 3, 1);
      await show(
        tester,
        StatefulBuilder(
          builder: (context, setState) => BeakValueInput(
            column: _date,
            value: value,
            onError: (_) {},
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      expect(find.text('1 März 2028'), findsOneWidget);
      final input = tester.widget<OiDateInput>(find.byType(OiDateInput));
      expect(input.dateFormat, _formatting.dateInputPattern);
      expect(input.locale, 'de_AT');
      input.onChanged!(DateTime(2028, 2, 29));
      await tester.pumpAndSettle();
      expect(value, const BeakDate(2028, 2, 29));
      expect(find.text('29 Februar 2028'), findsOneWidget);
      expect(_date.semantic.encode(value).raw, '2028-02-29');
      expect(_formatting.calendarDate(value! as BeakDate), 'Di. 29 Feb.');
    },
  );

  testWidgets(
    'timestamp editor uses input pattern and preserves explicit-zone roundtrip',
    (tester) async {
      Object? value = DateTime.utc(2028, 2, 29, 23, 15);
      await show(
        tester,
        StatefulBuilder(
          builder: (context, setState) => BeakValueInput(
            column: const BeakDateTimeColumn(key: 'at', label: 'At'),
            value: value,
            onError: (_) {},
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      final input = tester.widget<OiDateTimeInput>(
        find.byType(OiDateTimeInput),
      );
      expect(input.dateFormat, _formatting.dateInputPattern);
      expect(input.locale, 'de_AT');
      expect(input.value, DateTime.utc(2028, 3, 1, 1, 15));
      input.onChanged!(DateTime(2028, 3, 1, 1, 15));
      await tester.pumpAndSettle();
      expect(value, DateTime.utc(2028, 2, 29, 23, 15));
    },
  );

  for (final inline in [false, true]) {
    testWidgets(
      'date filter endpoints use input pattern and canonical bounds (inline: $inline)',
      (tester) async {
        BeakFilter? filter;
        await show(
          tester,
          BeakSemanticRangeControl(
            definition: BeakSemanticRangeFilter(
              label: 'Delivery',
              field: _dateField,
              inline: inline,
            ),
            initial: const BeakFieldFilter.forKey(
              'delivery',
              BeakOperator.gte,
              BeakStringValue('2028-03-01'),
            ),
            onChanged: (next) => filter = next,
          ),
        );
        expect(find.text('1 März 2028'), findsOneWidget);
        final inputs = tester
            .widgetList<OiDateInput>(find.byType(OiDateInput))
            .toList();
        expect(inputs, hasLength(2));
        expect(
          inputs.every(
            (input) =>
                input.dateFormat == _formatting.dateInputPattern &&
                input.locale == 'de_AT',
          ),
          isTrue,
        );
        inputs.first.onChanged!(DateTime(2028, 2, 29));
        await tester.pumpAndSettle();
        expect(
          filter,
          const BeakFieldFilter.forKey(
            'delivery',
            BeakOperator.gte,
            BeakStringValue('2028-02-29'),
          ),
        );
      },
    );
  }
}

/// The model owning the [_date] column.
final class _DeliveryModel extends BeakModel {
  const _DeliveryModel();

  @override
  String get table => 'deliveries';

  @override
  String get displayColumnKey => 'delivery';

  @override
  List<BeakColumn> get columns => const [_date];
}
