import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'gabel_theme_data.dart';

/// The official Gabel design for a Beak panel: Mona Sans and JetBrains Mono,
/// a violet brand on cool grays, hairline-ringed cards, a dark rail and an
/// icon set drawn as 1.5 px strokes.
///
/// Select it on the panel configuration. Both the light and the dark theme
/// are preconfigured, so the shell's theme toggle works unchanged:
///
/// ```dart
/// BeakPanelConfig(
///   title: 'Gabel Admin',
///   theme: GabelTheme(),
///   resources: resources,
/// )
/// ```
///
/// The fonts ship with this package under `packages/beak_theme_gabel/...`, so
/// the app declares none. The theme adds the fonts' SIL Open Font License
/// texts to Flutter's licence registry when the panel mounts.
class GabelTheme extends BeakTheme {
  /// Creates the Gabel theme, with its light and dark themes built.
  GabelTheme()
    : super(
        light: buildGabelTheme(dark: false),
        dark: buildGabelTheme(dark: true),
      );

  /// The font licence texts, as (package name, asset) pairs.
  static const _licenseAssets = [
    ('Mona Sans', 'packages/beak_theme_gabel/lib/fonts/MonaSans-OFL.txt'),
    (
      'JetBrains Mono',
      'packages/beak_theme_gabel/lib/fonts/JetBrainsMono-OFL.txt',
    ),
  ];

  static bool _registered = false;

  /// Adds the OFL texts of the bundled fonts to `LicenseRegistry`, once per
  /// app no matter how many [GabelTheme]s are built or panels mounted.
  ///
  /// The texts are read from the package's assets when a licence page opens,
  /// not at startup.
  @override
  void registerLicenses() {
    super.registerLicenses();
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(_fontLicenses);
  }

  /// Forgets that the licences were registered, so a test can register them
  /// again after `LicenseRegistry.reset()`.
  @visibleForTesting
  static void resetLicenseRegistrationForTesting() => _registered = false;

  static Stream<LicenseEntry> _fontLicenses() async* {
    for (final (name, asset) in _licenseAssets) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(asset));
    }
  }
}
