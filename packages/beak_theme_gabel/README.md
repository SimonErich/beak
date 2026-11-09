# beak_theme_gabel

The official Gabel design for a [Beak](https://github.com/SimonErich/beak)
panel: color tokens for light and dark, the Mona Sans type ramp, themes for
the obers_ui components a panel draws, an icon set drawn as 1.5 px strokes, and
the fonts themselves (Mona Sans, JetBrains Mono, and their Extended cuts).

## When you depend on it

An app that wants this look. The umbrella `beak` package does not depend on
this one, so a panel that keeps the stock theme ships none of its fonts (about
360 KB). Add the package, then select the theme on the panel configuration:

```yaml
dependencies:
  beak: ...
  beak_theme_gabel: ...
```

```dart
import 'package:beak/panel.dart';
import 'package:beak_theme_gabel/beak_theme_gabel.dart';

final config = BeakPanelConfig(
  title: 'Gabel Admin',
  theme: GabelTheme(),
  resources: resources,
);
```

A project that lets `beak prepare` write the panel sets `theme.preset: gabel`
in `beak.yaml` instead, and `beak prepare` writes the same line.

The fonts are declared in this package's pubspec and referenced as
`packages/beak_theme_gabel/Mona Sans`, so the app declares no fonts and adds
no assets. `GabelTheme` also adds the fonts' SIL Open Font License texts to
the app's licence page the first time a panel with it mounts.

## What it exports

| Name | What it is |
| --- | --- |
| `GabelTheme` | A `BeakTheme` with the light and the dark Gabel theme preconfigured |
| `GabelLight`, `GabelDark` | The semantic color tokens, named as in the design |
| `gabelNumericBodyStyle`, `gabelNumericMediumStyle`, `gabelNumericCaptionStyle`, `gabelNumericMetricStyle`, `gabelNumericTotalStyle` | Text styles for amounts: tabular figures, so digits line up |
| `gabelHeading2Style` | The wide heading role the total shares |
| `gabelIconSources` | The icon table, as `OiIconThemeData.sources` |
| `gabelSansFamily`, `gabelMonoFamily` and their fallbacks | The font family names, in the package form |

Part of [Beak](https://github.com/SimonErich/beak). Theming docs:
[Built-in themes](https://simonerich.github.io/beak/theming/built-in-themes/).
