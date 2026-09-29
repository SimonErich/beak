import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: ArticleModel(),
  column: ArticleColumns.title,
);
const _summary = BeakScalarField<String>(
  model: ArticleModel(),
  column: ArticleColumns.summary,
);

Future<void> _pump(WidgetTester tester, BeakFormLayout layout) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    OiApp(
      theme: OiThemeData.light(),
      home: BeakConfiguredForm(
        model: const ArticleModel(),
        dataSource: FakeDataSource(models: const [ArticleModel()]),
        layout: layout,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<double> _distanceBetweenInputs(
  WidgetTester tester,
  double spacingInPixels,
) async {
  await _pump(
    tester,
    BeakFormLayout(
      spacingInPixels: spacingInPixels,
      children: [_title.inputText(), _summary.inputText()],
    ),
  );
  final inputs = find.byType(EditableText);
  return tester.getTopLeft(inputs.at(1)).dy -
      tester.getTopLeft(inputs.at(0)).dy;
}

void main() {
  testWidgets('spacingInPixels sets the gap between a layout\'s children', (
    tester,
  ) async {
    final tight = await _distanceBetweenInputs(tester, 8);
    final loose = await _distanceBetweenInputs(tester, 40);
    expect(loose - tight, 32);
  });

  testWidgets('heightInPixels sizes a placeholder', (tester) async {
    await _pump(
      tester,
      const BeakFormLayout(
        children: [BeakFormPlaceholder(label: 'Empty', heightInPixels: 120)],
      ),
    );
    expect(tester.getSize(find.byType(OiHatchPlaceholder)).height, 120);
  });

  testWidgets('capacity track height and gap are passed in pixels', (
    tester,
  ) async {
    await _pump(
      tester,
      BeakFormLayout(
        children: [
          BeakFormCapacity(
            label: 'Stock',
            value: (_) => 3,
            max: (_) => 10,
            heightInPixels: 12,
            gapInPixels: 5,
          ),
        ],
      ),
    );
    final capacity = tester.widget<OiCapacityIndicator>(
      find.byType(OiCapacityIndicator),
    );
    expect(capacity.height, 12);
    expect(capacity.gap, 5);
  });

  testWidgets('a section takes its gaps in pixels', (tester) async {
    await _pump(
      tester,
      BeakFormLayout(
        children: [
          BeakSection(
            title: 'Details',
            gapInPixels: 33,
            headingGapInPixels: 7,
            children: [_title.inputText(), _summary.inputText()],
          ),
        ],
      ),
    );
    final gaps = tester
        .widgetList<OiColumn>(find.byType(OiColumn))
        .map((column) => column.gap)
        .toList();
    expect(gaps, contains(const OiResponsive<double>(33)));
    expect(gaps, contains(const OiResponsive<double>(7)));
  });
}
