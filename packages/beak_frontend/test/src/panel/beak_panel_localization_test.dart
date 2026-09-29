import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  test('accepts Flutter generated localization delegate list types', () {
    // The SDK app surface exposes the same delegate generic as gen-l10n's
    // AppLocalizations.localizationsDelegates, without narrowing its values.
    final flutterDelegates = const OiApp(
      home: SizedBox(),
      localizationsDelegates: [_HostDelegate()],
    ).localizationsDelegates!.toList();
    final config = BeakPanelConfig(
      title: 'Panel',
      resources: const [],
      localizationsDelegates: flutterDelegates,
    );
    expect(config.localizationsDelegates.single, isA<_HostDelegate>());
    expect(
      config
          .copyWith(localizationsDelegates: flutterDelegates)
          .localizationsDelegates
          .single,
      isA<_HostDelegate>(),
    );
  });

  test('locale configuration defaults and copy preserve host delegates', () {
    const config = BeakPanelConfig(title: 'Panel', resources: []);
    expect(config.locale, null);
    expect(config.supportedLocales, BeakLocalizations.supportedLocales);
    expect(config.localizationsDelegates, isEmpty);
    final localized = config.copyWith(
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: const [_HostDelegate()],
    );
    final renamed = localized.copyWith(title: 'Renamed');
    expect(renamed.locale, const Locale('de'));
    expect(renamed.supportedLocales, const [Locale('de')]);
    expect(renamed.localizationsDelegates.single, isA<_HostDelegate>());
  });

  testWidgets('standalone panel localizes Beak and host widgets in one app', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: BeakPanelConfig(
          title: 'Panel',
          resources: const [],
          locale: const Locale('de'),
          supportedLocales: const [Locale('de')],
          localizationsDelegates: const [_HostDelegate()],
          pages: [
            BeakScreen(
              path: '/',
              title: 'Home',
              icon: const BeakIconToken(OiIcons.house),
              body: BeakWidgetBlock((context) {
                final host = Localizations.of<_HostLabels>(
                  context,
                  _HostLabels,
                )!;
                return OiLabel.body(
                  '${host.title} / ${BeakLocalizations.of(context).authSignIn}',
                );
              }),
            ),
          ],
        ),
        dataSource: FakeDataSource(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OiApp), findsOneWidget);
    expect(find.text('Anwendung / Anmelden'), findsOneWidget);
    final context = tester.element(find.byType(OiAppShell));
    expect(Localizations.localeOf(context), const Locale('de'));
    expect(
      tester.widget<OiApp>(find.byType(OiApp)).localizationsDelegates,
      contains(BeakLocalizations.delegate),
    );
  });

  testWidgets('a supplied framework delegate can add another language', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: BeakPanelConfig(
          title: 'Panel',
          resources: const [],
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [_FrenchBeakDelegate()],
          pages: [
            BeakScreen(
              path: '/',
              title: 'Home',
              icon: const BeakIconToken(OiIcons.house),
              body: BeakWidgetBlock(
                (context) =>
                    OiLabel.body(BeakLocalizations.of(context).authSignIn),
              ),
            ),
          ],
        ),
        dataSource: FakeDataSource(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);
  });
}

class _HostLabels {
  const _HostLabels(this.title);
  final String title;
}

class _HostDelegate extends LocalizationsDelegate<_HostLabels> {
  const _HostDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'de';

  @override
  Future<_HostLabels> load(Locale locale) =>
      SynchronousFuture(const _HostLabels('Anwendung'));

  @override
  bool shouldReload(_HostDelegate old) => false;
}

// --8<-- [start:frenchLocalizations]
class _FrenchBeakLabels extends BeakLocalizations {
  const _FrenchBeakLabels() : super(const Locale('fr'));

  @override
  String get authSignIn => 'Connexion';
}

class _FrenchBeakDelegate extends LocalizationsDelegate<BeakLocalizations> {
  const _FrenchBeakDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fr';

  @override
  Future<BeakLocalizations> load(Locale locale) =>
      SynchronousFuture(const _FrenchBeakLabels());

  @override
  bool shouldReload(_FrenchBeakDelegate old) => false;
}
// --8<-- [end:frenchLocalizations]
