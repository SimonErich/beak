import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  const model = ArticleModel();
  const title = BeakScalarField<String>(
    model: model,
    column: ArticleColumns.title,
  );

  BeakFormLayout tallLayout() => BeakFormLayout(
    children: [
      title.input(),
      const BeakScalarField<String>(
        model: model,
        column: ArticleColumns.summary,
      ).input(),
      const BeakScalarField<double>(
        model: model,
        column: ArticleColumns.price,
      ).input(),
      const BeakScalarField<int>(
        model: model,
        column: ArticleColumns.stock,
      ).input(),
      const BeakScalarField<bool>(
        model: model,
        column: ArticleColumns.active,
      ).input(),
    ],
  );

  Future<ScrollController> pumpScrolledForm(
    WidgetTester tester, {
    bool reviewBeforeSave = false,
  }) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.binding.setSurfaceSize(const Size(900, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: SingleChildScrollView(
          controller: scroll,
          child: BeakConfiguredForm(
            model: model,
            dataSource: FakeDataSource(),
            layout: tallLayout(),
            reviewBeforeSave: reviewBeforeSave,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return scroll;
  }

  bool titleFocused(WidgetTester tester) => tester
      .widget<EditableText>(find.byType(EditableText).first)
      .focusNode
      .hasFocus;

  testWidgets(
    'a failed save scrolls to the first invalid field and focuses it',
    (tester) async {
      final scroll = await pumpScrolledForm(tester);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(titleFocused(tester), isFalse);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsWidgets);
      expect(titleFocused(tester), isTrue);
      expect(scroll.offset, lessThan(scroll.position.maxScrollExtent));
    },
  );

  testWidgets('a failed check before the review does the same', (tester) async {
    final scroll = await pumpScrolledForm(tester, reviewBeforeSave: true);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsNothing);
    expect(titleFocused(tester), isTrue);
  });
}
