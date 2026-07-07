import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import '../../support/panel_fixtures.dart';

void main() {
  // A structured layout: a Basics card plus a Pricing card, exactly the shape
  // a detail screen would use — reused here to drive the form.
  const layout = BeakColumnBlock(
    children: [
      BeakCardBlock(
        title: 'Basics',
        child: BeakColumnBlock(
          children: [
            BeakFieldBlock(ArticleColumns.title),
            BeakFieldBlock(ArticleColumns.summary),
          ],
        ),
      ),
      BeakCardBlock(
        title: 'Pricing',
        child: BeakFieldGroupBlock([
          ArticleColumns.price,
          ArticleColumns.stock,
        ]),
      ),
    ],
  );

  test('beakFormColumnsOf collects the layout fields in order', () {
    final keys = [for (final c in beakFormColumnsOf(layout)) c.key];
    expect(keys, ['title', 'summary', 'price', 'stock']);
  });

  testWidgets('a layout form renders inputs inside the structured cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dataSource = FakeDataSource(records: const {});

    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakDataForm(
          model: const ArticleModel(),
          dataSource: dataSource,
          layout: layout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The layout's cards are present…
    expect(find.byType(OiCard), findsWidgets);
    expect(find.text('Basics'), findsOneWidget);
    expect(find.text('Pricing'), findsOneWidget);
    // …and the field blocks rendered *inputs*, not read-only values.
    expect(find.byType(OiAfTextInput<BeakFormSlot>), findsWidgets);
    expect(find.byType(OiAfNumberInput<BeakFormSlot>), findsNWidgets(2));
    expect(
      find.byType(OiAfSubmitButton<BeakFormSlot, BeakRecord>),
      findsOneWidget,
    );
    // A column absent from the layout registered no field, so no select shows.
    expect(find.byType(OiAfSelect<BeakFormSlot, Enum>), findsNothing);
  });
}
