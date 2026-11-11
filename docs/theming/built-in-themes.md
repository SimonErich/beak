---
title: Built-in themes
description: Select the stock theme or the Gabel design with one line, add the package that ships it, and write a built-in theme of your own.
type: guide
audience: [beginner, expert]
status: stable
---

# Built-in themes

A built-in theme is a complete look you select instead of build: colors, type ramp, component styles, icons and, when the look needs them, fonts. After this page you can switch a panel to the Gabel design with one line, in an authored panel and in a generated one, know what that adds to your app, and ship a look of your own the same way.

## At a glance

| Theme | Package | Select it with | Brings |
| --- | --- | --- | --- |
| Standard | `beak` | nothing, or `theme.preset: standard` | The stock obers_ui light and dark theme |
| Gabel | `beak_theme_gabel` | `theme: GabelTheme()`, or `theme.preset: gabel` | Mona Sans and JetBrains Mono (about 360 KB), a 1.5 px stroke icon set, color tokens and component themes for light and dark |

`beak` does not depend on `beak_theme_gabel`. A panel that keeps the stock theme ships none of the Gabel fonts, and a panel that selects Gabel adds the package and nothing else.

## The type every theme shares

A panel takes one `BeakTheme`: a light `OiThemeData`, a dark one, and the licences of whatever the look bundles. `BeakTheme.standard()` is the default, and a built-in theme is a subclass with both modes already configured.

```dart title="packages/beak_frontend/lib/src/panel/beak_theme.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_theme.dart:BeakTheme"
```

The shell's theme toggle switches between the two without rebuilding the router, which is why a theme always supplies both. `BeakPanelConfig.theme` and the `theme:` argument of `BeakPanel` replace the old `theme` and `darkTheme` pair.

## Select Gabel in an authored panel

Depend on the package next to `beak`, with the same source and the same ref:

```yaml
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak
  beak_theme_gabel:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_theme_gabel
```

Import its library in the file that builds the panel, and pass the theme:

```dart
import 'package:beak_theme_gabel/beak_theme_gabel.dart';
```

Foodio does exactly this, in the configuration it builds for the panel:

```dart title="examples/foodio-adminpanel/lib/main.dart"
--8<-- "examples/foodio-adminpanel/lib/main.dart:foodioTheme"
```

Nothing else changes. The app declares no fonts and adds no assets, because the package declares them and the theme names them as `packages/beak_theme_gabel/Mona Sans`.

## Select Gabel in a generated panel

A generated panel has no Dart file to put the line in, so `beak.yaml` carries it:

```yaml
theme:
  preset: gabel
```

`theme.preset` takes `standard` or `gabel`. `beak prepare` writes the import and `theme: GabelTheme()` into `lib/beak/panel.g.dart`, and refuses to generate until the package is in `pubspec.yaml`. `beak doctor` reports the same:

```console
$ beak prepare
Cannot generate: fix these first:
  pubspec.yaml: beak.yaml sets theme.preset: gabel, which needs the beak_theme_gabel package. Add it under dependencies, next to beak (same git ref, `path: packages/beak_theme_gabel`).
```

Add the dependency, run `flutter pub get`, then `beak prepare` again:

```console
$ beak prepare
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  8 of 8 files
$ grep -n "Gabel" lib/beak/panel.g.dart
7:import 'package:beak_theme_gabel/beak_theme_gabel.dart' show GabelTheme;
23:    theme: GabelTheme(),
```

`beak init` repeats the instruction when the `beak.yaml` it finds names a preset whose package the pubspec lacks. A project that ejected `lib/theme.dart` and also sets a preset has two sources for one value, and `beak prepare` refuses it: remove the preset, or return `GabelTheme()` from `beakTheme()`.

## What Gabel adds

| Part | What it is |
| --- | --- |
| Color tokens | `GabelLight` and `GabelDark`, one constant per token of the design, named as in its prototype (`canvas`, `sheet`, `inkMuted`, `primarySoft`) |
| Text ramp | The 14 roles of the type ramp in Mona Sans, plus a field label role (12/16, medium, subtle ink) that captions and input labels share |
| Component themes | Buttons, inputs, tables, cards, the sidebar (64 px compact width), badges, banners, tabs, charts, field displays and more, for both modes |
| Icons | `gabelIconSources`, the table of redrawn icons the theme hands to `components.icon` |
| Amount styles | `gabelNumericBodyStyle`, `gabelNumericMediumStyle`, `gabelNumericCaptionStyle`, `gabelNumericMetricStyle` and `gabelNumericTotalStyle`, text styles with tabular figures for money |
| Fonts | Mona Sans and JetBrains Mono, each with an Extended cut as fallback |

The tokens are plain constants, so a screen can use them where a design asks for an exact color. Foodio colors its chart legends with `GabelLight.chart1`. Prefer `context.colors` where the color should follow the mode.

## Fonts and licences

The package declares four font families in its own `pubspec.yaml`, and Flutter bundles them for every app that depends on it, under the name `packages/beak_theme_gabel/<family>`. The theme refers to them by that name, including the fallbacks, so an app needs no font declaration and no `fontFamily:` of its own. To set a style of your own in Gabel's type, use the exported names:

```dart
const style = TextStyle(fontFamily: gabelSansFamily, fontSize: 14);
```

Both fonts ship under the SIL Open Font License. The texts live next to the font files, and `GabelTheme` adds them to Flutter's `LicenseRegistry` the first time a panel with it mounts, so the app's licence page lists them whichever widget draws it. A second panel, or a second `GabelTheme()`, adds nothing again.

`flutter test` does not load the fonts an app declares. Text in a widget test or a golden is then the test font's squares, about twice as wide as the real glyphs. Load them once:

```dart
import 'package:beak_theme_gabel/testing.dart';

void main() {
  setUpAll(loadGabelFonts);
}
```

## Write a built-in theme of your own

A look that more than one app shares belongs in a package, the way Gabel does.

1. Subclass `BeakTheme` and pass both modes to `super`. Build each `OiThemeData` as [Colors and tokens](colors-and-tokens.md) and [Typography and icons](typography-and-icons.md) describe.
2. Declare the fonts in the package's `pubspec.yaml`, and name them `packages/<your_package>/<family>` in every `fontFamily` and `fontFamilyFallback`.
3. Pass licences you know up front as `licenses:`. A theme that must read its licence texts from assets overrides `registerLicenses()`, as `GabelTheme` does, and registers them once.
4. Keep the package out of `beak`'s dependencies, so only the apps that select it ship its assets.

```dart
class AcmeTheme extends BeakTheme {
  AcmeTheme() : super(light: _buildAcme(dark: false), dark: _buildAcme(dark: true));
}
```

An app selects it as `theme: AcmeTheme()`. `beak.yaml` knows the presets Beak ships, so a generated panel uses a custom theme through `lib/theme.dart` (`beak eject theme`) and returns it from `beakTheme()`.

## Rules and limits

- One theme per panel. `theme.preset` in `beak.yaml` and `lib/theme.dart` both set it, and `beak prepare` refuses the pair.
- Presets are the ones Beak ships. `standard` and `gabel` are the only values of `theme.preset`, and anything else is an error that lists them.
- Fonts are a cost. Gabel adds about 360 KB of font files to a web build.
- A theme changes how the panel is drawn and never how it writes. Numbers, dates and currency come from [Formatting and localization](formatting-and-localization.md), whichever theme is selected.
- Licences register once per app run. A test that calls `LicenseRegistry.reset()` has to reset the guard too, with `GabelTheme.resetLicenseRegistrationForTesting()` (and `BeakTheme.resetLicenseRegistrationForTesting()` for entries passed as `licenses:`).
- `BeakColor` roles still resolve through the theme's swatches. A look that redefines the swatches decides what a `success` badge looks like.

## Verify it

The package tests cover the token mapping, the font names, the licence registration and a golden of a small showcase in each mode:

```console
$ cd packages/beak_theme_gabel
$ flutter test --no-pub
...
All tests passed!
```

The goldens are `test/goldens/showcase_light.png` and `test/goldens/showcase_dark.png`. In an app, run the panel with `theme: GabelTheme()`, press the theme toggle, and open a table, a form and a chart. Every surface should change with the mode, and text should render in Mona Sans.

## Reference

| Symbol | Notes |
| --- | --- |
| `BeakTheme(light:, dark:, licenses:)` | A light and a dark `OiThemeData` and the licences they bundle. |
| `BeakTheme.standard()` | The stock obers_ui light and dark theme. |
| `BeakTheme.registerLicenses()` | Adds the licences to `LicenseRegistry`, once per entry. The panel calls it on mount. |
| `GabelTheme()` | The Gabel design, both modes preconfigured, with the font licences registered once. |
| `GabelLight`, `GabelDark` | The color tokens. |
| `gabelNumeric*Style`, `gabelHeading2Style` | Text styles with tabular figures, and the wide heading role. |
| `gabelIconSources` | `Map<IconData, OiIconSource>` for `OiIconThemeData(sources:)`. |
| `gabelSansFamily`, `gabelMonoFamily` | The font families in the package form, with `...FallbackFamilies` lists. |
| `loadGabelFonts()` | From `package:beak_theme_gabel/testing.dart`. Loads the fonts for tests and goldens. |
| `theme.preset` | `beak.yaml` key: `standard` or `gabel`. |

## Continue reading

- [Theming basics](theming-basics.md) one brand color, the theme toggle and where the theme goes.
- [Colors and tokens](colors-and-tokens.md) how Gabel maps a design's tokens onto an `OiColorScheme`.
- [Typography and icons](typography-and-icons.md) the type ramp, the variable-font trap and the icon table Gabel is built on.
- [Foodio](../examples/foodio.md) a complete panel that selects Gabel.
