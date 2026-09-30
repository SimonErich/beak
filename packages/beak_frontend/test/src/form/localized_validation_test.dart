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

void main() {
  Future<void> submitEmpty(WidgetTester tester, Locale locale) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        locale: locale,
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: [BeakLocalizations.delegate],
        home: BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: FakeDataSource(),
          mode: BeakFormMode.create,
          layout: BeakFormLayout(children: [_title.inputText()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(BeakLocalizations(locale).save));
    await tester.pumpAndSettle();
  }

  testWidgets('a German panel reports a built-in rule in German', (
    tester,
  ) async {
    await submitEmpty(tester, const Locale('de'));

    expect(find.text('Dieses Feld ist erforderlich.'), findsWidgets);
    expect(find.text('This field is required.'), findsNothing);
  });

  testWidgets('an English panel keeps the rule message', (tester) async {
    await submitEmpty(tester, const Locale('en'));

    expect(find.text('This field is required.'), findsWidgets);
  });

  testWidgets('a German panel words a length rule in German', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        locale: const Locale('de'),
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: [BeakLocalizations.delegate],
        home: BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: FakeDataSource(),
          mode: BeakFormMode.create,
          layout: BeakFormLayout(children: [_title.inputText()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'x' * 25);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Höchstens 20 Zeichen erlaubt.'), findsWidgets);
    expect(find.text('Must be at most 20 characters.'), findsNothing);
  });
}
