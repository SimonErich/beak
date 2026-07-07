import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'categories': {
          'c1': BeakRecord.fromRow(const {'id': 'c1', 'name': 'News'}),
        },
      },
    );
  });

  Future<void> pump(WidgetTester tester, Widget form) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(OiApp(theme: OiThemeData.light(), home: form));
    await tester.pumpAndSettle();
  }

  Widget articleWizard() => BeakDataForm(
    model: const ArticleModel(),
    dataSource: dataSource,
    steps: const [
      BeakFormStep(
        title: 'Basics',
        description: 'Name the article.',
        columns: [ArticleColumns.title, ArticleColumns.summary],
      ),
      BeakFormStep(
        title: 'Pricing',
        columns: [ArticleColumns.price, ArticleColumns.stock],
      ),
    ],
  );

  testWidgets('renders as a wizard showing only the current step', (
    tester,
  ) async {
    await pump(tester, articleWizard());

    expect(find.byType(OiWizard), findsOneWidget);
    // Step one's description and its field are visible…
    expect(find.text('Name the article.'), findsOneWidget);
    expect(find.byType(OiAfTextInput<BeakFormSlot>), findsWidgets);
    // …but step two's numeric fields are not yet mounted.
    expect(find.byType(OiAfNumberInput<BeakFormSlot>), findsNothing);
  });

  testWidgets('blocks advancing past a step with an empty required field', (
    tester,
  ) async {
    await pump(tester, articleWizard());

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Still on step one (its field present, step two's absent) with a notice.
    expect(find.byType(OiAfNumberInput<BeakFormSlot>), findsNothing);
    expect(find.textContaining('complete the required fields'), findsOneWidget);
  });

  testWidgets('advances to the next step once the step is valid', (
    tester,
  ) async {
    await pump(tester, articleWizard());

    await tester.enterText(
      find.byType(OiAfTextInput<BeakFormSlot>).first,
      'My article',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step two's numeric fields are now mounted.
    expect(find.byType(OiAfNumberInput<BeakFormSlot>), findsWidgets);
  });
}
