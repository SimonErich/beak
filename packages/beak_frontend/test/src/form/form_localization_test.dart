import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'title', label: 'Titel'),
);

/// The controls a form draws itself, not the labels a resource brings.
void main() {
  Future<void> pumpGerman(WidgetTester tester, Widget form) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        locale: const Locale('de'),
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: [BeakLocalizations.delegate],
        home: form,
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget editForm(FakeDataSource source) => BeakConfiguredForm(
    model: const NoteModel(),
    dataSource: source,
    recordId: 'n1',
    layout: BeakFormLayout(children: [_title.inputText()]),
  );

  FakeDataSource seeded() => FakeDataSource(
    records: {
      'notes': {
        'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'Eins'}),
      },
    },
  );

  testWidgets('leaving a dirty form asks in German', (tester) async {
    await pumpGerman(tester, editForm(seeded()));
    await tester.enterText(find.byType(EditableText).first, 'Zwei');
    await tester.pumpAndSettle();
    expect(find.text('Änderungen prüfen'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.text('Dieses Formular verlassen?'), findsOneWidget);
    expect(find.text('Bleiben'), findsOneWidget);
    expect(find.text('Leave this form?'), findsNothing);
  });

  testWidgets('the review dialog is German', (tester) async {
    await pumpGerman(tester, editForm(seeded()));
    await tester.enterText(find.byType(EditableText).first, 'Zwei');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Änderungen prüfen'));
    await tester.pumpAndSettle();

    expect(find.text('Zurück'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('a wizard names its steps and buttons in German', (tester) async {
    await pumpGerman(
      tester,
      BeakConfiguredForm(
        model: const NoteModel(),
        dataSource: FakeDataSource(),
        steps: [
          BeakWizardStep(title: 'Eins', children: [_title.inputText()]),
          const BeakWizardStep(
            title: 'Zwei',
            children: [BeakCalculated(label: 'Info', value: _info)],
          ),
        ],
      ),
    );
    expect(find.text('Weiter'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Vorheriger Schritt'), findsOneWidget);
    expect(find.text('Abschließen'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
  });

  testWidgets('an upload field speaks German to a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpGerman(
      tester,
      BeakConfiguredForm(
        model: const ArticleModel(),
        dataSource: FakeDataSource(),
        layout: BeakFormLayout(
          children: [
            const BeakScalarField<String>(
              model: ArticleModel(),
              column: ArticleColumns.attachment,
            ).input(),
          ],
        ),
      ),
    );

    expect(find.text('Datei auswählen'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Datei auswählen für Attachment'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  test('counts read naturally in both languages', () {
    const en = BeakLocalizations.english;
    const de = BeakLocalizations(Locale('de'));
    expect(en.formUnsavedChanges(1), '1 unsaved change');
    expect(en.formUnsavedChanges(3), '3 unsaved changes');
    expect(de.formUnsavedChanges(1), '1 ungespeicherte Änderung');
    expect(de.formUnsavedChanges(3), '3 ungespeicherte Änderungen');
    expect(en.formFieldsNeedAttention(1), '1 field needs attention');
    expect(en.formFieldsNeedAttention(2), '2 fields need attention');
    expect(de.formFieldsNeedAttention(2), '2 Felder benötigen Aufmerksamkeit');
    expect(
      en.formPartlySaved(1),
      '1 change saved. The remaining changes still need attention.',
    );
    expect(
      de.formPartlySaved(2),
      '2 Änderungen gespeichert. '
      'Die übrigen Änderungen benötigen noch Ihre Aufmerksamkeit.',
    );
    expect(de.formStepOf(1, 3), 'Schritt 1 von 3');
  });
}

String _info(BeakFormReader state) => 'Info';
