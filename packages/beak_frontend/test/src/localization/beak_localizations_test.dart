import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/src/localization/beak_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('translates labels and rule failures without changing validity', () {
    const en = BeakLocalizations(Locale('en'));
    const de = BeakLocalizations(Locale('de', 'AT'));
    expect(en.save, 'Save');
    expect(en.editTitle('Categories'), 'Edit Categories');
    expect(de.editTitle('Kategorien'), 'Kategorien bearbeiten');
    expect(en.editTitle('Categories', 'old-id'), 'Edit Categories · old-id');
    expect(de.save, 'Speichern');
    expect(
      de.validate(const BeakRequired(), ''),
      'Dieses Feld ist erforderlich.',
    );
    expect(
      de.validate(const BeakMinLength(3), 'a'),
      'Mindestens 3 Zeichen erforderlich.',
    );
    expect(de.validate(const BeakMinLength(3), 'abc'), isNull);
    expect(
      de.validate(const BeakPattern('x', message: 'Domain message'), 'y'),
      'Domain message',
    );
    expect(const BeakLocalizations(Locale('fr')).save, en.save);
  });

  test('the controls the panel draws itself speak both languages', () {
    const en = BeakLocalizations.english;
    const de = BeakLocalizations(Locale('de'));
    expect((en.back, de.back), ('Back', 'Zurück'));
    expect((en.undo, de.undo), ('Undo', 'Rückgängig'));
    expect(
      (en.notifications, de.notifications),
      ('Notifications', 'Benachrichtigungen'),
    );
    expect((en.duplicate, de.duplicate), ('Duplicate', 'Duplizieren'));
    expect(en.checkPendingAction('Ship'), 'Check Ship');
    expect(de.checkPendingAction('Versenden'), 'Versenden prüfen');
    expect(
      en.applyToSelection('Ship', 3),
      'Apply Ship to 3 selected records? Each record is saved independently.',
    );
    expect(
      de.applyToSelection('Versenden', 3),
      'Versenden auf 3 ausgewählte Einträge anwenden? '
      'Jeder Eintrag wird einzeln gespeichert.',
    );
    expect(en.createIn('Shop'), 'Create in Shop');
    expect(de.createIn('Shop'), 'Erstellen in Shop');
    expect(de.workspaceSettings, 'Arbeitsbereich-Einstellungen');
    expect(de.pendingActionsNotice, isNot(en.pendingActionsNotice));
  });

  test('German strings address the user formally', () {
    const de = BeakLocalizations(Locale('de'));
    expect(de.actionDenied, 'Sie haben keine Berechtigung für diese Aktion.');
    expect(de.actionDenied, isNot(contains('Du ')));
  });

  test(
    'infrastructure failures show the generic text, never their message',
    () {
      const en = BeakLocalizations.english;
      const secret = 'postgres://admin:hunter2@db/internal';
      for (final BeakException error in const [
        BeakConfigurationException(secret),
        BeakStorageException(secret),
        BeakInternalException(secret),
        BeakTransportException(secret),
      ]) {
        expect(en.errorMessage(error), en.operationFailed);
      }
      expect(
        en.errorMessage(const BeakPayloadTooLargeException('Body too large.')),
        'Body too large.',
      );
      expect(
        en.errorMessage(const BeakValidationException('Fix the title.')),
        'Fix the title.',
      );
    },
  );

  test('the list, saved-view and block chrome speaks German too', () {
    const en = BeakLocalizations.english;
    const de = BeakLocalizations(Locale('de'));
    expect(en.allFilters, 'All filters');
    expect(de.allFilters, 'Alle Filter');
    expect(en.showMatching(4, 'records'), 'Show 4 records');
    expect(de.showMatching(4, 'Einträge'), '4 Einträge anzeigen');
    expect(en.savedViews, 'Saved views');
    expect(de.saveView, 'Ansicht speichern');
    expect(de.saveAsView, 'Als Ansicht speichern');
    expect(en.resetView, 'Reset view');
    expect(de.deleteRecordQuestion, 'Diesen Eintrag löschen?');
    expect(de.invoiceLineItems, 'Positionen');
    expect(de.recordActions, 'Eintragsaktionen');
    for (final text in [
      de.clearAll,
      de.applyFilters,
      de.applyColumns,
      de.searchPlaceholder,
      de.showCharts,
      de.moreFilters,
      de.carousel,
      de.timeline,
      de.gallery,
      de.chartView,
      de.tableView,
      de.invoiceTotals,
      de.invoiceFrom,
      de.invoiceTo,
    ]) {
      expect(text, isNotEmpty);
    }
    expect(de.clearAll, isNot(en.clearAll));
  });

  testWidgets('resolves context language without requiring the delegate', (
    tester,
  ) async {
    late BeakLocalizations strings;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('de'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            strings = BeakLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(strings.retry, 'Erneut versuchen');
    expect(
      await BeakLocalizations.delegate.load(const Locale('en')),
      isA<BeakLocalizations>(),
    );
  });
}
