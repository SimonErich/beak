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
  final layout = BeakFormLayout(
    children: [
      BeakCard(
        title: 'Basics',
        children: [
          const BeakScalarField<String>(
            model: ArticleModel(),
            column: ArticleColumns.title,
          ).input(),
          const BeakScalarField<String>(
            model: ArticleModel(),
            column: ArticleColumns.summary,
          ).input(),
        ],
      ),
      BeakCard(
        title: 'Pricing',
        children: [
          const BeakScalarField<double>(
            model: ArticleModel(),
            column: ArticleColumns.price,
          ).input(),
          const BeakScalarField<int>(
            model: ArticleModel(),
            column: ArticleColumns.stock,
          ).input(),
        ],
      ),
    ],
  );

  testWidgets('a layout form renders inputs inside the structured cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dataSource = FakeDataSource(records: const {});

    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
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
    expect(find.byType(OiAfTextInput<Enum>), findsWidgets);
    expect(find.byType(OiAfNumberInput<Enum>), findsNWidgets(2));
    expect(find.text('Save'), findsOneWidget);
    // A column absent from the layout registered no field, so no select shows.
    expect(find.byType(OiAfSelect<Enum, Enum>), findsNothing);
  });
}
