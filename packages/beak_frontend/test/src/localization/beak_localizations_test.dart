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

  test('the import view and the draft controls speak both languages', () {
    const en = BeakLocalizations.english;
    const de = BeakLocalizations(Locale('de'));
    expect(en.importCsvData, 'CSV data');
    expect(de.importCsvData, 'CSV-Daten');
    expect(en.importPreview, 'Preview import');
    expect(de.importPreview, 'Import prüfen');
    expect(en.importPreviewChanges, 'Preview changes');
    expect(de.importPreviewChanges, 'Änderungen prüfen');
    expect(
      en.importPasteHint('Title, Body'),
      'Paste CSV with these headers: Title, Body.',
    );
    expect(
      de.importPasteHint('Title, Body'),
      'Fügen Sie CSV mit diesen Spaltenköpfen ein: Title, Body.',
    );
    expect(en.importSummary(5, 2), '5 records. 2 need correction.');
    expect(de.importSummary(5, 2), '5 Einträge. 2 müssen korrigiert werden.');
    expect(en.importRow(3), 'Row 3');
    expect(de.importRow(3), 'Zeile 3');
    expect(en.importSubmit(4), 'Import 4 records');
    expect(de.importSubmit(4), '4 Einträge importieren');
    expect(en.importUpdate(4), 'Update 4 records');
    expect(de.importUpdate(4), '4 Einträge aktualisieren');
    expect(
      (en.importResume, de.importResume),
      ('Resume import', 'Import fortsetzen'),
    );
    expect(
      (en.importResumeUpdates, de.importResumeUpdates),
      ('Resume updates', 'Aktualisierung fortsetzen'),
    );
    expect(en.importEditRemaining, 'Edit remaining rows');
    expect(de.importEditRemaining, 'Verbleibende Zeilen bearbeiten');
    expect(en.importReloadRemaining, 'Reload remaining records');
    expect(de.importReloadRemaining, 'Verbleibende Einträge neu laden');
    expect(en.importStop, 'Stop after current record');
    expect(de.importStop, 'Nach dem aktuellen Eintrag anhalten');
    expect(en.importCheckInterrupted, 'Check interrupted save');
    expect(de.importCheckInterrupted, 'Unterbrochenes Speichern prüfen');
    expect(en.importWorking, 'Working…');
    expect(de.importWorking, 'Wird ausgeführt…');
    expect(en.importProgress(2, 5), '2 of 5 records saved.');
    expect(de.importProgress(2, 5), '2 von 5 Einträgen gespeichert.');
    expect(en.importStartNewReview, 'Start new review');
    expect(de.importStartNewReview, 'Neue Prüfung beginnen');
    expect(
      en.importSavesIndividually,
      startsWith('Records save individually.'),
    );
    expect(de.importSavesIndividually, startsWith('Einträge werden einzeln'));
    expect(
      en.importShowingFirst(20),
      startsWith('Showing the first 20 records.'),
    );
    expect(de.importShowingFirst(20), startsWith('Die ersten 20 Einträge'));
    expect(en.importCorrectUnsaved, startsWith('Correct unsaved rows'));
    expect(de.importCorrectUnsaved, startsWith('Korrigieren Sie'));
    expect(en.importConfigurationChanged, startsWith('The source or batch'));
    expect(de.importConfigurationChanged, startsWith('Die Quelle oder'));
    expect(en.formInspect, 'Inspect form');
    expect(de.formInspect, 'Formular untersuchen');
    expect(
      (en.formSaveDraft, de.formSaveDraft),
      ('Save as draft', 'Als Entwurf speichern'),
    );
    expect(
      (en.formSavingDraft, de.formSavingDraft),
      ('Saving draft…', 'Entwurf wird gespeichert…'),
    );
    expect(en.formDraftSavedAt('12:30'), 'Draft saved 12:30');
    expect(de.formDraftSavedAt('12:30'), 'Entwurf gespeichert 12:30');
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
