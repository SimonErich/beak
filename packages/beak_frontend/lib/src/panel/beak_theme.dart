import 'package:flutter/foundation.dart';
import 'package:obers_ui/obers_ui.dart';

/// The look of a panel: one [OiThemeData] per brightness, plus the licences
/// of whatever the look ships (fonts, icon sets).
///
/// A panel takes it as [BeakPanelConfig.theme]. The shell's theme toggle
/// switches between [light] and [dark] without rebuilding the router, so a
/// theme always supplies both. A package that bundles a complete design
/// extends this class and preconfigures both values (for example
/// `GabelTheme` in `package:beak_theme_gabel`); an app that only wants a brand
/// color builds one inline:
///
/// ```dart
/// final theme = BeakTheme(
///   light: OiThemeData.fromBrand(color: const Color(0xFF315D91)),
///   dark: OiThemeData.fromBrand(
///     color: const Color(0xFF8DB4E8),
///     brightness: Brightness.dark,
///   ),
/// );
/// ```
// --8<-- [start:BeakTheme]
class BeakTheme {
  /// Creates a theme from a [light] and a [dark] [OiThemeData].
  ///
  /// [licenses] are added to Flutter's `LicenseRegistry` once, when a panel
  /// that uses this theme mounts, so `showLicensePage` lists what the theme
  /// bundles. Give every entry a stable identity: an entry whose packages and
  /// text match one already registered is skipped.
  const BeakTheme({
    required this.light,
    required this.dark,
    this.licenses = const [],
  });

  /// The stock obers_ui look: `OiThemeData.light()` and `OiThemeData.dark()`.
  ///
  /// What a panel uses when it sets no theme.
  factory BeakTheme.standard() =>
      BeakTheme(light: OiThemeData.light(), dark: OiThemeData.dark());

  /// The theme used when the panel is in light mode.
  final OiThemeData light;

  /// The theme used when the panel is in dark mode.
  final OiThemeData dark;

  /// The licences of the fonts, icons or other assets this theme bundles.
  final List<LicenseEntry> licenses;

  /// Adds [licenses] to Flutter's `LicenseRegistry`.
  ///
  /// Idempotent per entry: an entry that was registered before, by this theme
  /// or by another with the same packages and text, is not added again. The
  /// panel calls it when it mounts, so a host rarely needs to.
  void registerLicenses() {
    final fresh = [
      for (final entry in licenses)
        if (_registered.add(_licenseKey(entry))) entry,
    ];
    if (fresh.isEmpty) return;
    LicenseRegistry.addLicense(() => Stream.fromIterable(fresh));
  }

  /// Forgets which licences were registered, so a test can register them
  /// again after `LicenseRegistry.reset()`.
  @visibleForTesting
  static void resetLicenseRegistrationForTesting() => _registered.clear();

  static final Set<String> _registered = <String>{};

  static String _licenseKey(LicenseEntry entry) {
    final paragraphs = [
      for (final paragraph in entry.paragraphs)
        '${paragraph.indent}:${paragraph.text}',
    ];
    return '${entry.packages.join('\u0000')}\u0001${paragraphs.join('\n')}';
  }
}
// --8<-- [end:BeakTheme]
