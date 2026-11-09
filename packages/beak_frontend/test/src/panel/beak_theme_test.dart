import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _brandLight = Color(0xFF123456);
const _brandDark = Color(0xFF654321);

BeakPanelConfig _config({BeakTheme? theme}) => BeakPanelConfig(
  title: 'Beak Admin',
  theme: theme,
  resources: const [
    BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.notebook)),
  ],
);

BeakTheme _themeWith(List<LicenseEntry> licenses) => BeakTheme(
  light: OiThemeData.light(),
  dark: OiThemeData.dark(),
  licenses: licenses,
);

Future<List<LicenseEntry>> _registered() async => [
  for (final entry in await LicenseRegistry.licenses.toList()) entry,
];

void main() {
  setUp(() {
    LicenseRegistry.reset();
    BeakTheme.resetLicenseRegistrationForTesting();
  });
  tearDown(() {
    LicenseRegistry.reset();
    BeakTheme.resetLicenseRegistrationForTesting();
  });

  group('BeakTheme.standard', () {
    test('is the stock obers light and dark theme', () {
      final theme = BeakTheme.standard();

      expect(theme.light, OiThemeData.light());
      expect(theme.dark, OiThemeData.dark());
      expect(theme.licenses, isEmpty);
    });
  });

  group('panel theme', () {
    OiApp appOf(WidgetTester tester) =>
        tester.widget<OiApp>(find.byType(OiApp));

    Future<void> pump(WidgetTester tester, BeakPanelConfig config) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(config: config, dataSource: FakeDataSource()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hands the light and dark theme of the BeakTheme to OiApp', (
      tester,
    ) async {
      final light = OiThemeData.fromBrand(color: _brandLight);
      final dark = OiThemeData.fromBrand(
        color: _brandDark,
        brightness: Brightness.dark,
      );

      await pump(
        tester,
        _config(
          theme: BeakTheme(light: light, dark: dark),
        ),
      );

      expect(appOf(tester).theme, light);
      expect(appOf(tester).darkTheme, dark);
    });

    testWidgets('falls back to the standard theme when none is set', (
      tester,
    ) async {
      await pump(tester, _config());

      expect(appOf(tester).theme, OiThemeData.light());
      expect(appOf(tester).darkTheme, OiThemeData.dark());
    });

    test('the shorthand BeakPanel takes a BeakTheme too', () {
      final light = OiThemeData.fromBrand(color: _brandLight);
      final theme = BeakTheme(light: light, dark: OiThemeData.dark());

      final panel = BeakPanel(
        resources: _config().resources,
        theme: theme,
        dataSource: FakeDataSource(),
      );

      expect(panel.config.theme, same(theme));
    });

    testWidgets('copyWith replaces the theme', (tester) async {
      final theme = BeakTheme.standard();

      expect(_config().copyWith(theme: theme).theme, same(theme));
      expect(_config(theme: theme).copyWith(title: 'Other').theme, same(theme));
    });
  });

  group('licences', () {
    const entry = LicenseEntryWithLineBreaks(['Gabel Sans'], 'OFL text');
    final theme = _themeWith(const [entry]);

    test('registerLicenses adds each entry to the registry once', () async {
      theme.registerLicenses();
      theme.registerLicenses();

      final entries = await _registered();

      expect(entries, hasLength(1));
      expect(entries.single.packages, ['Gabel Sans']);
      expect(entries.single.paragraphs.single.text, 'OFL text');
    });

    test('an equal entry from another theme is not added again', () async {
      theme.registerLicenses();
      final twin = _themeWith(const [
        LicenseEntryWithLineBreaks(['Gabel Sans'], 'OFL text'),
      ]);
      twin.registerLicenses();

      expect(await _registered(), hasLength(1));
    });

    test('a theme without licences registers nothing', () async {
      BeakTheme.standard().registerLicenses();

      expect(await _registered(), isEmpty);
    });

    testWidgets('mounting the panel registers them, rebuilding does not', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = _config(theme: theme);

      for (var round = 0; round < 2; round++) {
        await tester.pumpWidget(
          BeakPanel(config: config, dataSource: FakeDataSource()),
        );
        await tester.pumpAndSettle();
      }

      expect(await _registered(), hasLength(1));
    });

    testWidgets('a theme that overrides registerLicenses is asked once', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final counting = _CountingTheme();
      final config = _config(theme: counting);

      for (var round = 0; round < 2; round++) {
        await tester.pumpWidget(
          BeakPanel(config: config, dataSource: FakeDataSource()),
        );
        await tester.pumpAndSettle();
      }

      expect(counting.registrations, 1);
    });
  });
}

/// A theme whose licences are not known up front, as a font package's are
/// when it reads their text from assets.
class _CountingTheme extends BeakTheme {
  _CountingTheme()
    : super(light: OiThemeData.light(), dark: OiThemeData.dark());

  int registrations = 0;

  @override
  void registerLicenses() => registrations++;
}
