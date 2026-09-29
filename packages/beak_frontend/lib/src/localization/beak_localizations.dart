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
