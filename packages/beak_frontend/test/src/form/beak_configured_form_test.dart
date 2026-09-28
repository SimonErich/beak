import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';
import 'package:go_router/go_router.dart';

import '../../support/panel_fixtures.dart';

void main() {
  const title = BeakScalarField<String>(
    model: NoteModel(),
    column: BeakStringColumn(key: 'title', label: 'Title'),
  );
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(OiApp(theme: OiThemeData.light(), home: child));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'wizard preserves values, validates steps, and saves only on Finish',
    (tester) async {
      final source = FakeDataSource();
      await pump(
        tester,
        BeakConfiguredForm(
          model: const NoteModel(),
          dataSource: source,
          steps: [
            BeakWizardStep(
              title: 'Basics',
              children: [
                title.inputText(validate: [const BeakRequired()]),
              ],
            ),
            const BeakWizardStep(
              title: 'Review',
              children: [BeakCalculated(label: 'Review', value: _review)],
            ),
          ],
        ),
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      expect(source.createCalls, isEmpty);
      await tester.enterText(find.byType(EditableText).first, 'Wizard note');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Review: Wizard note'), findsOneWidget);
      expect(source.createCalls, isEmpty);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(source.createCalls.single.$2['title']?.raw, 'Wizard note');
      expect(find.text('Edit'), findsOneWidget);
    },
  );

  testWidgets('model renderers preserve color rich text JSON and uploads', (
    tester,
  ) async {
    const model = ArticleModel();
    await pump(
      tester,
      BeakConfiguredForm(
        model: model,
        dataSource: FakeDataSource(),
        layout: BeakFormLayout(
          children: [
            const BeakScalarField<String>(
              model: model,
              column: ArticleColumns.brandColor,
            ).input(label: 'Accent'),
            const BeakScalarField<String>(
              model: model,
              column: ArticleColumns.body,
            ).input(),
            const BeakScalarField<String>(
              model: model,
              column: ArticleColumns.meta,
            ).input(),
            const BeakScalarField<String>(
              model: model,
              column: ArticleColumns.avatar,
            ).input(),
          ],
        ),
      ),
    );
    expect(find.byType(OiAfColorInput<Enum>), findsOneWidget);
    expect(find.byType(OiAfRichEditor<Enum>), findsOneWidget);
    expect(find.byType(BeakUploadField), findsOneWidget);
    expect(find.text('Accent'), findsOneWidget);
    final metadata = tester
        .widgetList<OiTextInput>(find.byType(OiTextInput))
        .where((input) => input.label == ArticleColumns.meta.label)
        .single;
    expect(metadata.maxLines, greaterThan(1));
    await tester.enterText(
      find.descendant(
        of: find.byWidget(metadata),
        matching: find.byType(EditableText),
      ),
      '{"valid":true}',
    );
    expect(tester.takeException(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route replacement confirms dirty drafts and Stay retains text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        resources: const [BeakResource(model: NoteModel())],
        dataSource: FakeDataSource(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go('/notes/create');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Unsaved');
    router.go('/notes');
    await tester.pumpAndSettle();
    expect(find.text('Leave this form?'), findsWidgets);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/notes/create');
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Unsaved',
    );
    router.go('/notes');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/notes');
  });

  testWidgets('read mode uses the same layout and respects edit permission', (
    tester,
  ) async {
    final source = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Read only'}),
        },
      },
    );
    await pump(
      tester,
      BeakConfiguredForm(
        model: const NoteModel(),
        dataSource: source,
        recordId: 'n1',
        mode: BeakFormMode.read,
        canEdit: false,
        layout: BeakFormLayout(
          children: [
            BeakCard(title: 'Identity', children: [title.inputText()]),
          ],
        ),
      ),
    );
    expect(find.text('Read only'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });
}

Object? _review(BeakFormReader state) => state.read(
  const BeakScalarField<String>(
    model: NoteModel(),
    column: BeakStringColumn(key: 'title', label: 'Title'),
  ),
);
