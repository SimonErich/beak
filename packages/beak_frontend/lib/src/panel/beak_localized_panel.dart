import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;

import '../localization/beak_localizations.dart';
import 'beak_panel.dart';
import 'beak_panel_config.dart';

/// Builds a panel's configuration in a localized [BuildContext].
typedef BeakPanelConfigBuilder = BeakPanelConfig Function(BuildContext context);

/// A [BeakPanel] whose configuration is built with a [BuildContext] that
/// already holds the app's localizations.
///
/// Model, field, enum and command labels come from the generated models in
/// the panel's language on their own. This is for the app's own copy, such
/// as navigation sections or wizard steps: the builder reads it the Flutter
/// way, from the context, instead of having it passed around:
///
/// ```dart
/// BeakLocalizedPanel(
///   locale: const Locale('de'),
///   supportedLocales: AppLocalizations.supportedLocales,
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   config: (context) => BeakPanelConfig(
///     title: AppLocalizations.of(context).appTitle,
///     resources: shopResources(context),
///   ),
/// )
/// ```
///
/// The builder runs again when the locale changes, with
/// [BeakLabels.language] already set; the panel then starts over at `/`.
/// The languages are this widget's: a locale, supported locales or
/// delegates in the built configuration are replaced by them.
class BeakLocalizedPanel extends StatelessWidget {
  /// Shows the panel [config] builds, in [locale] or the platform's best
  /// match among [supportedLocales].
  const BeakLocalizedPanel({
    required this.config,
    this.locale,
    this.supportedLocales = BeakLocalizations.supportedLocales,
    this.localizationsDelegates = const [],
    this.dataSource,
    this.httpClient,
    super.key,
  });

  /// Builds the configuration in a context with the app's localizations.
  final BeakPanelConfigBuilder config;

  /// The language the panel speaks; the platform's best match when `null`.
  final Locale? locale;

  /// The languages the panel offers.
  final List<Locale> supportedLocales;

  /// The app's own localizations, such as a gen-l10n class's delegates.
  final Iterable<LocalizationsDelegate<Object?>> localizationsDelegates;

  /// Forwarded to [BeakPanel.dataSource].
  final BeakDataSource? dataSource;

  /// Forwarded to [BeakPanel.httpClient].
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) => Localizations(
    locale:
        locale ??
        basicLocaleListResolution(
          View.of(context).platformDispatcher.locales,
          supportedLocales,
        ),
    delegates: [
      ...localizationsDelegates,
      BeakLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    child: _BuiltPanel(this),
  );
}

class _BuiltPanel extends HookWidget {
  const _BuiltPanel(this.panel);

  final BeakLocalizedPanel panel;

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final BeakPanelConfig built = useMemoized(() {
      BeakLabels.language = locale.languageCode;
      return panel
          .config(context)
          .copyWith(
            locale: locale,
            supportedLocales: panel.supportedLocales,
            localizationsDelegates: panel.localizationsDelegates.toList(),
          );
    }, [locale]);
    return BeakPanel(
      config: built,
      dataSource: panel.dataSource,
      httpClient: panel.httpClient,
    );
  }
}
