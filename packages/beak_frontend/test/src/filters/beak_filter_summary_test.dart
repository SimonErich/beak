import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _price = BeakScalarField<double>(
  model: ArticleModel(),
  column: BeakDecimalColumn(key: 'price', label: 'Price'),
);

Future<String> _summary(
  WidgetTester tester,
  BeakFilterDef definition,
  BeakFilter filter,
) async {
  late String summary;
  await tester.pumpWidget(
    OiApp(
      theme: OiThemeData.light(),
      home: Builder(
        builder: (context) {
          summary = beakFilterSummary(context, definition, filter);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return summary;
}

BeakFieldFilter _bound(BeakOperator operator, double value) =>
    BeakFieldFilter.forKey('price', operator, BeakDoubleValue(value));

void main() {
  group('a number range summary', () {
    final definition = _price.numberRangeFilter();

    testWidgets('shows both bounds', (tester) async {
      final summary = await _summary(
        tester,
        definition,
        BeakAndFilter([
          _bound(BeakOperator.gte, 10),
          _bound(BeakOperator.lte, 20),
        ]),
      );

      expect(summary, isNot('Active'));
      expect(summary, allOf(contains('10'), contains(' – '), contains('20')));
    });

    testWidgets('marks a lower bound alone as a minimum', (tester) async {
      final summary = await _summary(
        tester,
        definition,
        _bound(BeakOperator.gte, 10),
      );

      expect(summary, allOf(startsWith('≥'), contains('10')));
    });

    testWidgets('marks an upper bound alone as a maximum', (tester) async {
      final summary = await _summary(
        tester,
        definition,
        _bound(BeakOperator.lte, 20),
      );

      expect(summary, allOf(startsWith('≤'), contains('20')));
    });
  });
}
