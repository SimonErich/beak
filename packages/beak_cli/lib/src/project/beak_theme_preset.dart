import 'dart:io';

import 'package:path/path.dart' as p;

import 'beak_discovery.dart';
import 'beak_project_config.dart';

/// A built-in look `beak.yaml` can select with `theme.preset`.
enum BeakThemePreset {
  /// obers_ui's stock light and dark theme, what a panel uses when it sets
  /// none.
  standard,

  /// The Gabel design from the `beak_theme_gabel` package.
  gabel;

  /// The package a project must depend on to use this preset, or `null` when
  /// the preset ships with `beak` itself.
  String? get package => switch (this) {
    standard => null,
    gabel => 'beak_theme_gabel',
  };

  /// The `BeakTheme` subclass that implements this preset, or `null` for the
  /// panel's own default.
  String? get className => switch (this) {
    standard => null,
    gabel => 'GabelTheme',
  };

  /// The Dart expression that builds this preset's `BeakTheme`, or `null`
  /// for the panel's own default.
  String? get expression => className == null ? null : '$className()';

  /// The library that declares [className], or `null` when `beak` already
  /// exports it.
  String? get importUri =>
      package == null ? null : 'package:$package/$package.dart';

  /// Whether [pubspecSource] depends on this preset's package.
  ///
  /// Always true for a preset that needs none. A line scan, like the other
  /// pubspec checks in the CLI: the entry may be a path, git or hosted one.
  bool isAvailableIn(String pubspecSource) =>
      package == null ||
      RegExp('^\\s{2}$package\\s*:', multiLine: true).hasMatch(pubspecSource);
}

/// Problems with the panel theme that only the project around `beak.yaml`
/// can see.
///
/// The preset generates `theme: GabelTheme()`, which needs the package that
/// declares it, and an ejected `lib/theme.dart` is a second source for the
/// same value. A `lib/theme.dart` that still declares the old
/// `beakLightTheme()` and `beakDarkTheme()` pair is never read, so the panel
/// would silently fall back to the stock theme. `beak prepare` refuses on all
/// of these, so `beak doctor` reports them: a doctor that stayed quiet would
/// call a project healthy that cannot be generated, or generated wrongly.
List<BeakDiscoveryIssue> beakThemeIssues(
  BeakProjectConfig config,
  BeakDiscovery discovery, {
  required Directory root,
}) {
  final BeakThemePreset preset = config.themePreset;
  final String? package = preset.package;
  final bool overridden = discovery.overrides.containsKey(
    BeakOverrideKind.theme,
  );
  final File pubspec = File(p.join(root.path, 'pubspec.yaml'));
  final File themeFile = File(
    p.join(root.path, 'lib', BeakOverrideKind.theme.path),
  );
  return [
    if (package != null &&
        pubspec.existsSync() &&
        !preset.isAvailableIn(pubspec.readAsStringSync()))
      BeakDiscoveryIssue(
        path: 'pubspec.yaml',
        message:
            'beak.yaml sets theme.preset: ${preset.name}, which needs the '
            '$package package. Add it under dependencies, next to beak (same '
            'git ref, `path: packages/$package`).',
      ),
    if (package != null && overridden)
      BeakDiscoveryIssue(
        path: 'beak.yaml',
        message:
            'theme.preset: ${preset.name} and lib/theme.dart both set the '
            'panel theme. Remove the preset, or return its theme from '
            'beakTheme() in lib/theme.dart.',
      ),
    if (!overridden &&
        themeFile.existsSync() &&
        themeFile.readAsStringSync().contains('beakLightTheme'))
      const BeakDiscoveryIssue(
        path: 'lib/theme.dart',
        message:
            'declares beakLightTheme() and beakDarkTheme(), which Beak no '
            'longer reads. Replace them with one `BeakTheme beakTheme()`: '
            '`BeakTheme(light: ..., dark: ...)`, see `beak eject theme`.',
      ),
  ];
}
