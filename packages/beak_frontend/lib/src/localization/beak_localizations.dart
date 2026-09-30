import 'package:beak_core/beak_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Translations for Beak-owned controls, independent of application resources.
///
/// Resource labels remain caller-owned. The default delegate supports English
/// and German; a caller can install a delegate returning a subclass for another
/// language. Without a delegate, [of] follows the ambient locale safely.
class BeakLocalizations {
  /// Creates the built-in translations for [locale].
  const BeakLocalizations(this.locale);

  /// Locale selected by the host application.
  final Locale locale;

  bool get _de => locale.languageCode == 'de';

  /// Status line while the form asks the server to check its values.
  String get formChecking => _de ? 'Werte werden geprüft…' : 'Checking values…';

  /// Reloads a record after another editor saved first, to merge the edits.
  String get formCompareLatest =>
      _de ? 'Mit aktueller Version vergleichen' : 'Compare with latest version';

  /// Heading of the notice offering a stored draft.
  String get formDraftAvailable => _de
      ? 'Ein nicht abgeschlossener Entwurf ist verfügbar'
      : 'An unfinished draft is available';

  /// Loads the stored draft into the form.
  String get formResumeDraft => _de ? 'Entwurf fortsetzen' : 'Resume draft';

  /// Deletes the stored draft.
  String get formDiscardStoredDraft =>
      _de ? 'Gespeicherten Entwurf verwerfen' : 'Discard saved draft';

  /// The user's own value in a merge conflict.
  String formYourValue(String value) =>
      _de ? 'Ihr Entwurf: $value' : 'Your draft: $value';

  /// The value another editor saved, in a merge conflict.
  String formLatestValue(String value) =>
      _de ? 'Aktuelle Version: $value' : 'Latest version: $value';

  /// Keeps the user's own value in a merge conflict.
  String get formKeepDraft => _de ? 'Entwurf behalten' : 'Keep draft';

  /// Takes the other editor's value in a merge conflict.
  String get formUseLatest =>
      _de ? 'Aktuelle Version übernehmen' : 'Use latest';

  /// Banner after a save whose outcome is not known.
  String get formSaveUnknown => _de
      ? 'Der Status einiger Speichervorgänge ist unbekannt. Prüfen Sie den Speicherstatus, bevor Sie fortfahren.'
      : 'Some save results are unknown. Check the save status before continuing.';

  /// Banner after a save that applied only part of the graph.
  String formPartlySaved(int count) => _de
      ? (count == 1
            ? '1 Änderung gespeichert. Die übrigen Änderungen benötigen noch Ihre Aufmerksamkeit.'
            : '$count Änderungen gespeichert. Die übrigen Änderungen benötigen noch Ihre Aufmerksamkeit.')
      : (count == 1
            ? '1 change saved. The remaining changes still need attention.'
            : '$count changes saved. The remaining changes still need attention.');

  /// Asks the server for the receipt of a save whose outcome is not known.
  String get formCheckSaveStatus =>
      _de ? 'Speicherstatus prüfen' : 'Check save status';

  /// Position in a multi-step form.
  String formStepOf(int current, int total) =>
      _de ? 'Schritt $current von $total' : 'Step $current of $total';

  /// Moves a multi-step form back one step.
  String get formPrevious => _de ? 'Vorheriger Schritt' : 'Previous';

  /// Moves a multi-step form forward one step.
  String get formNext => _de ? 'Weiter' : 'Next';

  /// Moves a multi-step form forward, or confirms the review.
  String get formContinue => _de ? 'Weiter' : 'Continue';

  /// Saves the last step of a multi-step form.
  String get formFinish => _de ? 'Abschließen' : 'Finish';

  /// Saves what a partial save left over.
  String get formSaveRemaining =>
      _de ? 'Übrige Änderungen speichern' : 'Save remaining changes';

  /// Opens the review of a form's changes.
  String get formReviewChanges => _de ? 'Änderungen prüfen' : 'Review changes';

  /// Resets a form to the saved record.
  String get formDiscardChanges =>
      _de ? 'Änderungen verwerfen' : 'Discard changes';

  /// Body of the review when the form has nothing to save.
  String get formNoChanges => _de
      ? 'Keine Feld- oder Beziehungsänderungen.'
      : 'No field or relationship changes.';

  /// Count in the change bar.
  String formUnsavedChanges(int count) => _de
      ? '$count ${count == 1 ? 'ungespeicherte Änderung' : 'ungespeicherte Änderungen'}'
      : '$count unsaved ${count == 1 ? 'change' : 'changes'}';

  /// Count of invalid fields in the change bar.
  String formFieldsNeedAttention(int count) => _de
      ? (count == 1
            ? '1 Feld benötigt Aufmerksamkeit'
            : '$count Felder benötigen Aufmerksamkeit')
      : '$count ${count == 1 ? 'field needs' : 'fields need'} attention';

  /// Title of the dialog shown while a save is running.
  String get formSaveInProgress => _de ? 'Speichern läuft' : 'Save in progress';

  /// Body of the dialog shown while a save is running.
  String get formWaitForSave => _de
      ? 'Warten Sie auf das Speicherergebnis, bevor Sie dieses Formular verlassen.'
      : 'Wait for the save result before leaving this form.';

  /// Accessible name of the leave confirmation.
  String get formUnsavedChangesLabel =>
      _de ? 'Ungespeicherte Änderungen' : 'Unsaved changes';

  /// Title of the leave confirmation.
  String get formLeaveQuestion =>
      _de ? 'Dieses Formular verlassen?' : 'Leave this form?';

  /// Leave confirmation when a save outcome is unknown.
  String get formLeaveUnknown => _de
      ? 'Der Status einiger Speichervorgänge ist unbekannt. Beim Verlassen werden bereits gespeicherte Änderungen nicht rückgängig gemacht. Bleiben Sie, um den Speicherstatus zu prüfen.'
      : 'Some save results are unknown. Leaving cannot undo changes already saved. Stay to check the save status.';

  /// Leave confirmation after a partial save.
  String get formLeavePartial => _de
      ? 'Einige Änderungen sind bereits gespeichert. Nur die übrigen ungespeicherten Änderungen verwerfen?'
      : 'Some changes are already saved. Discard only the remaining unsaved changes?';

  /// Leave confirmation when a local draft keeps the edits.
  String get formLeaveStored => _de
      ? 'Ihr Entwurf ist lokal gespeichert und kann fortgesetzt werden, wenn Sie zurückkehren.'
      : 'Your draft is stored locally and can be resumed when you return.';

  /// Leave confirmation when the edits would be lost.
  String get formLeaveDiscard => _de
      ? 'Die ungespeicherten Änderungen in diesem Formular verwerfen?'
      : 'Discard the unsaved changes in this form?';

  /// Stays on the form.
  String get formStay => _de ? 'Bleiben' : 'Stay';

  /// Leaves the form.
  String get formLeave => _de ? 'Verlassen' : 'Leave';

  /// File picker button of an upload field.
  String get formChooseFile => _de ? 'Datei auswählen' : 'Choose file';

  /// File picker button while a file is being read.
  String get formPreparingFile =>
      _de ? 'Datei wird vorbereitet…' : 'Preparing file…';

  /// Clears the file of an upload field.
  String get formRemoveFile => _de ? 'Datei entfernen' : 'Remove file';

  /// Shown when the platform picker fails.
  String get formOpenFileFailed => _de
      ? 'Die Datei konnte nicht geöffnet werden. Bitte versuchen Sie es erneut.'
      : 'Unable to open the file. Please try again.';

  /// Screen-reader name of an upload field's picker button.
  String formChooseFileFor(String label) =>
      _de ? 'Datei auswählen für $label' : 'Choose file for $label';

  /// Screen-reader name of an upload field's remove button.
  String formRemoveFileFrom(String label) =>
      _de ? 'Datei entfernen aus $label' : 'Remove file from $label';

  /// Explains what a gallery's first picture is for.
  String get formGalleryHint => _de
      ? 'Das erste Bild ist das Titelbild. Bilder und Reihenfolge werden mit dem Eintrag gespeichert.'
      : 'The first image is the cover. Images and ordering are saved with the record.';

  /// Shown by a gallery without pictures.
  String get formGalleryEmpty => _de ? 'Noch keine Bilder.' : 'No images yet.';

  /// Heading of a gallery's first picture.
  String get formCoverImage => _de ? 'Titelbild' : 'Cover image';

  /// Heading of a gallery picture; [number] counts from one.
  String formImageNumber(int number) => _de ? 'Bild $number' : 'Image $number';

  /// Moves a gallery picture one place towards the front.
  String get formMoveEarlier => _de ? 'Weiter nach vorn' : 'Move earlier';

  /// Moves a gallery picture one place towards the back.
  String get formMoveLater => _de ? 'Weiter nach hinten' : 'Move later';

  /// Removes a gallery picture.
  String get formRemoveImage => _de ? 'Bild entfernen' : 'Remove image';

  /// Adds a gallery picture.
  String get formAddImage => _de ? 'Bild hinzufügen' : 'Add image';

  /// Screen-reader name of the move-earlier button of picture [number].
  String formMoveImageEarlier(int number) =>
      _de ? 'Bild $number weiter nach vorn' : 'Move image $number earlier';

  /// Screen-reader name of the move-later button of picture [number].
  String formMoveImageLater(int number) =>
      _de ? 'Bild $number weiter nach hinten' : 'Move image $number later';

  /// Screen-reader name of the remove button of picture [number].
  String formRemoveImageNumber(int number) =>
      _de ? 'Bild $number entfernen' : 'Remove image $number';

  /// Removes a row of a related-records table.
  String get formRemove => _de ? 'Entfernen' : 'Remove';

  /// Opens the advanced fields of a related-records row.
  String get formAdvanced => _de ? 'Erweitert' : 'Advanced';

  /// Screen-reader name of the remove button of row [number] of [label].
  String formRemoveRow(String label, int number) =>
      _de ? '$label $number entfernen' : 'Remove $label $number';

  /// Screen-reader name of the advanced button of row [number] of [label].
  String formAdvancedRow(String label, int number) => _de
      ? 'Erweiterte Angaben zu $label $number'
      : 'Advanced options for $label $number';

  /// Sign-in action and screen title.
  String get authSignIn => _de ? 'Anmelden' : 'Sign in';

  /// Sign-out shell action.
  String get authSignOut => _de ? 'Abmelden' : 'Sign out';

  /// Registration action and screen title.
  String get authRegister => _de ? 'Konto erstellen' : 'Create account';

  /// Password recovery screen title.
  String get authRecover => _de ? 'Passwort zurücksetzen' : 'Reset password';

  /// Email field label.
  String get authEmail => _de ? 'E-Mail-Adresse' : 'Email address';

  /// Sign-in identifier label: an account name is not always an email address.
  String get authIdentifier =>
      _de ? 'Benutzername oder E-Mail-Adresse' : 'Username or email';

  /// Password field label.
  String get authPassword => _de ? 'Passwort' : 'Password';

  /// Password confirmation label.
  String get authConfirmPassword =>
      _de ? 'Passwort bestätigen' : 'Confirm password';

  /// Verification code label.
  String get authCode => _de ? 'Bestätigungscode' : 'Verification code';

  /// Initial email verification action.
  String get authSendCode => _de ? 'Code senden' : 'Send code';

  /// Verification action.
  String get authVerifyCode => _de ? 'Code bestätigen' : 'Verify code';

  /// Resend action.
  String get authResendCode => _de ? 'Code erneut senden' : 'Resend code';

  /// Reset completion action.
  String get authSavePassword => _de ? 'Passwort speichern' : 'Save password';

  /// Link to recovery.
  String get authForgotPassword =>
      _de ? 'Passwort vergessen?' : 'Forgot password?';

  /// Link back to login.
  String get authBackToLogin =>
      _de ? 'Zurück zur Anmeldung' : 'Back to sign in';

  /// Neutral verification notice that does not reveal account existence.
  String get authCodeSent => _de
      ? 'Prüfen Sie Ihr E-Mail-Postfach auf einen Bestätigungscode.'
      : 'Check your email for a verification code.';

  /// Confirmation mismatch.
  String get authPasswordsDiffer => _de
      ? 'Die Passwörter stimmen nicht überein.'
      : 'The passwords do not match.';

  /// Safe, localized auth errors never expose raw backend descriptions.
  String authError(BeakException error) => switch (error) {
    BeakAuthenticationException() =>
      _de
          ? 'Die Anmeldung ist fehlgeschlagen. Prüfen Sie Ihre Zugangsdaten.'
          : 'Sign-in failed. Check your credentials.',
    BeakAuthorizationException() =>
      _de
          ? 'Dieses Konto hat keinen Zugriff auf dieses Admin-Panel.'
          : 'This account cannot access this panel.',
    BeakValidationException(:final fieldErrors)
        when fieldErrors.containsKey('confirmation') =>
      authPasswordsDiffer,
    BeakValidationException(:final fieldErrors)
        when fieldErrors.containsKey('email') =>
      validationMessage(const BeakEmail()),
    BeakValidationException() =>
      _de
          ? 'Prüfen Sie Ihre Eingaben und versuchen Sie es erneut.'
          : 'Check your entries and try again.',
    BeakConflictException() =>
      _de
          ? 'Bitte warten Sie kurz und versuchen Sie es erneut.'
          : 'Please wait briefly and try again.',
    _ => operationFailed,
  };

  /// Built-in delegate for the host application's localization delegates.
  static const LocalizationsDelegate<BeakLocalizations> delegate =
      _BeakLocalizationsDelegate();

  /// Locales translated by the built-in delegate.
  static const supportedLocales = [Locale('en'), Locale('de')];

  /// Default translations for context-free configuration helpers.
  static const english = BeakLocalizations(Locale('en'));

  /// Reads installed translations or follows the context locale with fallback.
  static BeakLocalizations of(BuildContext context) =>
      Localizations.of<BeakLocalizations>(context, BeakLocalizations) ??
      BeakLocalizations(
        Localizations.maybeLocaleOf(context) ?? const Locale('en'),
      );

  /// Loading indicator label.
  String get loading => _de ? 'Wird geladen…' : 'Loading…';

  /// Create action label.
  String get create => _de ? 'Erstellen' : 'Create';

  /// Edit action label.
  String get edit => _de ? 'Bearbeiten' : 'Edit';

  /// Save action label.
  String get save => _de ? 'Speichern' : 'Save';

  /// Pending save label.
  String get saving => _de ? 'Wird gespeichert…' : 'Saving…';

  /// Delete action label.
  String get delete => _de ? 'Löschen' : 'Delete';

  /// Archive action label.
  String get archive => _de ? 'Archivieren' : 'Archive';

  /// An action became unavailable before it could execute.
  String get actionDenied => _de
      ? 'Sie haben keine Berechtigung für diese Aktion.'
      : 'You do not have permission to perform this action.';

  /// Detail action label.
  String get view => _de ? 'Ansehen' : 'View';

  /// Cancel action label.
  String get cancel => _de ? 'Abbrechen' : 'Cancel';

  /// Confirmation action label.
  String get confirm => _de ? 'Bestätigen' : 'Confirm';

  /// Close action label.
  String get close => _de ? 'Schließen' : 'Close';

  /// Clear a nullable input or active filter.
  String get clear => _de ? 'Leeren' : 'Clear';

  /// Record detail section label.
  String get details => _de ? 'Details' : 'Details';

  /// Additional record fields section.
  String get more => _de ? 'Weitere Angaben' : 'More';

  /// Related records section.
  String get related => _de ? 'Verknüpfte Einträge' : 'Related';

  /// Immediate relative timestamp.
  String get justNow => _de ? 'gerade eben' : 'just now';

  /// Relative minute timestamp.
  String minutesAgo(int count) => _de ? 'vor $count Min.' : '${count}m ago';

  /// Relative hour timestamp.
  String hoursAgo(int count) => _de ? 'vor $count Std.' : '${count}h ago';

  /// Relative day timestamp.
  String daysAgo(int count) => _de ? 'vor $count Tagen' : '${count}d ago';

  /// Generic records table label.
  String get records => _de ? 'Einträge' : 'Records';

  /// Empty records state.
  String get noRecords => _de ? 'Keine Einträge vorhanden' : 'No records yet';

  /// Navigation command palette title.
  String get goTo => _de ? 'Gehe zu' : 'Go to';

  /// Command palette accessibility label.
  String get commandBar => _de ? 'Befehlssuche' : 'Command bar';

  /// Navigation command group.
  String get navigate => _de ? 'Navigation' : 'Navigate';

  /// Resource navigation group.
  String get resources => _de ? 'Ressourcen' : 'Resources';

  /// Custom page navigation group.
  String get pages => _de ? 'Seiten' : 'Pages';

  /// Boolean true label.
  String get yes => _de ? 'Ja' : 'Yes';

  /// Boolean false label.
  String get no => _de ? 'Nein' : 'No';

  /// Remove a relationship link.
  String get detach => _de ? 'Verknüpfung lösen' : 'Detach';

  /// Default confirmation message.
  String get confirmAction => _de
      ? 'Bitte bestätigen Sie diese Aktion.'
      : 'Please confirm this action.';

  /// Safe placeholder when a field renderer is not configured.
  String get unavailable => _de ? 'Nicht verfügbar' : 'Unavailable';

  /// Noun used by table status and pagination controls.
  String get tableRows => _de ? 'Einträge' : 'rows';

  /// Column visibility menu label.
  String get tableColumns => _de ? 'Spalten' : 'Columns';

  /// Accessible column visibility menu label.
  String get tableManageColumns =>
      _de ? 'Sichtbare Spalten verwalten' : 'Manage visible columns';

  /// Number of records currently rendered in the table.
  String tableRowCount(int count) => _de
      ? '$count ${count == 1 ? 'Eintrag' : 'Einträge'}'
      : '$count ${count == 1 ? 'row' : 'rows'}';

  /// Prefix of the pagination page-size selector.
  String get tablePerPage => _de ? 'Einträge pro Seite' : 'Rows per page';

  /// Accessible pagination container label.
  String get tablePagination =>
      _de ? 'Seitennavigation' : 'Pagination navigation';

  /// Accessible first-page action label.
  String get tableFirstPage => _de ? 'Erste Seite' : 'First page';

  /// Accessible previous-page action label.
  String get tablePreviousPage => _de ? 'Vorherige Seite' : 'Previous page';

  /// Accessible next-page action label.
  String get tableNextPage => _de ? 'Nächste Seite' : 'Next page';

  /// Accessible last-page action label.
  String get tableLastPage => _de ? 'Letzte Seite' : 'Last page';

  /// Accessible numbered-page action label.
  String tablePage(int page) => _de ? 'Seite $page' : 'Page $page';

  /// Range and total displayed by the table pagination.
  String tablePageTotal(int start, int end, int total) {
    if (total == 0) return tableRowCount(0);
    return _de
        ? '$start–$end von $total ${total == 1 ? 'Eintrag' : 'Einträgen'}'
        : 'Showing $start–$end of $total';
  }

  /// Selection count.
  String selectedCount(int count) =>
      _de ? '$count ausgewählt' : '$count selected';

  /// Related-record paging action.
  String loadMore(int count) =>
      _de ? 'Weitere laden ($count)' : 'Load more ($count)';

  /// Notice that a list stops at the most rows a server answers with.
  String showingFirst(int shown, int total) => _de
      ? 'Die ersten $shown von $total Einträgen werden angezeigt.'
      : 'Showing the first $shown of $total.';

  /// Empty related-record state.
  String noRelatedRecords(String label) => _de
      ? 'Noch keine Einträge für $label.'
      : 'No ${label.toLowerCase()} yet.';

  /// Relation picker label.
  String attachLabel(String label) =>
      _de ? '$label verknüpfen' : 'Attach ${label.toLowerCase()}';

  // --8<-- [start:errorMessage]
  /// Displays already mapped domain failures while hiding infrastructure details.
  ///
  /// A configuration, storage, internal or transport failure describes the
  /// deployment rather than the user's request, so it shows the generic
  /// [operationFailed] text and never the message.
  String errorMessage(BeakException error) => switch (error) {
    BeakConfigurationException() ||
    BeakStorageException() ||
    BeakInternalException() ||
    BeakTransportException() => operationFailed,
    _ => error.message,
  };
  // --8<-- [end:errorMessage]

  /// Retry action label.
  String get retry => _de ? 'Erneut versuchen' : 'Retry';

  /// Dashboard navigation label.
  String get dashboard => _de ? 'Übersicht' : 'Dashboard';

  /// Search field label.
  String get search => _de ? 'Suchen' : 'Search';

  /// Dashboard return link.
  String get backToDashboard =>
      _de ? 'Zurück zur Übersicht' : 'Back to dashboard';

  /// Failed picker load message.
  String get failedToLoadOptions => _de
      ? 'Optionen konnten nicht geladen werden.'
      : 'Failed to load options.';

  /// Safe fallback for an operation failure.
  String get operationFailed => _de
      ? 'Die Aktion konnte nicht ausgeführt werden.'
      : 'The operation could not be completed.';

  /// Successful deletion message.
  String get recordDeleted => _de ? 'Eintrag gelöscht.' : 'Record deleted.';

  /// Return to the previous page.
  String get back => _de ? 'Zurück' : 'Back';

  /// Reverts the last change while its undo window is open.
  String get undo => _de ? 'Rückgängig' : 'Undo';

  /// The notification bell and its sheet.
  String get notifications => _de ? 'Benachrichtigungen' : 'Notifications';

  /// Copies a record into a new one.
  String get duplicate => _de ? 'Duplizieren' : 'Duplicate';

  /// Explains the banner shown while commands await their receipts.
  String get pendingActionsNotice => _de
      ? 'Einige Aktionen warten auf Bestätigung. Ihre ursprünglichen Belege werden geprüft, ohne sie erneut zu senden.'
      : 'Some actions are awaiting confirmation. Their original receipts will be checked without resubmitting.';

  /// Re-checks the receipt of an action whose outcome is unknown.
  String checkPendingAction(String label) =>
      _de ? '$label prüfen' : 'Check $label';

  /// Confirmation text before a command runs over the selected records.
  String applyToSelection(String label, int count) => _de
      ? '$label auf $count ausgewählte Einträge anwenden? Jeder Eintrag wird einzeln gespeichert.'
      : 'Apply $label to $count selected records? Each record is saved independently.';

  /// Accessible label of the rail that holds the workspace settings.
  String get workspaceSettings =>
      _de ? 'Arbeitsbereich-Einstellungen' : 'Workspace settings';

  /// Tooltip of the shell's create button, naming the workspace it creates in.
  String createIn(String section) =>
      _de ? 'Erstellen in $section' : '$create in $section';

  /// Form step validation summary.
  String get requiredStep => _de
      ? 'Bitte füllen Sie alle erforderlichen Felder dieses Schritts aus.'
      : 'Please complete the required fields on this step before continuing.';

  /// Title for a create form, using the caller's localized resource label.
  String createTitle(String label) =>
      _de ? '$label erstellen' : 'Create $label';

  /// Title for an edit form, with an optional identifier for legacy layouts.
  String editTitle(String label, [Object? id]) {
    final title = _de ? '$label bearbeiten' : 'Edit $label';
    return id == null ? title : '$title · $id';
  }

  /// Message for an unmatched route.
  String notFoundPath(String path) => _de
      ? 'Die Seite „$path“ wurde nicht gefunden.'
      : 'Page "$path" was not found.';

  /// Runs the rule unchanged, translating only a reported validation failure.
  String? validate(BeakRule rule, Object? value) {
    final message = rule.validate(value);
    return message == null || !_de ? message : validationMessage(rule);
  }

  /// Question asked before a related record is deleted for good.
  String get deleteRecordQuestion =>
      _de ? 'Diesen Eintrag löschen?' : 'Delete this record?';

  /// Title of the list's filter sheet and its opening button.
  String get allFilters => _de ? 'Alle Filter' : 'All filters';

  /// Switch that shows or hides a list's overview charts.
  String get showCharts => _de ? 'Diagramme anzeigen' : 'Show charts';

  /// Resets every filter and the search of a list.
  String get clearAll => _de ? 'Alle zurücksetzen' : 'Clear all';

  /// Applies the filters staged in the filter sheet.
  String get applyFilters => _de ? 'Filter anwenden' : 'Apply filters';

  /// Applies the filters staged in the sheet and says how many rows match.
  String showMatching(int count, String noun) =>
      _de ? '$count $noun anzeigen' : 'Show $count $noun';

  /// Applies the columns chosen in the column sheet.
  String get applyColumns => _de ? 'Spalten übernehmen' : 'Apply columns';

  /// Placeholder of a list's search field.
  String get searchPlaceholder => _de ? 'Suchen…' : 'Search…';

  /// Selector of the views saved for a list.
  String get savedViews => _de ? 'Gespeicherte Ansichten' : 'Saved views';

  /// Saves the current list choices as a named view.
  String get saveView => _de ? 'Ansicht speichern' : 'Save view';

  /// Saves the staged filters as a named view.
  String get saveAsView => _de ? 'Als Ansicht speichern' : 'Save as view';

  /// Drops a bookmarked list state that cannot be restored.
  String get resetView => _de ? 'Ansicht zurücksetzen' : 'Reset view';

  /// Overflow menu of a table row's actions.
  String get recordActions => _de ? 'Eintragsaktionen' : 'Record actions';

  /// Invoice line items heading.
  String get invoiceLineItems => _de ? 'Positionen' : 'Line items';

  /// Invoice totals heading.
  String get invoiceTotals => _de ? 'Summen' : 'Totals';

  /// Invoice sender heading.
  String get invoiceFrom => _de ? 'Von' : 'From';

  /// Invoice recipient heading.
  String get invoiceTo => _de ? 'An' : 'To';

  /// Accessible label of a carousel block.
  String get carousel => _de ? 'Karussell' : 'Carousel';

  /// Accessible label of a timeline block.
  String get timeline => _de ? 'Zeitverlauf' : 'Timeline';

  /// Accessible label of a gallery block.
  String get gallery => _de ? 'Galerie' : 'Gallery';

  /// Summary switch that shows the chart.
  String get chartView => _de ? 'Diagramm' : 'Chart view';

  /// Summary switch that shows the table.
  String get tableView => _de ? 'Tabelle' : 'Table view';

  /// Opens the filters a quick-filter row does not show.
  String get moreFilters => _de ? 'Weitere Filter' : 'More filters';

  /// Translates declarative rule failures while retaining custom pattern text.
  String validationMessage(BeakRule rule) => switch (rule) {
    BeakFutureDate() => _de ? 'Muss in der Zukunft liegen.' : rule.message,
    BeakRequired() =>
      _de ? 'Dieses Feld ist erforderlich.' : 'This field is required.',
    BeakEmail() =>
      _de
          ? 'Bitte geben Sie eine gültige E-Mail-Adresse ein.'
          : 'Enter a valid email address.',
    BeakUrl() =>
      _de ? 'Bitte geben Sie eine gültige URL ein.' : 'Enter a valid URL.',
    BeakMin(:final min) =>
      _de ? 'Der Wert muss mindestens $min sein.' : 'Must be at least $min.',
    BeakMax(:final max) =>
      _de ? 'Der Wert darf höchstens $max sein.' : 'Must be at most $max.',
    BeakMinLength(:final minLength) =>
      _de
          ? 'Mindestens $minLength Zeichen erforderlich.'
          : 'Must be at least $minLength characters.',
    BeakMaxLength(:final maxLength) =>
      _de
          ? 'Höchstens $maxLength Zeichen erlaubt.'
          : 'Must be at most $maxLength characters.',
    BeakPattern(:final message) =>
      message ??
          (_de
              ? 'Bitte verwenden Sie das erwartete Format.'
              : 'Must match the expected format.'),
    BeakInList() =>
      _de
          ? 'Bitte wählen Sie einen gültigen Wert aus.'
          : 'Select an allowed value.',
    BeakMaxFileSize(:final maxSizeInBytes) =>
      _de
          ? 'Die Datei darf höchstens $maxSizeInBytes Bytes groß sein.'
          : 'File must be at most $maxSizeInBytes bytes.',
    BeakAllowedFileTypes(:final allowedTypes) =>
      _de
          ? 'Erlaubte Dateitypen: ${allowedTypes.map((type) => type.extensions.first).join(', ')}.'
          : 'Allowed file types: ${allowedTypes.map((type) => type.extensions.first).join(', ')}.',
  };
}

final class _BeakLocalizationsDelegate
    extends LocalizationsDelegate<BeakLocalizations> {
  const _BeakLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => BeakLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<BeakLocalizations> load(Locale locale) =>
      SynchronousFuture(BeakLocalizations(locale));

  @override
  bool shouldReload(_BeakLocalizationsDelegate old) => false;
}
